defmodule AdnsTest.Server do
  use ExUnit.Case

  @behaviour Adns.Resolver

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
end
