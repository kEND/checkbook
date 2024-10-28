defmodule Credo.Check.Refactor.UnusedPublicFunctionsTest do
  use Credo.Test.Case

  alias Credo.Check.Refactor.UnusedPublicFunctions

  describe "run/2" do
    setup do
      module_a =
        """
        defmodule ModuleA do

          alias ModuleB, as: ModuleB

          def public_function do
            ModuleB.public_function()
            :ok
          end

          defp private_function do
            public_function()
          end
        end
        """
        |> to_source_file("lib/module_a.ex")

      module_b =
        """
        defmodule ModuleB do
          alias ModuleA, as: ModuleA

          def public_function do
            :ok
          end

          defp private_function do
            ModuleA.public_function()
          end
        end
        """
        |> to_source_file("lib/module_b.ex")

      %{module_a: module_a, module_b: module_b, files: [module_a, module_b]}
    end

    test "returns no issues for used functions", %{files: files} do
      files
      |> run_check(UnusedPublicFunctions)
      |> refute_issues()
    end

    test "returns issues for unused functions", %{module_a: module_a} do
      module_a
      |> run_check(UnusedPublicFunctions)
      |> assert_issue(fn issue ->
        assert issue.filename == "lib/module_a.ex"
        assert issue.message =~ "ModuleA.private_function/0"
      end)
    end
  end
end
