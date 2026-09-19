defmodule Adns.Header do
  alias Adns.Utils.Types

  defstruct [
    :id,
    :qr,
    :opcode,
    :aa,
    :tc,
    :rd,
    :ra,
    :rcode,
    :qdcount,
    :ancount,
    :nscount,
    :arcount
  ]

  @type t() :: %__MODULE__{
          id: Types.uint16(),
          qr: Adns.Qr.atoms(),
          opcode: Adns.Opcode.atoms(),
          aa: boolean(),
          tc: boolean(),
          rd: boolean(),
          ra: boolean(),
          rcode: Adns.Rcode.atoms(),
          qdcount: Types.uint16(),
          ancount: Types.uint16(),
          nscount: Types.uint16(),
          arcount: Types.uint16()
        }

  import Adns.Utils.Bool

  @spec encode(t()) :: binary()
  def encode(%__MODULE__{
        id: id,
        qr: qr,
        opcode: opcode,
        aa: aa,
        tc: tc,
        rd: rd,
        ra: ra,
        rcode: rcode,
        qdcount: qdcount,
        ancount: ancount,
        nscount: nscount,
        arcount: arcount
      }) do
    <<id::16, Adns.Qr.value(qr)::1, Adns.Opcode.value(opcode)::4, bool_to_int(aa)::1,
      bool_to_int(tc)::1, bool_to_int(rd)::1, bool_to_int(ra)::1, 0::3,
      Adns.Rcode.value(rcode)::4, qdcount::16, ancount::16, nscount::16, arcount::16>>
  end

  @type error_reason() :: :malformed_header

  @spec decode(binary()) :: {:ok, {t(), binary()}} | {:error, error_reason()}
  def decode(
        <<id::16, qr::1, opcode::4, aa::1, tc::1, rd::1, ra::1, 0::3, rcode::4, qdcount::16,
          ancount::16, nscount::16, arcount::16, rest::binary>>
      ) do
    {:ok,
     {%__MODULE__{
        id: id,
        qr: Adns.Qr.atom(qr),
        opcode: Adns.Opcode.atom(opcode),
        aa: int_to_bool(aa),
        tc: int_to_bool(tc),
        rd: int_to_bool(rd),
        ra: int_to_bool(ra),
        rcode: Adns.Rcode.atom(rcode),
        qdcount: qdcount,
        ancount: ancount,
        nscount: nscount,
        arcount: arcount
      }, rest}}
  end

  def decode(_), do: {:error, :malformed_header}
end
