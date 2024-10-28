defmodule Credo.Check.Refactor.UnusedPublicFunctions.Collector do
  def collect_unused_functions(source_file, function_calls) do
    public_functions = MapSet.new(get_public_functions(source_file))
    called_functions = MapSet.new(function_calls)

    MapSet.difference(public_functions, called_functions)
    |> MapSet.to_list()
  end

  def get_public_functions(source_file) do
    ast = Credo.SourceFile.ast(source_file)

    {_, {_module_stack, functions}} =
      ast
      |> Macro.traverse(
        # initial acc: {module_stack, functions}
        {[], []},
        &pre_traverse/2,
        &post_traverse/2
      )

    functions
    |> Enum.reverse()
    |> group_module_functions()
  end

  # Handle entering a module definition
  defp pre_traverse({:defmodule, _, [{:__aliases__, _, module_parts} | _]} = node, {stack, fns}) do
    new_module = Module.concat([Elixir | List.flatten([stack | module_parts])])
    {node, {[new_module | stack], fns}}
  end

  # Handle public function definitions
  defp pre_traverse({:def, _meta, [{name, _, args} | _]} = node, {[current_module | _] = stack, fns}) do
    arity = if is_list(args), do: length(args), else: 0
    {node, {stack, [{current_module, name, arity} | fns]}}
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

  # Helper to create final MFA tuples
  defp group_module_functions(functions) do
    functions
  end
end
