defmodule AdnsTest.Header do
  use ExUnit.Case

  defp sample_header do
    %Adns.Header{
      id: 0xABCD,
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
  end

  test "encoding and decoding" do
    header = sample_header()
    data = Adns.Header.encode(header)
    assert {:ok, {^header, <<>>}} = Adns.Header.decode(data)
  end

  test "rejects truncated header" do
    assert {:error, :malformed_header} = Adns.Header.decode(<<1, 2, 3>>)
  end

  test "rejects non-zero Z bits" do
    # Valid layout but Z = 0b001 instead of 0
    data =
      <<0xABCD::16, 0::1, 0::4, 0::1, 0::1, 1::1, 0::1, 0b001::3, 0::4, 1::16, 0::16, 0::16,
        0::16>>

    assert {:error, :malformed_header} = Adns.Header.decode(data)
  end
end
