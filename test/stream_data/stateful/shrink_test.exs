defmodule StreamData.Stateful.ShrinkTest do
  @moduledoc """
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  import StreamData
  import StreamData.Stateful
  alias __MODULE__.{Push, Pop, PopOnEmpty}

  ######################################################################

  property "shrinking works" do
    # TODO currently broken because can't easily nuke state
    check all cmds <- scale(gen_commands(__MODULE__), &(&1 * 3)) do

      case run_commands(__MODULE__, cmds) do
        {{_, _, :ok}, _} -> true
        {{history, state, result}, env} -> 
          IO.inspect(result, label: "result", pretty: true)
          IO.inspect(history, label: "history", pretty: true)
          IO.inspect(state, label: "state", pretty: true)
          IO.inspect(env, label: "env", pretty: true)
      end

      #cleanup()
    end
  end

  ######################################################################

  # SUT (system under test), the default Stack GenServer example (with
  # support for :pop on empty.

  defmodule Stack do
    use GenServer
  
    def handle_call(:pop, _from, stack) do
      case stack do
        []      -> {:reply, :empty, stack}
        [h | t] -> {:reply, h, t}
      end
    end
  
    def handle_cast({:push, item}, stack) do
      {:noreply, [item | stack]}
    end
  end

  ######################################################################

  defmodule State do
    defstruct pid: nil, stack: []
  end

  def initial_state() do
    {:ok, pid} = GenServer.start_link(Stack, [])
    %State{pid: pid, stack: []}
  end

  def gen_command(state) do
    case state.stack do
      [] ->
        frequency([
          {1, Push.gen(state)},
          #{1, PopOnEmpty.gen(state)},
        ])
      _ ->
        frequency([
          {1, Push.gen(state)},
          {1, Pop.gen(state)},
        ])
    end
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

  defmodule Push do

    def gen(state) do
      gen_symcall run(constant(state.pid), integer())
    end

    def run(pid, item), do: GenServer.cast(pid, {:push, item})

    def pre!(s, [pid, _item]) do
      assert s.pid == pid
    end
 
    def post!(_s, [_pid, _item], :ok) do
      #assert s.pid == pid
    end
 
    def next(s, [_pid, item], _ret) do
      %{ s |
        stack: [item | s.stack]
      }
    end
  end

  defmodule Pop do

    def gen(state) do
      gen_symcall run(constant state.pid)
    end

    def run(pid), do: GenServer.call(pid, :pop)

    def pre!(s, [_pid]) do
      #assert s.pid == pid
      assert length(s.stack) > 0
    end
 
    def post!(%State{stack: [val | _rest]}, [_pid], ret) do
      assert val == ret
    end
 
    def next(s = %State{stack: [_popped | rest]}, [_pid], _ret) do
      %{ s |
        stack: rest
      }
    end
  end

  defmodule PopOnEmpty do

    def gen(state) do
      gen_symcall run(constant state.pid)
    end

    def run(pid), do: GenServer.call(pid, :pop)

    def pre!(s, [_pid]) do
      #assert s.pid == pid
      assert length(s.stack) == 0
    end
 
    def post!(s, [_pid], ret) do
      assert length(s.stack) == 0
      assert :empty == ret
    end
 
    def next(s, [_pid], _ret) do
      s
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

:dbg.p(:all, :c)

