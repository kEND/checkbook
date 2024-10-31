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

    test "should iterate over Enum.each wrapping a def unquote" do
      module_a =
        """
        defmodule ModuleA do
          def public_function do
            :ok
          end

          Enum.each(["service_1", "service_2"], fn service ->
            def unquote(:"with_valid_\#{service}_authentication_header")(%{conn: conn}) do
              service = unquote(service)
              username = "username_\#{service}"
              password = "password_\#{service}"

              conn_with_auth =
                conn
                |> Plug.Conn.put_req_header("authorization", "Basic " <> Base.encode64("\#{username}:\#{password}"))

              %{conn_with_auth: conn_with_auth}
            end
          end)
        end
        """
        |> to_source_file("lib/module_a.ex")

      assert [
               {{ModuleA, :public_function, 0}, line: 2},
               {{ModuleA, :with_valid_service_1_authentication_header, 1}, line: 6},
               {{ModuleA, :with_valid_service_2_authentication_header, 1}, line: 6}
             ] == Collector.get_public_functions(module_a)
    end

    test "considers calls that will be used with `use` as public functions" do
      myapp_web =
        """
        defmodule MyAppWeb do

          def controller do
            quote do
              use Phoenix.Controller, namespace: MyAppWeb

              import Plug.Conn
              import ClarusWeb.Gettext
              import Clarus.Schema, only: [cast_and_apply: 2, cast_and_apply: 3]
              alias ClarusWeb.Router.Helpers, as: Routes

              unquote(verified_routes())
            end
          end
        end
        """
        |> to_source_file("lib/myapp_web.ex")

      assert [
               {{MyAppWeb, :controller, 0}, line: 3}
             ] == Collector.get_public_functions(myapp_web)

      module_a =
        """
        defmodule ModuleA do
          use MyAppWeb, :controller

          def some_public_function do
            :ok
          end
        end
        """
        |> to_source_file("lib/module_a.ex")

      assert [
               {{ModuleA, :some_public_function, 0}, line: 4}
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
