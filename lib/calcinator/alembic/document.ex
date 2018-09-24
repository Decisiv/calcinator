defmodule Calcinator.Alembic.Document do
  @moduledoc """
  `Alembic.Document.t` for errors added by `Calcinator` on top of `Alembic.Error`
  """

  alias Alembic.Document
  alias Calcinator.Alembic.Error

  @doc """
  Retort returned a 500 JSONAPI error inside a 422 JSONRPC error.
  """
  @spec bad_gateway() :: Document.t()
  def bad_gateway do
    Error.bad_gateway()
    |> Error.to_document()
  end

  @doc """
  Retort returned a 400 JSONAPI error.
  """
  @spec bad_request(String.t()) :: Document.t()
  def bad_request(detail) do
    detail
    |> Error.bad_request()
    |> Error.to_document()
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
  @spec error_reason(term) :: Document.t()
  def error_reason(reason) do
    reason
    |> Error.error_reason()
    |> Error.to_document()
  end

  @doc """
  The current resource or action is forbidden to the authenticated user
  """
  @spec forbidden :: Document.t()
  def forbidden do
    Error.forbidden()
    |> Error.to_document()
  end

  @doc """
  504 Gateway Timeout JSONAPI error document.
  """
  @spec gateway_timeout :: Document.t()
  def gateway_timeout do
    Error.gateway_timeout()
    |> Error.to_document()
  end

  @doc """
  Puts 404 Resource Not Found JSONAPI error with `parameter` as the source parameter.
  """
  @spec not_found(String.t()) :: Document.t()
  def not_found(parameter) do
    parameter
    |> Error.not_found()
    |> Error.to_document()
  end

  @doc """
  500 Internal Server Error JSONAPI error document with error with title `"Ownership Error"`.
  """
  @spec ownership_error :: Document.t()
  def ownership_error do
    Error.ownership_error()
    |> Error.to_document()
  end

  @doc """
  Puts 422 Unprocessable Entity JSONAPI error document with error with title `"Sandbox Access Disallowed"`.
  """
  @spec sandbox_access_disallowed :: Document.t()
  def sandbox_access_disallowed do
    Error.sandbox_access_disallowed()
    |> Error.to_document()
  end

  @doc """
  Puts 422 Unrpcessable Entity JSONAPI error document with error with title `"Child missing"`.
  """
  @spec sandbox_token_missing :: Document.t()
  def sandbox_token_missing do
    Error.sandbox_token_missing()
    |> Error.to_document()
  end
end
