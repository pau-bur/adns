defmodule Adns.RR.Codec do
  alias Adns.Types
  @callback encode(any()) :: binary()
  @callback decode(binary(), binary()) :: any()
  @callback atom() :: atom()
  @callback type() :: Types.uint16()
end
