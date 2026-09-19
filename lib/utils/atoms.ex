defmodule Adns.Utils.Atom do
  def union_type(elements) do
    Enum.reduce(elements, fn element, acc ->
      quote do
        unquote(acc) | unquote(element)
      end
    end)
  end

  defmacro define_mapping(mapping, default \\ true, generic \\ false) do
    mappings =
      for {atom, value} <- mapping do
        lower =
          atom
          |> Atom.to_string()
          |> String.downcase()
          |> String.to_atom()

        quote do
          @spec atom(unquote(value)) :: unquote(atom)
          def atom(unquote(value)), do: unquote(atom)

          @spec value(unquote(atom)) :: unquote(value)
          def value(unquote(atom)), do: unquote(value)

          @spec unquote(lower)() :: unquote(atom)
          def unquote(lower)(), do: unquote(atom)
        end
      end

    atoms = Enum.map(mapping, &elem(&1, 0))
    values = Enum.map(mapping, &elem(&1, 1))

    atom_type = union_type(atoms)
    value_type = union_type(values)

    quote do
      if unquote(generic) do
        @type atoms() :: unquote(atom_type)
        @type values() :: unquote(value_type)
      else
        @type atoms() :: unquote(atom_type) | atom()
        @type values() :: unquote(value_type) | term()
      end

      unquote_splicing(mappings)

      if unquote(default) do
        @spec atom(term()) :: :unknown
        def atom(_), do: :unknown

        @spec value(atom()) :: :unknown
        def value(_), do: :unknown
      end
    end
  end
end
