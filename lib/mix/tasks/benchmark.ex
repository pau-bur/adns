defmodule Mix.Tasks.Benchmark do
  use Mix.Task

  @impl true
  def run(args) do
    {opts, _args} =
      OptionParser.parse!(args,
        strict: [
          concurrency: :integer,
          seconds: :integer,
          warmup: :integer,
          samples: :integer,
          client: :string,
          sync: :boolean
        ]
      )

    samples = Keyword.get(opts, :samples, 1000)
    concurrency = Keyword.get(opts, :concurrency)
    seconds = Keyword.get(opts, :seconds, 10)
    warmup = Keyword.get(opts, :warmup, 5000)
    client = Keyword.get(opts, :client, "stateful")
    sync = Keyword.get(opts, :sync, false)

    if is_nil(concurrency) do
      for concurrency <- [1, 10, 100, 1_000, 2_000] do
        {:ok, pid} =
          Adns.Benchmark.start_link(
            concurrency: concurrency,
            samples: samples,
            client: client,
            sync: sync
          )

        Process.sleep(warmup)

        stats = Adns.Benchmark.stats(seconds)
        IO.inspect(stats, label: "Concurrency: #{concurrency} sync=#{sync}")

        Supervisor.stop(pid)
        Adns.Benchmark.TelemetryHandler.clean()
      end
    else
      {:ok, _pid} =
        Adns.Benchmark.start_link(
          concurrency: concurrency,
          samples: samples,
          client: client,
          sync: sync
        )

      Process.sleep(warmup)

      stats = Adns.Benchmark.stats(seconds)
      IO.inspect(stats)
    end
  end
end
