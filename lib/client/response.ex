defmodule Adns.Client.Response do
  alias Adns.RR

  defstruct [:answers, :authority, :additional, :aa, :ra, :tc, :rcode]

  @type t() :: %__MODULE__{
          answers: [RR.t()],
          authority: [RR.t()],
          additional: [RR.t()],
          aa: boolean(),
          ra: boolean(),
          tc: boolean(),
          rcode: Adns.Rcode.atoms()
        }
end
