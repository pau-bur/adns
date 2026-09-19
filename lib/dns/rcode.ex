defmodule Adns.Rcode do
  import Adns.Utils.Atom

  define_mapping(
    ok: 0,
    format_error: 1,
    server_failure: 2,
    name_error: 3,
    not_implemented: 4,
    refused: 5
  )
end
