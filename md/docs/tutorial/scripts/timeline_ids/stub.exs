defmodule Jido.Harness.Event do
  defstruct [:type, :sequence, :turn_id, :request_id, :session_id, payload: %{}]
end
