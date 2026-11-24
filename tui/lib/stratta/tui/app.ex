defmodule Stratta.TUI.App do
  @moduledoc """
  The loop every full-screen view shares: it owns the terminal, feeds keys
  and daemon frames to the view, repaints, and reports status when it changes.

  A view is a module with these functions:

    * `init(sock, arg)` returns `{:ok, state}` or `{:error, message}`
    * `key(key, state, size)` returns `{:cont, state}` or `{:halt, result}`
    * `frame(frame, state)` returns the state after one decoded daemon frame
    * `render(state, size)` returns `{rows, cursor}`
    * `status(state)` returns any term describing what to report
    * `emit(old_status, new_status, state)` returns the escape sequences for a change
    * `leave(state)` returns the escape sequences to write on the way out
  """

  alias Stratta.TUI.{Client, Keys, Render, Term}

  @tick_ms 250

  def run(view, sock, arg) do
    with {:ok, state} <- view.init(sock, arg) do
      :inet.setopts(sock, active: true)
      Term.enter()
      timer = :timer.send_interval(@tick_ms, self(), :tick)

      try do
        loop(%{view: view, sock: sock, state: state, size: Term.size(), pending: nil, painted: nil, status: nil})
      after
        :timer.cancel(timer)
        :inet.setopts(sock, active: false)
        Term.leave()
      end
    end
  end

  defp loop(app) do
    app = app |> report() |> paint()

    receive do
      {:keys, data} ->
        {keys, pending} = Keys.parse(data, app.pending)
        keys(keys, %{app | pending: pending})

      {:tcp, sock, data} when sock == app.sock ->
        loop(%{app | state: app.view.frame(Client.decode(data), app.state)})

      {:tcp_closed, sock} when sock == app.sock ->
        finish(app, {:error, "The daemon went away."})

      :tick ->
        case Term.size() do
          size when size == app.size -> loop(app)
          size -> loop(%{app | size: size, painted: nil})
        end

      :eof ->
        finish(app, :eof)

      _other ->
        loop(app)
    end
  end

  defp keys([], app), do: loop(app)
  defp keys([:ctrl_l | rest], app), do: keys(rest, %{app | painted: nil})

  defp keys([key | rest], app) do
    case app.view.key(key, app.state, app.size) do
      {:cont, state} -> keys(rest, %{app | state: state})
      {:halt, result} -> finish(app, result)
    end
  end

  defp finish(app, result) do
    IO.write(app.view.leave(app.state))
    result
  end

  defp report(app) do
    case app.view.status(app.state) do
      status when status == app.status ->
        app

      status ->
        IO.write(app.view.emit(app.status, status, app.state))
        %{app | status: status}
    end
  end

  defp paint(%{size: {width, _}} = app) do
    {rows, cursor} = app.view.render(app.state, app.size)
    frame = IO.iodata_to_binary(Render.frame(rows, width, cursor))

    if frame == app.painted do
      app
    else
      IO.write(frame)
      %{app | painted: frame}
    end
  end
end
