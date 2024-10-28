defmodule Credo.Check.Refactor.UnusedPublicFunctions.CallsCollectorTest do
  use Credo.Test.Case

  alias Credo.Check.Refactor.UnusedPublicFunctions.CallsCollector

  test "returns empty list for empty source files" do
    assert [] == CallsCollector.collect_function_calls([])
  end

  test "collects direct function calls" do
    source = """
    defmodule MyModule do
      def my_function do
        OtherModule.some_function()
        OtherModule.another_function(1, 2)
      end
    end
    """
    |> to_source_file()

    assert [
      {OtherModule, :some_function, 0},
      {OtherModule, :another_function, 2}
    ] == CallsCollector.collect_function_calls([source])
  end

  test "collects function calls through aliases" do
    source = """
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
    source = """
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
    source = """
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

  test "collects delegated function calls" do
    source = """
    defmodule MyModule do
      defdelegate process_user(user), to: UserProcessor
      defdelegate transform(data, opts), to: DataTransformer
    end
    """
    |> to_source_file()

    assert [
      {UserProcessor, :process_user, 1},
      {DataTransformer, :transform, 2}
    ] == CallsCollector.collect_function_calls([source])
  end

  test "collects function calls from multiple modules in one file" do
    source = """
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
    source = """
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
      {MyApp.Services.UserService, :create, 0},
      {MyApp.Services.AccountService, :verify, 1},
      {MyApp.Services.EmailService, :send_welcome, 0}
    ] == CallsCollector.collect_function_calls([source])
  end

  test "collects function calls with multi-alias and nested modules" do
    source = """
    defmodule MyModule do
      alias MyApp.{Users.UserService, Accounts.AccountService}

      def process do
        UserService.create()
        AccountService.verify(123)
      end
    end
    """
    |> to_source_file()

    assert [
      {MyApp.Users.UserService, :create, 0},
      {MyApp.Accounts.AccountService, :verify, 1}
    ] == CallsCollector.collect_function_calls([source])
  end
end
