defmodule Adns.Resolver.Cache do
  use Adns.Resolver

  @spec config(list(term())) :: :ets.table()
  def config(opts \\ []) do
    :ets.new(
      :adns_cache,
      [
        :set,
        :public
      ] ++ opts
    )
  end

  @type t() :: :ets.table()

  @type key() :: Question.t()

  @type value() :: {answers :: [RR.t()], authority :: [RR.t()], additional :: [RR.t()]}

  @spec register(
          t(),
          key(),
          value()
        ) :: :ok
  def register(cache, key, value) do
    :ets.insert(cache, {key, value})
    :ok
  end

  def find(cache, key) do
    case :ets.lookup(cache, key) do
      [{^key, value}] -> {:ok, value}
      [] -> :miss
    end
  end

  def find_many(_cache, []), do: {:ok, {[], [], []}}

  def find_many(cache, [key]) do
    with {:ok, {answers, authority, additional}} <- find(cache, key) do
      {:ok, {answers, authority, additional}}
    end
  end

  def find_many(cache, [key | rest]) do
    with {:ok, {answers, authority, additional}} <- find(cache, key),
         {:ok, {rest_answers, rest_authority, rest_additional}} <- find_many(cache, rest) do
      {:ok, {answers ++ rest_answers, authority ++ rest_authority, additional ++ rest_additional}}
    end
  end

  @spec delete(:ets.table(), key()) :: :ok
  def delete(cache, key) do
    :ets.delete(cache, key)
    :ok
  end

  def resolve(%Adns.Resolver.Request{questions: questions}, cache) do
    with {:ok, {answers, authority, additional}} <-
           Adns.Resolver.Cache.find_many(cache, questions) do
      %Adns.Resolver.Response{
        answers: answers,
        authority: authority,
        additional: additional,
        aa: false,
        ra: false,
        rcode: Rcode.ok()
      }
    else
      :miss ->
        {%Adns.Resolver.Response{
           answers: [],
           authority: [],
           additional: [],
           aa: false,
           ra: false,
           rcode: Rcode.server_failure()
         }, cache}
    end
  end
end
