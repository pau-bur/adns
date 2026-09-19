defmodule Adns.Client.Response do
  @moduledoc """
  Parsed DNS reply sections and flags returned by `Adns.Client`.
  """

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
