defmodule Adns.Question do
  defstruct [:qname, :qtype, :qclass]

  @type t :: %__MODULE__{
          qname: String.t(),
          qtype: Adns.Qtypes.atoms(),
          qclass: Adns.Qclass.atoms()
        }

  @spec encode(t()) :: binary()
  def encode(%__MODULE__{qname: qname, qtype: qtype, qclass: qclass}) do
    data = Adns.Label.encode_labels(qname)
    data <> <<Adns.Qtypes.value(qtype)::16, Adns.Qclass.value(qclass)::16>>
  end

  @type error_reason() :: :malformed_question_metadata | Adns.Label.error_reason()

  @spec decode(binary(), binary()) :: {:ok, {t(), binary()}} | {:error, error_reason()}
  def decode(data, message) do
    with {:ok, {labels, rest}} <- Adns.Label.decode_labels(data, message),
         <<qtype::16, qclass::16, rest::binary>> <- rest do
      {:ok,
       {%__MODULE__{
          qname: labels,
          qtype: Adns.Qtypes.atom(qtype),
          qclass: Adns.Qclass.atom(qclass)
        }, rest}}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :malformed_question_metadata}
    end
  end

  @spec decode_questions(binary(), binary(), non_neg_integer()) ::
          {:ok, {[t()], binary()}} | {:error, error_reason()}
  def decode_questions(data, _, 0), do: {:ok, {[], data}}

  def decode_questions(data, message, n) do
    with {:ok, {question, rest}} <- Adns.Question.decode(data, message),
         {:ok, {questions, rest}} <- decode_questions(rest, message, n - 1) do
      {:ok, {[question | questions], rest}}
    end
  end
end
