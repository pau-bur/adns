defmodule Adns.Server.TCP do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def init(opts) do
    children = [
      {Task.Supervisor, name: Adns.Server.TCP.TaskSupervisor},
      {Task, fn -> listen(opts) end}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp listen(opts) do
    {:ok, socket} =
      :gen_tcp.listen(opts.port, [:binary, packet: :raw, active: false, reuseaddr: true])

    accept(socket, opts)
  end

  defp accept(socket, opts) do
    {:ok, client} = :gen_tcp.accept(socket)

    Task.Supervisor.start_child(Adns.Server.Tasks, fn ->
      handle_connection(client, opts.resolver)
    end)
  end

  defp handle_connection(socket, resolver) do
    {:ok, <<length::16>>} = :gen_tcp.recv(socket, 2)
    {:ok, message} = :gen_tcp.recv(socket, length)

    response = Adns.Server.handle_message_stream(message, resolver)
    :ok = :gen_tcp.send(socket, response)

    handle_connection(socket, resolver)
  end
end
