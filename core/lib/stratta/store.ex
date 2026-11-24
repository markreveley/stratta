defmodule Stratta.Store do
  @moduledoc """
  Small JSON-file store for projects, threads and transcripts.

  Harness sessions do not survive a BEAM restart, so Stratta keeps its own
  durable record: `state.json` holds projects and thread metadata, and each
  thread's timeline lives in `threads/<id>.json`. Writes are serialized
  through this process and written atomically (write + rename).
  """
  use GenServer

  @name __MODULE__

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: @name)

  @doc "Where Stratta keeps its state: `STRATTA_DATA_DIR`, then app config, then `~/.stratta`."
  def data_dir do
    System.get_env("STRATTA_DATA_DIR") || Application.get_env(:stratta, :data_dir) || Path.expand("~/.stratta")
  end

  # -- projects ---------------------------------------------------------------

  def list_projects, do: GenServer.call(@name, :list_projects)
  def get_project(id), do: GenServer.call(@name, {:get, :projects, id})
  def put_project(project), do: GenServer.call(@name, {:put, :projects, project})
  def delete_project(id), do: GenServer.call(@name, {:delete, :projects, id})

  # -- threads ----------------------------------------------------------------

  def list_threads, do: GenServer.call(@name, :list_threads)
  def get_thread(id), do: GenServer.call(@name, {:get, :threads, id})
  def put_thread(thread), do: GenServer.call(@name, {:put, :threads, thread})
  def delete_thread(id), do: GenServer.call(@name, {:delete, :threads, id})

  def load_items(thread_id) do
    case File.read(items_path(thread_id)) do
      {:ok, json} -> Jason.decode!(json)
      {:error, _} -> []
    end
  end

  def save_items(thread_id, items), do: atomic_write(items_path(thread_id), Jason.encode_to_iodata!(items))

  defp items_path(thread_id), do: Path.join([data_dir(), "threads", "#{thread_id}.json"])

  # -- server -----------------------------------------------------------------

  @impl true
  def init(:ok) do
    File.mkdir_p!(Path.join(data_dir(), "threads"))
    {:ok, read_state()}
  end

  @impl true
  def handle_call(:list_projects, _from, state),
    do: {:reply, state.projects |> Map.values() |> Enum.sort_by(& &1["name"]), state}

  def handle_call(:list_threads, _from, state),
    do: {:reply, state.threads |> Map.values() |> Enum.sort_by(& &1["updated_at"], :desc), state}

  def handle_call({:get, kind, id}, _from, state), do: {:reply, Map.get(Map.fetch!(state, kind), id), state}

  def handle_call({:put, kind, %{"id" => id} = record}, _from, state) do
    state = Map.update!(state, kind, &Map.put(&1, id, record))
    write_state(state)
    {:reply, {:ok, record}, state}
  end

  def handle_call({:delete, kind, id}, _from, state) do
    state = Map.update!(state, kind, &Map.delete(&1, id))
    if kind == :threads, do: File.rm(items_path(id))
    write_state(state)
    {:reply, :ok, state}
  end

  defp state_path, do: Path.join(data_dir(), "state.json")

  defp read_state do
    with {:ok, json} <- File.read(state_path()),
         {:ok, %{} = map} <- Jason.decode(json) do
      %{projects: Map.get(map, "projects", %{}), threads: Map.get(map, "threads", %{})}
    else
      _ -> %{projects: %{}, threads: %{}}
    end
  end

  defp write_state(state),
    do:
      atomic_write(
        state_path(),
        Jason.encode_to_iodata!(%{projects: state.projects, threads: state.threads}, pretty: true)
      )

  defp atomic_write(path, data) do
    File.mkdir_p!(Path.dirname(path))
    tmp = path <> ".tmp-#{System.unique_integer([:positive])}"
    File.write!(tmp, data)
    File.rename!(tmp, path)
  end
end
