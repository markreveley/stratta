defmodule Stratta.ThreadServer do
  @moduledoc """
  One process per open thread. It owns a `Jido.Harness.Session`, follows its
  event stream, folds events into a `Stratta.Timeline`, persists the timeline,
  and broadcasts `{:thread, thread_id, snapshot}` on `"thread:<id>"`.

  The harness session is started lazily on the first message, so opening an
  old thread never spawns a CLI. When the provider supports `session/load`,
  a restarted thread resumes its previous provider conversation.
  """
  use GenServer, restart: :transient
  require Logger

  alias Jido.Harness.Session
  alias Stratta.{Providers, Store, Timeline}

  @save_debounce_ms 400

  # -- client -----------------------------------------------------------------

  def start_link(thread_id), do: GenServer.start_link(__MODULE__, thread_id, name: via(thread_id))

  def via(thread_id), do: {:via, Registry, {Stratta.ThreadRegistry, thread_id}}

  def ensure_started(thread_id) do
    case DynamicSupervisor.start_child(Stratta.ThreadSupervisor, {__MODULE__, thread_id}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      other -> other
    end
  end

  def snapshot(id), do: call(id, :snapshot)

  @doc "Session status of a thread without starting its process (`:detached` if it is not running)."
  def status(id) do
    case Registry.lookup(Stratta.ThreadRegistry, id) do
      [{pid, _}] -> GenServer.call(pid, :status)
      [] -> :detached
    end
  catch
    :exit, _ -> :detached
  end

  def send_input(id, text, mode \\ :auto), do: call(id, {:input, text, mode}, 30_000)
  def interrupt(id), do: call(id, :interrupt)
  def respond_approval(id, request_id, decision), do: call(id, {:approval, request_id, decision})
  def set_model(id, model), do: call(id, {:set_model, model}, 30_000)
  def add_notice(id, level, text), do: call(id, {:notice, level, text})
  def stop_session(id), do: call(id, :stop_session)
  def update_meta(id, fun), do: call(id, {:update_meta, fun})

  defp call(id, msg, timeout \\ 10_000) do
    with {:ok, _pid} <- ensure_started(id), do: GenServer.call(via(id), msg, timeout)
  end

  def topic(thread_id), do: "thread:" <> thread_id

  # -- server -----------------------------------------------------------------

  @impl true
  def init(thread_id) do
    case Store.get_thread(thread_id) do
      nil ->
        {:stop, :not_found}

      thread ->
        state = %{
          id: thread_id,
          thread: thread,
          timeline: thread_id |> Store.load_items() |> Timeline.new() |> Timeline.close_dangling(),
          session_id: nil,
          session_state: :detached,
          follower: nil,
          save_timer: nil,
          active_turn: nil,
          queued: 0
        }

        {:ok, state}
    end
  end

  @impl true
  def handle_call(:snapshot, _from, state), do: {:reply, snapshot_of(state), state}
  def handle_call(:status, _from, state), do: {:reply, status_of(state), state}

  def handle_call({:input, text, mode}, _from, state) do
    {wire_text, state} = with_handoff_context(state, text)

    with {:ok, state} <- ensure_session(state),
         {:ok, turn_id, how, state} <- dispatch_input(state, wire_text, mode) do
      state =
        if how == :steer,
          do: state,
          else: update_timeline(state, &Timeline.add_user(&1, turn_id, text, %{"mode" => Atom.to_string(how)}))

      state =
        if how == :steer, do: update_timeline(state, &Timeline.add_notice(&1, :info, "Steered: " <> text)), else: state

      state = touch(state, maybe_title(state.thread, text))
      {:reply, {:ok, how}, broadcast(state)}
    else
      {:error, reason, state} ->
        state = update_timeline(state, &Timeline.add_notice(&1, :error, format_error(reason)))
        {:reply, {:error, reason}, broadcast(state)}
    end
  end

  def handle_call(:interrupt, _from, %{session_id: nil} = state), do: {:reply, {:error, :no_session}, state}

  def handle_call(:interrupt, _from, state), do: {:reply, Session.interrupt(state.session_id, :active), state}

  def handle_call({:approval, request_id, decision}, _from, state) when decision in [:approve, :deny] do
    result =
      if state.session_id,
        do: Session.respond_approval(state.session_id, request_id, decision),
        else: {:error, :no_session}

    state =
      case result do
        :ok ->
          update_timeline(
            state,
            &Timeline.resolve_approval(&1, request_id, if(decision == :approve, do: :approved, else: :denied))
          )

        _ ->
          state
      end

    {:reply, result, broadcast(state)}
  end

  def handle_call({:set_model, model}, _from, state) do
    thread = Map.put(state.thread, "model", model)
    state = %{state | thread: thread}
    Store.put_thread(thread)

    result =
      if state.session_id && state.session_state not in [:closed, :failed, :cancelled, :detached],
        do: Session.configure(state.session_id, %{model: model}),
        else: :ok

    state =
      case result do
        :ok ->
          update_timeline(state, &Timeline.add_notice(&1, :info, "Model set to #{model}."))

        {:error, reason} ->
          update_timeline(state, &Timeline.add_notice(&1, :error, "Could not switch model: #{format_error(reason)}"))
      end

    {:reply, result, broadcast(state)}
  end

  def handle_call({:notice, level, text}, _from, state),
    do: {:reply, :ok, state |> update_timeline(&Timeline.add_notice(&1, level, text)) |> broadcast()}

  def handle_call(:stop_session, _from, state) do
    if state.session_id, do: Session.close(state.session_id)
    {:reply, :ok, state}
  end

  def handle_call({:update_meta, fun}, _from, state) do
    thread = fun.(state.thread)
    Store.put_thread(thread)
    {:reply, {:ok, thread}, broadcast(%{state | thread: thread})}
  end

  # Events arrive from the follower task in order.
  @impl true
  def handle_info({:harness_events, session_id, events}, %{session_id: session_id} = state) do
    state =
      Enum.reduce(events, state, fn event, acc ->
        acc
        |> update_timeline(&Timeline.apply_event(&1, event), false)
        |> track_session(event)
      end)

    {:noreply, state |> schedule_save() |> broadcast()}
  end

  def handle_info({:harness_events, _stale, _events}, state), do: {:noreply, state}

  def handle_info({:follower_done, session_id}, %{session_id: session_id} = state) do
    state = refresh_info(state)
    {:noreply, broadcast(%{state | follower: nil})}
  end

  def handle_info({:follower_done, _}, state), do: {:noreply, state}

  def handle_info(:save, state) do
    Store.save_items(state.id, state.timeline.items)
    {:noreply, %{state | save_timer: nil}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    Store.save_items(state.id, state.timeline.items)
    if state.session_id, do: Session.close(state.session_id)
    :ok
  end

  # -- session management -----------------------------------------------------

  defp ensure_session(%{session_id: sid, session_state: s} = state)
       when is_binary(sid) and s not in [:closed, :failed, :cancelled],
       do: {:ok, state}

  defp ensure_session(state) do
    thread = state.thread
    provider = String.to_existing_atom(thread["provider"])
    spec = Providers.spec(provider)
    request = build_request(thread, spec)

    with :ok <- check_ready(provider, spec) do
      start_session(state, thread, provider, request)
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp check_ready(provider, spec) do
    case Jido.Harness.status(provider) do
      {:ok, status} ->
        if Providers.ready?(status),
          do: :ok,
          else:
            {:error,
             "#{(spec && spec.name) || provider} is #{Providers.label(status)}. Open Providers (⚙) for the install plan, then sign in with its CLI."}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp start_session(state, thread, provider, request) do
    case Session.start(provider, request) do
      {:ok, session_id} ->
        case await_ready(session_id) do
          {:ok, info} ->
            state = %{state | session_id: session_id, session_state: info.state}
            state = start_follower(state)
            thread = Map.put(thread, "provider_session_id", info.provider_session_id || thread["provider_session_id"])
            Store.put_thread(thread)
            {:ok, %{state | thread: thread}}

          {:error, reason} ->
            # Resume failed (the provider may have forgotten the conversation):
            # retry once as a fresh conversation.
            if request[:provider_session_id] do
              thread = Map.delete(thread, "provider_session_id")

              state
              |> Map.put(:thread, thread)
              |> update_timeline(
                &Timeline.add_notice(&1, :warn, "Could not resume the previous conversation; starting a new one.")
              )
              |> ensure_session()
            else
              {:error, reason, state}
            end
        end

      {:error, reason} ->
        {:error, reason, state}
    end
  end

  defp build_request(thread, spec) do
    allowed = Providers.session_options(spec)

    base = %{
      cwd: thread["cwd"],
      turn_runtime_timeout_ms: 30 * 60_000,
      approval_timeout_ms: 10 * 60_000,
      session_idle_timeout_ms: 4 * 60 * 60_000,
      metadata: %{"stratta_thread_id" => thread["id"]}
    }

    candidates = %{
      model: blank_to_nil(thread["model"]),
      approval_mode: atom_or_nil(thread["approval_mode"]),
      sandbox_mode: atom_or_nil(thread["sandbox_mode"]),
      reasoning_effort: atom_or_nil(thread["reasoning_effort"]),
      system_prompt: blank_to_nil(thread["system_prompt"]),
      provider_session_id: if(Providers.supports?(spec, :load_session), do: thread["provider_session_id"])
    }

    Enum.reduce(candidates, base, fn {key, value}, acc ->
      if key in allowed and value not in [nil, :default], do: Map.put(acc, key, value), else: acc
    end)
  end

  defp await_ready(session_id, attempts \\ 150) do
    case Session.info(session_id) do
      {:ok, %{state: :starting}} when attempts > 0 ->
        Process.sleep(100)
        await_ready(session_id, attempts - 1)

      {:ok, %{state: s} = info} when s in [:idle, :running, :awaiting_approval] ->
        {:ok, info}

      {:ok, %{error: error}} ->
        {:error, error || :session_not_ready}

      other ->
        other
    end
  end

  defp start_follower(state) do
    parent = self()
    session_id = state.session_id

    {:ok, pid} =
      Task.start(fn ->
        {:ok, stream} = Session.stream(session_id, cursor: 0, poll_interval_ms: 30)

        stream
        |> Stream.each(&send(parent, {:harness_events, session_id, [&1]}))
        |> Stream.run()

        send(parent, {:follower_done, session_id})
      end)

    %{state | follower: pid}
  end

  defp dispatch_input(state, text, mode) do
    spec = Providers.spec(String.to_existing_atom(state.thread["provider"]))
    busy = state.session_state in [:running, :awaiting_approval]

    result =
      cond do
        mode == :steer and busy and Providers.supports?(spec, :steer) ->
          case Session.steer(state.session_id, text) do
            {:ok, turn_id} -> {:ok, turn_id, :steer}
            {:error, :no_active_turn} -> with_how(Session.follow_up(state.session_id, text), :queued)
            {:error, _} -> with_how(Session.follow_up(state.session_id, text), :queued)
          end

        busy ->
          with_how(Session.follow_up(state.session_id, text), :queued)

        true ->
          case Session.send_message(state.session_id, text) do
            {:ok, turn_id} -> {:ok, turn_id, :sent}
            # Raced with another turn starting: queue instead.
            {:error, _} -> with_how(Session.follow_up(state.session_id, text), :queued)
          end
      end

    case result do
      {:ok, turn_id, how} -> {:ok, turn_id, how, %{state | session_state: :running}}
      {:error, reason} -> {:error, reason, state}
    end
  end

  # A handed-off thread sends the previous agent's transcript once, ahead of
  # the first message, so the new provider starts with the context.
  defp with_handoff_context(%{thread: %{"handoff_context" => ctx} = thread} = state, text)
       when is_binary(ctx) and ctx != "" do
    wire = """
    You are continuing work that another coding agent started in this same working directory.
    Here is the recent conversation for context:

    #{ctx}

    ---
    New request:
    #{text}
    """

    thread = Map.delete(thread, "handoff_context")
    Store.put_thread(thread)
    {wire, %{state | thread: thread}}
  end

  defp with_handoff_context(state, text), do: {text, state}

  defp with_how({:ok, turn_id}, how), do: {:ok, turn_id, how}
  defp with_how(other, _how), do: other

  defp track_session(state, %{type: type} = event) do
    case type do
      :turn_started ->
        %{state | session_state: :running, active_turn: event.turn_id}

      :approval_requested ->
        %{state | session_state: :awaiting_approval}

      :approval_resolved ->
        %{state | session_state: :running}

      t when t in [:turn_completed, :turn_failed, :turn_interrupted] ->
        %{state | session_state: :idle, active_turn: nil}

      :session_idle ->
        %{state | session_state: :idle}

      :queue_changed ->
        %{state | queued: event.payload["queued"] || event.payload["count"] || state.queued}

      :session_closed ->
        %{state | session_state: :closed}

      :session_failed ->
        %{state | session_state: :failed}

      :session_cancelled ->
        %{state | session_state: :cancelled}

      _ ->
        state
    end
  end

  defp refresh_info(%{session_id: nil} = state), do: state

  defp refresh_info(state) do
    case Session.info(state.session_id) do
      {:ok, info} -> %{state | session_state: info.state, queued: info.queued_turns}
      _ -> %{state | session_state: :closed}
    end
  end

  # -- helpers ----------------------------------------------------------------

  defp update_timeline(state, fun, save? \\ true) do
    state = %{state | timeline: fun.(state.timeline)}
    if save?, do: schedule_save(state), else: state
  end

  defp schedule_save(%{save_timer: nil} = state),
    do: %{state | save_timer: Process.send_after(self(), :save, @save_debounce_ms)}

  defp schedule_save(state), do: state

  defp touch(state, thread) do
    thread = Map.put(thread, "updated_at", now())
    Store.put_thread(thread)
    %{state | thread: thread}
  end

  defp maybe_title(%{"title" => title} = thread, text) when title in [nil, "", "New thread"] do
    title = text |> String.split("\n") |> hd() |> String.slice(0, 60)
    Map.put(thread, "title", title)
  end

  defp maybe_title(thread, _text), do: thread

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(Stratta.PubSub, topic(state.id), {:thread, state.id, snapshot_of(state)})
    Phoenix.PubSub.broadcast(Stratta.PubSub, "threads", {:thread_status, state.id, status_of(state), state.thread})
    state
  end

  defp snapshot_of(state) do
    %{
      thread: state.thread,
      items: state.timeline.items,
      status: status_of(state),
      session_id: state.session_id,
      live_model: state.timeline.model,
      usage: state.timeline.usage,
      queued: state.queued
    }
  end

  defp status_of(state), do: state.session_state

  defp now, do: DateTime.utc_now() |> DateTime.to_iso8601()

  defp blank_to_nil(v) when v in [nil, ""], do: nil
  defp blank_to_nil(v), do: v

  defp atom_or_nil(v) when v in [nil, "", "default"], do: nil
  defp atom_or_nil(v) when is_binary(v), do: String.to_existing_atom(v)
  defp atom_or_nil(v), do: v

  def format_error(%Jido.Harness.Error{message: msg, details: details}) when map_size(details) > 0,
    do: "#{msg} (#{inspect(details)})"

  def format_error(%Jido.Harness.Error{message: msg}), do: msg
  def format_error(reason) when is_binary(reason), do: reason
  def format_error(reason), do: inspect(reason)
end
