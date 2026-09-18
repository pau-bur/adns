defmodule Adns.Header do
  alias Adns.Types

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
          qr: 0 | 1,
          opcode: Types.uint4(),
          aa: 0 | 1,
          tc: 0 | 1,
          rd: 0 | 1,
          ra: 0 | 1,
          rcode: Types.uint4(),
          qdcount: Types.uint16(),
          ancount: Types.uint16(),
          nscount: Types.uint16(),
          arcount: Types.uint16()
        }

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
    <<id::16, qr::1, opcode::4, aa::1, tc::1, rd::1, ra::1, 0::3, rcode::4, qdcount::16,
      ancount::16, nscount::16, arcount::16>>
  end

  @spec decode(binary()) :: {t(), binary()}
  def decode(
        <<id::16, qr::1, opcode::4, aa::1, tc::1, rd::1, ra::1, 0::3, rcode::4, qdcount::16,
          ancount::16, nscount::16, arcount::16, rest::binary>>
      ) do
    {%__MODULE__{
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
     }, rest}
  end
end
