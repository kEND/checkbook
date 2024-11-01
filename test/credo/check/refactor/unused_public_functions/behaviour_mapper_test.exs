defmodule Credo.Check.Refactor.UnusedPublicFunctions.BehaviourMapperTest do
  use Credo.Test.Case

  alias Credo.Check.Refactor.UnusedPublicFunctions.BehaviourMapper

  describe "map_behaviours/1" do
    test "identifies behaviour modules and their implementations" do
      source_files =
        [
          "test/fixtures/service/service.ex",
          "test/fixtures/service/client.ex",
          "test/fixtures/service/sandbox_client.ex"
        ]
        |> Enum.map(&File.read!/1)
        |> Enum.map(&to_source_file/1)

      {behaviours, implementations} = BehaviourMapper.map_behaviours(source_files)

      # The Service module defines callbacks, so it's a behaviour
      assert MapSet.member?(behaviours, MyApp.ExternalServices.Service)

      # Both Client and SandboxClient implement the Service behaviour
      expected_implementations =
        MapSet.new([
          {MyApp.ExternalServices.Service.Client, MyApp.ExternalServices.Service},
          {MyApp.ExternalServices.Service.SandboxClient, MyApp.ExternalServices.Service}
        ])

      assert MapSet.equal?(implementations, expected_implementations)
    end

    test "handles basic behaviour modules" do
      source_file =
        """
        defmodule MyApp.SomeImplementation do
          @behaviour MyApp.ExternalServices.Service

          def send_reminder_email(_, _), do: :ok
          def send_submit_request(_, _), do: :ok
        end
        """
        |> to_source_file()

      {_behaviours, implementations} = BehaviourMapper.map_behaviours([source_file])

      assert MapSet.member?(
               implementations,
               {MyApp.SomeImplementation, MyApp.ExternalServices.Service}
             )
    end

    test "handles basic aliased behaviour modules" do
      source_file =
        """
        defmodule MyApp.SomeImplementation do
          alias MyApp.ExternalServices.Service
          @behaviour Service

          def send_reminder_email(_, _), do: :ok
          def send_submit_request(_, _), do: :ok
        end
        """
        |> to_source_file()

      {_behaviours, implementations} = BehaviourMapper.map_behaviours([source_file])

      assert MapSet.member?(
               implementations,
               {MyApp.SomeImplementation, MyApp.ExternalServices.Service}
             )
    end
  end
end
