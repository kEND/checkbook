defmodule Credo.Check.Refactor.UnusedPublicFunctions.CollectorTest do
  use Credo.Test.Case

  alias Credo.Check.Refactor.UnusedPublicFunctions.Collector

  describe "get_public_functions/1" do
    test "returns public functions defined in a module" do
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

      assert [{{ModuleA, :public_function, 0}, line: 5}] == Collector.get_public_functions(module_a)
    end

    test "returns public functions defined in multiple modules in a file" do
      module_a =
        """
        defmodule ModuleA do
          def public_function do
            :ok
          end
        end

        defmodule ModuleB do
          def public_function do
            :ok
          end
        end
        """
        |> to_source_file("lib/module_a.ex")

      assert [
               {{ModuleA, :public_function, 0}, line: 2},
               {{ModuleB, :public_function, 0}, line: 8}
             ] ==
               Collector.get_public_functions(module_a)
    end

    test "returns public functions defined in nested modules" do
      module_a =
        """
        defmodule ModuleA do
          defmodule NestedModule do
            def public_function do
              :ok
            end
          end

          def another_function do
            :ok
          end
        end

        """
        |> to_source_file("lib/module_a.ex")

      assert [
               {{ModuleA.NestedModule, :public_function, 0}, line: 3},
               {{ModuleA, :another_function, 0}, line: 8}
             ] ==
               Collector.get_public_functions(module_a)
    end

    test "returns public functions defined in nested modules and second module" do
      module_a =
        """
        defmodule ModuleA do
          defmodule NestedModule do
            def public_function do
              :ok
            end
          end

          def another_function do
            :ok
          end
        end

        defmodule ModuleB do
          def another_function do
            :ok
          end
        end
        """
        |> to_source_file("lib/module_a.ex")

      assert [
               {{ModuleA.NestedModule, :public_function, 0}, line: 3},
               {{ModuleA, :another_function, 0}, line: 8},
               {{ModuleB, :another_function, 0}, line: 14}
             ] ==
               Collector.get_public_functions(module_a)
    end

    test "considers defdelegate calls as defined public functions" do
      module_a =
        """
        defmodule ModuleA do
          defdelegate process_user(user), to: UserProcessor
        end
        """
        |> to_source_file("lib/module_a.ex")

      assert [
               {{ModuleA, :process_user, 1}, line: 2}
             ] == Collector.get_public_functions(module_a)
    end
  end

  describe "collect_unused_functions/2" do
    test "returns unused public functions if there are no calls" do
      module_a =
        """
        defmodule ModuleA do
          def public_function do
            :ok
          end
        end
        """
        |> to_source_file("lib/module_a.ex")

      function_calls = []

      assert [
               {{ModuleA, :public_function, 0}, line: 2}
             ] == Collector.collect_unused_functions(module_a, function_calls)
    end

    test "returns empty unused public functions if there are calls" do
      module_a =
        """
        defmodule ModuleA do
          def public_function do
            :ok
          end
        end
        """
        |> to_source_file("lib/module_a.ex")

      function_calls = [{ModuleA, :public_function, 0}]

      assert [] == Collector.collect_unused_functions(module_a, function_calls)
    end
  end
end
