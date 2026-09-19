defmodule Adns.Supervisor do
  @moduledoc """
  Boots the RR codec registry, then supervises the given children.

  Pass `codecs:` to override `Adns.RR.Registry.default_codecs/0`.
  """

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def init(children, opts \\ []) do
    {codecs, opts} = Keyword.pop(opts, :codecs, Adns.RR.Registry.default_codecs())

    Adns.RR.Registry.init(codecs)

    Supervisor.init(children, opts)
  end
end
