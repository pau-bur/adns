defmodule Adns.Benchmark do
  use Supervisor
  alias Adns.Class
  alias Adns.RR
  alias Adns.Qtypes
  alias Adns.Qclass
  alias Adns.Question
  alias Adns.Resolver.Cache

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @doc """
  Starts only the cached UDP server (no Elixir load workers).

  Used by `mix dnsperf` so an external tool can drive the server.
  """
  def start_server(opts \\ []) do
    Supervisor.start_link(__MODULE__, Keyword.put(opts, :mode, :server),
      name: Adns.Benchmark.Server
    )
  end

  def cache_data() do
    [
      {%Question{qname: "www.test.com", qclass: Qclass.in(), qtype: Qtypes.a()},
       %RR.Known{name: "test.com", ttl: 3000, class: Class.in(), rdata: %RR.A{address: 12314}}},
      {%Question{qname: "other.test.com", qclass: Qclass.in(), qtype: Qtypes.cname()},
       %RR.Known{
         name: "test.com",
         ttl: 3000,
         class: Class.in(),
         rdata: %RR.CNAME{cname: "www.test.com"}
       }},
      {%Question{qname: "some.test.com", qclass: Qclass.in(), qtype: Qtypes.txt()},
       %RR.Known{name: "test.com", ttl: 3000, class: Class.in(), rdata: %RR.TXT{txtdata: "text"}}}
    ]
  end

  def random_question() do
    data = cache_data()
    len = length(data)
    idx = :rand.uniform(len) - 1
    {question, _} = Enum.at(data, idx)
    question
  end

  defp seed_cache(cache) do
    Enum.each(cache_data(), fn {question, answer} ->
      Cache.register(cache, question, {[answer], [], []})
    end)
  end

  def init(opts) do
    mode = Keyword.get(opts, :mode, :full)
    port = Keyword.get(opts, :port, 8000)
    sync = Keyword.get(opts, :sync, false)
    concurrency = Keyword.get(opts, :concurrency, 1000)
    samples = Keyword.get(opts, :samples, 1000)
    min_latency = Keyword.get(opts, :min_latency, 1000)
    client = Keyword.get(opts, :client, "stateful")
    telemetry = Keyword.get(opts, :telemetry, true)

    if telemetry and mode == :full do
      Adns.Benchmark.TelemetryHandler.init(sample_rate: samples, min_latency: min_latency)
    end

    cache = Cache.config()
    seed_cache(cache)

    server_opts = [
      port: port,
      resolver: Adns.Resolver.Cache,
      config: cache,
      sync: sync
    ]

    children =
      case mode do
        :server ->
          [{Adns.Server.UDP, server_opts}]

        :full ->
          [
            {Adns.Server.UDP, server_opts},
            client == "stateful" && {Adns.Client, debug: true},
            {Adns.Benchmark.Workers, concurrency: concurrency, client: client}
          ]
          |> Enum.filter(& &1)
      end

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
    Adns.Benchmark.TelemetryHandler.start_registering()
    time = System.monotonic_time(:microsecond)

    Process.sleep(1000 * seconds)

    Adns.Benchmark.TelemetryHandler.stop_registering()
    requests = Adns.Benchmark.TelemetryHandler.requests()
    elapsed = System.monotonic_time(:microsecond) - time
    rps = requests / (elapsed / 1_000_000)

    latencies =
      Adns.Benchmark.TelemetryHandler.latencies()
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
  alias Adns.Rcode
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
        question = Adns.Benchmark.random_question()

        request = %Adns.Client.Request{
          address: {127, 0, 0, 1},
          port: 8000,
          opcode: Adns.Opcode.query(),
          rd: false,
          questions: [question]
        }

        Supervisor.child_spec(
          {Task,
           fn ->
             start_loop(request, samples, client)
           end},
          id: {:worker, id}
        )
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp start_loop(request, samples, "once") do
    loop_once(request, samples)
  end

  defp start_loop(request, samples, "stateful") do
    loop_stateful(request, samples)
  end

  defp start_loop(request, samples, "sustained") do
    {:ok, socket} = Adns.Client.start_client()
    loop_sustained(request, samples, socket)
  end

  defp handle_res(res = %Adns.Client.Response{rcode: rcode}) do
    if rcode == Rcode.server_failure() do
      IO.inspect(res)
    end
  end

  defp loop_stateful(request, samples) do
    start = System.monotonic_time(:microsecond)
    {:ok, res} = Adns.Client.request(request, :infinity)
    handle_res(res)

    latency = System.monotonic_time(:microsecond) - start

    :ok = :telemetry.execute([:dns, :worker, :done], %{latency: latency}, %{})

    loop_stateful(request, samples)
  end

  defp loop_once(request, samples) do
    start = System.monotonic_time(:microsecond)
    {:ok, res} = Adns.Client.request_once(request)
    handle_res(res)

    latency = System.monotonic_time(:microsecond) - start

    :ok = :telemetry.execute([:dns, :worker, :done], %{latency: latency}, %{})

    loop_once(request, samples)
  end

  defp loop_sustained(request, samples, socket) do
    start = System.monotonic_time(:microsecond)
    {:ok, res} = Adns.Client.request_client(socket, request)
    handle_res(res)

    latency = System.monotonic_time(:microsecond) - start

    :ok = :telemetry.execute([:dns, :worker, :done], %{latency: latency}, %{})

    loop_sustained(request, samples, socket)
  end
end

defmodule Adns.Benchmark.TelemetryHandler do
  require Logger

  def init(config) do
    {:ok, _} = Application.ensure_all_started(:telemetry)

    :logger.update_formatter_config(:default, %{
      metadata: [
        :id,
        :genserver_receive_us,
        :encode_us,
        :send_us,
        :receive_us,
        :decode_us,
        :genserver_send_us,
        :genserver_total_us,
        :total_us,
        :handle_us
      ]
    })

    :ok =
      :telemetry.attach_many(
        "client-telemetry-handler",
        [[:dns, :client, :done], [:dns, :client, :error]],
        &__MODULE__.handle_event/4,
        config
      )

    :ok =
      :telemetry.attach(
        "worker-telemetry-handler",
        [:dns, :worker, :done],
        &__MODULE__.handle_event/4,
        config
      )

    :ok =
      :telemetry.attach_many(
        "server-telemetry-handler",
        [[:dns, :server, :done], [:dns, :server, :error]],
        &__MODULE__.handle_event/4,
        config
      )

    :ets.new(:adns_stats, [
      :named_table,
      :set,
      :public
    ])

    :ets.insert(:adns_stats, [{:requests, 0}, {:latencies, []}, {:started, false}])
  end

  def clean() do
    :telemetry.detach("client-telemetry-handler")
    :telemetry.detach("worker-telemetry-handler")
    :telemetry.detach("server-telemetry-handler")
  end

  def started?() do
    :ets.lookup_element(:adns_stats, :started, 2)
  end

  def start_registering() do
    :ets.insert(:adns_stats, {:started, true})
  end

  def stop_registering() do
    :ets.insert(:adns_stats, {:started, false})
  end

  def requests() do
    :ets.lookup_element(:adns_stats, :requests, 2)
  end

  defp increment_requests() do
    if started?() do
      :ets.update_counter(:adns_stats, :requests, {2, 1})
    end
  end

  defp register_latency(latency) do
    if started?() do
      id = System.unique_integer([:positive])
      :ets.insert(:adns_stats, {{:latency, id}, latency})
    end
  end

  def latencies() do
    :ets.match_object(:adns_stats, {{:latency, :_}, :_})
    |> Enum.map(fn {{:latency, _key}, latency} -> latency end)
  end

  defp sample?(sample_rate) do
    if sample_rate == :all do
      true
    else
      :rand.uniform(sample_rate) == 1
    end
  end

  def handle_event([:dns, :client, :done], timings, metadata,
        sample_rate: sample_rate,
        min_latency: min_latency
      ) do
    %{
      request_start: request_start,
      genserver_receive: genserver_receive,
      client_encode: client_encode,
      client_send: client_send,
      client_receive: client_receive,
      client_decode: client_decode,
      request_end: request_end
    } = timings

    total_us = request_end - request_start

    if started?() && sample?(sample_rate) && total_us >= min_latency do
      diffs = %{
        genserver_receive_us: genserver_receive - request_start,
        encode_us: client_encode - genserver_receive,
        send_us: client_send - client_encode,
        receive_us: client_receive - client_send,
        decode_us: client_decode - client_receive,
        genserver_send_us: request_end - client_decode,
        genserver_total_us: client_decode - genserver_receive,
        total_us: total_us
      }

      {:message_queue_len, len} = Process.info(self(), :message_queue_len)
      diffs = Map.put(diffs, :queue_len, len)
      Logger.info("DNS client timings", Map.merge(diffs, metadata))
    end
  end

  def handle_event([:dns, :client, :error], reason, metadata, _config) do
    Logger.info("DNS client error", Map.merge(reason, metadata))
  end

  def handle_event([:dns, :worker, :done], %{latency: latency}, _metadata,
        sample_rate: sample_rate,
        min_latency: _
      ) do
    increment_requests()

    if sample?(sample_rate) do
      register_latency(latency)
    end
  end

  def handle_event([:dns, :server, :done], timings, metadata,
        sample_rate: sample_rate,
        min_latency: min_latency
      ) do
    total_us = timings.encoded_time - timings.received_time

    if started?() && sample?(sample_rate) && total_us >= min_latency do
      %{
        received_time: received_time,
        decoded_time: decoded_time,
        handled_time: handled_time,
        encoded_time: encoded_time
      } = timings

      diffs = %{
        decode_us: decoded_time - received_time,
        handle_us: handled_time - decoded_time,
        encode_us: encoded_time - handled_time,
        total_us: total_us
      }

      Logger.info("DNS server timings", Map.merge(diffs, metadata))
    end
  end

  def handle_event([:dns, :server, :error], reason, metadata, _config) do
    Logger.info("DNS server error", Map.merge(reason, metadata))
  end
end
