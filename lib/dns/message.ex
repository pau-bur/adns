defmodule Adns.Message do
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
    :questions,
    :answers,
    :authority,
    :additional
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
          questions: [Adns.Question.t()],
          answers: [Adns.RR.t()],
          authority: [Adns.RR.t()],
          additional: [Adns.RR.t()]
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
        questions: questions,
        answers: answers,
        authority: authority,
        additional: additional
      }) do
    header = %Adns.Header{
      id: id,
      qr: qr,
      opcode: opcode,
      aa: aa,
      tc: tc,
      rd: rd,
      ra: ra,
      rcode: rcode,
      qdcount: length(questions),
      ancount: length(answers),
      nscount: length(authority),
      arcount: length(additional)
    }

    header_data = Adns.Header.encode(header)
    questions_data = Enum.into(questions, <<>>, &Adns.Question.encode/1)

    rr_data =
      Stream.concat([answers, authority, additional]) |> Enum.into(<<>>, &Adns.RR.encode/1)

    header_data <> questions_data <> rr_data
  end

  @spec decode(binary()) :: t()
  def decode(message) do
    {header, rest} = Adns.Header.decode(message)
    {questions, rest} = Adns.Question.decode_questions(rest, message, header.qdcount)
    {answers, rest} = Adns.RR.decode_rrs(rest, message, header.ancount)
    {authority, rest} = Adns.RR.decode_rrs(rest, message, header.nscount)
    {additional, _} = Adns.RR.decode_rrs(rest, message, header.arcount)

    %__MODULE__{
      id: header.id,
      qr: header.qr,
      opcode: header.opcode,
      aa: header.aa,
      tc: header.tc,
      rd: header.rd,
      ra: header.ra,
      rcode: header.rcode,
      questions: questions,
      answers: answers,
      authority: authority,
      additional: additional
    }
  end
end
