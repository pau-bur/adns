defmodule AdnsTest.Message do
  use ExUnit.Case
  doctest Adns.Message

  setup do
    Adns.RR.Registry.init(Adns.RR.Registry.default_codecs())
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
end
