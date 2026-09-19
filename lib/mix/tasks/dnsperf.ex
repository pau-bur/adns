defmodule Mix.Tasks.Dnsperf do
  @moduledoc """
  Load-test the Adns UDP server with [dnsperf](https://github.com/DNS-OARC/dnsperf).

      mix dnsperf
      mix dnsperf --clients 50 --threads 4 --seconds 10 --outstanding 100
      mix dnsperf --sync

  Requires the `dnsperf` binary on `PATH` (e.g. `apt install dnsperf`).
  """

  use Mix.Task

  @shortdoc "Benchmark Adns with dnsperf"

  @default_query_file "bench/dnsperf.query"

  @impl true
  def run(args) do
    {opts, _args} =
      OptionParser.parse!(args,
        strict: [
          port: :integer,
          clients: :integer,
          threads: :integer,
          seconds: :integer,
          outstanding: :integer,
          max_qps: :integer,
          datafile: :string,
          family: :string,
          sync: :boolean,
          extra: :keep
        ]
      )

    ensure_dnsperf!()

    port = Keyword.get(opts, :port, 8000)
    clients = Keyword.get(opts, :clients, 10)
    threads = Keyword.get(opts, :threads, 2)
    seconds = Keyword.get(opts, :seconds, 10)
    outstanding = Keyword.get(opts, :outstanding, 100)
    datafile = Keyword.get(opts, :datafile, @default_query_file) |> Path.expand()
    family = Keyword.get(opts, :family, "inet")
    max_qps = Keyword.get(opts, :max_qps)
    sync = Keyword.get(opts, :sync, false)
    extras = Keyword.get_values(opts, :extra)

    unless File.exists?(datafile) do
      Mix.raise("dnsperf query file not found: #{datafile}")
    end

    Mix.shell().info("Starting Adns UDP server on 127.0.0.1:#{port} (sync=#{sync})")

    {:ok, server} =
      Adns.Benchmark.start_server(
        port: port,
        sync: sync,
        telemetry: false
      )

    # Let listeners bind before driving traffic.
    Process.sleep(1000)

    dnsperf_args =
      [
        "-s",
        "127.0.0.1",
        "-p",
        Integer.to_string(port),
        "-d",
        datafile,
        "-c",
        Integer.to_string(clients),
        "-T",
        Integer.to_string(threads),
        "-l",
        Integer.to_string(seconds),
        "-q",
        Integer.to_string(outstanding),
        "-f",
        family
      ]
      |> maybe_max_qps(max_qps)
      |> Kernel.++(extras)

    Mix.shell().info("Running: dnsperf #{Enum.join(dnsperf_args, " ")}")

    {output, code} =
      System.cmd("dnsperf", dnsperf_args, stderr_to_stdout: true)

    IO.write(output)

    Supervisor.stop(server)

    if code != 0 do
      Mix.raise("dnsperf exited with status #{code}")
    end
  end

  defp maybe_max_qps(args, nil), do: args

  defp maybe_max_qps(args, max_qps) when is_integer(max_qps) do
    args ++ ["-Q", Integer.to_string(max_qps)]
  end

  defp ensure_dnsperf!() do
    case System.find_executable("dnsperf") do
      nil ->
        Mix.raise("""
        dnsperf not found on PATH.

        Install it (Debian/Ubuntu): apt install dnsperf
        Or build from https://github.com/DNS-OARC/dnsperf
        """)

      _path ->
        :ok
    end
  end
end
