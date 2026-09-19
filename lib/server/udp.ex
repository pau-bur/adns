defmodule Adns.Server.UDP do
  use Task

  def start_link(opts) do
    port = Keyword.fetch!(opts, :port)
    resolver = Keyword.fetch!(opts, :resolver)
    config = Keyword.get(opts, :config)

    Task.start_link(fn ->
      listen(port, resolver, config)
    end)
  end

  defp listen(port, resolver, config) do
    {:ok, socket} = :gen_udp.open(port, [:binary, active: false, reuseaddr: true])
    loop(socket, resolver, config)
  end

  defp loop(socket, resolver, config) do
    {:ok, {address, port, message}} = :gen_udp.recv(socket, 0)

    case Adns.Server.handle_message_stream(message, resolver, config) do
      {:ok, response} ->
        :gen_udp.send(socket, address, port, response)
    end

    loop(socket, resolver, config)
  end
end
