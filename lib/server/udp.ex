defmodule Adns.Server.UDP do
  @moduledoc """
  Concurrent UDP DNS server.

  Opens one shared socket and runs a recv loop. By default each query is
  answered on `Adns.Server.UDP.TaskSupervisor`; with `sync: true`, handle and
  reply on the recv process itself.

  Options: `:port`, `:resolver`, `:config`, `:sync` (default `false`).
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def init(opts) do
    port = Keyword.fetch!(opts, :port)
    resolver = Keyword.fetch!(opts, :resolver)
    config = Keyword.get(opts, :config)
    sync = Keyword.get(opts, :sync, false)

    {:ok, socket} = :gen_udp.open(port, [:binary, active: false, reuseaddr: true])

    children = [
      {Task.Supervisor, name: Adns.Server.UDP.TaskSupervisor},
      if sync do
        {Task, fn -> loop_sync(socket, resolver, config) end}
      else
        {Task, fn -> loop(socket, resolver, config) end}
      end
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp loop_sync(socket, resolver, config) do
    with {:ok, {address, port, message}} <- :gen_udp.recv(socket, 0) do
      case Adns.Server.handle_message_stream(message, resolver, config) do
        {:ok, response} ->
          :gen_udp.send(socket, address, port, response)
      end
    end

    loop_sync(socket, resolver, config)
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
