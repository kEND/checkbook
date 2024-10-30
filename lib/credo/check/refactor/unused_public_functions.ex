defmodule Credo.Check.Refactor.UnusedPublicFunctions do
  use Credo.Check,
    run_on_all: true,
    category: :refactor,
    base_priority: :high,
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
    # Collect all function calls in the codebase
    function_calls = CallsCollector.collect_function_calls(source_files)

    # Process each source file
    source_files
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
end
