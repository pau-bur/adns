defmodule AdnsTest.Question do
  use ExUnit.Case

  test "encoding and decoding" do
    question = %Adns.Question{
      qname: "www.example.com",
      qtype: Adns.Qtypes.a(),
      qclass: Adns.Qclass.in()
    }

    data = Adns.Question.encode(question)
    assert {:ok, {^question, <<>>}} = Adns.Question.decode(data, data)
  end
end
