defmodule Adns.Label do
  @moduledoc """
  DNS domain name labels.

  Decode follows compression pointers (`11` + 14-bit offset) into the full
  message buffer (RFC 1035 §4.1.4). Encode writes labels without pointers.
  """

  defp decode_label(<<1::2, offset::14, rest::binary>>) do
    {:offset, offset, rest}
  end

  defp decode_label(<<0::8, rest::binary>>), do: {:end, rest}

  defp decode_label(<<size::8, data::binary-size(size), rest::binary>>) do
    {:label, data, rest}
  end

  defp decode_label(_), do: {:error, :malformed_label}

  @type error_reason() :: :malformed_label

  @spec decode_labels(binary(), binary()) ::
          {:ok, {String.t(), binary()}} | {:error, error_reason()}
  def decode_labels(rest, message) do
    case decode_label(rest) do
      {:error, reason} ->
        {:error, reason}

      {:end, rest} ->
        {:ok, {"", rest}}

      {:offset, offset, rest} ->
        <<_::binary-size(offset), data_at_offset::binary>> = message

        with {:ok, {labels, _}} <- decode_labels(data_at_offset, message) do
          {:ok, {labels, rest}}
        end

      {:label, label, rest} ->
        with {:ok, {labels, rest}} <- decode_labels(rest, message) do
          if labels == "" do
            {:ok, {label, rest}}
          else
            {:ok, {label <> "." <> labels, rest}}
          end
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
