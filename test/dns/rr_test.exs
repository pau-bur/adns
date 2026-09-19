defmodule AdnsTest.RR do
  use ExUnit.Case
  doctest Adns.RR

  setup do
    ensure_rr_registry()
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

  test "known A encoding and decoding" do
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

  test "MX encoding and decoding" do
    rr = %Adns.RR.Known{
      name: "example.com",
      class: Adns.Class.in(),
      ttl: 300,
      rdata: %Adns.RR.MX{preference: 10, exchange: "mail.example.com"}
    }

    data = Adns.RR.encode(rr)
    assert {:ok, {^rr, <<>>}} = Adns.RR.decode(data, data)
  end

  test "CNAME encoding and decoding" do
    rr = %Adns.RR.Known{
      name: "www.example.com",
      class: Adns.Class.in(),
      ttl: 300,
      rdata: %Adns.RR.CNAME{cname: "example.com"}
    }

    data = Adns.RR.encode(rr)
    assert {:ok, {^rr, <<>>}} = Adns.RR.decode(data, data)
  end

  test "TXT encoding and decoding" do
    rr = %Adns.RR.Known{
      name: "example.com",
      class: Adns.Class.in(),
      ttl: 300,
      rdata: %Adns.RR.TXT{txtdata: "hello"}
    }

    data = Adns.RR.encode(rr)
    assert {:ok, {^rr, <<>>}} = Adns.RR.decode(data, data)
  end

  test "SOA encoding and decoding" do
    rr = %Adns.RR.Known{
      name: "example.com",
      class: Adns.Class.in(),
      ttl: 300,
      rdata: %Adns.RR.SOA{
        mname: "ns1.example.com",
        rname: "hostmaster.example.com",
        serial: 1,
        refresh: 3600,
        retry: 600,
        expire: 86400,
        minimum: 60
      }
    }

    data = Adns.RR.encode(rr)
    assert {:ok, {^rr, <<>>}} = Adns.RR.decode(data, data)
  end

  test "malformed rr metadata" do
    # Valid name then truncated type/class/ttl/rdlength
    name = Adns.Label.encode_labels("x.com")
    assert {:error, :malformed_rr_metadata} = Adns.RR.decode(name <> <<1, 2>>, name)
  end

  defp ensure_rr_registry do
    case :ets.whereis(Adns.RR.Registry) do
      :undefined -> Adns.RR.Registry.init(Adns.RR.Registry.default_codecs())
      _ -> :ok
    end
  end
end
