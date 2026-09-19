defmodule AdnsTest.Message do
  use ExUnit.Case
  doctest Adns.Message

  setup do
    ensure_rr_registry()
    :ok
  end

  test "encoding and decoding" do
    message = %Adns.Message{
      id: 123,
      qr: Adns.Qr.question(),
      opcode: Adns.Opcode.query(),
      aa: false,
      tc: false,
      rd: false,
      ra: false,
      rcode: Adns.Rcode.ok(),
      questions: [
        %Adns.Question{
          qname: "www.test.com",
          qtype: Adns.Qtypes.a(),
          qclass: Adns.Qclass.in()
        }
      ],
      answers: [
        %Adns.RR.Known{
          name: "node",
          class: Adns.Class.in(),
          ttl: 300,
          rdata: %Adns.RR.A{address: 1234}
        }
      ],
      authority: [
        %Adns.RR.Known{
          name: "node",
          class: Adns.Class.in(),
          ttl: 300,
          rdata: %Adns.RR.NS{nsdname: "ns1.test.com"}
        }
      ],
      additional: [
        %Adns.RR.Known{
          name: "node",
          class: Adns.Class.in(),
          ttl: 300,
          rdata: %Adns.RR.TXT{txtdata: "test"}
        }
      ]
    }

    data = Adns.Message.encode(message)
    {:ok, retrieved} = Adns.Message.decode(data)

    assert message == retrieved
  end

  test "empty questions message" do
    message = %Adns.Message{
      id: 1,
      qr: Adns.Qr.answer(),
      opcode: Adns.Opcode.query(),
      aa: false,
      tc: false,
      rd: false,
      ra: false,
      rcode: Adns.Rcode.format_error(),
      questions: [],
      answers: [],
      authority: [],
      additional: []
    }

    data = Adns.Message.encode(message)
    assert {:ok, ^message} = Adns.Message.decode(data)
  end

  test "partial decode when body is truncated" do
    header = %Adns.Header{
      id: 42,
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

    # Header claims one question but body is empty
    data = Adns.Header.encode(header)

    assert {:partial, %Adns.Header{id: 42}, _reason} = Adns.Message.decode(data)
  end

  defp ensure_rr_registry do
    case :ets.whereis(Adns.RR.Registry) do
      :undefined -> Adns.RR.Registry.init(Adns.RR.Registry.default_codecs())
      _ -> :ok
    end
  end
end
