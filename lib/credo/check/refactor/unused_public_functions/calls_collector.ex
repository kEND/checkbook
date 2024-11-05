defmodule Credo.Check.Refactor.UnusedPublicFunctions.CallsCollector do
  alias Credo.Check.Refactor.UnusedPublicFunctions.BehaviourMapper

  import Credo.Check.Refactor.UnusedPublicFunctions.ModuleHelper

  @moduledoc """
  Collects all function calls from all source files.

  Returns a list of MFA tuples.
  """

  def collect_function_calls(source_files) do
    # Get behaviour mappings
    {behaviours, implementations} = BehaviourMapper.map_behaviours(source_files)

    # Collect calls with behaviour context
    source_files
    |> Enum.flat_map(&get_function_calls(&1, behaviours, implementations))
    |> MapSet.new()
    |> MapSet.to_list()
  end

  defp get_function_calls(source_file, behaviours, implementations) do
    ast = Credo.SourceFile.ast(source_file)
    {aliases, imports, delegates, current_module} = extract_module_context(ast)

    {_, calls} =
      Macro.traverse(ast, [],
        fn
          # Skip the {} operator calls from multiple aliases
          {{:., _, [_, :{}]}, _, _} = node, acc ->
            {node, acc}

          # Collect piped function calls with correct arity
          {:|>, _, [_, {{:., _, [{:__aliases__, _, module_parts}, function]}, _, args}]} = node, acc ->
            module = resolve_module(module_parts, aliases)
            {node, [{module, function, length(args) + 1} | acc]}

          # Skip all other nodes in pre-traversal
          node, acc ->
            {node, acc}
        end,
        fn node, acc ->
          {node, acc}
        end)

    # Now collect all non-piped function calls
    {_, non_piped_calls} =
      Macro.traverse(ast, [],
        fn
          # Skip the {} operator calls from multiple aliases
          {{:., _, [_, :{}]}, _, _} = node, acc ->
            {node, acc}

          # Skip if parent is a pipe
          {{:., _, [{:__aliases__, _, _}, _]}, _, _} = node, acc ->
            parent = get_parent(ast, node)
            case parent do
              {:|>, _, [_, _]} -> {node, acc}
              _ ->
                case node do
                  {{:., _, [{:__aliases__, _, module_parts}, function]}, _, args} ->
                    module = resolve_module(module_parts, aliases)
                    {node, [{module, function, length(args)} | acc]}
                  _ -> {node, acc}
                end
            end

          # Match dynamic function calls: api_client().send_submit_request(args)
          {{:., _, [{fn1, _, []}, fn2]}, _, args} = node, acc
          when is_atom(fn1) and is_atom(fn2) ->
            new_calls =
              if MapSet.member?(behaviours, current_module) do
                implementations_of_current =
                  implementations
                  |> Enum.filter(fn {_impl, behaviour} -> behaviour == current_module end)
                  |> Enum.map(fn {impl, _} -> impl end)

                [current_module | implementations_of_current]
                |> Enum.map(fn module -> {module, fn2, length(args)} end)
              else
                [{current_module, fn2, length(args)}]
              end
            {node, new_calls ++ acc}

          # Handle unquote calls within quote blocks
          {:unquote, _meta, [{function, _, args}]} = node, acc when is_atom(function) ->
            arity = if is_list(args), do: length(args), else: 0
            {node, [{current_module, function, arity} | acc]}

          # Handle use Module, :function pattern
          {:use, _meta, [{:__aliases__, _, module_parts}, function]} = node, acc when is_atom(function) ->
            module = resolve_module(module_parts, aliases)
            {node, [{module, function, 0} | acc]}

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
        end,
        fn node, acc -> {node, acc} end)

    (calls ++ non_piped_calls)
    |> Enum.sort_by(fn {module, function, _arity} -> {Kernel.to_string(module), Kernel.to_string(function)} end)
  end

  # Helper function to find parent node
  defp get_parent(ast, target) do
    {_, parent} =
      Macro.traverse(ast, nil,
        fn
          node, nil ->
            children = case node do
              {_, _, args} when is_list(args) -> args
              _ -> []
            end
            if target in List.wrap(children) do
              {node, node}
            else
              {node, nil}
            end
          node, acc -> {node, acc}
        end,
        fn node, acc -> {node, acc} end)
    parent
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
end
