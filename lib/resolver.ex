defmodule Adns.Resolver do
  @callback resolve(Adns.Resolver.Request.t()) :: Adns.Resolver.Response.t()
end

defmodule Adns.Resolver.Request do
  alias Adns.Question
  alias Adns.Types

  defstruct [:opcode, :rd, :questions]

  @type t() :: %__MODULE__{
          opcode: Types.uint4(),
          rd: 0 | 1,
          questions: [Question.t()]
        }
end

defmodule Adns.Resolver.Response do
  alias Adns.RR
  alias Adns.Types

  defstruct [:answers, :authority, :additional, :aa, :ra, :rcode]

  @type t() :: %__MODULE__{
          answers: [RR.t()],
          authority: [RR.t()],
          additional: [RR.t()],
          aa: 0 | 1,
          ra: 0 | 1,
          rcode: Types.uint4()
        }
end
