defmodule Credo.Check.Refactor.UnusedPublicFunctions.CallsCollectorTest do
  use Credo.Test.Case

  alias Credo.Check.Refactor.UnusedPublicFunctions.CallsCollector

  test "returns empty list for empty source files" do
    assert [] == CallsCollector.collect_function_calls([])
  end

  test "collects direct function calls" do
    source =
      """
      defmodule MyModule do
        def my_function do
          OtherModule.some_function()
          OtherModule.another_function(1, 2)
        end
      end
      """
      |> to_source_file()

    assert [
             {OtherModule, :another_function, 2},
             {OtherModule, :some_function, 0}
           ] == CallsCollector.collect_function_calls([source])
  end

  test "collects function calls through aliases" do
    source =
      """
      defmodule MyModule do
        alias Very.Long.ModuleName, as: Short

        def my_function do
          Short.some_function()
        end
      end
      """
      |> to_source_file()

    assert [{Very.Long.ModuleName, :some_function, 0}] ==
             CallsCollector.collect_function_calls([source])
  end

  test "collects function calls through regular alias" do
    source =
      """
      defmodule MyModule do
        alias MyApp.Services.UserService

        def my_function do
          UserService.create_user()
        end
      end
      """
      |> to_source_file()

    assert [{MyApp.Services.UserService, :create_user, 0}] ==
             CallsCollector.collect_function_calls([source])
  end

  test "collects imported function calls" do
    source =
      """
      defmodule MyModule do
        import String, only: [downcase: 1]

        def my_function do
          downcase("HELLO")
        end
      end
      """
      |> to_source_file()

    assert [{String, :downcase, 1}] == CallsCollector.collect_function_calls([source])
  end

  test "collects both delegate and target module calls" do
    source =
      """
      defmodule MyModule do
        defdelegate process_user(user), to: UserProcessor

        def my_function do
          process_user("john")  # Should collect both MyModule.process_user/1 and UserProcessor.process_user/1
        end
      end
      """
      |> to_source_file()

    assert [
             {MyModule, :process_user, 1},
             {UserProcessor, :process_user, 1}
           ] == CallsCollector.collect_function_calls([source])
  end

  test "collects both delegate and imported function calls" do
    source =
      """
      defmodule MyModule do
        import String, only: [downcase: 1]
        defdelegate process_user(user), to: UserProcessor

        def my_function do
          process_user(downcase("JOHN"))  # Should collect delegate calls and the imported String.downcase
        end
      end
      """
      |> to_source_file()

    assert [
             {MyModule, :process_user, 1},
             {String, :downcase, 1},
             {UserProcessor, :process_user, 1}
           ] == CallsCollector.collect_function_calls([source])
  end

  test "collects function calls from multiple modules in one file" do
    source =
      """
      defmodule ModuleA do
        def function_a do
          ModuleB.some_function()
        end
      end

      defmodule ModuleC do
        alias ModuleD, as: D

        def function_c do
          D.another_function(1)
        end
      end
      """
      |> to_source_file()

    assert [
             {ModuleB, :some_function, 0},
             {ModuleD, :another_function, 1}
           ] == CallsCollector.collect_function_calls([source])
  end

  test "collects function calls with multiple aliases" do
    source =
      """
      defmodule MyModule do
        alias MyApp.Services.{UserService, AccountService, EmailService}

        def process do
          UserService.create()
          AccountService.verify(123)
          EmailService.send_welcome()
        end
      end
      """
      |> to_source_file()

    assert [
             {MyApp.Services.AccountService, :verify, 1},
             {MyApp.Services.EmailService, :send_welcome, 0},
             {MyApp.Services.UserService, :create, 0}
           ] == CallsCollector.collect_function_calls([source])
  end

  test "collects function calls in unquoted expressions within a quoted expression" do
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
             {MyAppWeb, :verified_routes, 0}
           ] == CallsCollector.collect_function_calls([myapp_web])
  end

  test "collects function calls from modules that use MyAppWeb, :some_function" do
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
             {MyAppWeb, :controller, 0}
           ] == CallsCollector.collect_function_calls([module_a])
  end

  test "collects function calls through dynamic module resolution in behaviours" do
    source_files =
      [
        "test/fixtures/service/service.ex",
        "test/fixtures/service/client.ex",
        "test/fixtures/service/sandbox_client.ex"
      ]
      |> Enum.map(&File.read!/1)
      |> Enum.map(&to_source_file/1)

    function_calls = CallsCollector.collect_function_calls(source_files)

    # should include calls to the Service behaviour
    assert Enum.member?(
             function_calls,
             {MyApp.ExternalServices.Service, :send_reminder_email, 2}
           )

    assert Enum.member?(
             function_calls,
             {MyApp.ExternalServices.Service, :send_submit_request, 2}
           )

    # Should include calls to both implementations through api_client()
    assert Enum.member?(
             function_calls,
             {MyApp.ExternalServices.Service.Client, :send_reminder_email, 2}
           )

    assert Enum.member?(
             function_calls,
             {MyApp.ExternalServices.Service.SandboxClient, :send_reminder_email, 2}
           )

    assert Enum.member?(
             function_calls,
             {MyApp.ExternalServices.Service.Client, :send_submit_request, 2}
           )

    assert Enum.member?(
             function_calls,
             {MyApp.ExternalServices.Service.SandboxClient, :send_submit_request, 2}
           )
  end

  test "collect function calls from piping" do
    source_file =
      """
      defmodule MyModule do
        def my_function do
          "hello" |> String.downcase()
        end
      end
      """
      |> to_source_file()

    assert [{String, :downcase, 1}] == CallsCollector.collect_function_calls([source_file])
  end

  test "collect function calls from pipes with multiple arguments" do
    source_file =
      """
      defmodule MyModule do
        def my_function do
          "hello" |> String.pad_trailing(10, ".")
        end
      end
      """
      |> to_source_file()

    assert [{String, :pad_trailing, 3}] == CallsCollector.collect_function_calls([source_file])
  end

  test "collect function calls from nested pipes" do
    source_file =
      """
      defmodule MyModule do
        def my_function do
          "hello"
          |> String.upcase()
          |> (fn x -> String.slice(x, 0, 2) end).()
        end
      end
      """
      |> to_source_file()

    assert [
             {String, :slice, 3},
             {String, :upcase, 1}
           ] == CallsCollector.collect_function_calls([source_file]) |> Enum.sort()
  end
end
