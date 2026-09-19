defmodule Adns.Resolver do
  @callback resolve(Adns.Resolver.Request.t(), config :: term()) :: Adns.Resolver.Response.t()

  defmacro __using__(_opts) do
    quote do
      alias Adns.Resolver
      @behaviour Resolver
      alias Adns.Question
      alias Adns.Client
      alias Adns.Class
      alias Adns.Qclass
      alias Adns.Types
      alias Adns.Qtypes
      alias Adns.Opcode
      alias Adns.Rcode
      alias Adns.RR
    end
  end
end

defmodule Adns.Resolver.Request do
  alias Adns.Question

  defstruct [:opcode, :rd, :questions]

  @type t() :: %__MODULE__{
          opcode: Adns.Opcode.atoms(),
          rd: boolean(),
          questions: [Question.t()]
        }
end

defmodule Adns.Resolver.Response do
  alias Adns.RR

  defstruct [:answers, :authority, :additional, :aa, :ra, :rcode]

  @type t() :: %__MODULE__{
          answers: [RR.t()],
          authority: [RR.t()],
          additional: [RR.t()],
          aa: boolean(),
          ra: boolean(),
          rcode: Adns.Rcode.atoms()
        }
end
