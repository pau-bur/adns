defmodule AdnsTest.RR do
  use ExUnit.Case
  doctest Adns.RR

  setup do
    Adns.RR.Registry.init(Adns.RR.Registry.default_codecs())
    :ok
  end

  test "unhandled encoding and decoding" do
    message = %Adns.RR.Unhandled{
      name: "name",
      type: 202,
      class: Adns.Class.in(),
      ttl: 900,
      rdata: <<1, 4, 9>>
    }

    data = Adns.RR.encode(message)
    {:ok, {retrieved, <<>>}} = Adns.RR.decode(data, data)

    assert message == retrieved
  end

  test "known encoding and decoding" do
    message = %Adns.RR.Known{
      name: "name",
      class: Adns.Class.in(),
      ttl: 900,
      rdata: %Adns.RR.A{address: 135}
    }

    data = Adns.RR.encode(message)
    {:ok, {retrieved, <<>>}} = Adns.RR.decode(data, data)

    assert message == retrieved
  end
end
