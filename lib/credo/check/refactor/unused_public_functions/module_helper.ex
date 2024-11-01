defmodule Credo.Check.Refactor.UnusedPublicFunctions.ModuleHelper do
  @moduledoc """
  Helper functions for module name resolution and concatenation.
  Extracted from CallsCollector.
  """

  def resolve_module(module_parts, aliases) do
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

  def safe_module_concat(parts) do
    parts
    |> Enum.map(fn
      {:__MODULE__, _, _} -> "__MODULE__"
      part when is_atom(part) -> Atom.to_string(part)
      part when is_binary(part) -> part
    end)
    |> Enum.reject(&(&1 == "__MODULE__"))
    |> Module.concat()
  end
end
