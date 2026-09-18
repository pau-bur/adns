defmodule Adns.Server.UDP do
  use Task

  def start_link(opts) do
    port = Keyword.fetch!(opts, :port)
    resolver = Keyword.fetch!(opts, :resolver)

    Task.start_link(fn ->
      listen(port, resolver)
    end)
  end

  defp listen(port, resolver) do
    {:ok, socket} = :gen_udp.open(port, [:binary, active: false, reuseaddr: true])
    loop(socket, resolver)
  end

  defp loop(socket, resolver) do
    {:ok, {address, port, message}} = :gen_udp.recv(socket, 0)

    response = Adns.Server.handle_message_stream(message, resolver)
    :gen_udp.send(socket, address, port, response)

    loop(socket, resolver)
  end
end
