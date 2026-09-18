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
      qr: 0,
      opcode: 1,
      aa: 0,
      tc: 0,
      rd: 0,
      ra: 0,
      rcode: 0,
      questions: [%Adns.Question{qname: "www.test.com", qtype: 0, qclass: 1}],
      answers: [
        %Adns.RR.Known{name: "node", class: 1, ttl: 300, rdata: %Adns.RR.A{address: 1234}}
      ],
      authority: [
        %Adns.RR.Known{
          name: "node",
          class: 1,
          ttl: 300,
          rdata: %Adns.RR.NS{nsdname: "ns1.test.com"}
        }
      ],
      additional: [
        %Adns.RR.Known{name: "node", class: 1, ttl: 300, rdata: %Adns.RR.TXT{txtdata: "test"}}
      ]
    }

    data = Adns.Message.encode(message)
    retrieved = Adns.Message.decode(data)

    assert message == retrieved
  end
end
