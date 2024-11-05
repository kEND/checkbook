defmodule Credo.Check.Refactor.UnusedPublicFunctions do
  use Credo.Check,
    run_on_all: true,
    category: :refactor,
    base_priority: :high,
    param_defaults: [
      files_to_scan: ["lib/", "test/"],
      files_to_analyze: ["lib/", "test/"]
    ],
    explanations: [
      check: """
      Public functions that are never called should be considered for removal.

      Unused public functions:
      - Increase cognitive load by making the codebase larger than necessary
      - May indicate dead code or incomplete refactoring
      - Can lead to maintenance confusion about what code is actually in use
      - Expose more of the module's API than necessary

      Example:

          defmodule MyModule do
            def used_function, do: :ok

            # this function is never called
            def unused_function, do: :ok

            defp private_function do
              used_function()
            end
          end

      The `unused_function` should be removed if it's no longer needed.
      """
    ]

  alias Credo.Check.Refactor.UnusedPublicFunctions.CallsCollector
  alias Credo.Check.Refactor.UnusedPublicFunctions.Collector

  @impl true
  def run_on_all_source_files(exec, source_files, params) do
    files_to_scan = Params.get(params, :files_to_scan, __MODULE__)
    files_to_analyze = Params.get(params, :files_to_analyze, __MODULE__)

    # Collect all function calls in the codebase
    function_calls =
      source_files
      |> filter_files(files_to_scan)
      |> CallsCollector.collect_function_calls()

    # Process each source file
    source_files
    |> filter_files(files_to_analyze)
    |> Task.async_stream(
      fn source_file ->
        issues =
          source_file
          |> Collector.collect_unused_functions(function_calls)
          |> Enum.map(fn {{module, function, arity}, [line: line]} ->
            format_issue(
              IssueMeta.for(source_file, params),
              message: "#{inspect(module)}.#{function}/#{arity} is unused",
              trigger: "#{function}/#{arity}",
              line_no: line
            )
          end)

        Credo.Execution.ExecutionIssues.append(exec, issues)
      end,
      max_concurrency: exec.max_concurrent_check_runs,
      timeout: :infinity,
      ordered: false
    )
    |> Stream.run()

    :ok
  end

  defp filter_files(source_files, nil), do: source_files

  defp filter_files(source_files, file_patterns) do
    Enum.filter(source_files, fn source_file ->
      Enum.any?(file_patterns, fn prefix -> String.starts_with?(source_file.filename, prefix) end)
    end)
  end
end
