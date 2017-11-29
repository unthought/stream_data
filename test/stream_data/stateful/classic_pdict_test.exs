defmodule StreamData.Stateful.ClassicPdictTest do
  @moduledoc """
  implements the pdict property check in classic style.
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  import StreamData
  import StreamData.Stateful

  property "pdict works (classic style)" do
    check all cmds <- scale(gen_commands(__MODULE__), &(&1 * 3)) do
      case run_commands(__MODULE__, cmds) do
        {{_, _, :ok}, _} -> true
        {{history, state, result}, env} -> 
          IO.inspect(result, label: "result", pretty: true)
          IO.inspect(history, label: "history", pretty: true)
          IO.inspect(state, label: "state", pretty: true)
          IO.inspect(env, label: "env", pretty: true)
      end

      cleanup()
    end
  end

  ######################################################################

  @keys ~w(a b c d)a

  def key(), do: member_of(@keys)

  def cleanup() do
    #Enum.each(@keys, &:erlang.erase/1)
  end

  def initial_state() do
    :erlang.get() |> Keyword.take(@keys)
  end

  def gen_command([]) do
    bind(
      {key(), integer()}, 
      fn {k, v} ->
        constant(symcall :erlang.put(k, v))
      end)
  end
  def gen_command(props) do
    # Note: could incorporate pre! with bind_filter
    bind(
      frequency([
        {2, member_of(props)},   # existing kv pair
        {1, {key(), integer()}}  # non-existing kv pair
      ]),
      fn {k, v} ->
        member_of([
          (symcall :erlang.put(k, v)),
          (symcall :erlang.get(k)),
          (symcall :erlang.erase(k)),
        ])
      end)
  end


  def pre!(_, {:call, :erlang, :put, [_,_]}) do
  end
  def pre!(props, {:call, :erlang, fun, [key]}) when fun in [:get, :erase] do
    assert :proplists.is_defined(key, props)
  end
 
 
  def post!(prev_props, {:call, :erlang, :put, [key, _]}, :undefined) do
    assert not :proplists.is_defined(key, prev_props)
  end
  def post!(prev_props, {:call, :erlang, :put, [key, _]}, old) do
    assert {key, old} == :proplists.lookup(key, prev_props)
  end
  def post!(prev_props, {:call, :erlang, fun, [key]}, val) when fun in [:get, :erase] do
    assert {key, val} == :proplists.lookup(key, prev_props)
  end


  def next(props, {:call, :erlang, :put, [key, value]}, _ret) do
    [{key, value} | :proplists.delete(key, props)] # working model
    #props ++ [{key, value}]                        # b0rked model
  # [{key, value} | props]
  end
  def next(props, {:call, :erlang, :erase, [key]}, _ret) do
    :proplists.delete(key, props)
  end
  def next(props, {:call, :erlang, :get, [_]}, _ret) do
    props
  end
end

#:dbg.tpl(StreamData.Stateful, :run_command, [])
#
#:dbg.tpl(StreamData.Stateful, :_, [])
#:dbg.ctpl(StreamData.Stateful, :eval)

#:dbg.tpl(StreamData.Stateful.ClassicProplistTest, :_, [])
#:dbg.tpl(:erlang, :apply, [])
#:dbg.tpl(Kernel, :apply, [])
#:dbg.tpl(Elixir.Kernel, :apply, [])
#:dbg.tpl(:_, :apply, [])
#
#:dbg.tpl(:_, :pre!, [])
#:dbg.tpl(:_, :next, [])
#:dbg.tpl(:_, :post!, [])

#:dbg.tpl(:proplists, :lookup, [])
#:dbg.tpl(:proplists, :lookup, [:return_trace])
#:dbg.tpl(:proplists, :lookup, 2, [:return_trace])
#:dbg.tpl(StreamData, '_', [])

:dbg.p(:all, :c)
