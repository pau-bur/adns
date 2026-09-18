defmodule Adns.Label do
  defp decode_label(<<1::2, offset::14, rest::binary>>) do
    {:offset, offset, rest}
  end

  defp decode_label(<<0::8, rest::binary>>), do: {:end, rest}

  defp decode_label(<<size::8, data::binary-size(size), rest::binary>>) do
    {:label, data, rest}
  end

  @spec decode_labels(binary(), binary()) :: {String.t(), binary()}
  def decode_labels(rest, message) do
    case decode_label(rest) do
      {:end, rest} ->
        {"", rest}

      {:offset, offset, rest} ->
        <<_::binary-size(offset), data_at_offset::binary>> = message
        {labels, _} = decode_labels(data_at_offset, message)
        {labels, rest}

      {:label, label, rest} ->
        {labels, rest} = decode_labels(rest, message)

        if labels == "" do
          {label, rest}
        else
          {label <> "." <> labels, rest}
        end
    end
  end

  defp encode_label(label) do
    <<byte_size(label)::8, label::binary>>
  end

  @spec encode_labels(String.t()) :: binary()
  def encode_labels(full_name) do
    labels = String.split(full_name, ".")

    data =
      Enum.reduce(labels, <<>>, fn label, acc ->
        data = encode_label(label)
        acc <> data
      end)

    data <> <<0::8>>
  end
end
