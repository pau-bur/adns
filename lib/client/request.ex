defmodule Adns.Client.Request do
  @moduledoc """
  Outbound DNS query: questions plus destination `address` and `port`.
  """

  defstruct [:opcode, :rd, :questions, :address, :port]

  @type t() :: %__MODULE__{
          opcode: Adns.Opcode.atoms(),
          rd: boolean(),
          questions: [Adns.Question.t()],
          address: :inet.socket_address() | :inet.hostname(),
          port: :inet.port_number()
        }
end
