for {k, v} <- [initial_size: 1, max_runs: 100, max_run_time: :infinity, max_shrinking_steps: 200, inspect_opts: []],
    do: Application.put_env(:stream_data, k, v)

ExUnit.start()
