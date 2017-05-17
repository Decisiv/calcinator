defmodule Calcinator.Resources.Ecto.Repo do
  @moduledoc """
  Default callbacks for `Calcinator.Resources` behaviour when backed by a single `Ecto.Repo`

  If you don't have any default loaded associations, you only need to define `ecto_schema_module/0` and `repo/0`

      defmodule MyApp.Posts do
        @moduledoc \"""
        Retrieves `%MyApp.Post{}` from `MyApp.Repo`
        \"""

        use Calcinator.Resources.Ecto.Repo

        # Functions

        ## Calcinator.Resources.Ecto.Repo callbacks

        def ecto_schema_module(), do: MyApp.Post

        def repo(), do: MyApp.Repo
      end

  If you need to override the loaded associations also override `full_associations/1`

       defmodule MyApp.Posts do
        @moduledoc \"""
        Retrieves `%MyApp.Post{}` from `MyApp.Repo`
        \"""

        use Calcinator.Resources.Ecto.Repo

        # Functions

        ## Calcinator.Resources.Ecto.Repo callbacks

        def ecto_schema_module(), do: MyApp.Post

        @doc \"""
        Always loads post author
        \"""
        def full_associations(query_options) do
          [:author | super(query_options)]
        end

        def repo(), do: MyApp.Repo
      end

  """

  alias Alembic.Document
  alias Ecto.{Adapters.SQL.Sandbox, Query}

  require Ecto.Query
  require Logger

  import Calcinator.Resources, only: [unknown_filter: 1]
  import Ecto.Changeset, only: [cast: 3]
  import Ecto.Query, only: [distinct: 2]

  # Types

  @typedoc """
  Name of a module that defines an `Ecto.Schema.t`
  """
  @type ecto_schema_module :: module

  # Callbacks

  @doc """
  The `Ecto.Schema` module stored in `repo/0`.
  """
  @callback ecto_schema_module() :: module

  @doc """
  Filters `query` by `name` with the given `value` prior to running query on `module` `repo` in `list/1`

  ## Returns

    `{:ok, query}` - given `query` with `name` filter with `value` applied
    `{:error, Alembic.Document.t}` - JSONAPI error document with error(s) showing why either `name` filter was not
      supported or `value` was not supported for `name` filter.

  """
  @callback filter(Ecto.Query.t, name :: String.t, value :: String.t) :: {:ok, Ecto.Query.t} | {:error, Document.t}

  @doc """
  The full list of associations to preload in

    * `Calcinator.Resources.get/2`
    * `Calcinator.Resources.insert/2`
    * `Calcinator.Resources.list/1`
    * `Calcinator.Resources.update/2`
    * `Calcinator.Resources.update/3`

  Should combine the request-specific associations in `Resources.query_options` with any default associations and/or
  transform requested associations to `repo/0`-specific associations.
  """
  @callback full_associations(Resources.query_options) :: [atom] | Keyword.t

  @doc """
  The `Ecto.Repo` that stores `ecto_schema_module/0`.
  """
  @callback repo() :: module

  @optional_callbacks filter: 3

  # Macros

  defmacro __using__([]) do
    quote do
      alias Calcinator.Resources.Ecto.Repo, as: EctoRepoResources

      # Behaviours

      @behaviour Calcinator.Resources
      @behaviour EctoRepoResources

      # Functions

      def full_associations(query_options = %{}), do: EctoRepoResources.full_associations(query_options)

      ## Resources callbacks

      @spec allow_sandbox_access(Resources.sandbox_access_token) :: :ok | {:error, :sandbox_access_disallowed}
      def allow_sandbox_access(token), do: EctoRepoResources.allow_sandbox_access(token)

      def changeset(params), do: EctoRepoResources.changeset(__MODULE__, params)

      def changeset(data, params), do: EctoRepoResources.changeset(__MODULE__, data, params)

      def delete(changeset, query_options), do: EctoRepoResources.delete(__MODULE__, changeset, query_options)

      @spec get(Resources.id, Resources.query_options) ::
            {:ok, Ecto.Schema.t} | {:error, :not_found} | {:error, :ownership}
      def get(id, opts), do: EctoRepoResources.get(__MODULE__, id, opts)

      def insert(changeset_or_params, query_options) do
        EctoRepoResources.insert(__MODULE__, changeset_or_params, query_options)
      end

      @spec list(Resources.query_options) :: {:ok, [Ecto.Schema.t], nil} | {:error, :ownership}
      def list(query_options), do: EctoRepoResources.list(__MODULE__, query_options)

      def sandboxed?(), do: EctoRepoResources.sandboxed?(__MODULE__)

      def update(changeset, query_options), do: EctoRepoResources.update(__MODULE__, changeset, query_options)

      def update(data, params, query_options), do: EctoRepoResources.update(__MODULE__, data, params, query_options)

      defoverridable [
                       allow_sandbox_access: 1,
                       changeset: 1,
                       changeset: 2,
                       delete: 2,
                       full_associations: 1,
                       get: 2,
                       insert: 2,
                       list: 1,
                       sandboxed?: 0,
                       update: 2,
                       update: 3
                     ]
    end
  end

  # Functions

  @doc """
  Allows access to `Ecto.Adapters.SQL.Sandbox`
  """
  @spec allow_sandbox_access(Resources.sandbox_access_token) :: :ok | {:error, :sandbox_access_disallowed}
  def allow_sandbox_access(%{owner: owner, repo: repo}) do
    repo
    |> List.wrap()
    |> Enum.reduce_while(
         :ok,
         fn repo_element, :ok ->
           case allow_sandbox_access(repo_element, owner) do
             :ok -> {:cont, :ok}
             error = {:error, :sandbox_access_disallowed} -> {:halt, error}
           end
         end
       )
  end

  @doc """
  `Ecto.Changeset.t` using the default `Ecto.Schema.t` for `module` with `params`
  """
  @spec changeset(module, Resources.params) :: Ecto.Changeset.t
  def changeset(module, params) when is_map(params), do: module.changeset(module.ecto_schema_module.__struct__, params)

  @doc """
  1. Casts `params` into `data` using `optional_field/0` and `required_fields/0` of `module`
  2. Validates changeset with `module` `ecto_schema_module/0` `changeset/0`
  """
  @spec changeset(module, Ecto.Schema.t, Resources.params) :: Ecto.Changeset.t
  def changeset(module, data, params) when is_map(params) do
    ecto_schema_module = module.ecto_schema_module()

    data
    |> cast(params, ecto_schema_module.optional_fields() ++ ecto_schema_module.required_fields())
    |> ecto_schema_module.changeset()
  end

  @doc """
  Deletes `changeset` from `module`'s `repo/0`
  """
  @spec delete(module, changeset :: Ecto.Changeset.t, Resources.query_options) ::
        {:ok, Ecto.Schema.t} | {:error, :ownership} | {:error, Ecto.Changeset.t}
  def delete(module, changeset, _query_options) do
    repo = module.repo()

    wrap_ownership_error(repo, :delete, [changeset])
  end

  @doc """
  Uses `query_options` as full associatons with no additions.
  """
  def full_associations(query_options) when is_map(query_options), do: Map.get(query_options, :associations, [])

  @doc """
  Gets resource with `id` from `module` `repo/0`.

  ## Returns

    * `{:error, :not_found}` - if `id` is not found in `module`'s `repo/0`.
    * `{:error, :ownership}` - if `DBConnection.OwnershipError` due to connection sharing error during tests.
    * `{:ok, struct}` - if `id` is found in `module`'s `repo/0`.  Associations will also be preloaded in `struct` based
      on `Resources.query_options`.

  """
  @spec get(module, Resources.id, Resources.query_options) ::
        {:ok, Ecto.Schema.t} | {:error, :not_found} | {:error, :ownership}
  def get(module, id, query_options) when is_map(query_options) do
    ecto_schema_module = module.ecto_schema_module()
    repo = module.repo()

    case wrap_ownership_error(repo, :get, [ecto_schema_module, id]) do
      {:error, :ownership} ->
        {:error, :ownership}
      nil ->
        {:error, :not_found}
      data ->
        preload(module, data, query_options)
    end
  end

  @doc """
  1. Insert `changeset` into `module` `repo/0`
  2. Inserts `params` into `module` `repo/0` after converting them into an `Ecto.Changeset.t`

  ## Returns

    * `{:error, :ownership}` - connection to backing store was not owned by the calling process
    * `{:error, Ecto.Changeset.t}` - if `changeset` cannot be inserted into `module` `repo/0`
    * `{:ok, struct}` - if `changeset` was inserted in to `module` `repo/0`.  `struct` is preloaded with associations
      according to `Resource.query_iptions` in `opts`.

  """
  @spec insert(module, Ecto.Changeset.t | map, Resources.query_options) ::
        {:ok, Ecto.Schema.t} | {:error, :ownership} | {:error, Ecto.Changeset.t}

  def insert(module, changeset = %Ecto.Changeset{}, query_options) when is_map(query_options) do
    repo = module.repo()

    with {:ok, inserted} <- wrap_ownership_error(repo, :insert, [changeset]) do
      preload(module, inserted, query_options)
    end
  end

  def insert(module, params, query_options) when is_map(params) and is_map(query_options) do
    params
    |> module.changeset()
    |> module.insert(query_options)
  end

  @doc """

  ## Returns

    * `{:error, Alembic.Document.t}` - JSONAPI error listing the unknown filters in `opts`
    * `{:error, :ownership}` - connection to backing store was not owned by the calling process
    * `{:ok, [struct], nil}` - `[struct]` is the list of all `module` `ecto_schema_module/0` in `module` `repo/0`.
      There is no (current) support for pagination: pagination is the `nil` in the 3rd element of the tuple.

  """
  @spec list(module, Resources.query_options) ::
        {:ok, [Ecto.Schema.t], nil} | {:error, :ownership} | {:error, Document.t}
  def list(module, query_options) when is_map(query_options) do
    repo = module.repo()
    {:ok, query} = preload(module, module.ecto_schema_module(), query_options)

    with {:ok, query} <- filter(module, query, query_options) do
      case wrap_ownership_error(repo, :all, [distinct(query, true)]) do
        {:error, :ownership} ->
          {:error, :ownership}
        all ->
          {:ok, all, nil}
      end
    end
  end

  @doc """
  Whether `module` `repo/0` is sandboxed and `allow_sandbox_access/1` should be called.
  """
  def sandboxed?(module), do: module.repo().config[:pool] == Ecto.Adapters.SQL.Sandbox

  @doc """
  Updates `struct` in `module` `repo/0` using `changeset`.

  ## Returns

    * `{:error, :ownership}` - connection to backing store was not owned by the calling process
    * `{:error, Ecto.Changeset.t}` - if the `changeset` had validations error or it could not be used to update `struct`
      in `module` `repo/0`.
    * `{:ok, struct}` - the updated `struct`.  Associations are preloaded using `Resources.query_options` in
      `query_options`.

  """
  @spec update(module, Ecto.Changeset.t, Resources.query_options) ::
        {:ok, Ecto.Schema.t} | {:error, :ownership} | {:error, Ecto.Changeset.t}
  def update(module, changeset, query_options) when is_map(query_options) do
    repo = module.repo()

    with {:ok, updated} <- wrap_ownership_error(repo, :update, [changeset]) do
      update_preload(module, updated, query_options)
    end
  end

  @doc """
  Updates `data` with `params` in `module` `repo/0`

  ## Returns

    * `{:error, :ownership}` - connection to backing store was not owned by the calling process
    * `{:error, Ecto.Changeset.t}` - if the changeset derived from updating `data` with `params` had validations error
      or it could not be used to update `data` in `module` `repo/0`.
    * `{:ok, struct}` - the updated `struct`.  Associations are preloaded using `Resources.query_options` in
      `query_options`.

  """
  @spec update(module, Ecto.Schema.t, Resources.params, Resources.query_options) ::
          {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  def update(module, data, params, query_options) when is_map(params) and is_map(query_options) do
    data
    |> module.changeset(params)
    |> module.update(query_options)
  end

  ## Private Functions

  defp allow_sandbox_access(repo, owner) do
    case Sandbox.allow(repo, owner, self()) do
      {:already, :allowed} -> :ok
      {:already, :owner} -> :ok
      :not_found -> {:error, :sandbox_access_disallowed}
      :ok -> :ok
    end
  end

  defp apply_filter(module, query, name, value) when is_binary(name) and is_binary(value) do
    if function_exported?(module, :filter, 3) do
      module.filter(query, name, value)
    else
      {:error, unknown_filter(name)}
    end
  end

  defp apply_filters(module, query, filters) when is_map(filters) do
    Enum.reduce filters, {:ok, query}, fn {name, value}, acc ->
      case acc do
        {:ok, acc_query} ->
          apply_filter(module, acc_query, name, value)
        acc = {:error, acc_document = %Document{}} ->
          case apply_filter(module, query, name, value) do
            {:ok, _} -> acc
            {:error, filter_document = %Document{}} -> {:error, Document.merge(acc_document, filter_document)}
          end
      end
    end
  end

  defp filter(module, query, query_options) when is_map(query_options) do
    filters = Map.get(query_options, :filters, %{})
    apply_filters(module, query, filters)
  end

  defp preload(module, data_or_queryable, query_options) when is_map(query_options) do
    ecto_schema_module = module.ecto_schema_module()

    case data_or_queryable do
      data = %{__struct__: ^ecto_schema_module} ->
        preload_data(module, data, query_options)
      queryable ->
        {:ok, Query.preload(queryable, ^module.full_associations(query_options))}
    end
  end

  defp preload_data(module, data, query_options) when is_map(query_options) do
    repo = module.repo()

    case wrap_ownership_error(repo, :preload, [data, module.full_associations(query_options)]) do
      {:error, :ownership} ->
        {:error, :ownership}
      preloaded ->
        {:ok, preloaded}
    end
  end

  # have to unload preloads that may have been updated
  # See http://stackoverflow.com/a/34946099/470451
  # See https://github.com/elixir-lang/ecto/issues/1212
  defp unload_preloads(updated, preloads) do
    Enum.reduce(
      preloads,
      updated,
      fn
        # preloads = [:<field>]
        (field, acc) when is_atom(field) ->
          Map.put(acc, field, Map.get(acc.__struct__.__struct__, field))
        # preloads = [<field>: <association_preloads>]
        ({field, _}, acc) when is_atom(field) ->
          Map.put(acc, field, Map.get(acc.__struct__.__struct__, field))
      end
    )
  end

  @spec update_preload(module, Ecto.Schema.t, Resources.query_options) :: {:ok, Ecto.Schema.t} | {:error, :ownership}
  defp update_preload(module, updated, query_options) when is_map(query_options) do
    preloads = module.full_associations(query_options)
    repo = module.repo()
    unloaded_updated = unload_preloads(updated, preloads)

    case wrap_ownership_error(repo, :preload, [unloaded_updated, preloads]) do
      {:error, :ownership} -> {:error, :ownership}
      reloaded_updated -> {:ok, reloaded_updated}
    end
  end

  defp wrap_ownership_error(repo, function, arguments) do
    apply(repo, function, arguments)
  rescue
    ownership_error in DBConnection.OwnershipError ->
      ownership_error
      |> inspect()
      |> Logger.error()

      {:error, :ownership}
  else
    other -> other
  end
end
