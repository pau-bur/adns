defmodule AdnsTest.Label do
  use ExUnit.Case
  doctest Adns.Label

  test "encoding and decoding" do
    labels = "www.site.com"

    data = Adns.Label.encode_labels(labels)
    {retrieved, <<>>} = Adns.Label.decode_labels(data, <<>>)

    assert retrieved == labels
  end

  test "decode pointers" do
    root = Adns.Label.encode_labels("site.com")
    data = <<3, "www", 1::2, 0::14>>
    message = root <> data

    {retrieved, <<>>} = Adns.Label.decode_labels(data, message)

    assert retrieved == "www.site.com"
  end
end
