defmodule Adns.Server.UDP do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def init(opts) do
    port = Keyword.fetch!(opts, :port)
    resolver = Keyword.fetch!(opts, :resolver)
    config = Keyword.get(opts, :config)
    workers = Keyword.get(opts, :workers, 10)

    {:ok, socket} = :gen_udp.open(port, [:binary, active: false, reuseaddr: true])

    children =
      for id <- 1..workers do
        Supervisor.child_spec({Task, fn -> loop(socket, resolver, config) end},
          id: {Adns.Server.UDP.Listener, id}
        )
      end

    children = [{Task.Supervisor, name: Adns.Server.UDP.TaskSupervisor} | children]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp loop(socket, resolver, config) do
    with {:ok, {address, port, message}} <- :gen_udp.recv(socket, 0) do
      Task.Supervisor.start_child(Adns.Server.UDP.TaskSupervisor, fn ->
        case Adns.Server.handle_message_stream(message, resolver, config) do
          {:ok, response} ->
            :gen_udp.send(socket, address, port, response)
        end
      end)
    end

    loop(socket, resolver, config)
  end
end
