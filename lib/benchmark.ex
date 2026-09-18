defmodule Adns.Benchmark do
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def init(opts) do
    concurrency = Keyword.get(opts, :concurrency, 1000)
    samples = Keyword.get(opts, :samples, 1000)
    client = Keyword.get(opts, :client, "stateful")

    Adns.Benchmark.Resolver.create_table()

    children =
      [
        {Adns.Server.UDP, port: 8000, resolver: Adns.Benchmark.Resolver, name: Adns.Server.UDP},
        client == "stateful" && Adns.Client,
        {Adns.Benchmark.Workers, concurrency: concurrency, samples: samples, client: client}
      ]
      |> Enum.filter(fn child -> child end)

    Adns.Supervisor.init(children, strategy: :one_for_one)
  end

  defp mean(latencies) do
    len = length(latencies)
    Enum.reduce(latencies, fn latency, acc -> latency + acc end) / len
  end

  def pX(latencies, percentile) do
    len = length(latencies)
    idx = ceil(percentile / 100 * len) - 1
    Enum.at(latencies, max(idx, 0))
  end

  def underXus(latencies, us) do
    case Enum.find_index(latencies, fn lat -> lat >= us end) do
      nil -> 1
      idx -> idx / length(latencies)
    end
  end

  def stats(seconds \\ 1) do
    requests = Adns.Benchmark.Resolver.requests()
    time = System.monotonic_time(:microsecond)

    Process.sleep(1000 * seconds)

    new_requests = Adns.Benchmark.Resolver.requests()
    elapsed = System.monotonic_time(:microsecond) - time
    rps = (new_requests - requests) / (elapsed / 1_000_000)

    latencies =
      Adns.Benchmark.Workers.latencies()
      |> Enum.sort()

    samples = length(latencies)

    min = Enum.at(latencies, 0)
    max = Enum.at(latencies, length(latencies) - 1)

    under_1ms = underXus(latencies, 1000)
    mean = mean(latencies)

    p50 = pX(latencies, 50)
    p95 = pX(latencies, 95)
    p99 = pX(latencies, 99)
    p999 = pX(latencies, 99.9)

    %{
      rps: rps,
      min: min,
      max: max,
      mean: mean,
      p50: p50,
      p95: p95,
      p99: p99,
      p999: p999,
      under_1ms: under_1ms,
      samples: samples
    }
  end
end

defmodule Adns.Benchmark.Workers do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def init(opts) do
    concurrency = Keyword.get(opts, :concurrency, 1000)
    samples = Keyword.get(opts, :samples, 1000)
    client = Keyword.get(opts, :client, "stateful")

    children =
      for id <- 1..concurrency do
        Supervisor.child_spec({Task, fn -> start_loop(samples, client) end}, id: {:worker, id})
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp register_latency(latency) do
    latencies = latencies()
    :ets.insert(:adns_stats, {:latencies, [latency | latencies]})
  end

  def latencies() do
    :ets.lookup_element(:adns_stats, :latencies, 2)
  end

  defp start_loop(samples, "once") do
    loop_once(samples)
  end

  defp start_loop(samples, "stateful") do
    loop_stateful(samples)
  end

  defp start_loop(samples, "sustained") do
    socket = Adns.Client.start_client()
    loop_sustained(samples, socket)
  end

  defp loop_stateful(samples) do
    request =
      %Adns.Client.Request{
        address: {127, 0, 0, 1},
        port: 8000,
        opcode: 0,
        rd: 1,
        questions: [%Adns.Question{qname: "www.test.com", qclass: 0, qtype: 0}]
      }

    if :rand.uniform(samples) == 1 do
      start = System.monotonic_time(:microsecond)

      request = %{request | opcode: 1}

      Adns.Client.request(request, :infinity)

      latency = System.monotonic_time(:microsecond) - start
      register_latency(latency)
    end

    Adns.Client.request(request, :infinity)

    loop_stateful(samples)
  end

  defp loop_once(samples) do
    request =
      %Adns.Client.Request{
        address: {127, 0, 0, 1},
        port: 8000,
        opcode: 0,
        rd: 1,
        questions: [%Adns.Question{qname: "www.test.com", qclass: 0, qtype: 0}]
      }

    if :rand.uniform(samples) == 1 do
      start = System.monotonic_time(:microsecond)

      request = %{request | opcode: 1}

      Adns.Client.request_once(request)

      latency = System.monotonic_time(:microsecond) - start
      register_latency(latency)
    end

    Adns.Client.request_once(request)

    loop_once(samples)
  end

  defp loop_sustained(samples, socket) do
    request =
      %Adns.Client.Request{
        address: {127, 0, 0, 1},
        port: 8000,
        opcode: 0,
        rd: 1,
        questions: [%Adns.Question{qname: "www.test.com", qclass: 0, qtype: 0}]
      }

    if :rand.uniform(samples) == 1 do
      start = System.monotonic_time(:microsecond)

      request = %{request | opcode: 1}

      Adns.Client.request_client(socket, request)

      latency = System.monotonic_time(:microsecond) - start
      register_latency(latency)
    end

    Adns.Client.request_client(socket, request)

    loop_sustained(samples, socket)
  end
end

defmodule Adns.Benchmark.Resolver do
  @behaviour Adns.Resolver

  def create_table() do
    :ets.new(:adns_stats, [
      :named_table,
      :set,
      :public
    ])

    :ets.insert(:adns_stats, [{:requests, 0}, {:latencies, []}])
  end

  def requests() do
    :ets.lookup_element(:adns_stats, :requests, 2)
  end

  def increment_requests() do
    :ets.update_counter(:adns_stats, :requests, {2, 1})
  end

  def resolve(%Adns.Resolver.Request{}) do
    answer = %Adns.RR.Known{name: "name", class: 0, ttl: 3000, rdata: %Adns.RR.A{address: 12345}}

    increment_requests()

    %Adns.Resolver.Response{
      answers: [answer],
      authority: [],
      additional: [],
      aa: 1,
      ra: 0,
      rcode: 0
    }
  end
end
