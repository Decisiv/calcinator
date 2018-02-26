defmodule Calcinator do
  @moduledoc """
  Converts actions from a controller or RPC server using JSONAPI formatted params to calls on a `Calcinator.Resources`
  module.
  """

  require Calcinator.Instrument

  import Calcinator.Instrument, only: [instrument: 3]

  alias Alembic.{Document, Fetch, Fetch.Includes, FromJson, ToParams, Source}
  alias Calcinator.{Authorization, Meta}
  alias Calcinator.Authorization.SubjectLess
  alias Calcinator.Resources
  alias Calcinator.Resources.{Page, Sorts}

  # Constants

  @actions ~w(create delete index update show)a

  # Struct

  defstruct associations_by_include: %{},
            authorization_module: SubjectLess,
            ecto_schema_module: nil,
            params: %{},
            resources_module: nil,
            subject: nil,
            view_module: nil

  # Types

  @type association :: atom | list | map

  @typedoc """
  Nested params format used by `Ecto.Changeset.t`.
  """
  @type insertable_params :: %{String.t() => term}

  @typedoc """
  The name of the parameter that was used for the query and was not found.
  """
  @type parameter :: String.t()

  @typedoc """
  The raw request params that need to be validated as a JSONAPI document and converted to an `Alembic.Document.t`
  """
  @type params :: %{String.t() => term}

  @typedoc """
  A rendered JSONAPI document as a `map`
  """
  @type rendered :: map

  @typedoc """
    * `asociation_by_include` - maps JSONAPI nested includes (`%{String.t => String.t | map}` to the nested associations
      (`atom | Keyword.t`) that are understood by `resources_module`.
    * `authorization_module` - The module that implements the `Calcinator.Authorization` behaviour.
      Defaults to `Calcinator.Authorization.Subjectless`.
    * `resources_module` - The module that implements the `Calcinator.Resources` behaviour.
    * `subject` - the subject that is trying to do the action and needs to be authorized by `authorization_module`
    * `view_module` - The module that implements the `Calcinator.View` behaviour.
  """
  @type t :: %__MODULE__{
          associations_by_include: map,
          authorization_module: module,
          ecto_schema_module: module,
          resources_module: module,
          subject: Authorization.subject(),
          view_module: module
        }

  # Functions

  ## Client Functions

  @spec allow_sandbox_access(t, params) :: :ok | {:error, :sandbox_access_disallowed} | {:error, :sandbox_token_missing}
  def allow_sandbox_access(state = %__MODULE__{}, params) do
    allow_sandbox_access(state, params, resources(state, :sandboxed?, []))
  end

  # Filters a related resource that does not exist
  @spec authorized(t, related :: nil) :: nil
  # Filters `struct` or list of `struct`s to only those that can be shown
  @spec authorized(t, unfiltered :: struct) :: struct
  @spec authorized(t, unfiltered :: [struct]) :: [struct]
  def authorized(calcinator = %__MODULE__{}, resource_or_related) do
    instrument(:calcinator_authorization, %{action: :show, calcinator: calcinator, target: resource_or_related}, fn ->
      instrumented_authorized(calcinator, resource_or_related)
    end)
  end

  @spec can(t, Authorization.action(), Authorizaton.target()) :: :ok | {:error, :unauthorized}
  def can(calcinator = %__MODULE__{}, action, target)
      when action in @actions and (is_atom(target) or is_map(target) or is_list(target)) do
    instrument(:calcinator_authorization, %{action: action, calcinator: calcinator, target: target}, fn ->
      instrumented_can(calcinator, action, target)
    end)
  end

  @spec changeset(t, Ecto.Schema.t(), insertable_params) ::
          {:ok, Ecto.Changeset.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ownership}
  def changeset(calcinator, updatable, updatable_params) do
    with {:ok, changeset} <- resources(calcinator, :changeset, [updatable, updatable_params]) do
      status_changeset(changeset)
    end
  end

  @spec get(t, params, id_key :: String.t(), Resources.query_options()) ::
          {:ok, Ecto.Schema.t()}
          | {:error, {:not_found, parameter}}
          | {:error, :ownership}
          | {:error, :timeout}
          | {:error, reason :: term}
  def get(calcinator = %__MODULE__{}, params, id_key, query_options) when is_map(query_options) do
    id = Map.fetch!(params, id_key)

    with {:error, :not_found} <- resources(calcinator, :get, [id, query_options]) do
      {:error, {:not_found, id_key}}
    end
  end

  @spec update_changeset(t, Ecto.Changeset.t(), params) ::
          {:ok, Ecto.Schema.t()}
          | {:error, Document.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :bad_gateway}
          | {:error, :not_found}
  def update_changeset(state = %__MODULE__{}, changeset = %Ecto.Changeset{}, params) do
    with {:ok, query_options} <- params_to_query_options(state, params) do
      resources(state, :update, [changeset, query_options])
    end
  end

  ## Actions

  @doc """
  [Creates resource](http://jsonapi.org/format/#crud-creating) from `params`.

  ## Steps

    1. `state` `authorization_module` `can?(subject, :create, ecto_schema_module)`
    2. Check `params` are a valid JSONAPI document
    3. `state` `authorization_module` `can?(subject, :create, Ecto.Changeset.t)`
    4. `allow_sandbox_access/2`
    5. `state` `authorization_module` `filter_associations_can(created, subject, :show)`
    6. `state` `view_module` `show(authorized, ...)`

  ## Returns

    * `{:ok, rendereded}` - rendered view of created resource
    * `{:error, :ownership}` - connection to backing store was not owned by the calling process
    * `{:error, :sandbox_access_disallowed}` - Sandbox token was required and present, but did not have the correct
      information to grant access.
    * `{:error, :sandbox_token_missing}` - Sandbox token was required (because `state` `resources_module`
      `Calcinator.Resources.sandboxed?/0` returned `true`), but `params["meta"]["beam"]` was not present.
    * `{:error, :timeout}` - if the backing store for `state` `resources_module` times out when calling
      `Calcinator.Resources.insert/2`.
    * `{:error, :unauthorized}` - if `state` `authorization_module` `can?(subject, :create, ecto_schema_module)` or
      `can?(subject, :create, %Ecto.Changeset{})` returns `false`
    * `{:error, Alembic.Document.t}` - if `params` is not a valid JSONAPI document
    * `{:error, Ecto.Changeset.t}` - if validations errors inserting `Ecto.Changeset.t`

  """
  @spec create(t, params) ::
          {:ok, rendered}
          | {:error, :ownership}
          | {:error, :sandbox_access_disallowed}
          | {:error, :sandbox_token_missing}
          | {:error, :timeout}
          | {:error, :unauthorized}
          | {:error, Document.t()}
          | {:error, Ecto.Changeset.t()}
  def create(
        state = %__MODULE__{
          ecto_schema_module: ecto_schema_module,
          subject: subject,
          view_module: view_module
        },
        params
      )
      when not is_nil(ecto_schema_module) and is_atom(ecto_schema_module) and not is_nil(view_module) and
             is_atom(view_module) and is_map(params) do
    with :ok <- can(state, :create, ecto_schema_module),
         {:ok, document} <- document(params, :create),
         insertable_params = insertable_params(state, document),
         :ok <- allow_sandbox_access(state, params),
         {:ok, changeset} <- changeset(state, insertable_params),
         :ok <- can(state, :create, changeset),
         {:ok, created} <- create_changeset(state, changeset, params) do
      authorized = authorized(state, created)
      {:ok, view(state, :show, [authorized, %{params: params, subject: subject}])}
    end
  end

  @doc """
  [Deletes resource](http://jsonapi.org/format/#crud-deleting) with `"id"` in `params`.

  ## Steps

    1. `allow_sandbox_access/2`
    2. `state` `resources_module` `get(id, ...)`
    3. `state` `authorization_module` `can?(subject, :delete, struct)`
    4. `state` `resources_module` `delete(struct)`

  ## Returns

    * `:ok` - resource was successfully deleted
    * `{:error, {:not_found, "id"}}` - The "id" did not correspond to resource in the backing store
    * `{:error, :ownership}` - connection to backing store was not owned by the calling process
    * `{:error, :sandbox_access_disallowed}` - Sandbox token was required and present, but did not have the correct
      information to grant access.
    * `{:error, :sandbox_token_missing}` - Sandbox token was required (because `state` `resources_module`
      `Calcinator.Resources.sandboxed?/0` returned `true`), but `params["meta"]["beam"]` was not present.
    * `{:error, :timeout}` - if the backing store for `state` `resources_module` times out when calling
      `Calcinator.Resources.get/2` or `Calcinator.Resources.delete/1`.
    * `{:error, :unauthorized}` - The `state` `subject` is not authorized to delete the resource
    * `{:error, Alembic.Document.t}` - JSONAPI error document with `params` errors
    * `{:error, Ecto.Changeset.t}` - the deletion failed with the errors in `Ecto.Changeset.t`
    * `{:error, reason}` - a backing store-specific error

  """
  @spec delete(t, params) ::
          :ok
          | {:error, {:not_found, parameter}}
          | {:error, :ownership}
          | {:error, :sandbox_access_disallowed}
          | {:error, :sandbox_token_missing}
          | {:error, :timeout}
          | {:error, :unauthorized}
          | {:error, Document.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, reason :: term}
  def delete(state = %__MODULE__{}, params) do
    with :ok <- allow_sandbox_access(state, params),
         {:ok, query_options} <- params_to_query_options(state, params),
         {:ok, target} <- get(state, params, query_options),
         :ok <- can(state, :delete, target),
         # generate a changeset, so `resources_module` can add constraints
         {:ok, changeset} <- changeset(state, target, %{}),
         {:ok, _deleted} <- delete_changeset(state, changeset, query_options) do
      :ok
    end
  end

  @doc """
  [Gets a resource related through a relationship]
  (http://jsonapi.org/format/#document-resource-object-related-resource-links).

  ## Steps

    1. Gets source
    2. `state` `authorization_module` `can?(subject, :show, source)`
    3. Get related
    4. `state` `authorization_module` `can?(subject, :show, [related, source])`
    5. `state` `authorization_module` `filter_associations_can(related, subject, :show)`
    6. `state` `view_module` `get_related_resource(authorized, ...)`

  ## Returns

    * `{:ok, rendered}` - rendered view of related resource
    * `{:error, {:not_found, id_key}}` - The value of the `id_key` key in `params` did not correspond to a resource in
      the backing store.
    * `{:error, :ownership}` - connection to backing store was not owned by the calling process
    * `{:error, :sandbox_access_disallowed}` - Sandbox token was required and present, but did not have the correct
      information to grant access.
    * `{:error, :sandbox_token_missing}` - Sandbox token was required (because `state` `resources_module`
      `Calcinator.Resources.sandboxed?/0` returned `true`), but `params["meta"]["beam"]` was not present.
    * `{:error, :timeout}` - if the backing store for `state` `resources_module` times out when calling
      `Calcinator.Resources.get/2`.
    * `{:error, :unauthorized}` - if the either the source or related resource cannot be shown
    * `{:error, Alembic.Document.t}` - JSONAPI error document with `params` errors
    * `{:error, reason}` - a backing store-specific error

  """
  @spec get_related_resource(t, params, map) ::
          {:ok, rendered}
          | {:error, {:not_found, parameter}}
          | {:error, :ownership}
          | {:error, :sandbox_access_disallowed}
          | {:error, :sandbox_token_missing}
          | {:error, :timeout}
          | {:error, :unauthorized}
          | {:error, Document.t()}
          | {:error, reason :: term}
  def get_related_resource(
        state = %__MODULE__{},
        params,
        options = %{related: related}
      ) do
    related_property(state, params, put_in(options.related, Map.put(related, :property, :resource)))
  end

  @doc """
  [Gets index of a resource](http://jsonapi.org/format/#fetching-resources) with
  [(optional) pagination](http://jsonapi.org/format/#fetching-pagination) depending on whether the `state`
  `resources_module` supports pagination.

  ## Steps

    1. `state` `authorization_module` `can?(subject, :index, ecto_schema_module)`
    2. `allow_sandbox_access/2`
    3. `state` `resources_module` `list/1`
    4. `state` `authorization_module` `filter_can(listed, subject, :show)`
    5. `state` `authorization_module` `filter_associations_can(filtered_listed, subject, :show)`
    6. `state` `view_module` `index(association_filtered,  ...)`

  ## Returns

    * `{:ok, rendered}` - the rendered resources with (optional) pagination in the `"meta"`.
    * `{:error, :ownership}` - connection to backing store was not owned by the calling process
    * `{:error, :sandbox_access_disallowed}` - Sandbox token was required and present, but did not have the correct
      information to grant access.
    * `{:error, :sandbox_token_missing}` - Sandbox token was required (because `state` `resources_module`
      `Calcinator.Resources.sandboxed?/0` returned `true`), but `params["meta"]["beam"]` was not present.
    * `{:error, :timeout}` - if the backing store for `state` `resources_module` times out when calling `list/1`.
    * `{:error, :unauthorized}` - if `state` `authorization_module` `can?(subject, :index, ecto_schema_module)` returns
      `false`
    * `{:error, Alembic.Document.t}` - if `params` are not valid JSONAPI.

  """
  @spec index(t, params, %{required(:base_uri) => URI.t()}) ::
          {:ok, rendered}
          | {:error, :ownership}
          | {:error, :sandbox_access_disallowed}
          | {:error, :sandbox_token_missing}
          | {:error, :timeout}
          | {:error, :unauthorized}
          | {:error, Document.t()}
  def index(
        state = %__MODULE__{
          ecto_schema_module: ecto_schema_module,
          subject: subject
        },
        params,
        %{base_uri: base_uri}
      ) do
    with :ok <- can(state, :index, ecto_schema_module),
         :ok <- allow_sandbox_access(state, params),
         {:ok, list, pagination} <- list(state, params) do
      {authorized, authorized_pagination} = authorized(state, list, pagination)

      {
        :ok,
        view(state, :index, [
          authorized,
          %{base_uri: base_uri, pagination: authorized_pagination, params: params, subject: subject}
        ])
      }
    end
  end

  @doc """
  [Shows resource](http://jsonapi.org/format/#fetching-resources) with the `"id"` in `params`.

  ## Steps

    1. `allow_sandbox_acces/2`
    2. `state` `resources_module` `get(id, ...)`
    3. `state` `authorization_module` `can?(subject, :show, got)`
    4. `state` `authorization_module` `filter_associations_can(got, subject, :show)`
    5. `state` `view_module` `show(authorized, ...)`

  ## Returns

    * `{:ok, rendered}` - rendered resource
    * `{:error, {:not_found, "id"}}` - The "id" did not correspond to resource in the backing store
    * `{:error, :ownership}` - connection to backing store was not owned by the calling process
    * `{:error, :sandbox_access_disallowed}` - Sandbox token was required and present, but did not have the correct
      information to grant access.
    * `{:error, :sandbox_token_missing}` - Sandbox token was required (because `state` `resources_module`
      `Calcinator.Resources.sandboxed?/0` returned `true`), but `params["meta"]["beam"]` was not present.
    * `{:error, :timeout}` - if the backing store for `state` `resources_module` times out when calling
      `Calcinator.Resources.get/2`.
    * `{:error, :unauthorized}` - `state` `authorization_module` `can?(subject, :show, got)` returns `false`
    * `{:error, Alembic.Document.t}` - `params` is not valid JSONAPI
    * `{:error, reason}` - a backing store-specific error

  """
  @spec show(t, params) ::
          {:ok, rendered}
          | {:error, {:not_found, parameter}}
          | {:error, :ownership}
          | {:error, :sandbox_access_disallowed}
          | {:error, :sandbox_token_missing}
          | {:error, :timeout}
          | {:error, :unauthorized}
          | {:error, Document.t()}
          | {:error, reason :: term}
  def show(state = %__MODULE__{subject: subject}, params = %{"id" => _}) do
    with :ok <- allow_sandbox_access(state, params),
         {:ok, shown} <- get(state, params),
         :ok <- can(state, :show, shown) do
      authorized = authorized(state, shown)
      {:ok, view(state, :show, [authorized, %{params: params, subject: subject}])}
    end
  end

  @doc """
  [Shows a relationship](http://jsonapi.org/format/#fetching-relationships).

  ## Steps

    1. Gets source
    2. `state` `authorization_module` `can?(subject, :show, source)`
    3. Get related
    4. `state` `authorization_module` `can?(subject, :show, [related, source])`
    5. `state` `authorization_module` `filter_associations_can(related, subject, :show)`
    6. `state` `view_module` `show_relationship(authorized, ...)`

  ## Returns

    * `{:ok, rendered}` - rendered view of relationship
    * `{:error, {:not_found, id_key}}` - The value of the `id_key` key in `params` did not correspond to a resource in
      the backing store.
    * `{:error, :ownership}` - connection to backing store was not owned by the calling process
    * `{:error, :sandbox_access_disallowed}` - Sandbox token was required and present, but did not have the correct
      information to grant access.
    * `{:error, :sandbox_token_missing}` - Sandbox token was required (because `state` `resources_module`
      `Calcinator.Resources.sandboxed?/0` returned `true`), but `params["meta"]["beam"]` was not present.
    * `{:error, :timeout}` - if the backing store for `state` `resources_module` times out when calling
      `Calcinator.Resources.get/2`.
    * `{:error, :unauthorized}` - if the either the source or related resource cannot be shown
    * `{:error, Alembic.Document.t}` - JSONAPI error document with `params` errors
    * `{:error, reason}` - a backing store-specific error

  """
  @spec show_relationship(t, params, map) ::
          {:ok, rendered}
          | {:error, {:not_found, parameter}}
          | {:error, :ownership}
          | {:error, :sandbox_access_disallowed}
          | {:error, :sandbox_token_missing}
          | {:error, :timeout}
          | {:error, :unauthorized}
          | {:error, Document.t()}
          | {:error, reason :: term}
  def show_relationship(
        state = %__MODULE__{},
        params,
        options = %{related: related}
      ) do
    related_property(state, params, put_in(options.related, Map.put(related, :property, :relationship)))
  end

  @doc """
  [Updates a resource](http://jsonapi.org/format/#crud-updating) with the `"id"` in `params`

  ## Steps

    1. `allow_sandbox_access/2`
    2. `state` `resources_module` `get(id, ...)`
    3. Check `params` are a valid JSONAPI document
    4. `state` `authorization_module` `can?(subject, :update, Ecto.Changeset.t)`
    5. `state` `resources_module` `update(Ecto.Changeset.t, ...)`
    6. `state` `authorization_module` `filter_associations_can(updated, subject, :show)`
    6. `state` `view_module` `show(authorized, ...)`

  ## Returns

    * `{:ok, rendered}` - the rendered updated resource
    * `{:error, :bad_gateway}` - backing store as internal error that can't be represented in any other format.
      Try again later or call support.
    * `{:error, {:not_found, "id"}}` - get failed or update failed because the resource was deleted between the get and
      update.
    * `{:error, :ownership}` - connection to backing store was not owned by the calling process
    * `{:error, :sandbox_access_disallowed}` - Sandbox token was required and present, but did not have the correct
      information to grant access.
    * `{:error, :sandbox_token_missing}` - Sandbox token was required (because `state` `resources_module`
      `Calcinator.Resources.sandboxed?/0` returned `true`), but `params["meta"]["beam"]` was not present.
    * `{:error, :timeout}` - if the backing store for `state` `resources_module` times out when calling
      `Calcinator.Resources.get/2` or `Calcinator.Resources.update/2`.
    * `{:error, :unauthorized}` - the resource either can't be shown or can't be updated
    * `{:error, Alembic.Document.t}` - the `params` are not valid JSONAPI
    * `{:error, Ecto.Changeset.t}` - validations error when updating
    * `{:error, reason}` - a backing store-specific error

  """
  @spec update(t, params) ::
          {:ok, rendered}
          | {:error, :bad_gateway}
          | {:error, {:not_found, parameter}}
          | {:error, :ownership}
          | {:error, :sandbox_access_disallowed}
          | {:error, :sandbox_token_missing}
          | {:error, :unauthorized}
          | {:error, Document.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, reason :: term}
  def update(state = %__MODULE__{subject: subject}, params) do
    with :ok <- allow_sandbox_access(state, params),
         {:ok, updatable} <- get(state, params),
         :ok <- can(state, :show, updatable),
         {:ok, document} <- document(params, :update),
         updatable_params = insertable_params(state, document),
         {:ok, changeset} <- changeset(state, updatable, updatable_params),
         :ok <- can(state, :update, changeset),
         {:ok, updated} <- update_changeset(state, changeset, params) do
      # DO NOT `:ok <- can(state, :show, updated)` because user can update to attributees they can't view, but we need
      # to send back the updated resource
      authorized = authorized(state, updated)
      {:ok, view(state, :show, [authorized, %{params: params, subject: subject}])}
    end
  end

  ## Private Functions

  defp alembic_fetch_to_associations_query_option(
         %__MODULE__{associations_by_include: associations_by_include},
         %Alembic.Fetch{includes: includes}
       ) do
    Includes.to_preloads(includes, associations_by_include)
  end

  defp alembic_fetch_to_sorts_query_option(
         %__MODULE__{associations_by_include: associations_by_include, ecto_schema_module: ecto_schema_module},
         fetch
       ) do
    Sorts.from_alembic_fetch(fetch, %{
      associations_by_include: associations_by_include,
      ecto_schema_module: ecto_schema_module
    })
  end

  @spec allow_sandbox_access(t, map, sandboxed? :: false) :: :ok
  @spec allow_sandbox_access(t, map, sandboxed? :: true) ::
          :ok | {:error, :sandbox_access_disallowed} | {:error, :sandbox_token_missing}

  defp allow_sandbox_access(
         calcinator,
         %{
           "meta" => %{
             "beam" => encoded_beam_meta
           }
         },
         true
       )
       when is_binary(encoded_beam_meta) do
    beam = Meta.Beam.decode(encoded_beam_meta)
    resources(calcinator, :allow_sandbox_access, [beam])
  end

  defp allow_sandbox_access(%__MODULE__{}, params, true) when is_map(params), do: {:error, :sandbox_token_missing}
  defp allow_sandbox_access(%__MODULE__{}, params, false) when is_map(params), do: :ok

  @spec authorized(t, [struct], Resources.pagination()) :: {[struct], Resources.pagination()}
  defp authorized(%__MODULE__{authorization_module: authorization_module, subject: subject}, unfiltered, pagination)
       when is_list(unfiltered) and (is_nil(pagination) or is_map(pagination)) do
    {shallow_filtered, filtered_pagination} =
      case authorization_module.filter_can(unfiltered, subject, :show) do
        ^unfiltered ->
          {unfiltered, pagination}

        filtered_can ->
          {filtered_can, pagination}
      end

    deep_filtered = authorization_module.filter_associations_can(shallow_filtered, subject, :show)

    {deep_filtered, filtered_pagination}
  end

  @spec changeset(t, insertable_params) ::
          {:ok, Ecto.Changeset.t()} | {:error, Ecto.Changeset.t()} | {:error, :ownership}
  defp changeset(calcinator, insertable_params) when is_map(insertable_params) do
    with {:ok, changeset} <- resources(calcinator, :changeset, [insertable_params]) do
      status_changeset(changeset)
    end
  end

  @spec create_changeset(t, Ecto.Changeset.t(), params) ::
          {:ok, struct}
          | {:error, :ownership}
          | {:error, :sandbox_access_disallowed}
          | {:error, :sandbox_token_missing}
          | {:error, :timeout}
          | {:error, Document.t()}
          | {:error, Ecto.Changeset.t()}
  defp create_changeset(state, changeset = %Ecto.Changeset{}, params) do
    with {:ok, query_options} <- params_to_query_options(state, params) do
      resources(state, :insert, [changeset, query_options])
    end
  end

  @spec delete_changeset(t, Ecto.Changeset.t(), Resources.query_options()) ::
          {:ok, Ecto.Schema.t()}
          | {:error, :ownership}
          | {:error, :timeout}
          | {:error, Ecto.Changeset.t()}
  defp delete_changeset(calcinator = %__MODULE__{}, changeset, query_options) do
    resources(calcinator, :delete, [changeset, query_options])
  end

  @spec document(params, FromJson.action()) :: {:ok, Document.t()} | {:error, Document.t()}
  defp document(raw_params, action) do
    instrument(:alembic, %{action: action, params: raw_params}, fn ->
      Document.from_json(raw_params, %Alembic.Error{
        meta: %{
          "action" => action,
          "sender" => :client
        },
        source: %Source{
          pointer: ""
        }
      })
    end)
  end

  @spec get(t, params) ::
          {:ok, Ecto.Schema.t()}
          | {:error, {:not_found, parameter}}
          | {:error, :ownership}
          | {:error, :timeout}
          | {:error, Document.t()}
          | {:error, reason :: term}
  defp get(state, params) do
    with {:ok, query_options} <- params_to_query_options(state, params) do
      get(state, params, query_options)
    end
  end

  @spec get(t, params, Resources.query_options()) ::
          {:ok, Ecto.Schema.t()}
          | {:error, {:not_found, parameter}}
          | {:error, :ownership}
          | {:error, :timeout}
          | {:error, Document.t()}
          | {:error, reason :: term}
  defp get(calcinator, params, query_options), do: get(calcinator, params, "id", query_options)

  @spec get_maybe_authorized_related(t, Ecto.Schema.t(), atom) ::
          {:ok, nil} | {:ok, Ecto.Schema.t()} | {:error, :unauthorized}
  defp get_maybe_authorized_related(state, source, association) do
    case get_related(source, association) do
      nil ->
        {:ok, nil}

      related ->
        with :ok <- can(state, :show, [related, source]) do
          {:ok, authorized(state, related)}
        end
    end
  end

  # Gets related as long as association is correct
  @spec get_related(Ecto.Schema.t(), atom) :: [Ecto.Schema.t()] | Ecto.Schema.t() | nil
  defp get_related(source, association) do
    case Map.fetch(source, association) do
      :error ->
        raise ArgumentError, "%#{source.__struct__}{} does not have #{inspect(association)} associaton"

      {:ok, related} ->
        related
    end
  end

  @spec get_source(t, params, %{
          required(:association) => association,
          required(:id_key) => String.t()
        }) ::
          {:ok, Ecto.Schema.t()}
          | {:error, {:not_found, parameter}}
          | {:error, :ownership}
          | {:error, :timeout}
          | {:error, Document.t()}
          | {:error, term}
  defp get_source(calcinator, params, %{association: association, id_key: id_key}) do
    get(calcinator, params, id_key, %{associations: [association]})
  end

  @spec insertable_params(t, Document.t()) :: insertable_params
  defp insertable_params(%__MODULE__{ecto_schema_module: ecto_schema_module}, document) do
    document
    |> Document.to_params()
    |> ToParams.nested_to_foreign_keys(ecto_schema_module)
  end

  @spec instrumented_authorized(t, related :: nil) :: nil
  defp instrumented_authorized(%__MODULE__{}, nil), do: nil

  # Filters `struct` or list of `struct`s to only those that can be shown
  @spec instrumented_authorized(t, unfiltered :: struct) :: struct
  defp instrumented_authorized(
         %__MODULE__{authorization_module: authorization_module, subject: subject},
         unfiltered = %_{}
       ) do
    authorization_module.filter_associations_can(unfiltered, subject, :show)
  end

  @spec instrumented_authorized(t, unfiltered :: [struct]) :: [struct]
  defp instrumented_authorized(%__MODULE__{authorization_module: authorization_module, subject: subject}, unfiltered)
       when is_list(unfiltered) do
    authorization_module.filter_associations_can(unfiltered, subject, :show)
  end

  @spec instrumented_can(t, Authorization.action(), Authorizaton.target()) :: :ok | {:error, :unauthorized}
  defp instrumented_can(
         %__MODULE__{authorization_module: authorization_module, subject: subject},
         action,
         target
       )
       when action in @actions and not is_nil(authorization_module) and
              (is_atom(target) or is_map(target) or is_list(target)) do
    if authorization_module.can?(subject, action, target) do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  @spec list(t, params) ::
          {:ok, [Ecto.Schema.t()], Resources.pagination()}
          | {:error, :timeout}
          | {:error, Document.t()}
          | {:error, reason :: term}
  defp list(calcinator, params) do
    with {:ok, query_options} <- params_to_query_options(calcinator, params) do
      resources(calcinator, :list, [query_options])
    end
  end

  defp params_to_filters_query_option(params), do: {:ok, Map.get(params, "filter", %{})}

  defp params_to_meta_query_option(params), do: {:ok, Map.get(params, "meta", %{})}

  defp params_to_page_query_option(params), do: Page.from_params(params)

  @spec params_to_query_options(t, params) :: {:ok, Resources.query_options()} | {:error, Document.t()}
  defp params_to_query_options(state = %__MODULE__{}, params) when is_map(params) do
    fetch = Fetch.from_params(params)

    with {:ok, associations} <- alembic_fetch_to_associations_query_option(state, fetch),
         {:ok, filters} <- params_to_filters_query_option(params),
         {:ok, meta} <- params_to_meta_query_option(params),
         {:ok, page} <- params_to_page_query_option(params),
         {:ok, sorts} <- alembic_fetch_to_sorts_query_option(state, fetch) do
      {:ok, %{associations: associations, filters: filters, meta: meta, page: page, sorts: sorts}}
    end
  end

  @spec related_property(t, params, map) ::
          {:ok, rendered}
          | {:error, {:not_found, parameter}}
          | {:error, :ownership}
          | {:error, :sandbox_access_disallowed}
          | {:error, :sandbox_token_missing}
          | {:error, :timeout}
          | {:error, :unauthorized}
          | {:error, Document.t()}
          | {:error, term}
  defp related_property(state = %__MODULE__{subject: subject, view_module: view_module}, params, %{
         related: related_option,
         source:
           source_option = %{
             association: association
           }
       }) do
    with :ok <- allow_sandbox_access(state, params),
         {:ok, source} <- get_source(state, params, source_option),
         :ok <- can(state, :show, source),
         {:ok, authorized_related} <- get_maybe_authorized_related(state, source, association) do
      {
        :ok,
        view_related_property(state, %{
          params: params,
          related: Map.put(related_option, :resource, authorized_related),
          source: Map.merge(source_option, %{resource: source, view_module: view_module}),
          subject: subject
        })
      }
    end
  end

  defp resources(calcinator = %__MODULE__{resources_module: resources_module}, callback, args) do
    instrument(:calcinator_resources, %{calcinator: calcinator, callback: callback, args: args}, fn ->
      apply(resources_module, callback, args)
    end)
  end

  defp status_changeset(changeset) do
    status =
      if changeset.valid? do
        :ok
      else
        :error
      end

    {status, changeset}
  end

  defp view(calcinator = %__MODULE__{view_module: view_module}, callback, args) do
    instrument(:calcinator_view, %{calcinator: calcinator, callback: callback, args: args}, fn ->
      apply(view_module, callback, args)
    end)
  end

  defp view_related_property(calcinator = %__MODULE__{subject: subject, view_module: view_module}, %{
         params: params,
         related:
           related = %{
             property: property,
             resource: resource
           },
         source: source
       }) do
    function_name =
      case property do
        :relationship -> :show_relationship
        :resource -> :get_related_resource
      end

    view(calcinator, function_name, [
      resource,
      %{
        params: params,
        related: related,
        source: put_in(source.view_module, view_module),
        subject: subject
      }
    ])
  end
end
