defmodule Adns.Client.Response do
  alias Adns.RR
  alias Adns.Types

  defstruct [:answers, :authority, :additional, :aa, :ra, :tc, :rcode]

  @type t() :: %__MODULE__{
          answers: [RR.t()],
          authority: [RR.t()],
          additional: [RR.t()],
          aa: 0 | 1,
          ra: 0 | 1,
          tc: 0 | 1,
          rcode: Types.uint4()
        }
end
