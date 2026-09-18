defmodule Adns.Client do
  use GenServer

  defp write_request(%Adns.Client.Request{opcode: opcode, rd: rd, questions: questions}, id) do
    %Adns.Message{
      id: id,
      qr: 0,
      opcode: opcode,
      aa: 0,
      tc: 0,
      rd: rd,
      ra: 0,
      rcode: 0,
      questions: questions,
      answers: [],
      authority: [],
      additional: []
    }
    |> Adns.Message.encode()
  end

  defp read_response(message) do
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
    } = Adns.Message.decode(message)

    {id,
     %Adns.Client.Response{
       answers: answers,
       authority: authority,
       additional: additional,
       aa: aa,
       ra: ra,
       tc: tc,
       rcode: rcode
     }}
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
    request_data = write_request(request, id)
    :ok = :gen_udp.send(socket, request.address, request.port, request_data)

    request_map = Map.put(request_map, id, from)
    id = next_id(request_map, id)
    {:noreply, {socket, id, request_map}}
  end

  @impl true
  def handle_info({:udp, _socket, _address, _port, packet}, {socket, next_id, request_map}) do
    {id, response} = read_response(packet)

    case Map.pop(request_map, id) do
      {nil, _} ->
        {:noreply, {socket, next_id, request_map}}

      {from, request_map} ->
        GenServer.reply(from, response)
        {:noreply, {socket, next_id, request_map}}
    end
  end

  def request(req, timeout \\ 3000) do
    GenServer.call(__MODULE__, req, timeout)
  end

  def request_once(req) do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: false])

    id = 0
    req_data = write_request(req, id)

    :ok = :gen_udp.send(socket, req_data)

    {:ok, {_address, _port, packet}} = :gen_udp.recv(socket, 0)
    {^id, res} = read_response(packet)
    res
  end
end
