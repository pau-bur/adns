defmodule Adns.Client.Request do
  defstruct [:opcode, :rd, :questions, :address, :port]

  @type t() :: %__MODULE__{
          opcode: Adns.Opcode.atoms(),
          rd: boolean(),
          questions: [Adns.Question.t()],
          address: :inet.socket_address() | :inet.hostname(),
          port: :inet.port_number()
        }
end
