defmodule Credo.Check.Refactor.UnusedPublicFunctions.Collector do
  @moduledoc """
  Given a source file and a list of function calls, this module will return a list of unused public functions.

  The function defined are harvested from the ast and then compared to all calls in the code base represented by
  the list of function calls passed in to this module.
  """

  def collect_unused_functions(source_file, function_calls) do
    # Get public functions with their line numbers
    public_functions_with_lines = get_public_functions(source_file)

    # Create sets using just the MFA tuples for comparison
    defined_functions = MapSet.new(public_functions_with_lines, fn {mfa, _line} -> mfa end)
    called_functions = MapSet.new(function_calls)

    # Find unused functions
    unused_mfas = MapSet.difference(defined_functions, called_functions)

    # Return full tuples (with line numbers) for unused functions
    Enum.filter(public_functions_with_lines, fn {mfa, _line} -> MapSet.member?(unused_mfas, mfa) end)
  end

  def get_public_functions(source_file) do
    {_, {_module_stack, functions}} =
      source_file
      |> Credo.SourceFile.ast()
      |> Macro.traverse({[], []}, &pre_traverse/2, &post_traverse/2)

    Enum.reverse(functions)
  end

  # Handle entering a module definition
  defp pre_traverse({:defmodule, _, [{:__aliases__, _, module_parts} | _]} = node, {stack, fns}) do
    new_module = Module.concat([Elixir | List.flatten([stack | module_parts])])
    {node, {[new_module | stack], fns}}
  end

  # Handle defdelegate
  defp pre_traverse({:defdelegate, meta, [{function, _, args}, _to_part]} = node, {[current_module | _] = stack, fns}) do
    arity = if args, do: length(args), else: 0
    function_tuple = {{current_module, function, arity}, line: meta[:line]}
    {node, {stack, [function_tuple | fns]}}
  end

  # Handle public function definitions
  defp pre_traverse({:def, meta, [{name, _, args} | _]} = node, {[current_module | _] = stack, fns}) do
    arity = if is_list(args), do: length(args), else: 0
    function_tuple = {{current_module, name, arity}, line: meta[:line]}
    {node, {stack, [function_tuple | fns]}}
  end

  # Skip private functions
  defp pre_traverse({:defp, _, _} = node, acc) do
    {node, acc}
  end

  # Default case for pre_traverse
  defp pre_traverse(node, acc) do
    {node, acc}
  end

  # Handle exiting a module definition
  defp post_traverse({:defmodule, _, _}, {[_current | rest], fns}) do
    {[], {rest, fns}}
  end

  # Default case for post_traverse
  defp post_traverse(_node, acc) do
    {[], acc}
  end
end
