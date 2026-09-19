defmodule Adns.Opcode do
  import Adns.Utils.Atom

  define_mapping(
    QUERY: 0,
    IQUERY: 1,
    STATUS: 2
  )
end
