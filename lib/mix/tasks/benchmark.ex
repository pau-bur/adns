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
          client: :string
        ]
      )

    samples = Keyword.get(opts, :samples, 1000)
    concurrency = Keyword.get(opts, :concurrency, 1000)
    seconds = Keyword.get(opts, :seconds, 10)
    warmup = Keyword.get(opts, :warmup, 1000)
    client = Keyword.get(opts, :client, "stateful")

    {:ok, _pid} =
      Adns.Benchmark.start_link(concurrency: concurrency, samples: samples, client: client)

    Process.sleep(warmup)

    stats = Adns.Benchmark.stats(seconds)
    IO.inspect(stats)
  end
end
