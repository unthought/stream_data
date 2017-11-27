defmodule StreamData.Stateful.CommandPdictTest do
  @moduledoc """
  implements the pdict property check in command style.  Command style
  is more readable with larger models, because all operations are
  grouped by command.
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  import StreamData
  import StreamData.Stateful

  alias StreamData.Stateful.CommandPdictTest.{Put,Get,Erase}

  property "pdict works (command style)" do
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
        constant(symcall Put.run(k, v))
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
          (symcall Put.run(k, v)),
          (symcall Get.run(k)),
          (symcall Erase.run(k)),
        ])
      end)
  end

  def pre!(props, {:call, cmd_mod, :run, args}) do
    cmd_mod.pre!(props, args)
  end

  def post!(prev_props, {:call, cmd_mod, :run, args}, val) do
    cmd_mod.post!(prev_props, args, val)
  end

  def next(prev_props, {:call, cmd_mod, :run, args}, res) do
    cmd_mod.next(prev_props, args, res)
  end

  ######################################################################

  defmodule Put do

    def pre!(_, [_,_]) do
      # no preconditions
    end

    def run(key, value), do: :erlang.put(key, value)

    def post!(prev_props, [key, _], prev_val) do
      case prev_val do
        :undefined ->
          assert not :proplists.is_defined(key, prev_props)
        _ -> 
          assert {key, prev_val} == :proplists.lookup(key, prev_props)
      end
    end

    def next(props, [key, value], _ret) do
      [{key, value} | :proplists.delete(key, props)]
    end
  end


  defmodule Get do
    
    def pre!(props, [key]) do
      assert :proplists.is_defined(key, props)
    end

    def run(key), do: :erlang.get(key)

    def post!(prev_props, [key], val) do
      assert {key, val} == :proplists.lookup(key, prev_props)
    end

    def next(props, [_], _ret) do
      props
    end
  end


  defmodule Erase do

    def pre!(props, [key]) do
      assert :proplists.is_defined(key, props)
    end

    def run(key), do: :erlang.erase(key)

    def post!(prev_props, [key], val) do
      assert {key, val} == :proplists.lookup(key, prev_props)
    end

    def next(props, [key], _ret) do
      :proplists.delete(key, props)
    end
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

#:dbg.p(:all, :c)
