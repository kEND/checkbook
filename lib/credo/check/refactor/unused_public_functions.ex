defmodule Credo.Check.Refactor.UnusedPublicFunctions do
  use Credo.Check, run_on_all: true, category: :refactor

  alias Credo.Check.Refactor.UnusedPublicFunctions.Collector

  @impl true
  def run_on_all_source_files(exec, source_files, params) do
    # Collect all function calls in the codebase
    function_calls = collect_function_calls(source_files)

    # Run the collector for each source file
    source_files
    |> Enum.flat_map(&Collector.collect_unused_functions(&1, function_calls))
    |> format_issues()
  end

  defp collect_function_calls(source_files) do
    # Logic to collect all function calls from source files
    # Placeholder for now
    []
  end

  defp format_issues(unused_functions) do
    # Format the unused functions into Credo issues
    # Placeholder for now
    []
  end
end
