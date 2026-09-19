defmodule Adns.Qclass do
  import Adns.Utils.Atom

  define_mapping(
    IN: 1,
    CS: 2,
    CH: 3,
    HS: 4,
    *: 5
  )
end
