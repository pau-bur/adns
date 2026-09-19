defmodule Adns.RR.Codec do
  @moduledoc """
  Behaviour for typed RDATA encode/decode.

  Implement and register with `Adns.RR.Registry` to support custom RR types.
  """

  alias Adns.Utils.Types
  @callback encode(any()) :: binary()
  @callback decode(binary(), binary()) ::
              {:ok, Adns.RR.rdata()} | {:error, Adns.RR.rdata_error_reason()}
  @callback atom() :: atom()
  @callback type() :: Types.uint16()
end
