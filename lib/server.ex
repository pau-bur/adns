defmodule Adns.Server do
  @spec handle_message_stream(binary(), module()) :: binary()
  def handle_message_stream(message, resolver) do
    message
    |> Adns.Message.decode()
    |> handle_message(resolver)
    |> Adns.Message.encode()
  end

  @spec handle_message(Adns.Message.t(), module()) :: Adns.Message.t()
  def handle_message(
        %Adns.Message{
          id: id,
          qr: _qr,
          opcode: opcode,
          aa: _aa,
          tc: _tc,
          rd: rd,
          ra: _ra,
          rcode: _rcode,
          questions: questions,
          answers: _answers,
          authority: _authority,
          additional: _additional
        },
        resolver
      ) do
    request = %Adns.Resolver.Request{
      opcode: opcode,
      rd: rd,
      questions: questions
    }

    %Adns.Resolver.Response{
      answers: answers,
      authority: authority,
      additional: additional,
      aa: aa,
      ra: ra,
      rcode: rcode
    } = resolver.resolve(request)

    %Adns.Message{
      id: id,
      qr: 1,
      opcode: opcode,
      aa: aa,
      tc: 0,
      rd: rd,
      ra: ra,
      rcode: rcode,
      questions: questions,
      answers: answers,
      authority: authority,
      additional: additional
    }
  end
end
