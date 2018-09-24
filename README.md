# Calcinator (testing push)

[![CircleCI](https://circleci.com/gh/C-S-D/calcinator.svg?style=svg)](https://circleci.com/gh/C-S-D/calcinator)
[![Coverage Status](https://coveralls.io/repos/github/C-S-D/calcinator/badge.svg)](https://coveralls.io/github/C-S-D/calcinator)
[![Code Climate](https://codeclimate.com/github/C-S-D/calcinator/badges/gpa.svg)](https://codeclimate.com/github/C-S-D/calcinator)
[![Deps Status](https://beta.hexfaktor.org/badge/all/github/C-S-D/calcinator.svg)](https://beta.hexfaktor.org/github/C-S-D/calcinator)
[![Inline docs](http://inch-ci.org/github/C-S-D/alembic.svg)](http://inch-ci.org/github/C-S-D/alembic)

Calcinator provides a standardized interface for processing JSONAPI request that is transport neutral.  CSD uses it
for both API controllers and RPC servers.

Calcinator uses [Alembic](https://github.com/C-S-D/alembic) to validate JSONAPI documents passed to the action functions
in `Calcinator`.  `Calcinator` supports the JSONAPI CRUD-style actions:
* `create`
* `delete`
* `get_related_resource`
* `index`
* `show`
* `show_relationship`
* `update`

Each action expects to be passed a `%Calcinator{}`.  The struct allow `Calcinator` to support converting JSONAPI
includes to associations (`associations_by_include`), authorization (`authorization_module` and `subject`),
`Ecto.Schema.t` interaction (`resources_module`), and JSONAPI document rendering (`view_module`).

## Authorization

`%Calcinator{}` `authorization_modules` need to implement the `Calcinator.Authorization` behaviour.

* `can?(subject, action, target) :: boolean`
* `filter_associations_can(target, subject, action) :: target`
* `filter_can(targets :: [target], subject, action) :: [target]`

The `can?(suject, action, target) :: boolean` matches the signature of the `Canada` protocol, but it is not required.

## Resources

`Calcinator.Resources` is a behaviour to supporting standard CRUD actions on an Ecto-based backing store.  This backing
store does not need to be a database that uses `Ecto.Repo`.  At CSD, we use `Calcinator.Resources` to hide the
differences between `Ecto.Repo` backed `Ecto.Schema.t` and RPC backed `Ecto.Schema.t` (where we use `Ecto` to do the
type casting.)

Because `Calcinator.Resources` need to work as an interface for both `Ecto.Repo` and RPC backed resources,
the callbacks and returns need to work for both, so all `Calcinator.Resources` implementations need to support
`allow_sandbox_access` and `sandboxed?` used for concurrent `Ecto.Repo` tests, but they also can return RPC error
messages like `{:error, :bad_gateway}` and `{:error, :timeout}`.

### Pagination

The `list` callback instead of returning just the list of resources, also accepts and returns (optional) pagination
information.  The pagination param format is documented in `Calcinator.Resources.Page`.

In addition to pagination in `page`, `Calcinator.Resources.query_options` supports `associations` for JSONAPI includes
(after being converted using `%Calcinator{}` `associations_by_include`), `filters` for JSONAPI filters that are passed
through directly, and `sorts` for JSONAPI sort.

#### Page Size

##### Default

A default page size can be configured.

```elixir
config :calcinator, Calcinator.Resources.Page, size: [default: 5]
```

or at runtime using `Application.put_env/3`

```elixir
Application.put_env(:calcinator, Calcinator.Resources.Page, size: [default: 10])
```

When default page size is configured, a default page number of `1` is also assumed.

##### Maximum

```elixir
config :calcinator, Calcinator.Resources.Page, size: [maximum: 25]
```

or at runtime using `Application.put_env/3`

```elixir
Application.put_env(:calcinator, Calcinator.Resources.Page, size: [maximum: 25])
```

#### `Calcinator.Resources.Ecto.Repo`

Pagination for `Calcinator.Resources.Ecto.Repo` is opt-in and needs to be configured.

##### Configuration

```elixir
config :calcinator, Calcinator.Resources.Ecto.Repo, paginator: paginator
````

##### Paginators

Returns based on `paginator` and `query_options` `page`

<table>
  <thead>
    <tr>
      <th>
        <code>config :calcinator, Calcinator.Resources.Ecto.Repo, paginator: paginator</code>
      </th>
      <th colspan="2">
        <code>query_options[:page]</code>
      </th>
      <th rowspan="2">Description</th>
    </tr>
    <tr>
      <th>
        <code>paginator</code>
      </th>
      <th>
        <code>nil</code>
      </th>
      <th>
        <code>%Calcinator.Resources.Page{}</code>
      </th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>
        <code>Calcinator.Resources.Ecto.Repo.Pagination.Ignore</code>
      </td>
      <td>
        <code>{:ok, all_resources, nil}</code>
      </td>
      <td>
        <code>{:ok, all_resources, nil}</code>
      </td>
      <td>
        <code>query_options[:page]</code> is ignored: all resources are
        always returned.  There is no pagination information ever
        returned.
      </td>
    </tr>
    <tr>
      <td>
        <code>Calcinator.Resources.Ecto.Repo.Pagination.Disallow</code>
      </td>
      <td>
        <code>{:ok, all_resources, nil}</code>
      </td>
      <td>
        <code>{:error, %Alembic.Document{}}</code>
      </td>
      <td>
        All resources with <code>nil</code> pagination is returned when
        <code>query_options[:page]</code> is <code>nil</code>, but an
        error is returns if <code>query_optons[:page]</code> is not nil.
        This is an improvement over
        <code>Calcinator.Resources.Ecto.Repo.Pagination.Ignore</code>
        because it will tell callers that
        <code>query_options[:page]</code> will not be honored.
      </td>
    </tr>
    <tr>
      <td>
        <code>Calcinator.Resources.Ecto.Repo.Pagination.Allow</code>
      </td>
      <td>
        <code>{:ok, all_resources, nil}</code>
      </td>
      <td>
        <code>{:ok, page_of_resources, %Alembic.Pagination{}}</code>
      </td>
      <td>
        All resources with <code>nil</code> pagination is returned when
        <code>query_options[:page]</code> is <code>nil</code>.  A page
        of resources with the pagination information is returned when
        <code>query_options[:page]</code> is not <code>nil</code>.
        <strong>This is the default paginator.</strong>
      </td>
    </tr>
    <tr>
      <td>
        <code>Calcinator.Resources.Ecto.Repo.Pagination.Require</code>
      </td>
      <td>
        <code>{:error, %Alembic.Document{}</code>
      </td>
      <td>
        <code>{:ok, page_of_resources, %Alembic.Pagination{}}</code>
      </td>
      <td>
        An error is returned when <code>query_options[:page]</code> is
        <code>nil</code>.  A page of resources with the pagination
        information is returned when <code>query_options[:page]</code>
        is not <code>nil</code>.  This is a stronger form of
        <code>Calcinator.Resources.Ecto.Repo.Pagination.Allow</code>
        because it forces the caller to declare what page it wants.
        Using
        <code>Calcinator.Resources.Ecto.Repo.Pagination.Require</code>
        is recommended when not paginating would have a detrimental
        performance impact.
      </td>
    </tr>
  </tbody>
</table>

If you want to define your own paginator, it must implement the `Calcinator.Resources.Ecto.Repo.Pagination` behaviour.

##### Sorting

`c:Calcinator.Resources.list/1` from `use Calcinator.Resources.Ecto.Repo` can sort any of attribute of the primary `Ecto.Schema.t` returned by `c:Calcinator.Resources.Ecto.Repo.ecto_schema_module/0`

```elixir
TestPosts.list(%{sorts: [%Calcinator.Resources.Sort{direction: :ascending, field: :inserted_at}]})
TestPosts.list(%{sorts: [%Calcinator.Resources.Sort{direction: :descending, field: :inserted_at}]})
```

or any attribute of relationships that are mapped to associations of the primary data


```elixir
TestPosts.list(%{
                 sorts: [
                   %Calcinator.Resources.Sort{
                     association: :author,
                     direction: :ascending,
                     field: :name
                   }
                 ]
               })
TestPosts.list(%{
                 sorts: [
                   %Calcinator.Resources.Sort{
                     association: :author,
                     direction: :descending,
                     field: :name
                   }
                 ]
               })               
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `calcinator` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:calcinator, "~> 3.0"}]
    end
    ```

  2. Ensure `calcinator` is started before your application:

    ```elixir
    def application do
      [applications: [:calcinator]]
    end
    ```

## Usage

### Phoenix

`Calcinator.Controller` uses `Calcinator.Resources`, which is transport-agnostic, so you can use it to access multiple
backing stores.  CSD itself, uses it to access PostgreSQL database owned by the project using `Ecto` and to access
remote data over RabbitMQ.

#### Database

If you want to use `Calcinator` to access records in a database, you can use `Ecto`

#### `Ecto.Schema` modules

`MyApp.Author` and `MyAuthor.Post` are standard `use Ecto.Schema` modules.  `MyApp` is a separate OTP
application in the umbrella project.

```elixir
defmodule MyApp.Author do
  @moduledoc """
  The author of `MyApp.Post`s
  """

  use Ecto.Schema

  schema "authors" do
    field :name, :string
    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true

    timestamps

    has_many :posts, RemoteApp.Post, foreign_key: :author_id
  end
end
```
-- `apps/my_app/lib/my_app/author.ex`

```elixir
defmodule MyApp.Post do
  @moduledoc """
  Posts by a `MyApp.Author`.
  """

  use Ecto.Schema

  schema "posts" do
    field :text, :string

    timestamps

    belongs_to :author, MyApp.Author
  end
end
```
-- `apps/my_app/lib/my_app/post.ex`

#### Resources module

```elixir
defmodule MyApp.Posts do
  @moduledoc """
  Retrieves `%MyApp.Post{}` from `MyApp.Repo`
  """

  use Calcinator.Resources.Ecto.Repo

  # Functions

  ## Calcinator.Resources.Ecto.Repo callbacks

  def ecto_schema_module(), do: MyApp.Post

  def repo(), do: MyApp.Repo
end
```

##### View Module

`Calcinator` relies on `JaSerializer` to define view module

```elixir
defmodule MyAppWeb.PostView do
  @moduledoc """
  Handles encoding the Post model into JSON:API format.
  """

  alias MyApp.Post

  use JaSerializer.PhoenixView
  use Calcinator.JaSerializer.PhoenixView,
      phoenix_view_module: __MODULE__

  # Attributes

  attributes ~w(inserted_at
                text
                updated_at)a

  # Location

  location "/posts/:id"

  # Relationships

  has_one :author,
          serializer: MyAppWeb.AuthorView

  # Functions

  def relationships(post = %Post{}, conn) do
    partner
    |> super(conn)
    |> Enum.filter(relationships_filter(post))
    |> Enum.into(%{})
  end

  def type(_data, _conn), do: "posts"

  ## Private Functions

  def relationships_filter(%Post{author: %Ecto.Association.NotLoaded{}}) do
    fn {name, _relationship} ->
      name != :author
    end
  end

  def relationships_filter(_) do
    fn {_name, _relationship} ->
      true
    end
  end
end
```
-- `apps/my_app_web/lib/my_app_web/post_view.ex`

The `relationships/2` override is counter to `JaSerializer`'s own recommendations.  It recommends doing a `Repo` call
to load associations on demand, but that is against the Phoenix Core recommendations to make view modules side-effect
free, so the `relationships/2` override excludes the relationship from including even linkage data when it's not loaded

##### Controller Module

*NOTE: Assumes that `user` assign is set by an authorization plug before the controller is called.*

###### Authenticated/Authorized Read/Write Controller

```elixir
defmodule MyAppWeb.PostController do
  @moduledoc """
  Allows authenticated and authorized reading and writing of `%MyApp.Post{}` that are fetched from `MyApp.Repo`.
  """

  alias Calcinator.Controller

  use MyAppWeb.Web, :controller
  use Controller,
      actions: ~w(create delete get_related_resource index show show_relationship update)a,
      configuration: %Calcinator{
        authorization_module: MyAppWeb.Authorization,
        ecto_schema_module: MyApp.Post,
        resources_module: MyApp.Posts,
        view_module: MyAppWeb.PostView
      }

  # Plugs

  plug :put_subject

  # Functions

  def put_subject(conn = %Conn{assigns: %{user: user}}, _), do: Controller.put_subject(conn, user)
end
```
-- `apps/my_app_web/lib/my_app_web/post_controller.ex`

###### Public Read-only Controller

*NOTE: Although it is not recommended, if you want to run without authorization (say because all data is public and
read-only), then you can remove the `:authorization_module` configuration and `put_subject` plug.*

```
defmodule MyAppWeb.PostController do
  @moduledoc """
  Allows public reading of `MyApp.Post` that are fetched from `MyApp.Repo`.
  """

  alias Calcinator.Controller

  use MyAppWeb.Web, :controller
  use Controller,
      actions: ~w(get_related_resource index show show_relationship)a,
      configuration: %Calcinator{
        ecto_schema_module: MyApp.Post,
        resources_module: MyApp.Posts,
        view_module: MyAppWeb.PostView
      }
end
```
-- `apps/my_app_web/lib/my_app_web/post_controller.ex`

#### RabbitMQ

If you want to use `Calcinator` over RabbitMQ, use [`Retort`](https://github.com/C-S-D/retort): it's
[`Retort.Resources`](https://hexdocs.pm/retort/Retort.Resources.html) implements the `Calcinator.Resources` behaviour.

##### `Ecto.Schema` modules

`RemoteApp.Author` and `RemoteApp.Post` are standard `use Ecto.Schema` modules.  `RemoteApp` is a separate OTP
application in the umbrella project.

```elixir
defmodule RemoteApp.Author do
  @moduledoc """
  The author of `RemoteApp.Post`s
  """

  use Ecto.Schema

  schema "authors" do
    field :name, :string
    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true

    timestamps

    has_many :posts, RemoteApp.Post, foreign_key: :author_id
  end
end
```
-- `apps/remote_app/lib/remote_app/author.ex`

```elixir
defmodule RemoteApp.Post do
  @moduledoc """
  Posts by a `RemoteApp.Author`.
  """

  use Ecto.Schema

  schema "posts" do
    field :text, :string

    timestamps

    belongs_to :author, RemoteApp.Author
  end
end
```
-- `apps/remote_app/lib/remote_app/post.ex`

##### Client module

Define a module to setup a `Retort.Generic.Client` (you can also inline this at `Client.Post.start_link()` below, but
we find the module useful for tests.

```elixir
defmodule RemoteApp.Client.Post do
  @moduledoc """
  Client for accessing Posts on remote-server
  """

  alias RemoteApp.{Author, Post}

  # Functions

  def queue, do: "remote_server_post"

  def start_link(opts \\ []) do
    Retort.Client.Generic.start_link(
      opts ++ [
        ecto_schema_module_by_type: %{
          "authors" => Author,
          "posts" => Post
        },
        queue: queue,
        type: "posts"
      ]
    )
  end
end
```
-- `apps/remote_app/lib/remote_app/client/post.ex`

##### Resources module

Define a module that `use Retort.Resources` to get the `Ecto.Schema` structs using `Retort.Generic.Client`

```elixir
defmodule RemoteApp.Posts do
  @moduledoc """
  Retrieves `%RemoteApp.Post{}` over RPC
  """

  alias RemoteApp.Client
  alias RemoteApp.Post

  require Ecto.Query

  import Ecto.Changeset, only: [cast: 3]

  use Retort.Resources

  # Constants

  @default_timeout 5_000 # milliseconds

  @optional_fields ~w()a
  @required_fields ~w()a

  @allowed_fields @optional_fields ++ @required_fields

  # Functions

  ## Retort.Resources callbacks

  def association_to_include(:author), do: "author"

  def client_start_link() do
    __MODULE__
    |> Retort.Resources.client_start_link_options()
    |> Client.Post.start_link()
  end

  def ecto_schema_module(), do: Post

  ## Resources callbacks

  @doc """
  Creates a changeset that updates `post` with `params`.
  """
  @spec changeset(%Post{}, Resoures.params) :: Ecto.Changeset.t
  def changeset(post, params), do: cast(post, params, @allowed_fields)

  def sandboxed?(), do: LocalApp.Repo.sandboxed?()
end
```
-- `apps/remote_app/lib/remote_app/posts`

##### View Module

`Calcinator` relies on `JaSerializer` to define view module.

```elixir
defmodule LocalAppWeb.PostView do
  @moduledoc """
  Handles encoding the Post model into JSON:API format.
  """

  alias RemoteApp.Post

  use JaSerializer.PhoenixView
  use Calcinator.JaSerializer.PhoenixView,
      phoenix_view_module: __MODULE__

  # Attributes

  attributes ~w(inserted_at
                text
                updated_at)a

  # Location

  location "/posts/:id"

  # Relationships

  has_one :author,
          serializer: LocalAppWeb.AuthorView

  # Functions

  def relationships(post = %Post{}, conn) do
    partner
    |> super(conn)
    |> Enum.filter(relationships_filter(post))
    |> Enum.into(%{})
  end

  def type(_data, _conn), do: "posts"

  ## Private Functions

  def relationships_filter(%Post{author: %Ecto.Association.NotLoaded{}}) do
    fn {name, _relationship} ->
      name != :author
    end
  end

  def relationships_filter(_) do
    fn {_name, _relationship} ->
      true
    end
  end
end
```
-- `apps/local_app_web/lib/local_app_web/post_view.ex`

The `relationships/2` override is counter to `JaSerializer`'s own recommendations.  It recommends doing a `Repo` call
to load associations on demand, but that is against the Phoenix Core recommendations to make view modules side-effect
free, so the `relationships/2` override excludes the relationship from including even linkage data when it's not loaded

##### Controller Module

###### Authenticated/Authorized Read/Write Controller

*NOTE: Assumes that `user` assign is set by an authorization plug before the controller is called.*

```elixir
defmodule LocalAppWeb.PostController do
  @moduledoc """
  Allows authenticated and authorized reading and writing of `MyApp.Post` that are fetched from remote server over RPC.
  """

  alias Calcinator.Controller

  use LocalAppWeb.Web, :controller
  use Controller,
      actions: ~w(create delete get_related_resource index show show_relationship update)a,
      configuration: %Calcinator{
        authorization_module: LocalAppWeb.Authorization,
        ecto_schema_module: RemoteApp.Post,
        resources_module: RemoteApp.Posts,
        view_module: LocalAppWeb.PostView
      }

  # Plugs

  plug :put_subject

  # Functions

  def put_subject(conn = %Conn{assigns: %{user: user}}, _), do: Controller.put_subject(conn, user)
end
```
-- `apps/local_app_web/lib/local_app_web/post_controller.ex`

###### Public Read-only Controller

*NOTE: Although it is not recommended, if you want to run without authorization (say because all data is public and
read-only), then you can remove the `:authorization_module` configuration and `put_subject` plug.*

```
defmodule LocalAppWeb.PostController do
  @moduledoc """
  Allows public reading of `%RemoteApp.Post{}` that are fetched from remote server over RPC.
  """

  alias Calcinator.Controller

  use MyAppWeb.Web, :controller
  use Controller,
      actions: ~w(get_related_resource index show show_relationship)a,
      configuration: %Calcinator{
        ecto_schema_module: RemoteApp.Post,
        resources_module: RemoteApp.Posts,
        view_module: LocalAppWeb.PostView
      }
end
```
-- `apps/local_app_web/lib/local_app_web/post_controller.ex`

## Instrumentation

`Calcinator` supports instrumentation similar to `Phoenix`: calls in `Calcinator` will fire instrumentation events around calls to subsystems.

| event                      | subsystem                  |
|----------------------------|----------------------------|
| `alembic`                  | `Alembic`                  |
| `calcinator_authorization` | `Calcinator.Authorization` |
| `calcinator_resources`     | `Calcinator.Resources`     |
| `calcinator_view`          | `Calcinator.View`          |

### PryIn.IO

`Calcinator` ships with support for [pryin.io](https://pryin.io).

You can turn on PryIn support following the [`pryin` installation instructions](https://github.com/pryin-io/pryin#installation) and then adding `Calcinator.PryIn.Instrumenter` to your `:calcinator` config

```
config :calcinator,
       instrumenters: [Calcinator.PryIn.Instrumenter]
```

### Custom

You can write your own Instrumenter following the instructions in the `Calcinator.Instrument` documentation and then configuring `:calcinator` to use your custom instrumenter.

```
config :calcinator,
       instrumenters: [MyLib.Calcinator.Instrumenter]
```
