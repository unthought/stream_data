defmodule StreamData.Stateful do

  import ExUnitProperties, only: [pick: 1]
  import StreamData
# import Commander.Command

  defmacro symcall({{:., _, [mod, fun]}, _, args}) do
    quote do
      {:call, unquote(mod), unquote(fun), unquote(args)}
    end
  end
  defmacro symcall({fun, _, args}) do
    quote do
      {:call, __MODULE__, unquote(fun), unquote(args)}
    end
  end


  # TODO verify these
  @type args :: [any]
  @type symstate :: any
  @type runstate :: any
  @type result :: any | symvar

  @type symcall :: {:call, module, atom, args}
  @type symvar :: {:var, integer}
  @type symret :: symvar
  @type symset :: {:set, symvar, symcall}
  @type ret :: any

  @type driver :: module

  defmodule Driver do
    alias Stateful, as: St

    @callback gen_call(St.symstate) :: St.symcall

    @callback pre!(St.symstate, St.symcall) :: none | no_return

    @callback next(St.symstate | St.runstate,
                   St.symcall,
                   St.symret | St.ret) :: St.symstate | St.runstate

    @callback post!(St.runstate, St.symcall, St.ret) :: none | no_return
  end

# @spec gen_commands(module, {gen_state, exec_state}) :: StreamData.t([symcall])

  @spec gen_commands(module) :: StreamData.t([symcall])
  def gen_commands(driver) do
    gen_commands(driver, driver.initial_state())
  end

  # TODO shrinking doesn't seem to work
  @spec gen_commands(module, symstate | symcall) :: StreamData.t([symcall])
  def gen_commands(driver, init_symstate) do
    bind(
      sized(fn size ->
        gen_commands(size, driver, init_symstate, 1)
        |> filter(&valid_cmds?(driver, &1, init_symstate))
      end), fn cmds ->
        constant([{:init, init_symstate} | cmds])
      end)
  end

  # :: StreamData.t([symcall])
  defp gen_commands(1, driver, symstate, step) do
    constant([])
  end
  defp gen_commands(size, driver, symstate, step) do
    bind_filter(
      driver.gen_command(symstate),
      fn symcall ->
        if pre?(driver, symstate, symcall) do
          var = {:var, step}
          next_gen_state = driver.next(symstate, symcall, var)

          cmds = 
            bind(
              gen_commands(size - 1, driver, next_gen_state, step + 1),
              fn tail ->
                constant([{:set, var, symcall} | tail])
              end)
          {:cont, cmds}
        else
          :skip
        end
      end)
  end

  defp valid_cmds?(driver, cmds, gen_state) do
    final_state = 
      Enum.reduce_while(
        cmds, {gen_state, 1}, 
        fn {:set, _, {:call, _, _, _} = symcall}, {gen_state, var} ->
          if pre?(driver, gen_state, symcall) do
            {:cont, {driver.next(gen_state, symcall, {:var, var}), var + 1}}
          else
            {:halt, false}
          end
        end)
    case final_state do
      false -> false
      _ -> true
    end
  end

  @doc """
  Turns pre! into a boolean predicate (only for assert related errors).
  """
  @spec pre?(driver, symstate, symcall) :: boolean
  defp pre?(driver, symstate, symcall) do
    try do
      driver.pre!(symstate, symcall)
      true
    rescue
      ExUnit.AssertionError -> false
      ExUnit.MultiError -> false
      ExUnit.TimeoutError -> false
    end
  end


  def run_commands(driver, cmds) do
    run_commands(driver, cmds, [])
  end

  def run_commands(driver, cmds, env) do
    run_command(cmds, env, driver, [], driver.initial_state())
  end

  def run_command(cmds, env, driver, history, state) do
    case cmds do
      [] ->
        {{history, eval(env, state), :ok}, env}
      [{:init, _state} | cmds] ->
        # drop init, dynstate init already happened
        run_command(cmds, env, driver, history, state)
      [{:set, {:var, var}, {:call, mod, fun, args} = call} | cmds] ->

        mod = eval(env, mod)
        fun = eval(env, fun)
        args = eval(env, args)

        resolved_call = {:call, mod, fun, args} 
        res = apply(mod, fun, args)

        history = [resolved_call | history]

        # TODO exception aborts correctly, but we could send a bit more
        # details
        driver.post!(state, resolved_call, res)
        env = [{var, res} | :proplists.delete(var, env)]
        state = driver.next(state, call, res)
        state = eval(env, state)
        run_command(cmds, env, driver, history, state)
    end
  end


  def eval(env, [head | tail]) do
    [eval(env, head) | eval(env, tail)];
  end
  def eval(env, {:call, mod, fun, args}) do
    mod = eval(env, mod)
    fun = eval(env, fun)
    args = eval(env, args)
    apply(mod, fun, args)
  end
  def eval(env, {:var, var}) when is_integer(var) do
    case :proplists.lookup(var, env) do
      nil -> {:var, var}
      {^var, value} -> value
    end
  end
  def eval(env, tuple) when is_tuple(tuple) do
    eval(env, Tuple.to_list(tuple))
    |> List.to_tuple
  end
  # TODO maps
  def eval(_, term) do 
    term
  end


end

