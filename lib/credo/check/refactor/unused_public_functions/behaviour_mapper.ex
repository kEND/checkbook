defmodule Credo.Check.Refactor.UnusedPublicFunctions.BehaviourMapper do
  @moduledoc """
  Maps relationships between behaviour-defining modules and their implementations.
  """

  import Credo.Check.Refactor.UnusedPublicFunctions.ModuleHelper

  @type behaviour_module :: module()
  @type implementation_module :: module()
  @type implementation_tuple :: {implementation_module(), behaviour_module()}
  @type alias_map :: %{module() => module()}

  @spec map_behaviours([Credo.SourceFile.t()]) :: {MapSet.t(behaviour_module()), MapSet.t(implementation_tuple())}
  def map_behaviours(source_files) do
    Enum.reduce(source_files, {MapSet.new(), MapSet.new()}, fn source_file, {behaviours, implementations} ->
      ast = Credo.SourceFile.ast(source_file)

      {_, {_current_module, _aliases, new_behaviours, new_implementations}} =
        Macro.prewalk(ast, {nil, %{}, behaviours, implementations}, fn
          # Track module definition
          {:defmodule, _, [{:__aliases__, _, module_parts} | _]} = node, {_, aliases, behs, impls} ->
            current_module = safe_module_concat(module_parts)
            {node, {current_module, aliases, behs, impls}}

          # Track alias statements
          {:alias, _, [{:__aliases__, _, module_parts}]} = node, {current_module, aliases, behs, impls} ->
            full_module = safe_module_concat(module_parts)
            short_name = List.last(module_parts)
            new_aliases = Map.put(aliases, short_name, full_module)
            {node, {current_module, new_aliases, behs, impls}}

          # Track modules that define callbacks
          {:@, _, [{:callback, _, _}]} = node, {current_module, aliases, behs, impls} ->
            {node, {current_module, aliases, MapSet.put(behs, current_module), impls}}

          # Track modules that implement behaviours
          {:@, _, [{:behaviour, _, [{:__aliases__, _, module_parts}]}]} = node, {current_module, aliases, behs, impls} ->
            behaviour_module = resolve_module(module_parts, aliases)
            implementation = {current_module, behaviour_module}
            {node, {current_module, aliases, behs, MapSet.put(impls, implementation)}}

          node, acc ->
            {node, acc}
        end)

      {new_behaviours, new_implementations}
    end)
  end
end
