defmodule Adns.Utils.Bool do
  alias Adns.Utils.Types

  @spec int_to_bool(Types.uint1()) :: boolean()
  def int_to_bool(0), do: false
  def int_to_bool(1), do: true

  @spec bool_to_int(boolean()) :: Types.uint1()
  def bool_to_int(false), do: 0
  def bool_to_int(true), do: 1
end
