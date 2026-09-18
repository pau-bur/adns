defmodule Adns.Question do
  alias Adns.Types

  defstruct [:qname, :qtype, :qclass]

  @type t :: %__MODULE__{
          qname: String.t(),
          qtype: Types.uint16(),
          qclass: Types.uint16()
        }

  @spec encode(t()) :: binary()
  def encode(%__MODULE__{qname: qname, qtype: qtype, qclass: qclass}) do
    data = Adns.Label.encode_labels(qname)
    data <> <<qtype::16, qclass::16>>
  end

  @spec decode(binary(), binary()) :: {t(), binary()}
  def decode(data, message) do
    {labels, rest} = Adns.Label.decode_labels(data, message)
    <<qtype::16, qclass::16, rest::binary>> = rest

    {%__MODULE__{
       qname: labels,
       qtype: qtype,
       qclass: qclass
     }, rest}
  end

  @spec decode_questions(binary(), binary(), non_neg_integer()) :: {[t()], binary()}
  def decode_questions(data, _, 0), do: {[], data}

  def decode_questions(data, message, n) do
    {question, rest} = Adns.Question.decode(data, message)
    {questions, rest} = decode_questions(rest, message, n - 1)
    {[question | questions], rest}
  end
end
