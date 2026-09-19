defmodule Adns.RR.Registry do
  @table __MODULE__

  def default_codecs() do
    [
      Adns.RR.A,
      Adns.RR.NS,
      Adns.RR.MD,
      Adns.RR.MF,
      Adns.RR.CNAME,
      Adns.RR.SOA,
      Adns.RR.MB,
      Adns.RR.MG,
      Adns.RR.MR,
      Adns.RR.NULL,
      Adns.RR.WKS,
      Adns.RR.PTR,
      Adns.RR.HINFO,
      Adns.RR.MINFO,
      Adns.RR.MX,
      Adns.RR.TXT
    ]
  end

  def init(codecs) do
    :ets.new(@table, [
      :named_table,
      :set,
      :public,
      read_concurrency: true
    ])

    Enum.each(codecs, &register/1)
  end

  def register(codec) do
    type = codec.type()
    atom = codec.atom()

    :ets.insert(@table, [
      {{:atom, atom}, codec},
      {{:type, type}, atom}
    ])
  end

  def find_module(atom) do
    case :ets.lookup(@table, {:atom, atom}) do
      [{{:atom, ^atom}, codec}] -> codec
      [] -> nil
    end
  end

  @spec to_atom(Adns.Utils.Types.uint16()) :: atom() | :unknown
  def to_atom(type) do
    case :ets.lookup(@table, {:type, type}) do
      [{{:type, ^type}, atom}] -> atom
      [] -> :unknown
    end
  end

  @spec to_type(atom()) :: Adns.Utils.Types.uint16() | :unknown
  def to_type(atom) do
    case find_module(atom) do
      nil -> :unknown
      codec -> codec.type()
    end
  end
end
