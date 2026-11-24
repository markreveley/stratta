defmodule Stratta.Providers do
  @moduledoc """
  Provider catalogue on top of `Jido.Harness.providers/0` and
  `Jido.Harness.status/1`.

  Status checks spawn CLIs (`--version` and similar) but never send a prompt,
  so they are free. Results are cached for a minute in `:persistent_term`
  because the new-thread form asks often.
  """

  alias Jido.Harness.{AdapterSpec, ProviderStatus}

  @ttl_ms 60_000
  @cache_key {__MODULE__, :statuses}

  # Options Stratta knows how to put in a SessionRequest. Each provider only
  # receives the subset its ACP profile declares.
  @stratta_options [:model, :approval_mode, :sandbox_mode, :reasoning_effort, :system_prompt, :provider_session_id]

  @doc "All registered provider specs, demo first."
  def specs do
    Jido.Harness.providers()
    |> Enum.sort_by(fn spec -> {spec.provider != :demo, spec.name} end)
  end

  def spec(provider) when is_atom(provider), do: Enum.find(specs(), &(&1.provider == provider))

  def spec(provider) when is_binary(provider) do
    Enum.find(specs(), &(Atom.to_string(&1.provider) == provider))
  end

  @doc "Cached status map: provider => %ProviderStatus{} | {:error, reason}."
  def statuses(opts \\ []) do
    now = System.monotonic_time(:millisecond)

    case :persistent_term.get(@cache_key, nil) do
      {at, map} when now - at < @ttl_ms ->
        if opts[:refresh], do: refresh(), else: map

      _ ->
        refresh()
    end
  end

  def refresh do
    map =
      specs()
      |> Task.async_stream(fn spec -> {spec.provider, safe_status(spec.provider)} end,
        timeout: 20_000,
        on_timeout: :kill_task,
        max_concurrency: 6
      )
      |> Enum.reduce(%{}, fn
        {:ok, {provider, status}}, acc -> Map.put(acc, provider, status)
        {:exit, _}, acc -> acc
      end)

    :persistent_term.put(@cache_key, {System.monotonic_time(:millisecond), map})
    map
  end

  defp safe_status(provider) do
    case Jido.Harness.status(provider) do
      {:ok, status} -> status
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  def ready?(%ProviderStatus{} = status), do: ProviderStatus.ready?(status)
  def ready?(_), do: false

  @doc "Session options (from `@stratta_options`) this provider accepts."
  def session_options(%AdapterSpec{acp_agent: acp} = spec) when not is_nil(acp) do
    declared =
      case acp.session_options do
        :adapter -> spec.normalized_options
        list -> list
      end

    Enum.filter(@stratta_options, &(&1 in (declared ++ acp.configuration_options)))
  end

  def session_options(_), do: []

  @doc "Allowed values for a normalized option, or nil for free-form."
  def allowed_values(%AdapterSpec{normalized_values: values}, field), do: Map.get(values, field)

  def supports?(%AdapterSpec{acp_agent: %{capabilities: caps}}, capability), do: Map.get(caps, capability, false)
  def supports?(_, _), do: false

  def can_switch_model?(%AdapterSpec{acp_agent: acp} = spec) when not is_nil(acp),
    do: :model in acp.configuration_options and supports?(spec, :dynamic_model)

  def can_switch_model?(_), do: false

  @doc "A short human label for a status."
  def label(%ProviderStatus{} = s) do
    cond do
      ProviderStatus.ready?(s) -> "ready"
      not s.installed -> "not installed"
      s.authenticated == false -> "not signed in"
      not s.session_ready -> "ACP entry point missing"
      true -> "not ready"
    end
  end

  def label({:error, _}), do: "error"
  def label(nil), do: "checking…"

  @doc "Install plan without running anything."
  def install_plan(provider) do
    case Jido.Harness.install(provider, dry_run: true) do
      {:ok, plan} -> {:ok, plan}
      other -> other
    end
  rescue
    e -> {:error, Exception.message(e)}
  end
end
