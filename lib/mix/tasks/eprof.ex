defmodule Mix.Tasks.Eprof do
  use Mix.Task

  def profile_pids(supervisor) do
    supervisor
    |> Supervisor.which_children()
    |> Enum.flat_map(fn
      {_id, pid, :worker, _modules} ->
        [pid]

      {_id, pid, :supervisor, _modules} ->
        profile_pids(pid)

      _ ->
        []
    end)
  end

  @impl true
  def run(args) do
    {opts, _args} = OptionParser.parse!(args, strict: [concurrency: :integer, warmup: :integer])

    concurrency = Keyword.get(opts, :concurrency, 1000)
    warmup = Keyword.get(opts, :warmup, 5000)

    {:ok, pid} = Adns.Benchmark.start_link(concurrency: concurrency, telemetry: false)

    Process.sleep(warmup)

    :eprof.start()

    pid
    |> profile_pids()
    |> :eprof.start_profiling()

    Process.sleep(100)

    :eprof.stop_profiling()
    :eprof.analyze()

    # :observer.start_and_wait()
  end
end
