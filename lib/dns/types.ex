defmodule Adns.Types do
  alias Adns.Utils.Types
  import Adns.Utils.Atom

  define_mapping(
    [
      A: 1,
      NS: 2,
      MD: 3,
      MF: 4,
      CNAME: 5,
      SOA: 6,
      MB: 7,
      MG: 8,
      MR: 9,
      NULL: 10,
      WKS: 11,
      PTR: 12,
      HINFO: 13,
      MINFO: 14,
      MX: 15,
      TXT: 16
    ],
    false,
    true
  )

  @spec atom(Types.uint16()) :: atom()
  def atom(value) do
    Adns.RR.Registry.to_atom(value)
  end

  @spec value(atom()) :: Types.uint16()
  def value(atom) do
    Adns.RR.Registry.to_type(atom)
  end
end
