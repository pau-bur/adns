defmodule AdnsTest.Server do
  use ExUnit.Case

  @behaviour Adns.Resolver

  setup do
    case :ets.whereis(Adns.RR.Registry) do
      :undefined -> Adns.RR.Registry.init(Adns.RR.Registry.default_codecs())
      _ -> :ok
    end

    :ok
  end

  @impl true
  def resolve(%Adns.Resolver.Request{opcode: _opcode, rd: _rd, questions: _questions}, _config) do
    %Adns.Resolver.Response{
      answers: [
        %Adns.RR.Known{
          name: "name",
          class: Adns.Class.in(),
          ttl: 400,
          rdata: %Adns.RR.A{address: 1231}
        }
      ],
      additional: [],
      authority: [],
      aa: true,
      ra: true,
      rcode: Adns.Rcode.ok()
    }
  end

  test "gets resolved" do
    response =
      %Adns.Message{
        id: 123,
        qr: Adns.Qr.question(),
        opcode: Adns.Opcode.query(),
        aa: false,
        tc: false,
        rd: true,
        ra: false,
        rcode: Adns.Rcode.ok(),
        questions: [
          %Adns.Question{
            qtype: Adns.Qtypes.a(),
            qclass: Adns.Qclass.in(),
            qname: "www.test.com"
          }
        ],
        answers: [],
        authority: [],
        additional: []
      }
      |> Adns.Server.handle_message(__MODULE__, nil)

    assert response == %Adns.Message{
             id: 123,
             qr: Adns.Qr.answer(),
             opcode: Adns.Opcode.query(),
             rd: true,
             tc: false,
             questions: [
               %Adns.Question{
                 qtype: Adns.Qtypes.a(),
                 qclass: Adns.Qclass.in(),
                 qname: "www.test.com"
               }
             ],
             answers: [
               %Adns.RR.Known{
                 name: "name",
                 class: Adns.Class.in(),
                 ttl: 400,
                 rdata: %Adns.RR.A{address: 1231}
               }
             ],
             additional: [],
             authority: [],
             aa: true,
             ra: true,
             rcode: Adns.Rcode.ok()
           }
  end

  test "handle_partial returns FORMERR with same id" do
    header = %Adns.Header{
      id: 99,
      qr: Adns.Qr.question(),
      opcode: Adns.Opcode.query(),
      aa: false,
      tc: false,
      rd: true,
      ra: false,
      rcode: Adns.Rcode.ok(),
      qdcount: 1,
      ancount: 0,
      nscount: 0,
      arcount: 0
    }

    response = Adns.Server.handle_partial(header)

    assert response.id == 99
    assert response.qr == Adns.Qr.answer()
    assert response.rcode == Adns.Rcode.format_error()
    assert response.questions == []
    assert response.answers == []
  end

  test "handle_message_stream encodes a successful reply" do
    query = %Adns.Message{
      id: 7,
      qr: Adns.Qr.question(),
      opcode: Adns.Opcode.query(),
      aa: false,
      tc: false,
      rd: true,
      ra: false,
      rcode: Adns.Rcode.ok(),
      questions: [
        %Adns.Question{
          qname: "www.test.com",
          qtype: Adns.Qtypes.a(),
          qclass: Adns.Qclass.in()
        }
      ],
      answers: [],
      authority: [],
      additional: []
    }

    binary = Adns.Message.encode(query)
    assert {:ok, response_bin} = Adns.Server.handle_message_stream(binary, __MODULE__, nil)
    assert {:ok, response} = Adns.Message.decode(response_bin)
    assert response.id == 7
    assert response.qr == Adns.Qr.answer()
    assert length(response.answers) == 1
  end
end
