defmodule Adns.Supervisor do
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def init(children, opts \\ []) do
    {codecs, opts} = Keyword.pop(opts, :codecs, Adns.RR.Registry.default_codecs())

    Adns.RR.Registry.init(codecs)

    Supervisor.init(children, opts)
  end
end
