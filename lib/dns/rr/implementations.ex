# {1, Adns.RR.A},
# {2, Adns.RR.NS},
# {3, Adns.RR.MD},
# {4, Adns.RR.MF},
# {5, Adns.RR.CNAME},
# {6, Adns.RR.SOA},
# {7, Adns.RR.MB},
# {8, Adns.RR.MG},
# {9, Adns.RR.MR},
# {10, Adns.RR.NULL},
# {11, Adns.RR.WKS},
# {12, Adns.RR.PTR},
# {13, Adns.RR.HINFO},
# {14, Adns.RR.MINFO},
# {15, Adns.RR.MX},
# {16, Adns.RR.TXT}

defmodule Adns.RR.CNAME do
  @behaviour Adns.RR.Codec

  defstruct [:cname]

  @type t() :: %__MODULE__{
          cname: String.t()
        }

  def encode(%__MODULE__{cname: cname}) do
    Adns.Label.encode_labels(cname)
  end

  def decode(data, message) do
    {labels, _} = Adns.Label.decode_labels(data, message)

    %__MODULE__{cname: labels}
  end

  def atom(), do: :CNAME
  def type(), do: 5
end

defmodule Adns.RR.HINFO do
  @behaviour Adns.RR.Codec

  defstruct [:cpu, :os]

  @type t() :: %__MODULE__{
          cpu: String.t(),
          os: String.t()
        }

  def encode(%__MODULE__{cpu: cpu, os: os}) do
    <<byte_size(cpu), cpu::binary, byte_size(os), os::binary>>
  end

  def decode(
        <<cpu_length, cpu::binary-size(cpu_length), os_length, os::binary-size(os_length)>>,
        _
      ) do
    %__MODULE__{cpu: cpu, os: os}
  end

  def atom(), do: :HINFO
  def type(), do: 13
end

defmodule Adns.RR.MB do
  @behaviour Adns.RR.Codec

  defstruct [:madname]

  @type t() :: %__MODULE__{
          madname: String.t()
        }

  def encode(%__MODULE__{madname: madname}) do
    Adns.Label.encode_labels(madname)
  end

  def decode(data, message) do
    {labels, _} = Adns.Label.decode_labels(data, message)
    %__MODULE__{madname: labels}
  end

  def atom(), do: :MB
  def type(), do: 7
end

defmodule Adns.RR.MD do
  @behaviour Adns.RR.Codec

  defstruct [:madname]

  @type t() :: %__MODULE__{
          madname: String.t()
        }

  def encode(%__MODULE__{madname: madname}) do
    Adns.Label.encode_labels(madname)
  end

  def decode(data, message) do
    {labels, _} = Adns.Label.decode_labels(data, message)
    %__MODULE__{madname: labels}
  end

  def atom(), do: :MD
  def type(), do: 3
end

defmodule Adns.RR.MF do
  @behaviour Adns.RR.Codec

  defstruct [:madname]

  @type t() :: %__MODULE__{
          madname: String.t()
        }

  def encode(%__MODULE__{madname: madname}) do
    Adns.Label.encode_labels(madname)
  end

  def decode(data, message) do
    {labels, _} = Adns.Label.decode_labels(data, message)
    %__MODULE__{madname: labels}
  end

  def atom(), do: :MF
  def type(), do: 4
end

defmodule Adns.RR.MG do
  @behaviour Adns.RR.Codec

  defstruct [:madname]

  @type t() :: %__MODULE__{
          madname: String.t()
        }

  def encode(%__MODULE__{madname: madname}) do
    Adns.Label.encode_labels(madname)
  end

  def decode(data, message) do
    {labels, _} = Adns.Label.decode_labels(data, message)
    %__MODULE__{madname: labels}
  end

  def atom(), do: :MG
  def type(), do: 8
end

defmodule Adns.RR.MINFO do
  @behaviour Adns.RR.Codec

  defstruct [:rmailbx, :emailbx]

  @type t() :: %__MODULE__{
          rmailbx: String.t(),
          emailbx: String.t()
        }

  def encode(%__MODULE__{rmailbx: rmailbx, emailbx: emailbx}) do
    Adns.Label.encode_labels(rmailbx) <> Adns.Label.encode_labels(emailbx)
  end

  def decode(data, message) do
    {rmailbx, rest} = Adns.Label.decode_labels(data, message)
    {emailbx, _} = Adns.Label.decode_labels(rest, message)
    %__MODULE__{emailbx: emailbx, rmailbx: rmailbx}
  end

  def atom(), do: :MINFO
  def type(), do: 14
end

defmodule Adns.RR.MR do
  @behaviour Adns.RR.Codec

  defstruct [:newname]

  @type t() :: %__MODULE__{
          newname: String.t()
        }

  def encode(%__MODULE__{newname: newname}) do
    Adns.Label.encode_labels(newname)
  end

  def decode(data, message) do
    {labels, _} = Adns.Label.decode_labels(data, message)
    %__MODULE__{newname: labels}
  end

  def atom(), do: :MR
  def type(), do: 9
end

defmodule Adns.RR.MX do
  alias Adns.Types
  @behaviour Adns.RR.Codec

  defstruct [:preference, :exchange]

  @type t() :: %__MODULE__{
          preference: Types.uint16(),
          exchange: String.t()
        }

  def encode(%__MODULE__{preference: preference, exchange: exchange}) do
    <<preference::16>> <> Adns.Label.encode_labels(exchange)
  end

  def decode(<<preference::16, rest::binary>>, message) do
    {labels, _} = Adns.Label.decode_labels(rest, message)
    %__MODULE__{preference: preference, exchange: labels}
  end

  def atom(), do: :MX
  def type(), do: 15
end

defmodule Adns.RR.NULL do
  @behaviour Adns.RR.Codec

  defstruct [:data]

  @type t() :: %__MODULE__{
          data: binary()
        }

  def encode(%__MODULE__{data: data}) do
    data
  end

  def decode(data, _) do
    %__MODULE__{data: data}
  end

  def atom(), do: :NULL
  def type(), do: 10
end

defmodule Adns.RR.NS do
  @behaviour Adns.RR.Codec

  defstruct [:nsdname]

  @type t() :: %__MODULE__{
          nsdname: String.t()
        }

  def encode(%__MODULE__{nsdname: nsdname}) do
    Adns.Label.encode_labels(nsdname)
  end

  def decode(data, message) do
    {labels, _} = Adns.Label.decode_labels(data, message)
    %__MODULE__{nsdname: labels}
  end

  def atom(), do: :NS
  def type(), do: 2
end

defmodule Adns.RR.PTR do
  @behaviour Adns.RR.Codec

  defstruct [:ptrdname]

  @type t() :: %__MODULE__{
          ptrdname: String.t()
        }

  def encode(%__MODULE__{ptrdname: ptrdname}) do
    Adns.Label.encode_labels(ptrdname)
  end

  def decode(data, message) do
    {labels, _} = Adns.Label.decode_labels(data, message)
    %__MODULE__{ptrdname: labels}
  end

  def atom(), do: :PTR
  def type(), do: 12
end

defmodule Adns.RR.SOA do
  alias Adns.Types
  @behaviour Adns.RR.Codec

  defstruct [:mname, :rname, :serial, :refresh, :retry, :expire, :minimum]

  @type t() :: %__MODULE__{
          mname: String.t(),
          rname: String.t(),
          serial: Types.uint32(),
          refresh: Types.uint32(),
          retry: Types.uint32(),
          expire: Types.uint32(),
          minimum: Types.uint32()
        }

  def encode(%__MODULE__{
        mname: mname,
        rname: rname,
        serial: serial,
        refresh: refresh,
        retry: retry,
        expire: expire,
        minimum: minimum
      }) do
    Adns.Label.encode_labels(mname) <>
      Adns.Label.encode_labels(rname) <>
      <<serial::32, refresh::32, retry::32, expire::32, minimum::32>>
  end

  def decode(data, message) do
    {mname, rest} = Adns.Label.decode_labels(data, message)
    {rname, rest} = Adns.Label.decode_labels(rest, message)
    <<serial::32, refresh::32, retry::32, expire::32, minimum::32>> = rest

    %__MODULE__{
      mname: mname,
      rname: rname,
      serial: serial,
      refresh: refresh,
      retry: retry,
      expire: expire,
      minimum: minimum
    }
  end

  def atom(), do: :SOA
  def type(), do: 6
end

defmodule Adns.RR.TXT do
  @behaviour Adns.RR.Codec

  defstruct [:txtdata]

  @type t() :: %__MODULE__{
          txtdata: String.t()
        }

  def encode(%__MODULE__{txtdata: txtdata}) do
    <<byte_size(txtdata), txtdata::binary>>
  end

  def decode(<<txtdata_length, txtdata::binary-size(txtdata_length)>>, _) do
    %__MODULE__{txtdata: txtdata}
  end

  def atom(), do: :TXT
  def type(), do: 16
end

defmodule Adns.RR.A do
  alias Adns.Types
  @behaviour Adns.RR.Codec

  defstruct [:address]

  @type t() :: %__MODULE__{
          address: Types.uint32()
        }

  def encode(%__MODULE__{address: address}) do
    <<address::32>>
  end

  def decode(<<address::32>>, _) do
    %__MODULE__{address: address}
  end

  def atom(), do: :A
  def type(), do: 1
end

defmodule Adns.RR.WKS do
  alias Adns.Types
  @behaviour Adns.RR.Codec

  defstruct [:address, :protocol, :bitmap]

  @type t() :: %__MODULE__{
          address: Types.uint32(),
          protocol: Types.uint8(),
          bitmap: binary()
        }

  def encode(%__MODULE__{address: address, protocol: protocol, bitmap: bitmap}) do
    <<address::32, protocol::8, bitmap::binary>>
  end

  def decode(<<address::32, protocol::8, bitmap::binary>>, _) do
    %__MODULE__{address: address, protocol: protocol, bitmap: bitmap}
  end

  def atom(), do: :WKS
  def type(), do: 11
end
