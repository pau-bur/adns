defmodule Adns.Server.TCP do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def init(opts) do
    port = Keyword.fetch!(opts, :port)
    resolver = Keyword.fetch!(opts, :resolver)
    config = Keyword.get(opts, :config)

    children = [
      {Task.Supervisor, name: Adns.Server.TCP.TaskSupervisor},
      {Task, fn -> listen(port, resolver, config) end}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp listen(port, resolver, config) do
    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, packet: :raw, active: false, reuseaddr: true])

    accept(socket, resolver, config)
  end

  defp accept(socket, resolver, config) do
    {:ok, client} = :gen_tcp.accept(socket)

    Task.Supervisor.start_child(Adns.Server.Tasks, fn ->
      handle_connection(client, resolver, config)
    end)
  end

  defp handle_connection(socket, resolver, config) do
    {:ok, <<length::16>>} = :gen_tcp.recv(socket, 2)
    {:ok, message} = :gen_tcp.recv(socket, length)

    case Adns.Server.handle_message_stream(message, resolver, config) do
      {:ok, response} ->
        :ok = :gen_tcp.send(socket, response)
    end

    handle_connection(socket, resolver, config)
  end
end
