if Code.ensure_loaded?(Phoenix.Controller) do
  defmodule Calcinator.Controller.Error do
    @moduledoc """
    Errors returned by `Calcinator.Controller`.  Public, so that other controllers not using `Calcinator.Controller` can
    have same format for errors.
    """

    alias Calcinator.Alembic.Document
    alias JaSerializer.Formatter.Utils
    alias Plug.Conn

    require Logger

    import Conn, only: [halt: 1, put_resp_content_type: 2, put_status: 2, send_resp: 3]
    import Phoenix.Controller, only: [json: 2]

    @doc """
    Retort returned a 500 JSONAPI error inside a 422 JSONRPC error.
    """
    @spec bad_gateway(Conn.t()) :: Conn.t()
    def bad_gateway(conn), do: render_json(conn, Document.bad_gateway(), :bad_gateway)

    @doc """
    The resource was deleted
    """
    @spec deleted(Conn.t()) :: Conn.t()
    def deleted(conn) do
      conn
      |> put_resp_content_type()
      |> send_resp(:no_content, "")
    end

    @doc """
    The current resource or action is forbidden to the authenticated user
    """
    @spec forbidden(Conn.t()) :: Conn.t()
    def forbidden(conn), do: render_json(conn, Document.forbidden(), :forbidden)

    @doc """
    Puts 504 Gateway Timeout JSONAPI error in `conn`.
    """
    @spec gateway_timeout(Conn.t()) :: Conn.t()
    def gateway_timeout(conn), do: render_json(conn, Document.gateway_timeout(), :gateway_timeout)

    @doc """
    Puts 404 Resource Not Found JSONAPI error in `conn` with `parameter` as the source parameter.
    """
    @spec not_found(Conn.t(), String.t()) :: Conn.t()
    def not_found(conn, parameter), do: render_json(conn, Document.not_found(parameter), :not_found)

    @doc """
    Puts 500 Internal Server Error JSONAPI error in `conn` with title `"Ownership Error"`.
    """
    @spec ownership_error(Conn.t()) :: Conn.t()
    def ownership_error(conn) do
      render_json(
        conn,
        Document.ownership_error(),
        # DBConnection.OwnershipError raised when the connection was checked out from the pool too long and the lease
        # was revoked.  This could be a 504 Gateway Timeout, but that pool is inside Elixir and not part of the Database
        # itself, so keeping as 500 Internal Server Error.  504 Gateway Timeout is also not accurate, because the
        # "gateway" is responding, it's just saying you can't do it.
        #
        # See 5XX section of http://racksburg.com/choosing-an-http-status-code/
        :internal_server_error
      )
    end

    @doc """
    Converts an `{:error, _}` tuple from `Calcinator` into a JSONAPI document and encodes it as the `conn` response.
    """
    def put_calcinator_error(conn, {:error, :bad_gateway}), do: bad_gateway(conn)
    def put_calcinator_error(conn, {:error, {:not_found, parameter}}), do: not_found(conn, parameter)
    def put_calcinator_error(conn, {:error, :ownership}), do: ownership_error(conn)
    def put_calcinator_error(conn, {:error, :sandbox_access_disallowed}), do: sandbox_access_disallowed(conn)
    def put_calcinator_error(conn, {:error, :sandbox_token_missing}), do: sandbox_token_missing(conn)
    def put_calcinator_error(conn, {:error, :timeout}), do: gateway_timeout(conn)
    def put_calcinator_error(conn, {:error, :unauthorized}), do: forbidden(conn)

    def put_calcinator_error(
          conn,
          {:error, document = %Alembic.Document{errors: errors = [%Alembic.Error{status: status}]}}
        )
        when length(errors) == 1 and not is_nil(status) and (is_atom(status) or is_number(status)) do
      render_json(conn, document, status)
    end

    def put_calcinator_error(
          conn,
          {:error,
           document = %Alembic.Document{
             errors: errors = [%Alembic.Error{status: status}]
           }}
        )
        when length(errors) == 1 and is_binary(status) do
      render_json(conn, document, String.to_integer(status))
    end

    def put_calcinator_error(conn, {:error, document = %Alembic.Document{}}) do
      render_json(conn, document, :unprocessable_entity)
    end

    def put_calcinator_error(conn, {:error, changeset = %Ecto.Changeset{}}) do
      render_changeset_error(conn, changeset)
    end

    def put_calcinator_error(conn, {:error, reason}), do: render_error_reason(conn, reason)

    @doc """
    Puts JSONAPI Content Type in the Response of the `conn`
    """
    def put_resp_content_type(conn), do: put_resp_content_type(conn, "application/vnd.api+json")

    @doc """
    Converts an error `reason` from that isn't a standard format (such as those from the backing store) to a
    500 Internal Server Error JSONAPI error, but with `id` set to `id` that is also used in `Logger.error`, so that
    `reason`, which should remain private to limit implementation disclosures that could lead to security issues.

    ## Log Messages

    ```
    id=UUIDv4 reason=inspect(reason)
    ```

    ## Returns

      * `Plug.Conn.t` - The `Plug.Conn.t` is halted with `Plug.Conn.halt/1`

    """
    @spec render_error_reason(Conn.t(), reason :: term) :: Conn.t()
    def render_error_reason(conn, reason) do
      render_json(conn, Document.error_reason(reason), :internal_server_error)
    end

    @doc """
    Renders `changeset` as an error object using the `Alembic.Document.from_ecto_changeset/1`.
    """
    @spec render_changeset_error(Conn.t(), Ecto.Changeset.t()) :: Conn.t()
    def render_changeset_error(conn, changeset) do
      conn
      |> put_status(:unprocessable_entity)
      |> put_resp_content_type()
      |> json(Alembic.Document.from_ecto_changeset(changeset, %{format_key: &Utils.format_key/1}))
      |> halt()
    end

    @doc """
    Renders `encodable` as JSON after `put_jsonapi_and_status` on the `conn`.
    """
    @spec render_json(Conn.t(), term, atom) :: Conn.t()
    def render_json(conn, encodable, status) do
      conn
      |> put_status(status)
      |> put_resp_content_type()
      |> json(encodable)
      |> halt()
    end

    @doc """
    Puts 422 Unprocessable Entity JSONAPI error in `conn` with title `"Sandbox Access Disallowed"`.
    """
    @spec sandbox_access_disallowed(Conn.t()) :: Conn.t()
    def sandbox_access_disallowed(conn) do
      render_json(conn, Document.sandbox_access_disallowed(), :unprocessable_entity)
    end

    @doc """
    Puts 422 Unrpcessable Entity JSONAPI error in `conn` with title `"Child missing"`.
    """
    @spec sandbox_token_missing(Conn.t()) :: Conn.t()
    def sandbox_token_missing(conn) do
      render_json(conn, Document.sandbox_token_missing(), :unprocessable_entity)
    end
  end
end
