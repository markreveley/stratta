# Stand-in for Jido.Harness.Event: the fields Stratta.Timeline reads, nothing else.
defmodule Jido.Harness.Event do
  defstruct [:type, :provider, :payload, :turn_id, :sequence, :request_id, :timestamp, :session_id]
  def new!(opts), do: struct!(__MODULE__, opts)
end
