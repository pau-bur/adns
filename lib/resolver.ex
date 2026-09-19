defmodule Adns.Resolver do
  @moduledoc """
  Behaviour for DNS lookup logic, separate from transport.

  Implement `c:resolve/2` and pass the module to `Adns.Server.UDP`. `use Adns.Resolver`
  sets the behaviour and common aliases.
  """

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
  @moduledoc """
  Inputs passed to `c:Adns.Resolver.resolve/2` (opcode, recursion desired, questions).
  """

  alias Adns.Question

  defstruct [:opcode, :rd, :questions]

  @type t() :: %__MODULE__{
          opcode: Adns.Opcode.atoms(),
          rd: boolean(),
          questions: [Question.t()]
        }
end

defmodule Adns.Resolver.Response do
  @moduledoc """
  Resolver output: answer sections plus `aa`, `ra`, and `rcode` flags.
  """

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
