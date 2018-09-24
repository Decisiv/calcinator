defmodule Calcinator.Alembic.Error do
  @moduledoc """
  `Alembic.Error.t` for errors added by `Calcinator` on top of `Alembic.Error`
  """

  alias Alembic.{Document, Error, Source}

  require Logger

  @doc """
  Retort returned a 500 JSONAPI error inside a 422 JSONRPC error.
  """
  @spec bad_gateway() :: Error.t()
  def bad_gateway do
    %Error{
      status: "502",
      title: "Bad Gateway"
    }
  end

  @doc """
  Retort returned a 400 JSONAPI error.
  """
  @spec bad_request(String.t()) :: Error.t()
  def bad_request(detail) do
    %Error{
      detail: detail,
      status: "400",
      title: "Bad Request"
    }
  end

  @doc """
  Converts an error `reason` from that isn't a standard format (such as those from the backing store) to a
  500 Internal Server Error JSONAPI error, but with `id` set to `id` that is also used in `Logger.error`, so that
  `reason`, which should remain private to limit implementation disclosures that could lead to security issues.

  ## Log Messages

  ```
  id=UUIDv4 reason=inspect(reason)
  ```

  """
  @spec error_reason(reason :: term) :: Error.t()
  def error_reason(reason) do
    id = UUID.uuid4()

    Logger.error(fn ->
      "id=#{id} reason=#{inspect(reason)}"
    end)

    %Error{
      id: id,
      status: "500",
      title: "Internal Server Error"
    }
  end

  @doc """
  The current resource or action is forbidden to the authenticated user
  """
  @spec forbidden :: Error.t()
  def forbidden do
    %Error{
      detail: "You do not have permission for this resource.",
      status: "403",
      title: "Forbidden"
    }
  end

  @doc """
  504 Gateway Timeout JSONAPI error.
  """
  @spec gateway_timeout :: Error.t()
  def gateway_timeout do
    %Error{
      status: "504",
      title: "Gateway Timeout"
    }
  end

  @doc """
  Puts 404 Resource Not Found JSONAPI error with `parameter` as the source parameter.
  """
  @spec not_found(String.t()) :: Error.t()
  def not_found(parameter) do
    %Error{
      source: %Source{
        parameter: parameter
      },
      status: "404",
      title: "Resource Not Found"
    }
  end

  @doc """
  500 Internal Server Error JSONAPI error document with error with title `"Ownership Error"`.
  """
  @spec ownership_error :: Error.t()
  def ownership_error do
    %Error{
      detail: "Owner of backing store connection could not be found",
      status: "500",
      title: "Ownership Error"
    }
  end

  @doc """
  Puts 422 Unprocessable Entity JSONAPI error with title `"Sandbox Access Disallowed"`.
  """
  @spec sandbox_access_disallowed :: Error.t()
  def sandbox_access_disallowed do
    %Error{
      detail: "Information in /meta/beam was not enough to grant access to the sandbox",
      source: %Source{
        pointer: "/meta/beam"
      },
      status: "422",
      title: "Sandbox Access Disallowed"
    }
  end

  @doc """
  Puts 422 Unrpcessable Entity JSONAPI error document with error with title `"Child missing"`.
  """
  @spec sandbox_token_missing :: Error.t()
  def sandbox_token_missing do
    Error.missing(
      %Error{
        source: %Source{
          pointer: "/meta"
        }
      },
      "beam"
    )
  end

  @doc """
  Puts `error` in `Alembic.Document.t` as the only error.
  """
  @spec to_document(Error.t()) :: Document.t()
  def to_document(error), do: %Document{errors: [error]}
end
