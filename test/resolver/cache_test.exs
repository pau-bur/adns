defmodule AdnsTest.Cache do
  use ExUnit.Case

  alias Adns.Resolver.Cache
  alias Adns.Question
  alias Adns.RR
  alias Adns.Class
  alias Adns.Qtypes
  alias Adns.Qclass
  alias Adns.Rcode

  setup do
    cache = Cache.config()
    question = %Question{qname: "www.test.com", qtype: Qtypes.a(), qclass: Qclass.in()}

    answer = %RR.Known{
      name: "www.test.com",
      class: Class.in(),
      ttl: 60,
      rdata: %RR.A{address: 0x7F000001}
    }

    Cache.register(cache, question, {[answer], [], []})
    %{cache: cache, question: question, answer: answer}
  end

  test "resolve hit returns answers", %{cache: cache, question: question, answer: answer} do
    request = %Adns.Resolver.Request{
      opcode: Adns.Opcode.query(),
      rd: false,
      questions: [question]
    }

    assert %Adns.Resolver.Response{
             answers: [^answer],
             authority: [],
             additional: [],
             aa: false,
             ra: false,
             rcode: rcode
           } = Cache.resolve(request, cache)

    assert rcode == Rcode.ok()
  end

  test "resolve miss returns server_failure tuple", %{cache: cache} do
    request = %Adns.Resolver.Request{
      opcode: Adns.Opcode.query(),
      rd: false,
      questions: [
        %Question{qname: "missing.test", qtype: Qtypes.a(), qclass: Qclass.in()}
      ]
    }

    assert {%Adns.Resolver.Response{
              answers: [],
              authority: [],
              additional: [],
              aa: false,
              ra: false,
              rcode: rcode
            }, ^cache} = Cache.resolve(request, cache)

    assert rcode == Rcode.server_failure()
  end
end
