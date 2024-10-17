defmodule Checkbook.Check.Refactor.UnusedPublicFunctions do
  use Credo.Check,
    base_priority: :normal,
    category: :refactor,
    param_defaults: [
      ignore_exposed_for_testing: false
    ],
    explanations: [
      check: """
      Finds unused public functions in the current module.
      This check analyzes all files in the lib directory to accurately detect function usage.
      It also identifies functions that may be exposed solely for testing.
      """,
      params: [
        ignore_exposed_for_testing: "Set to true to ignore functions exposed for testing."
      ]
    ]

  @cache_table :unused_functions_cache
  @cache_agent :unused_functions_cache_agent

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    if should_run?(source_file) do
      ensure_cache_initialized()

      issue_meta = IssueMeta.for(source_file, params)

      public_functions = get_public_functions(source_file)
      exposed_for_testing = get_exposed_for_testing(source_file)
      all_function_calls = get_cached_function_calls()

      unused_functions = find_unused_functions(public_functions, exposed_for_testing, all_function_calls)

      ignore_exposed = Params.get(params, :ignore_exposed_for_testing, __MODULE__)

      unused_functions
      |> maybe_filter_exposed(ignore_exposed)
      |> Enum.map(fn {function, arity, type} ->
        create_issue(issue_meta, source_file, function, arity, type)
      end)
    else
      []
    end
  end

  defp should_run?(%SourceFile{filename: filename}) do
    String.starts_with?(filename, "lib/")
  end

  defp ensure_cache_initialized do
    Agent.start(fn -> false end, name: @cache_agent)
    Agent.get_and_update(@cache_agent, fn state ->
      if state do
        {state, state}
      else
        :ets.new(@cache_table, [:set, :public, :named_table])
        calls = gather_all_function_calls()
        :ets.insert(@cache_table, {:all_function_calls, calls})
        {true, true}
      end
    end)
  end

  defp get_cached_function_calls do
    case :ets.lookup(@cache_table, :all_function_calls) do
      [{:all_function_calls, calls}] -> calls
      [] ->
        calls = gather_all_function_calls()
        :ets.insert(@cache_table, {:all_function_calls, calls})
        calls
    end
  end

  defp get_public_functions(%SourceFile{} = source_file) do
    {_, functions} =
      Macro.prewalk(SourceFile.ast(source_file), [], fn
        {:def, _meta, [{name, _, args} | _]} = node, acc ->
          arity = if is_list(args), do: length(args), else: 0
          {node, [{name, arity} | acc]}

        {:defp, _, _}, acc ->
          {nil, acc}

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(functions)
  end

  defp gather_all_function_calls do
    Path.wildcard("lib/**/*.ex")
    |> Enum.flat_map(fn file ->
      {:ok, ast} = File.read!(file) |> Code.string_to_quoted()
      get_function_calls(ast)
    end)
    |> Enum.uniq()
  end

  def get_function_calls(ast) do
    aliases = extract_aliases(ast)

    {_, calls} =
      Macro.prewalk(ast, [], fn
        {{:., _, [{:__aliases__, _, module_parts}, function]}, _, args} = node, acc ->
          module = resolve_module(module_parts, aliases)
          {node, [{module, function, length(args)} | acc]}

        {:use, _, [{:__aliases__, _, module_parts}, arg]} = node, acc ->
          module = resolve_module(module_parts, aliases)
          {node, [{module, arg, 0} | acc]}

        {function, _, args} = node, acc when is_atom(function) and is_list(args) ->
          {node, [{:potential_import, function, length(args)} | acc]}

        {:alias, _, [{:__aliases__, _, alias_parts}]} = node, acc ->
          alias_module = safe_module_concat(alias_parts)
          {node, [{alias_module, :__aliases__, 0} | acc]}

        node, acc ->
          {node, acc}
      end)

    calls
  end

  defp find_unused_functions(public_functions, exposed_for_testing, all_function_calls) do
    public_functions
    |> Enum.reject(fn {function, arity} ->
      Enum.any?(all_function_calls, fn
        {_, ^function, ^arity} -> true
        {:potential_import, ^function, ^arity} -> true
        _ -> false
      end)
    end)
    |> Enum.map(fn {function, arity} ->
      case Enum.find(exposed_for_testing, fn {f, a, _} -> f == function and a == arity end) do
        nil -> {function, arity, :unused}
        {_, _, attr_name} -> {function, arity, {:exposed_for_testing, attr_name}}
      end
    end)
  end

  defp create_issue(issue_meta, source_file, function, arity, type) do
    line_no = find_function_line(source_file, function, arity)
    message = case type do
      :unused -> "Unused public function: #{function}/#{arity}"
      {:exposed_for_testing, attr_name} -> "Function likely exposed for testing: #{function}/#{arity} (returns @#{attr_name})"
    end
    format_issue(issue_meta, message: message, line_no: line_no)
  end

  defp find_function_line(%SourceFile{} = source_file, function_name, arity) do
    regex = ~r/^\s*def\s+#{function_name}\s*\/\s*#{arity}/

    SourceFile.lines(source_file)
    |> Enum.find_index(fn {_, line} -> line =~ regex end)
    |> case do
      nil -> nil
      index -> index + 1
    end
  end

  defp extract_aliases(ast) do
    {_, aliases} = Macro.prewalk(ast, %{}, fn
      {:alias, _, [{:__aliases__, _, alias_parts}, [as: {:__aliases__, _, [as_part]}]]} = node, acc ->
        alias_module = safe_module_concat(alias_parts)
        {node, Map.put(acc, as_part, alias_module)}

      {:alias, _, [{:__aliases__, _, alias_parts}]} = node, acc ->
        alias_module = safe_module_concat(alias_parts)
        {node, Map.put(acc, List.last(alias_parts), alias_module)}

      node, acc ->
        {node, acc}
    end)
    aliases
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

  defp get_exposed_for_testing(%SourceFile{} = source_file) do
    {_, exposed} =
      Macro.prewalk(SourceFile.ast(source_file), [], fn
        {:def, _meta, [{name, _, nil}, [do: {:@, _, [{attr_name, _, nil}]}]]} = node, acc ->
          {node, [{name, 0, attr_name} | acc]}

        {:def, _meta, [{name, _, nil}, [do: {{:., _, [{:__aliases__, _, [:Enum]}, :map]}, _,
          [{:@, _, [{attr_name, _, nil}]}, _]}]]} = node, acc ->
          {node, [{name, 0, attr_name} | acc]}

        node, acc ->
          {node, acc}
      end)

    exposed
  end

  defp maybe_filter_exposed(unused_functions, true) do
    Enum.reject(unused_functions, fn {_, _, type} ->
      case type do
        {:exposed_for_testing, _} -> true
        _ -> false
      end
    end)
  end
  defp maybe_filter_exposed(unused_functions, false), do: unused_functions
end
