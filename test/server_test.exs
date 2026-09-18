defmodule AdnsTest.Server do
  use ExUnit.Case

  @behaviour Adns.Resolver

  @impl true
  def resolve(%Adns.Resolver.Request{opcode: _opcode, rd: _rd, questions: _questions}) do
    %Adns.Resolver.Response{
      answers: [
        %Adns.RR.Known{name: "name", class: 0, ttl: 400, rdata: %Adns.RR.A{address: 1231}}
      ],
      additional: [],
      authority: [],
      aa: 1,
      ra: 1,
      rcode: 4
    }
  end

  test "gets resolved" do
    response =
      %Adns.Message{
        id: 123,
        qr: 0,
        opcode: 0,
        aa: 0,
        tc: 0,
        rd: 1,
        ra: 0,
        rcode: 1,
        questions: [%Adns.Question{qtype: 1, qclass: 1, qname: "www.test.com"}],
        answers: [],
        authority: [],
        additional: []
      }
      |> Adns.Server.handle_message(__MODULE__)

    assert response == %Adns.Message{
             id: 123,
             qr: 1,
             opcode: 0,
             rd: 1,
             tc: 0,
             questions: [%Adns.Question{qtype: 1, qclass: 1, qname: "www.test.com"}],
             answers: [
               %Adns.RR.Known{
                 name: "name",
                 class: 0,
                 ttl: 400,
                 rdata: %Adns.RR.A{address: 1231}
               }
             ],
             additional: [],
             authority: [],
             aa: 1,
             ra: 1,
             rcode: 4
           }
  end
end
