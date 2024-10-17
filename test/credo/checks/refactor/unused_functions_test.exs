defmodule Checkbook.Check.Refactor.UnusedPublicFunctionsTest do
  use ExUnit.Case
  alias Checkbook.Check.Refactor.UnusedPublicFunctions

  test "get_function_calls correctly identifies use calls" do
    code = """
    defmodule TestModule do
      use ClarusWeb, :controller
      use Phoenix.View

      alias App.OtherModule

      def some_function(arg1, arg2) do
        OtherModule.other_function(arg1)
      end

      def another_function do
        some_function(1, 2)
      end
    end
    """

    {:ok, ast} = Code.string_to_quoted(code)
    # IO.inspect(ast)
    calls = UnusedPublicFunctions.get_function_calls(ast)
    # IO.inspect(calls)

    assert {ClarusWeb, :controller, 0} in calls
    assert {App.OtherModule, :other_function, 1} in calls
    assert {:potential_import, :some_function, 2} in calls
  end
end
