defmodule Credo.Check.Refactor.UnusedPublicFunctions.CallsCollector do
  @moduledoc """
  Collects all function calls from all source files.

  Returns a list of MFA tuples.
  """

  def collect_function_calls(source_files) do
    Enum.flat_map(source_files, &get_function_calls/1)
    |> MapSet.new()
    |> MapSet.to_list()
  end

  defp get_function_calls(source_file) do
    ast = Credo.SourceFile.ast(source_file)

    {aliases, imports, delegates, current_module} = extract_module_context(ast)

    {_, calls} =
      Macro.prewalk(ast, [], fn
        # Handle use Module, :function pattern
        {:use, _meta, [{:__aliases__, _, module_parts}, function]} = node, acc when is_atom(function) ->
          module = resolve_module(module_parts, aliases)
          {node, [{module, function, 0} | acc]}

        # Skip the {} operator calls
        {{:., _, [_, :{}]}, _, _} = node, acc ->
          {node, acc}

        # Handle direct module calls
        {{:., _, [{:__aliases__, _, module_parts}, function]}, _, args} = node, acc ->
          module = resolve_module(module_parts, aliases)
          {node, [{module, function, length(args)} | acc]}

        # Handle potential delegated or imported function calls
        {function, _, args} = node, acc when is_atom(function) and is_list(args) ->
          arity = length(args)

          cond do
            # Check if this is a delegated function call
            delegate = Map.get(delegates, {function, arity}) ->
              case delegate do
                {target_mod, _fun, _arity} ->
                  # Add both the local call and the delegated call
                  local_call = {current_module, function, arity}
                  delegated_call = {target_mod, function, arity}
                  {node, [delegated_call, local_call | acc]}

                nil ->
                  {node, acc}
              end

            # Check imports
            import_result = resolve_import(function, arity, imports) ->
              {node, [import_result | acc]}

            true ->
              {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    Enum.sort_by(calls, fn {module, function, _arity} -> {Kernel.to_string(module), Kernel.to_string(function)} end)
  end

  defp extract_module_context(ast) do
    {_, {aliases, imports, delegates, current_module}} =
      Macro.prewalk(ast, {%{}, %{}, %{}, nil}, fn
        # Track current module
        {:defmodule, _, [{:__aliases__, _, module_parts} | _]} = node, {aliases, imports, delegates, _} ->
          module = safe_module_concat(module_parts)
          {node, {aliases, imports, delegates, module}}

        # Handle defdelegate
        {:defdelegate, _, [{function, _, args}, [to: {:__aliases__, _, module_parts}]]} = node,
        {aliases, imports, delegates, current_module} ->
          arity = if args, do: length(args), else: 0
          target_module = safe_module_concat(module_parts)
          delegate_key = {function, arity}
          delegate_value = {target_module, function, arity}
          {node, {aliases, imports, Map.put(delegates, delegate_key, delegate_value), current_module}}

        # Handle multi-alias syntax: alias MyApp.Services.{A, B, C}
        {:alias, _,
         [
           {{:., _, [{:__aliases__, _, base_parts}, :{}]}, _, multi_parts}
         ]} = node,
        {aliases, imports, delegates, current_module} ->
          base_module = safe_module_concat(base_parts)

          new_aliases =
            multi_parts
            |> Enum.map(fn {:__aliases__, _, [part]} ->
              full_module = Module.concat(base_module, part)
              {part, full_module}
            end)
            |> Enum.into(%{})

          {node, {Map.merge(aliases, new_aliases), imports, delegates, current_module}}

        # Skip the {} operator call itself
        {{:., _, [_module, :{}]}, _, _} = node, acc ->
          {node, acc}

        # Handle aliases with 'as'
        {:alias, _, [{:__aliases__, _, alias_parts}, [as: {:__aliases__, _, [as_part]}]]} = node,
        {aliases, imports, delegates, current_module} ->
          alias_module = safe_module_concat(alias_parts)
          {node, {Map.put(aliases, as_part, alias_module), imports, delegates, current_module}}

        # Handle regular aliases
        {:alias, _, [{:__aliases__, _, alias_parts}]} = node, {aliases, imports, delegates, current_module} ->
          alias_module = safe_module_concat(alias_parts)
          {node, {Map.put(aliases, List.last(alias_parts), alias_module), imports, delegates, current_module}}

        # Handle imports with only: option
        {:import, _, [{:__aliases__, _, module_parts}, [only: import_functions]]} = node,
        {aliases, imports, delegates, current_module} ->
          module = safe_module_concat(module_parts)
          new_imports = extract_import_functions(module, import_functions, imports)
          {node, {aliases, new_imports, delegates, current_module}}

        # Handle regular imports
        {:import, _, [{:__aliases__, _, module_parts}]} = node, {aliases, imports, delegates, current_module} ->
          module = safe_module_concat(module_parts)
          {node, {aliases, Map.put(imports, module, :all), delegates, current_module}}

        node, acc ->
          {node, acc}
      end)

    {aliases, imports, delegates, current_module}
  end

  defp extract_import_functions(module, import_functions, imports) do
    imported =
      Enum.reduce(import_functions, %{}, fn {function, arity}, acc ->
        Map.put(acc, {function, arity}, module)
      end)

    Map.merge(imports, imported)
  end

  defp resolve_import(function, arity, imports) do
    case Map.get(imports, {function, arity}) do
      nil -> nil
      module -> {module, function, arity}
    end
  end

  defp safe_module_concat(parts) do
    parts
    |> Enum.map(fn
      {:__MODULE__, _, _} -> "__MODULE__"
      part when is_atom(part) -> Atom.to_string(part)
      part when is_binary(part) -> part
    end)
    |> Enum.reject(&(&1 == "__MODULE__"))
    |> Module.concat()
  end

  defp resolve_module(module_parts, aliases) do
    case module_parts do
      [head | tail] ->
        case Map.get(aliases, head) do
          nil -> safe_module_concat(module_parts)
          base_module -> safe_module_concat([base_module | tail])
        end

      _ ->
        safe_module_concat(module_parts)
    end
  end
end
