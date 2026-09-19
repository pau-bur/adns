defmodule Adns.RR.Codec do
  alias Adns.Utils.Types
  @callback encode(any()) :: binary()
  @callback decode(binary(), binary()) ::
              {:ok, Adns.RR.rdata()} | {:error, Adns.RR.rdata_error_reason()}
  @callback atom() :: atom()
  @callback type() :: Types.uint16()
end
