defmodule Adns.Client do
  @moduledoc """
  UDP DNS client with concurrent in-flight request correlation.

  The GenServer path (`start_link/1` + `request/2`) assigns 16-bit IDs, tracks
  outstanding queries, and matches replies asynchronously. Also provides
  one-shot (`request_once/1`) and reusable-socket (`request_client/2`) helpers.

  Emits `:telemetry` events under `[:dns, :client, ...]` with phase timings.
  """

  require Logger
  use GenServer

  defp write_request(%Adns.Client.Request{opcode: opcode, rd: rd, questions: questions}, id) do
    %Adns.Message{
      id: id,
      qr: :question,
      opcode: opcode,
      aa: false,
      tc: false,
      rd: rd,
      ra: false,
      rcode: :ok,
      questions: questions,
      answers: [],
      authority: [],
      additional: []
    }
    |> Adns.Message.encode()
  end

  defp read_response(message) do
    with {:ok,
          %Adns.Message{
            id: id,
            qr: _qr,
            opcode: _opcode,
            aa: aa,
            tc: tc,
            rd: _rd,
            ra: ra,
            rcode: rcode,
            questions: _questions,
            answers: answers,
            authority: authority,
            additional: additional
          }} <- Adns.Message.decode(message) do
      {:ok,
       {id,
        %Adns.Client.Response{
          answers: answers,
          authority: authority,
          additional: additional,
          aa: aa,
          ra: ra,
          tc: tc,
          rcode: rcode
        }}}
    end
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: true])
    {:ok, {socket, 0, %{}}}
  end

  def next_id(request_map, id) do
    id = rem(id + 1, 65536)

    if Map.has_key?(request_map, id) do
      next_id(request_map, id)
    else
      id
    end
  end

  @impl true
  def handle_call(request, from, {socket, id, request_map}) do
    genserver_receive = System.monotonic_time(:microsecond)

    request_data = write_request(request, id)

    client_encode = System.monotonic_time(:microsecond)

    with :ok <- :gen_udp.send(socket, request.address, request.port, request_data) do
      client_send = System.monotonic_time(:microsecond)

      request_map =
        Map.put(request_map, id, {from, {genserver_receive, client_encode, client_send}})

      id = next_id(request_map, id)
      {:noreply, {socket, id, request_map}}
    else
      {:error, reason} ->
        :telemetry.execute([:dns, :client, :error], %{reason: reason}, %{})
        {:reply, {:error, reason}, {socket, id, request_map}}
    end
  end

  @impl true
  def handle_info({:udp, _socket, _address, _port, packet}, {socket, next_id, request_map}) do
    client_receive = System.monotonic_time(:microsecond)

    with {:ok, {id, response}} <- read_response(packet) do
      client_decode = System.monotonic_time(:microsecond)

      case Map.pop(request_map, id) do
        {nil, _} ->
          {:noreply, {socket, next_id, request_map}}

        {{from, {genserver_receive, client_encode, client_send}}, request_map} ->
          timings = %{
            genserver_receive: genserver_receive,
            client_encode: client_encode,
            client_send: client_send,
            client_receive: client_receive,
            client_decode: client_decode
          }

          GenServer.reply(from, {:ok, response, timings, id})

          {:noreply, {socket, next_id, request_map}}
      end
    else
      {:partial, header, reason} ->
        :telemetry.execute([:dns, :client, :error], %{reason: reason}, %{id: header.id})

      {:error, reason} ->
        :telemetry.execute([:dns, :client, :error], %{reason: reason}, %{})
        {:noreply, {socket, next_id, request_map}}
    end
  end

  @spec request(Adns.Client.Request.t()) :: {:ok, Adns.Client.Response.t()} | {:error, term()}
  def request(req, timeout \\ 3000) do
    request_start = System.monotonic_time(:microsecond)

    with {:ok, res, timings, id} <- GenServer.call(__MODULE__, req, timeout) do
      request_end = System.monotonic_time(:microsecond)

      :telemetry.execute(
        [:dns, :client, :done],
        Map.merge(timings, %{request_start: request_start, request_end: request_end}),
        %{
          id: id
        }
      )

      {:ok, res}
    end
  end

  @spec request_once(Adns.Client.Request.t()) ::
          {:ok, Adns.Client.Response.t()} | {:error, term()}
  def request_once(req) do
    with {:ok, socket} <- :gen_udp.open(0, [:binary, active: false]),
         {:ok, res} <- request_client(socket, req),
         :ok <- :gen_udp.close(socket) do
      {:ok, res}
    end
  end

  @spec start_client() :: {:ok, :gen_udp.socket()} | {:error, term()}
  def start_client() do
    :gen_udp.open(0, [:binary, active: false])
  end

  @spec request_client(:gen_udp.socket(), Adns.Client.Request.t()) ::
          {:ok, Adns.Client.Response.t()} | {:error, term()}
  def request_client(socket, req) do
    id = 0
    req_data = write_request(req, id)

    with :ok <- :gen_udp.send(socket, req.address, req.port, req_data),
         {:ok, {_address, _port, packet}} <- :gen_udp.recv(socket, 0),
         {:ok, {^id, res}} <- read_response(packet) do
      {:ok, res}
    end
  end
end
