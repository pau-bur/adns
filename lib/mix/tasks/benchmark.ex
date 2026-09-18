defmodule Mix.Tasks.Benchmark do
  use Mix.Task

  @impl true
  def run(args) do
    {opts, _args} =
      OptionParser.parse!(args,
        strict: [concurrency: :integer, seconds: :integer, warmup: :integer]
      )

    concurrency = Keyword.get(opts, :concurrency, 1000)
    seconds = Keyword.get(opts, :seconds, 10)
    warmup = Keyword.get(opts, :warmup, 1000)

    {:ok, _pid} = Adns.Benchmark.start_link(concurrency: concurrency)

    Process.sleep(warmup)

    stats = Adns.Benchmark.stats(seconds)
    IO.inspect(stats)
  end
end
