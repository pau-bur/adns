defmodule AdnsTest.Label do
  use ExUnit.Case
  doctest Adns.Label

  test "encoding and decoding" do
    labels = "www.site.com"

    data = Adns.Label.encode_labels(labels)
    {:ok, {retrieved, <<>>}} = Adns.Label.decode_labels(data, <<>>)

    assert retrieved == labels
  end

  test "decode pointers" do
    root = Adns.Label.encode_labels("site.com")
    data = <<3, "www", 1::2, 0::14>>
    message = root <> data

    {:ok, {retrieved, <<>>}} = Adns.Label.decode_labels(data, message)

    assert retrieved == "www.site.com"
  end

  test "root label" do
    assert {:ok, {"", <<>>}} = Adns.Label.decode_labels(<<0>>, <<0>>)
  end

  test "malformed label" do
    assert {:error, :malformed_label} = Adns.Label.decode_labels(<<5, "ab">>, <<5, "ab">>)
  end
end
