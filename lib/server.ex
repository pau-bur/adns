defmodule Adns.Server do
  @moduledoc """
  Message handling for DNS servers: decode → resolve → encode.

  Emits `:telemetry` events under `[:dns, :server, ...]`. Partial decodes
  produce a FORMERR response with the request ID preserved.
  """

  @spec handle_message_stream(binary(), module(), config :: term()) ::
          {:ok, binary()} | :no_message
  def handle_message_stream(message, resolver, config) do
    received_time = System.monotonic_time(:microsecond)

    case Adns.Message.decode(message) do
      {:ok, decoded} ->
        decoded_time = System.monotonic_time(:microsecond)

        message = handle_message(decoded, resolver, config)

        handled_time = System.monotonic_time(:microsecond)

        response = Adns.Message.encode(message)

        encoded_time = System.monotonic_time(:microsecond)

        :telemetry.execute(
          [:dns, :server, :done],
          %{
            received_time: received_time,
            decoded_time: decoded_time,
            handled_time: handled_time,
            encoded_time: encoded_time
          },
          %{id: message.id}
        )

        {:ok, response}

      {:partial, header, reason} ->
        :telemetry.execute([:dns, :server, :error], %{reason: reason}, %{id: header.id})

        response =
          header
          |> handle_partial()
          |> Adns.Message.encode()

        {:ok, response}

      {:error, reason} ->
        :telemetry.execute([:dns, :server, :error], %{reason: reason}, %{})
        :no_message
    end
  end

  @spec handle_partial(Adns.Header.t()) :: Adns.Message.t()
  def handle_partial(%Adns.Header{
        id: id,
        qr: _qr,
        opcode: opcode,
        aa: _aa,
        tc: _tc,
        rd: rd,
        ra: _ra,
        rcode: _rcode
      }) do
    %Adns.Message{
      id: id,
      qr: :answer,
      opcode: opcode,
      aa: false,
      tc: false,
      rd: rd,
      ra: false,
      rcode: :format_error,
      questions: [],
      answers: [],
      authority: [],
      additional: []
    }
  end

  @spec handle_message(Adns.Message.t(), module(), config :: term()) ::
          Adns.Message.t()
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
        resolver,
        config
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
    } = resolver.resolve(request, config)

    %Adns.Message{
      id: id,
      qr: :answer,
      opcode: opcode,
      aa: aa,
      tc: false,
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
