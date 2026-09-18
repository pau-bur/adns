defmodule Adns.Client.Request do
  alias Adns.Types
  defstruct [:opcode, :rd, :questions, :address, :port]

  @type t() :: %__MODULE__{
          opcode: Types.uint4(),
          rd: 0 | 1,
          questions: [Adns.Question.t()],
          address: :inet.socket_address() | :inet.hostname(),
          port: :inet.port_number()
        }
end
