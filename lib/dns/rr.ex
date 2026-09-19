defmodule Adns.RR.Known do
  @moduledoc """
  Resource record with typed RDATA (registered codec).
  """

  alias Adns.Utils.Types

  defstruct [:name, :class, :ttl, :rdata]

  @type t() :: %__MODULE__{
          name: String.t(),
          class: Adns.Class.atoms(),
          ttl: Types.uint32(),
          rdata: Adns.RR.rdata()
        }
end

defmodule Adns.RR.Unhandled do
  @moduledoc """
  Resource record with unknown type; RDATA kept as a raw binary.
  """

  alias Adns.Utils.Types

  defstruct [:name, :type, :class, :ttl, :rdata]

  @type t() ::
          %__MODULE__{
            name: String.t(),
            type: Types.uint16(),
            class: Adns.Class.atoms(),
            ttl: Types.uint32(),
            rdata: binary()
          }
end

defmodule Adns.RR do
  @moduledoc """
  Resource record encode/decode (RFC 1035 §4.1.3).

  Known types use `Adns.RR.Registry` codecs; unknown types become `Adns.RR.Unhandled`.
  """

  @type t() ::
          Adns.RR.Unhandled.t() | Adns.RR.Known.t()

  @spec encode(t()) :: binary()
  def encode(%Adns.RR.Unhandled{name: name, type: type, class: class, ttl: ttl, rdata: rdata}) do
    Adns.Label.encode_labels(name) <>
      <<type::16, Adns.Class.value(class)::16, ttl::32, byte_size(rdata)::16, rdata::binary>>
  end

  def encode(%Adns.RR.Known{name: name, class: class, ttl: ttl, rdata: rdata}) do
    type = rdata.__struct__.type()
    atom = rdata.__struct__.atom()
    mod = Adns.RR.Registry.find_module(atom)
    rdata = mod.encode(rdata)
    encode(%Adns.RR.Unhandled{name: name, type: type, class: class, ttl: ttl, rdata: rdata})
  end

  @type rdata() :: struct()

  @type rdata_error_reason() :: term()

  @type error_reason() ::
          Adns.Label.error_reason() | :malformed_rr_metadata | rdata_error_reason()

  defp decode_rdata(name, type, class, ttl, rdata, message) do
    type_num = type
    type = Adns.Types.atom(type)
    class = Adns.Class.atom(class)

    if type == :unknown do
      {:ok,
       %Adns.RR.Unhandled{
         name: name,
         type: type_num,
         class: class,
         ttl: ttl,
         rdata: rdata
       }}
    else
      mod = Adns.RR.Registry.find_module(type)

      with {:ok, rdata} <- mod.decode(rdata, message) do
        {:ok,
         %Adns.RR.Known{
           name: name,
           class: class,
           ttl: ttl,
           rdata: rdata
         }}
      end
    end
  end

  @spec decode(binary(), binary()) :: {:ok, {t(), binary()}} | {:error, error_reason()}
  def decode(data, message) do
    with {:ok, {name, rest}} <- Adns.Label.decode_labels(data, message),
         <<type::16, class::16, ttl::32, length::16, rdata::binary-size(length), rest::binary>> <-
           rest,
         {:ok, rr} <-
           decode_rdata(name, type, class, ttl, rdata, message) do
      {:ok, {rr, rest}}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :malformed_rr_metadata}
    end
  end

  @spec decode_rrs(binary(), binary(), non_neg_integer()) ::
          {:ok, {[t()], binary()}} | {:error, error_reason()}
  def decode_rrs(data, _, 0), do: {:ok, {[], data}}

  def decode_rrs(data, message, n) do
    with {:ok, {rr, rest}} <- decode(data, message),
         {:ok, {rrs, rest}} <- decode_rrs(rest, message, n - 1) do
      {:ok, {[rr | rrs], rest}}
    end
  end
end
