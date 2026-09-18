defmodule Adns.RR.Known do
  alias Adns.Types

  defstruct [:name, :class, :ttl, :rdata]

  @type t() :: %__MODULE__{
          name: String.t(),
          class: Types.uint16(),
          ttl: Types.uint32(),
          rdata: struct()
        }
end

defmodule Adns.RR.Unhandled do
  alias Adns.Types

  defstruct [:name, :type, :class, :ttl, :rdata]

  @type t() ::
          %__MODULE__{
            name: String.t(),
            type: Types.uint16(),
            class: Types.uint16(),
            ttl: Types.uint32(),
            rdata: binary()
          }
end

defmodule Adns.RR do
  @type t() ::
          Adns.RR.Unhandled.t() | Adns.RR.Known.t()

  @spec encode(t()) :: binary()
  def encode(%Adns.RR.Unhandled{name: name, type: type, class: class, ttl: ttl, rdata: rdata}) do
    Adns.Label.encode_labels(name) <>
      <<type::16, class::16, ttl::32, byte_size(rdata)::16, rdata::binary>>
  end

  def encode(%Adns.RR.Known{name: name, class: class, ttl: ttl, rdata: rdata}) do
    type = rdata.__struct__.type()
    mod = Adns.RR.Registry.find_module(type)
    rdata = mod.encode(rdata)
    encode(%Adns.RR.Unhandled{name: name, type: type, class: class, ttl: ttl, rdata: rdata})
  end

  @spec decode(binary(), binary()) :: {t(), binary()}
  def decode(data, message) do
    {name, rest} = Adns.Label.decode_labels(data, message)
    <<type::16, class::16, ttl::32, length::16, rdata::binary-size(length), rest::binary>> = rest

    mod = Adns.RR.Registry.find_module(type)

    rr =
      if is_nil(mod) do
        %Adns.RR.Unhandled{
          name: name,
          type: type,
          class: class,
          ttl: ttl,
          rdata: rdata
        }
      else
        rdata = mod.decode(rdata, message)

        %Adns.RR.Known{
          name: name,
          class: class,
          ttl: ttl,
          rdata: rdata
        }
      end

    {rr, rest}
  end

  @spec decode_rrs(binary(), binary(), non_neg_integer()) :: {[t()], binary()}
  def decode_rrs(data, _, 0), do: {[], data}

  def decode_rrs(data, message, n) do
    {rr, rest} = decode(data, message)
    {rrs, rest} = decode_rrs(rest, message, n - 1)
    {[rr | rrs], rest}
  end
end
