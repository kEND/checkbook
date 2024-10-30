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

  # Handle Enum.each specifically with def unquote
  defp pre_traverse(
         {{:., _, [{:__aliases__, _, [:Enum]}, :each]}, meta,
          [
            enum_items,
            {:fn, _, [{:->, _, [_params, {:def, _def_meta, [{{:unquote, _, _}, _, _} = unquote_expr | _] = def_args}]}]}
          ]} = node,
         {[current_module | _] = stack, fns}
       )
       when is_list(enum_items) do
    new_fns = create_dynamic_functions(enum_items, unquote_expr, def_args, current_module, meta[:line])
    {node, {stack, new_fns ++ fns}}
  end

  # Handle regular public function definitions (skip if it contains unquote)
  defp pre_traverse({:def, meta, [{name, _, args} | _]} = node, {[current_module | _] = stack, fns})
       when not is_tuple(name) do
    arity = if is_list(args), do: length(args), else: 0
    function_tuple = {{current_module, name, arity}, line: meta[:line]}
    {node, {stack, [function_tuple | fns]}}
  end

  # Skip private functions and other def with unquote
  defp pre_traverse({:def, _, [{:unquote, _, _} | _]} = node, acc), do: {node, acc}
  defp pre_traverse({:defp, _, _} = node, acc), do: {node, acc}

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

  defp create_dynamic_functions(enum_items, unquote_expr, def_args, current_module, line_no) do
    arity = count_args_from_pattern(def_args)

    enum_items
    |> Enum.reverse()
    |> Enum.map(fn item ->
      # Extract the string parts and interpolation from the function name
      function_name =
        case unquote_expr do
          {{:unquote, _,
            [
              {{:., _, [:erlang, :binary_to_atom]}, _,
               [
                 {:<<>>, _, parts},
                 :utf8
               ]}
            ]}, _, _} ->
            # Resolve the interpolated string
            parts
            |> Enum.map(fn
              string when is_binary(string) -> string
              {:"::", _, [{{:., _, _}, _, [_var]}, _]} -> item
            end)
            |> Enum.join()
            |> String.to_atom()
        end

      {{current_module, function_name, arity}, line: line_no}
    end)
  end

  defp count_args_from_pattern([{_, _, [args | _]} | _]) when is_map(args), do: 1
  defp count_args_from_pattern([{_, _, args} | _]) when is_list(args), do: length(args)
  defp count_args_from_pattern(_), do: 0
end
