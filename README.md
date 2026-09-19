# Adns

[![Elixir](https://img.shields.io/badge/Elixir-~%3E%201.18-4B275F?logo=elixir)](https://elixir-lang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)](mix.exs)

Elixir DNS **codec + concurrent UDP client/server** with pluggable resolvers.
Implements the classic [RFC 1035](https://www.rfc-editor.org/rfc/rfc1035.html) message format (§4.1) — header, questions, resource records, and name compression on decode.

Built as a network service stack: shared-socket UDP server, GenServer request correlation, `:telemetry` phase timings, and a load harness that reports RPS and latency percentiles.

## Features

- **Concurrent UDP server** — shared socket; async replies on a `Task.Supervisor`, or `sync: true` for inline handle/reply
- **Request/response correlation** — GenServer client matches in-flight queries by 16-bit DNS ID under concurrency
- **Clear service boundaries** — `Adns.Resolver` behaviour; transport stays separate from lookup logic
- **Observability** — `:telemetry` events with decode / handle / encode (and client encode / send / receive / decode) timings
- **Measured performance** — `mix benchmark` and `mix dnsperf` report RPS / QPS and latency
- **Protocol-correct failures** — valid header + broken body → `FORMERR` reply with the same ID
- **Extensible RR codecs** — ETS registry (`read_concurrency: true`); unknown types kept as opaque binaries

## Quick start

```elixir
# mix.exs
def deps do
  [{:adns, "~> 0.1.0"}]
end
```

```elixir
Adns.RR.Registry.init(Adns.RR.Registry.default_codecs())

msg = %Adns.Message{
  id: 1,
  qr: :question,
  opcode: :QUERY,
  aa: false,
  tc: false,
  rd: true,
  ra: false,
  rcode: :ok,
  questions: [%Adns.Question{qname: "example.com", qtype: :A, qclass: :IN}],
  answers: [],
  authority: [],
  additional: []
}

bin = Adns.Message.encode(msg)
{:ok, ^msg} = Adns.Message.decode(bin)
```

## Build a DNS server

Implement the resolver behaviour, then plug it into the UDP server:

```elixir
defmodule MyResolver do
  use Adns.Resolver

  @impl true
  def resolve(%Adns.Resolver.Request{questions: questions}, _config) do
    answers =
      for %Question{qname: name, qtype: :A} <- questions do
        %RR.Known{
          name: name,
          class: :IN,
          ttl: 60,
          rdata: %RR.A{address: 0x7F000001}
        }
      end

    %Adns.Resolver.Response{
      answers: answers,
      authority: [],
      additional: [],
      aa: true,
      ra: false,
      rcode: :ok
    }
  end
end

# Boot RR codecs, then the server (port 8053 for non-root)
{:ok, _} =
  Adns.Supervisor.start_link(
    [{Adns.Server.UDP, port: 8053, resolver: MyResolver, config: nil}],
    strategy: :one_for_one
  )
```

Or use the built-in ETS cache resolver:

```elixir
cache = Adns.Resolver.Cache.config()
question = %Adns.Question{qname: "example.com", qtype: :A, qclass: :IN}

Adns.Resolver.Cache.register(cache, question, {
  [%Adns.RR.Known{name: "example.com", class: :IN, ttl: 300, rdata: %Adns.RR.A{address: 0x08080808}}],
  [],
  []
})

{:ok, _} =
  Adns.Supervisor.start_link(
    [{Adns.Server.UDP, port: 8053, resolver: Adns.Resolver.Cache, config: cache}],
    strategy: :one_for_one
  )
```

## Client query

```elixir
{:ok, _} = Adns.Client.start_link([])

{:ok, response} =
  Adns.Client.request(%Adns.Client.Request{
    address: {127, 0, 0, 1},
    port: 8053,
    opcode: :QUERY,
    rd: true,
    questions: [%Adns.Question{qname: "example.com", qtype: :A, qclass: :IN}]
  })
```

One-shot helpers: `Adns.Client.request_once/1` and `Adns.Client.request_client/2` (reuse a socket).

## Architecture

```
UDP packet
    │
    ▼
Server.UDP  (shared socket; async Tasks or sync loop)
    │
    ▼
Message.decode
    │
    ├── {:ok, msg}      → Resolver.resolve/2 → Message.encode → reply
    └── {:partial, h, _} → FORMERR (same ID) → reply
```

The server does not embed lookup logic. Resolvers return answers, authority, additional, and flags (`aa`, `ra`, `rcode`); the server assembles the wire response.

## Benchmarks

### Built-in Elixir client

```bash
mix benchmark
mix benchmark --concurrency 100 --seconds 8 --warmup 3000 --client stateful
mix benchmark --concurrency 100 --seconds 5 --sync
```

Clients: `stateful` (shared GenServer), `once` (new socket per query), `sustained` (reused socket).  
`--sync` runs the UDP server recv/handle/reply on one process (no per-query Task).

**Sample run** (stateful client, concurrency 100, 8s, warmup 3s):

| Metric | Value |
|--------|-------|
| RPS | ~65k |
| p50 | 274 µs |
| p95 | 407 µs |
| p99 | 456 µs |
| p999 | 500 µs |
| under 1ms | 100% |

### dnsperf (industry-standard)

Requires [`dnsperf`](https://github.com/DNS-OARC/dnsperf) on `PATH` (`apt install dnsperf`).

```bash
mix dnsperf
mix dnsperf --clients 50 --threads 4 --seconds 10 --outstanding 100
mix dnsperf --sync
```

Starts the cached UDP server, then drives it with dnsperf using [`bench/dnsperf.query`](bench/dnsperf.query).

**Sample run** (`mix dnsperf --clients 10 --threads 2 --seconds 5 --outstanding 100`):

| Metric | Value |
|--------|-------|
| Queries / s | ~178k |
| Completed | 99.99% |
| Avg latency | ~91 µs |
| Response codes | NOERROR 100% |

Hardware: 13th Gen Intel Core i7-13620H (16 threads), Linux. Numbers are localhost client↔server; treat them as a relative baseline.

Profile hotspots with `mix eprof --concurrency 1000 --warmup 5000`.

## Wire format (RFC 1035)

Header layout matches [§4.1.1](https://www.rfc-editor.org/rfc/rfc1035.html#section-4.1.1):

```
  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
|                      ID                       |
+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
|QR|   Opcode  |AA|TC|RD|RA|   Z    |   RCODE   |
+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
|                    QDCOUNT                    |
|                    ANCOUNT                    |
|                    NSCOUNT                    |
|                    ARCOUNT                    |
+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
```

Mapped to `Adns.Header` / `Adns.Message` fields (`id`, `qr`, `opcode`, `aa`, `tc`, `rd`, `ra`, `rcode`, plus question and RR lists). Reserved `Z` bits are encoded as `0` and required to be `0` on decode.

**Name compression (§4.1.4):** decode follows pointers (`11` + 14-bit offset) into the full message buffer. Encode currently writes labels in full (no pointer emission yet).

**Supported RR types (classic set):** A, NS, MD, MF, CNAME, SOA, MB, MG, MR, NULL, WKS, PTR, HINFO, MINFO, MX, TXT.

## API overview

| Module | Role |
|--------|------|
| `Adns.Message` | Encode/decode full messages; `{:partial, header, reason}` on body errors |
| `Adns.Header` / `Adns.Question` / `Adns.Label` | Section and name codecs |
| `Adns.RR` | Known (typed RDATA) vs Unhandled (raw type + binary) |
| `Adns.RR.Registry` / `Adns.RR.Codec` | Pluggable RDATA codecs |
| `Adns.Resolver` | Behaviour: `resolve/2` → `Response` |
| `Adns.Resolver.Cache` | ETS-backed resolver |
| `Adns.Server` | Decode → resolve → encode; FORMERR on partial |
| `Adns.Server.UDP` | Shared-socket UDP listener (`sync:` for inline replies) |
| `Adns.Client` | Stateful GenServer client + one-shot helpers |
| `Adns.Supervisor` | Init RR registry, then supervise children |

### Codec

```elixir
Adns.Message.encode(t()) :: binary()
Adns.Message.decode(binary()) ::
  {:ok, t()} | {:error, reason} | {:partial, Adns.Header.t(), reason}

Adns.RR.encode(t()) :: binary()
Adns.RR.decode(binary(), message :: binary()) :: {:ok, {t(), rest}} | {:error, reason}
```

### Resolver

```elixir
@callback resolve(Adns.Resolver.Request.t(), config :: term()) ::
            Adns.Resolver.Response.t()
```

### Server / client

```elixir
Adns.Server.handle_message_stream(binary(), resolver, config) :: {:ok, binary()} | :no_message
Adns.Server.UDP.start_link(port:, resolver:, config:, sync: false)

Adns.Client.start_link(opts)
Adns.Client.request(request, timeout \\ 3000) :: {:ok, Response.t()} | {:error, term()}
```

Custom RR types: implement `Adns.RR.Codec`, then `Adns.RR.Registry.register/1` (or pass codecs into `Adns.Supervisor`).

## Status

**In scope today:** RFC 1035 classic RRs, UDP client/server, cache resolver, telemetry, benchmarks.

**Not yet:** AAAA / EDNS0 / DNSSEC, encode-side name compression, production-ready TCP (length-prefixed path is incomplete).

## Development

```bash
mix deps.get
mix test
mix format
mix benchmark
mix dnsperf
mix eprof
```

## License

MIT — see [LICENSE](LICENSE).
