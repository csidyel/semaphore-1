defmodule InternalApi.PreFlightChecksHub.PFCLevel do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  @type t :: integer | :ORGANIZATION | :PROJECT | :EVERYTHING

  field :ORGANIZATION, 0
  field :PROJECT, 1
  field :EVERYTHING, 2
end

defmodule InternalApi.PreFlightChecksHub.PreFlightChecks do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_pfc: InternalApi.PreFlightChecksHub.OrganizationPFC.t() | nil,
          project_pfc: InternalApi.PreFlightChecksHub.ProjectPFC.t() | nil
        }

  defstruct organization_pfc: nil,
            project_pfc: nil

  field :organization_pfc, 1,
    type: InternalApi.PreFlightChecksHub.OrganizationPFC,
    json_name: "organizationPfc"

  field :project_pfc, 2, type: InternalApi.PreFlightChecksHub.ProjectPFC, json_name: "projectPfc"
end

defmodule InternalApi.PreFlightChecksHub.OrganizationPFC do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          commands: [String.t()],
          secrets: [String.t()],
          agent: InternalApi.PreFlightChecksHub.Agent.t() | nil,
          requester_id: String.t(),
          created_at: Google.Protobuf.Timestamp.t() | nil,
          updated_at: Google.Protobuf.Timestamp.t() | nil
        }

  defstruct commands: [],
            secrets: [],
            agent: nil,
            requester_id: "",
            created_at: nil,
            updated_at: nil

  field :commands, 1, repeated: true, type: :string
  field :secrets, 2, repeated: true, type: :string
  field :agent, 3, type: InternalApi.PreFlightChecksHub.Agent
  field :requester_id, 4, type: :string, json_name: "requesterId"
  field :created_at, 5, type: Google.Protobuf.Timestamp, json_name: "createdAt"
  field :updated_at, 6, type: Google.Protobuf.Timestamp, json_name: "updatedAt"
end

defmodule InternalApi.PreFlightChecksHub.ProjectPFC do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          commands: [String.t()],
          secrets: [String.t()],
          requester_id: String.t(),
          created_at: Google.Protobuf.Timestamp.t() | nil,
          updated_at: Google.Protobuf.Timestamp.t() | nil,
          agent: InternalApi.PreFlightChecksHub.Agent.t() | nil
        }

  defstruct commands: [],
            secrets: [],
            requester_id: "",
            created_at: nil,
            updated_at: nil,
            agent: nil

  field :commands, 1, repeated: true, type: :string
  field :secrets, 2, repeated: true, type: :string
  field :requester_id, 3, type: :string, json_name: "requesterId"
  field :created_at, 4, type: Google.Protobuf.Timestamp, json_name: "createdAt"
  field :updated_at, 5, type: Google.Protobuf.Timestamp, json_name: "updatedAt"
  field :agent, 6, type: InternalApi.PreFlightChecksHub.Agent
end

defmodule InternalApi.PreFlightChecksHub.Agent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          machine_type: String.t(),
          os_image: String.t()
        }

  defstruct machine_type: "",
            os_image: ""

  field :machine_type, 1, type: :string, json_name: "machineType"
  field :os_image, 2, type: :string, json_name: "osImage"
end

defmodule InternalApi.PreFlightChecksHub.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          level: InternalApi.PreFlightChecksHub.PFCLevel.t(),
          organization_id: String.t(),
          project_id: String.t()
        }

  defstruct level: :ORGANIZATION,
            organization_id: "",
            project_id: ""

  field :level, 1, type: InternalApi.PreFlightChecksHub.PFCLevel, enum: true
  field :organization_id, 2, type: :string, json_name: "organizationId"
  field :project_id, 3, type: :string, json_name: "projectId"
end

defmodule InternalApi.PreFlightChecksHub.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t() | nil,
          pre_flight_checks: InternalApi.PreFlightChecksHub.PreFlightChecks.t() | nil
        }

  defstruct status: nil,
            pre_flight_checks: nil

  field :status, 1, type: InternalApi.Status

  field :pre_flight_checks, 2,
    type: InternalApi.PreFlightChecksHub.PreFlightChecks,
    json_name: "preFlightChecks"
end

defmodule InternalApi.PreFlightChecksHub.ApplyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          level: InternalApi.PreFlightChecksHub.PFCLevel.t(),
          organization_id: String.t(),
          project_id: String.t(),
          requester_id: String.t(),
          pre_flight_checks: InternalApi.PreFlightChecksHub.PreFlightChecks.t() | nil
        }

  defstruct level: :ORGANIZATION,
            organization_id: "",
            project_id: "",
            requester_id: "",
            pre_flight_checks: nil

  field :level, 1, type: InternalApi.PreFlightChecksHub.PFCLevel, enum: true
  field :organization_id, 2, type: :string, json_name: "organizationId"
  field :project_id, 3, type: :string, json_name: "projectId"
  field :requester_id, 4, type: :string, json_name: "requesterId"

  field :pre_flight_checks, 5,
    type: InternalApi.PreFlightChecksHub.PreFlightChecks,
    json_name: "preFlightChecks"
end

defmodule InternalApi.PreFlightChecksHub.ApplyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t() | nil,
          pre_flight_checks: InternalApi.PreFlightChecksHub.PreFlightChecks.t() | nil
        }

  defstruct status: nil,
            pre_flight_checks: nil

  field :status, 1, type: InternalApi.Status

  field :pre_flight_checks, 2,
    type: InternalApi.PreFlightChecksHub.PreFlightChecks,
    json_name: "preFlightChecks"
end

defmodule InternalApi.PreFlightChecksHub.DestroyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          level: InternalApi.PreFlightChecksHub.PFCLevel.t(),
          organization_id: String.t(),
          project_id: String.t(),
          requester_id: String.t()
        }

  defstruct level: :ORGANIZATION,
            organization_id: "",
            project_id: "",
            requester_id: ""

  field :level, 1, type: InternalApi.PreFlightChecksHub.PFCLevel, enum: true
  field :organization_id, 2, type: :string, json_name: "organizationId"
  field :project_id, 3, type: :string, json_name: "projectId"
  field :requester_id, 4, type: :string, json_name: "requesterId"
end

defmodule InternalApi.PreFlightChecksHub.DestroyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t() | nil
        }

  defstruct status: nil

  field :status, 1, type: InternalApi.Status
end

defmodule InternalApi.PreFlightChecksHub.PreFlightChecksService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.PreFlightChecksHub.PreFlightChecksService"

  rpc :Describe,
      InternalApi.PreFlightChecksHub.DescribeRequest,
      InternalApi.PreFlightChecksHub.DescribeResponse

  rpc :Apply,
      InternalApi.PreFlightChecksHub.ApplyRequest,
      InternalApi.PreFlightChecksHub.ApplyResponse

  rpc :Destroy,
      InternalApi.PreFlightChecksHub.DestroyRequest,
      InternalApi.PreFlightChecksHub.DestroyResponse
end

defmodule InternalApi.PreFlightChecksHub.PreFlightChecksService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.PreFlightChecksHub.PreFlightChecksService.Service
end
