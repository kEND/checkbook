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
        assert issue.message =~ "ModuleA.public_function/0 is unused"
      end)
    end

    test "uses default files_to_scan parameter lib/ and test/" do
      some_module =
        """
        defmodule MyApp.SomeModule do
          def used_function, do: :ok
        end
        """
        |> to_source_file("lib/my_app/some_module.ex")

      other_module =
        """
        defmodule MyApp.OtherModule do
            alias MyApp.SomeModule, as: SomeModule

            def public_function do
              SomeModule.used_function()
            end
          end
        """
        |> to_source_file("test/my_app/other_module.ex")

      [some_module, other_module]
      |> run_check(UnusedPublicFunctions)
      |> assert_issue(fn issue ->
        assert issue.filename == "test/my_app/other_module.ex"
        assert issue.message =~ "MyApp.OtherModule.public_function/0 is unused"
      end)
    end

    test "allows overriding files_to_scan parameter" do
      some_module =
        """
        defmodule MyApp.SomeModule do
          def used_function, do: :ok
        end
        """
        |> to_source_file("lib/my_app/some_module.ex")

      other_module =
        """
        defmodule MyApp.OtherModule do
          alias MyApp.SomeModule, as: SomeModule

          def unused_function do
            SomeModule.used_function()
          end
        end
        """
        |> to_source_file("test/my_app/other_module.ex")

      [some_module, other_module]
      # default files_to_scan is ["lib/", "test/"]
      |> run_check(UnusedPublicFunctions)
      |> assert_issue(fn issue ->
        assert issue.filename == "test/my_app/other_module.ex"
        assert issue.message =~ "MyApp.OtherModule.unused_function/0 is unused"
      end)

      [some_module, other_module]
      |> run_check(UnusedPublicFunctions, files_to_scan: ["lib/"], files_to_analyze: ["lib/"])
      |> assert_issue(fn issue ->
        assert issue.filename == "lib/my_app/some_module.ex"
        assert issue.message =~ "MyApp.SomeModule.used_function/0 is unused"
      end)
    end
  end
end
