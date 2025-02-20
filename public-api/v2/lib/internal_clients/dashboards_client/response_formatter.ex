defmodule InternalClients.Dashboards.ResponseFormatter do
  @moduledoc """
  Module parses the response from Dashboardhub service
  """
  alias InternalApi.Dashboardhub, as: API

  def process_response({:ok, r = %API.ListResponse{}}) do
    {:ok,
     %{
       next_page_token: r.next_page_token,
       page_size: r.page_size,
       entries: r.dashboards
     }}
  end

  def process_response({:ok, r = %API.DescribeResponse{}}) do
    {:ok, r.dashboard}
  end

  def process_response({:ok, r = %API.CreateResponse{}}) do
    {:ok, r.dashboard}
  end

  def process_response({:ok, r = %API.UpdateResponse{}}) do
    {:ok, r.dashboard}
  end

  def process_response({:ok, r = %API.DestroyResponse{}}) do
    {:ok, %{dashboard_id: r.id}}
  end

  @doc """
  Error responses are GRPC.RPCError structs. We pattern match on the status code and
  return a tuple with the error code and message.
  Status code is not an atom for this protobuf version, so we pattern match on the integer value as well.
  """
  def process_response({:error, %GRPC.RPCError{status: status, message: message}})
      when status in [5, :not_found] do
    {:error, {:not_found, message}}
  end

  def process_response({:error, %GRPC.RPCError{status: status, message: message}})
      when status in [3, :invalid_argument] do
    {:error, {:user, message}}
  end

  def process_response({:error, %GRPC.RPCError{status: status, message: message}})
      when status in [7, :internal] do
    {:error, {:internal, message}}
  end

  def process_response({:error, %GRPC.RPCError{status: status, message: message}})
      when status in [2, :unknown] do
    PublicAPI.Util.Log.internal_error("Unknown response", "process_response", "Dashboardhub")
    {:error, {:internal, message}}
  end

  def process_response(error), do: error
end
