defmodule PipelinesAPI.GoferClient.ResponseFormatter.Test do
  use ExUnit.Case

  alias PipelinesAPI.GoferClient.ResponseFormatter
  alias InternalApi.Gofer.TriggerResponse
  alias Util.Proto

  test "process_trigger_response() returns {:ok, msg} when given valid params" do
    response = trigger_response(:OK, "Everything OK")

    assert {:ok, message} = ResponseFormatter.process_trigger_response(response)
    assert message == "Promotion successfully triggered."
  end

  test "process_trigger_response() returns error and server message when server returns NOT_FOUND or REFUSED" do
    response = trigger_response(:NOT_FOUND, "NOT_FOUND message from server")

    assert {:error, {:user, message}} = ResponseFormatter.process_trigger_response(response)
    assert message == "NOT_FOUND message from server"

    response = trigger_response(:REFUSED, "REFUSED message from server")

    assert {:error, {:user, message}} = ResponseFormatter.process_trigger_response(response)
    assert message == "REFUSED message from server"
  end

  test "process_trigger_response() returns internal error when it receives {:ok, invalid_data}" do
    response = {:ok, "123"}

    assert {:error, {:internal, message}} = ResponseFormatter.process_trigger_response(response)
    assert message == "Internal error"
  end

  test "process_trigger_response() returns what it gets if it's not an :ok tuple" do
    response = {:error, {:user, "Error message"}}

    assert {:error, {:user, message}} = ResponseFormatter.process_trigger_response(response)
    assert message == "Error message"
  end

  defp trigger_response(code, message) do
    params = %{response_status: %{code: code, message: message}}
    Proto.deep_new(TriggerResponse, params)
  end
end
