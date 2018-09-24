<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Changelog](#changelog)
  - [v5.2.0](#v510)
    - [Enhancements](#enhancements)
  - [v5.1.0](#v510)
    - [Enhancements](#enhancements)
    - [Bug Fixes](#bug-fixes)
  - [v5.0.0](#v500)
    - [Enhancements](#enhancements-1)
    - [Bug Fixes](#bug-fixes-1)
    - [Incompatible Changes](#incompatible-changes)
  - [v4.0.1](#v401)
    - [Bug Fixes](#bug-fixes-2)
  - [v4.0.0](#v400)
    - [Enhancements](#enhancements-2)
    - [Bug Fixes](#bug-fixes-3)
    - [Incompatible Changes](#incompatible-changes-1)
  - [v3.0.0](#v300)
    - [Enhancements](#enhancements-3)
    - [Bug Fixes](#bug-fixes-4)
    - [Incompatible Changes](#incompatible-changes-2)
  - [v2.4.0](#v240)
    - [Enhancements](#enhancements-4)
  - [v2.3.1](#v231)
    - [Bug Fixes](#bug-fixes-5)
  - [v2.3.0](#v230)
    - [Enhancements](#enhancements-5)
  - [v2.2.0](#v220)
    - [Enhancements](#enhancements-6)
  - [v2.1.0](#v210)
    - [Enhancements](#enhancements-7)
    - [Bug Fixes](#bug-fixes-6)
  - [v2.0.0](#v200)
    - [Enhancements](#enhancements-8)
    - [Bug Fixes](#bug-fixes-7)
    - [Incompatible Changes](#incompatible-changes-3)
  - [v1.7.0](#v170)
    - [Enhancements](#enhancements-9)
    - [Bug Fixes](#bug-fixes-8)
  - [v1.6.0](#v160)
    - [Enhancements](#enhancements-10)
  - [v1.5.1](#v151)
    - [Bug Fixes](#bug-fixes-9)
  - [v1.5.0](#v150)
    - [Enhancements](#enhancements-11)
    - [Bug Fixes](#bug-fixes-10)
  - [v1.4.0](#v140)
    - [Enhancements](#enhancements-12)
  - [v1.3.0](#v130)
    - [Enhancements](#enhancements-13)
    - [Bug Fixes](#bug-fixes-11)
  - [v1.2.0](#v120)
    - [Enhancements](#enhancements-14)
    - [Bug Fixes](#bug-fixes-12)
  - [v1.1.0](#v110)
    - [Enhancements](#enhancements-15)
    - [Bug Fixes](#bug-fixes-13)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Changelog

## v5.2.0

### Enhancements

* [#3](https://github.com/Decisiv/calcinator/pull/3) - [@edipox](https://github.com/edipox)
 * Update `Calcinator.Controller.Error.put_calcinator_error` in order to render a response using the status code from the error whenever is possible.

## v5.1.0

### Enhancements
*
* [#36](https://github.com/C-S-D/calcinator/pull/36) - [@KronicDeth](https://github.com/KronicDeth)
  * Update to latest `mix.lock` format.
  * JaSerializer [supports](https://github.com/vt-elixir/ja_serializer#fields) [sparse fieldsets](http://jsonapi.org/format/#fetching-sparse-fieldsets), but `Calcinator.JaSerializer.PhoenixView`'s `params_to_render_opts/1` was only copying `params["include"]` to `opts[:include]`, so now copy over both `"include"` and `"fields"` if present.
* [#37[(https://github.com/C-S-D/calcinator/pull/37) - [@KronicDeth](https://github.com/KronicDeth)
  * `Calcinator.Resource.Ecto.Repo.list/2`  supports configurable pagination through

    ```elixir
    config :calcinator, Calcinator.Resources.Ecto.Repo, paginator: paginator
    ```

    4 `Calcinator.Resources.Ecto.Repo.Pagination` callback modules are included

    * `Calcinator.Resources.Ecto.Repo.Pagination.Ignore` - `query_options[:page]` is ignored: all resources are always returned.  There is no pagination information ever returned.  This replicates the old, bugged behavior.
    * `Calcinator.Resources.Ecto.Repo.Pagination.Disallow` - All resources with `nil` pagination is returned when `query_options[:page]` is `nil`, but an error is returns if `query_optons[:page]` is not `nil`. This is an improvement over `Calcinator.Resources.Ecto.Repo.Pagination.Ignore` because it will tell callers that `query_options[:page]` will not be honored.
    * `Calcinator.Resources.Ecto.Repo.Pagination.Allow` - All resources with `nil` pagination is returned when `query_options[:page]` is `nil`.  A page of resources with the pagination information is returned when `query_options[:page]` is not `nil`.  **This is the default paginator.**
    * `Calcinator.Resources.Ecto.Repo.Pagination.Require` - An error is returned when `query_options[:page]` is `nil`.  A page of resources with the pagination information is returned when `query_options[:page]` is not `nil`.  This is a stronger form of `Calcinator.Resources.Ecto.Repo.Pagination.Allow` because it forces the caller to declare what page it wants. Using `Calcinator.Resources.Ecto.Repo.Pagination.Require` (or a default and maximum size) is recommended when not paginating would have a detrimental performance impact.
  * `Calcinator.Resources.Page.from_params/1` supports default and maximum page sizes.

    ```eliir
     config :calcinator, Calcinator.Resources.Page, size: [default: 10, maximum: 25]
    ```
  * Update `credo` to `0.8.10` for Elixir 1.6 compatibility.
* [#41](https://github.com/C-S-D/calcinator/pull/41) - [@KronicDeth](https://github.com/KronicDeth)
  * `c:Calcinator.Resources.list/1` from `use Calcinator.Resources.Ecto.Repo` can sort any of attribute of the primary `Ecto.Schema.t` returned by `c:Calcinator.Resources.Ecto.Repo.ecto_schema_module/0`

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

### Bug Fixes
* [#36](https://github.com/C-S-D/calcinator/pull/36) - [@KronicDeth](https://github.com/KronicDeth)
  * Fix Elixir 1.6 GenServer warning about not defining `init/1` explicitly.
* [#37](https://github.com/C-S-D/calcinator/pull/37) - `query_options[:page]` is no longer ignored when passed to `use Calcinator.Resources.Ecto.Repo`'s `list/1` by default.  To restore the old behavior change the paginator to `Calcinator.Resources.Ecto.Repo.Pagination.Ignore`. - [@KronicDeth](https://github.com/KronicDeth)
* [#41](https://github.com/C-S-D/calcinator/pull/41) - add missing `alias Calcinator.Resources.Sorts` to `Calcinator.Resources` to fix `Sorts.t` being unknown - [@KronicDeth](https://github.com/KronicDeth)
* [#43](https://github.com/C-S-D/calcinator/pull/43) - Port [@jeffutter](https://github.com/jeffutter) [#34](https://github.com/C-S-D/calcinator/pull/34) to `insert/3` because similar to `update/3`, `insert/3` was missing a change to expect `changeset/2` to return an `{:ok, changeset} | {:error, reason}` tuple instead of a just a `changeset`. - [@KronicDeth](https://github.com/KronicDeth)

## v5.0.0

### Enhancements
* [#31](https://github.com/C-S-D/calcinator/pull/31) - [@KronicDeth](https://github.com/KronicDeth)
  * `Calcinator` now instruments calls to subsystem with events, similar to `Phoenix` instrumentation.

    | event                      | subsystem                  |
    |----------------------------|----------------------------|
    | `alembic`                  | `Alembic`                  |
    | `calcinator_authorization` | `Calcinator.Authorization` |
    | `calcinator_resources`     | `Calcinator.Resources`     |
    | `calcinator_view`          | `Calcinator.View`          |

    Instrumenters can be configured with

    ```elixir
    config :calcinator,
               instrumenters: [...]
    ```

    * [`pryin`](https://github.com/pryin-io/pryin) instrumentation can be configured following the [`pryin` installation instructions](https://github.com/pryin-io/pryin#installation) and then adding `Calcinator.PryIn.Instrumenter` to your `:calcinator` config

       ```elixir
       config :calcinator,
               :instrumenters: [Calcinator.PryIn.Instrumenter]

    * Custom instrumenters can be created following the docs in `Calcinator.Instrument`
* [#32](https://github.com/C-S-D/calcinator/pull/32) - [@KronicDeth](https://github.com/KronicDeth)
  * Update deps
    * `credo` `0.8.8`
    * `ex_doc` `0.17.1`
    * `ex_machina` `2.1.0`
    * `excoveralls` `0.7.4`
    * `faker` `0.9.0`
    * `junit_formatter` `2.0.0`
    * `uuid` `1.1.8`
* [#33](https://github.com/C-S-D/calcinator/pull/33) - Include the `id` field subject and target structs in `Calcinator.PryIn.Instrumenter` context entries. - [@KronicDeth](https://github.com/KronicDeth)

### Bug Fixes
* [#31](https://github.com/C-S-D/calcinator/pull/31) - The `@typedoc` and `@type` for `Calcinator.t` now has all the current struct fields documented and typed. - [@KronicDeth](https://github.com/KronicDeth)
* [#32](https://github.com/C-S-D/calcinator/pull/32) - [@KronicDeth](https://github.com/KronicDeth)
  * README formatting
    * Consistently use `--` instead of `---` for path marker as `--` becomes em dash in Markdown to HTML conversion
    * Add missing \`\`\` for code blocks.

### Incompatible Changes
* [#31](https://github.com/C-S-D/calcinator/pull/31) - In order to facilitate passing the entire `Calcinator.t` struct to `calcinator_resources` event callbacks in instrumenters, `Calcinator. get(Calcinator.Resources.t, params, id_key :: String.t, Resources.query_options)` has changed to `Calcinator. get(Calcinator.t, params, id_key :: String.t, Resources.query_options)`: The first argument must be the entire `Calcinator.t` struct instead of the `Calcinator.Resources.t` module that was in the `Calcinator.t` `resources_module` field. - [@KronicDeth](https://github.com/KronicDeth)

## v4.0.1

### Bug Fixes
* [#30](https://github.com/C-S-D/calcinator/pull/30) - [@KronicDeth](https://github.com/KronicDeth)
  * `Calcinator.Resources.changeset/1,2` is allowed to get `many_to_many` associations from the backing store, so during testing, this means that the sandbox access must be allowed prior to calling `changeset`.  This was already the case for other actions, but for `create`, `allow_sandbox_access` was not called until the `Ecto.Changeset.t` was authorized and about to be created.

## v4.0.0

### Enhancements
* [#28](https://github.com/C-S-D/calcinator/pull/28) - [@KronicDeth](https://github.com/KronicDeth)
  * `use Calcinator.Resources.Ecto.Repo`'s `changeset/2` will
    1. (New) Preload any `many_to_many` associations that appear in `params`
    2. Cast `params` into `data` using `optional_field/0` and `required_fields/0` of the module
    3. (New) Puts `many_to_many` associations from `params` into changeset. If any ids don't exist, they will generate changeset errors.
    4. Validates changeset with `module` `ecto_schema_module/0` `changeset/0`.
* [#29](https://github.com/C-S-D/calcinator/pull/29) - [@KronicDeth](https://github.com/KronicDeth)
  * Update dependencies
    * `alembic` `3.4.0`
    * `credo` `0.8.6`
    * `ex_doc` `0.16.3`
    * `excoveralls` `07.2`
    * `phoenix` `1.3.0`
  * Use Elixir `1.5.1` for CircleCI build
    * Use `@impl` for callbacks

### Bug Fixes
* [#28](https://github.com/C-S-D/calcinator/pull/28) - [@KronicDeth](https://github.com/KronicDeth)
  * Use `dockerize` to wait for postgres port to open
  * Use `calcinator.ecto.wait` `mix` task to ensure port can receive queries after opening

### Incompatible Changes
* [#28](https://github.com/C-S-D/calcinator/pull/28) - [@KronicDeth](https://github.com/KronicDeth)
  * `Calcinator.Resources.changeset/1,2` return goes from `Ecto.Changeset.t` to `{:ok, Ecto.Changeset.t} | {:error, :ownership}` as `changeset/1,2` will access database to preload, validate ids, and `put_assoc` on `many_to_many` association.  Accessing the database can lead to an ownership error, so `{:error, :ownership}` is necessary.

## v3.0.0

### Enhancements
* [#19](https://github.com/C-S-D/calcinator/pull/19) - [@KronicDeth](https://github.com/KronicDeth)
  * Can now return (and is preferred to return instead of a timeout exit) `{:error, :timeout}` from all `Calcinator.Resources` action `@callbacks`.  The following were added:
    * `Calcinator.Resources.delete/2`
    * `Calcinator.Resources.get/2`
    * `Calcinator.Resources.insert/2`
    * `Calcinator.Resources.update/2`
    * `Calcinator.Resources.update/3`
* [#21](https://github.com/C-S-D/calcinator/pull/21) - [@KronicDeth](https://github.com/KronicDeth)
  * Pass all JSON errors through `Calcinator.Controller.Error.render_json` to eliminate redundant pipelines.
  *  When structs are deleted directly instead of changesets, there's no way to add constraints, such as `no_assoc_constraint` or `assoc_constraint` that would transform DB errors into validation errors, so
     * `Calcinator.delete/3` generate a changeset from `Calcinator.Resources.changeset(struct, %{})`
     * Docs are updated to include tips are using changeset to add constraints
     * The docs for `Calcinator.Resources.changeset/2` is updated so that it states it will be used for both updating (which it was previously) and (now) deleting
  * Comment the expected path in the `get_related_resource` and `show_relationship` examples to makes it easier to remember when `get_related_resource` and `show_relationship` are called.
  * Test reproducible clauses in `Calcinator.Controller` cases (the majority of the bug fixes came from this testing).  [I couldn't remember how to trigger `{:error, :ownership}` and didn't want to fake it since I know I've produced it before because that's why `wrap_ownership_error` exists.]
  * Remove `{:ok, rendered}` duplication in `Calcinator.Controller`
  * Deduplicate `related_property` responses in `Calcinator.Controller`
  * Extract all the error-tuple handling in `Calcinator.Controller` to `Calcinator.Controller.Error.put_calcinator_error` as most clauses were duplicated in the various actions.  This would technically allow some unexpected errors (like `{:error, {:not_found, parameter}}` for create) to be handled, but it is unlikely to cause problems since it will lead to
  `conn` response instead of a `CaseClauseError` as would be the case if some of the clauses were missing as was the case before this PR.
* [#22](https://github.com/C-S-D/calcinator/pull/22) - [@KronicDeth](https://github.com/KronicDeth)
  * Make the `Alembic.Document.t` and `Alembic.Error.t` that `Calcinator.Controller.Error` uses internally available in `Calcinator.Alembic.Document` and `Calcinator.Alembic.Error`, respectively, so they can be reused in overrides and `retort`.
  * Pass `:meta` through `Calcinator.Retort.query_options`, which allows pass through of meta like from `Calcinator.Meta.Beam`, which is necessary for indirect callbacks through RPC calls for `retort`.
  * Move `Calcinator.Meta.Beam` key to module attribute to prevent typos.
  * `Calcinator.Meta.beam.put_new_laz` allows beam information to only be set in `meta` if its not already there to allow for loops between `Calcinator` servers.
* [#23](https://github.com/C-S-D/calcinator/pull/23) - Update to `phoenix` `1.2.4` - [@KronicDeth](https://github.com/KronicDeth)

### Bug Fixes
* [#19](https://github.com/C-S-D/calcinator/pull/19) - [@KronicDeth](https://github.com/KronicDeth)
  * Previously, the `Calcinator` actions (`create/2`, `delete/2`, `get_related_resource/3`, `index/3`, `show/2`, `show_relationship/3`, and `update/2`) `@spec` and `@doc` include (hopefully) all the errors they can return now
    * `{:error, :sandbox_access_disallowed}`
    * `{:error, :sandbox_token_missing}`
    * `{:error, :timeout}`
  * `@callback`s with the same name/arity can only have on `@doc`, so the second form of `Calcinator.Resources.insert/2` did not show up.
  * Change first level of header to `##` to match style guide for ex_doc in `Calcinator.Resources`.
  * Rearrange `Calcinator.Resources.update/2`, so it's before `Calcinator.Resources.update/3` to match doc sorted order.
* [#21](https://github.com/C-S-D/calcinator/pull/21) - [@KronicDeth](https://github.com/KronicDeth)
  * Ensure `Calcinator.Controller` actions have `case` clauses for all the declared return types from `Calcinator` calls.
  * Disable `mix docs` backquote check
  * `get_related_resources` could not handle has_many related resources, specifically
    * `Calcinator.JaSerializer.PhoenixView.get_related_resource/3` would not allow `data` to be a `list`.
    * `Calcinator.RelatedView.render` with data assumes the data was singular and "links" could be added to that "data" map.
    * `Calcinator.authorized` did not allow the unfiltered data to be `list`.
  * Fix `source` `assigns` for `get_related_resource` example: example still used pre-open-sourcing `association` and `id_key`.
  * Fix show_relationship example that was just wrong. The same `assigns` as `get_related_resource` should be used.  Since at first I couldn't figure out why showing a relationship would need a view module and I wrote the code, I added a note explaining its for the `view_module.type/0` callback since relationships are resource identifiers with `id` and `type`.
  * `Calcinator.RelationshipView.data/1` assumed that `[:related][:resource]` was `nil` or a `map`, which didn't handle the `list` for has_many relationships.
* [#22](https://github.com/C-S-D/calcinator/pull/22) - Fix `Calcinator.Alembic.Error.sandbox_token_missing/0` type, which should have returned an `Alembic.Error.t` instead of an `Alembic.Document.t`. - [@KronicDeth](https://github.com/KronicDeth)

### Incompatible Changes
* [#19](https://github.com/C-S-D/calcinator/pull/19) - [@KronicDeth](https://github.com/KronicDeth)
  * `Calcinator.Resources.allow_sandbox_access/1` must now return `:ok | {:error, :sandbox_access_disallowed}`.  The previous `{:already, :allowed | :owner}` maps to `:ok` while `:not_found` maps to `{:error, :sandbox_access_disallowed}`.
  * If you previously had total coverage for all return types from `Calcinator` actions, they now also return `{:error, :sandbox_access_disallowed}` and `{:error, :timeout}`.  Previously, instead of `{:error, :sandbox_access_disallowed}`, `:not_found` may been returned, but that was a bug that leaked an implementation detail from how `DBConnection.Ownership` works, so it was removed.
* [#21](https://github.com/C-S-D/calcinator/pull/21) - [@KronicDeth](https://github.com/KronicDeth)
  * `Calcinator.delete` deletes a changeset instead of a resource struct
    * `Calcinator.Resources.delete/1` must expect an `Ecto.Changeset.t`instead of a resource `struct`
    * `use Calcinator.Resources.Ecto.Repo` generates `delete/1` that expects an `Ecto.Changeset.t` and calls `Calcinator.Resources.Ecto.Repo.delete/2`, which now expects a changeset instead of resource struct as the second argument.
* [#22](https://github.com/C-S-D/calcinator/pull/22) - [@KronicDeth](https://github.com/KronicDeth)
  * `:meta` is now a required key in `Calcinator.Resources.query_options`.
  * `Calcinator.Resources.delete/2` must now accept both the `Ecto.Changeset.t` with any constraints and the `Calcinator.Resources.query_options`, so that the new `meta` key can be used to continue propagating the `Calcinator.Meta.Beam` from the original caller in a chain of calls.

## v2.4.0

### Enhancements

* [#18](https://github.com/C-S-D/calcinator/pull/18) - [@KronicDeth](https://github.com/KronicDeth)
  * JSONAPI filter values that allow multiple values, similar to includes, are comma separated without spaces, instead of having to do `String.split(comma_separated_values, ",")` in all filters that accept multiple values, `Calcinator.Resources.split_filter_value/1` can be used.
  * Pass the final `query` with all filters applied through `distinct(query, true)`, so that filters don't need to ensure they return distinct results, which is an expectation of JSONAPI.

## v2.3.1

### Bug Fixes
* [#17](https://github.com/C-S-D/calcinator/pull/17) - [@KronicDeth](https://github.com/KronicDeth)
  * Guard `Calcinator.Resources.params` and `Calcinator.Resources.query_options` with `is_map/1`
  * Update to `postgrex` `0.13.2` for Elixir `1.5.0-dev` compatibility
  * `Calcinator.Resources.query_options` `:filters` should be a map from filter name to filter value, each being a `String.t` instead of a list single-entry maps because filter names can only be used once and order should not matter.

## v2.3.0

### Enhancements
* [#16](https://github.com/C-S-D/calcinator/pull/16) - `Calcinator.Resources.Ecto.Repo.filter(query, name, value)` is a new optional callback that `use Calcinator.Resources.Ecto.Repo` modules can implement to support filters on the query before `module` `repo` `all` is called. - [@KronicDeth](https://github.com/KronicDeth)

## v2.2.0

### Enhancements
* [#14](https://github.com/C-S-D/calcinator/pull/14) - [@KronicDeth](https://github.com/KronicDeth)
  * Dependency updates
    * `alembic` to `3.2.0`
    * `ex_doc` to `0.15.1`
    * `ja_serializer` to `0.12.0` (but continue compatibility with older versions)
    * `phoenix` to `1.2.3`
    * `credo` to `0.7.3`
  * Add `excoveralls` for coverage tracking
  * Add CircleCI build status badge
  * Add CodeClimate `credo` status badge
  * Add HexFaktor dependencies status badge
  * Add InchEx documentation badge
  * Use Erlang 19.3 and Elixir 1.4.1 on CircleCI

## v2.1.0

### Enhancements
* [#12](https://github.com/C-S-D/calcinator/pull/12) - Regression tests that `%Calcinator{}` default `authorization_module` implements `Calcinator.Authorization` behaviour. - [@KronicDeth](https://github.com/KronicDeth)

### Bug Fixes
* [#12](https://github.com/C-S-D/calcinator/pull/12) - Fix capitalization of `SubjectLess` when used as the `%Calcinator{}` default `authorization_module`. - [@KronicDeth](https://github.com/KronicDeth)

## v2.0.0

### Enhancements
* [#10](https://github.com/C-S-D/calcinator/pull/10) - [@KronicDeth](https://github.com/KronicDeth)
  * Explain why `relationships/2` is overridden in views
  * Routing docs for `get_related_resource` and `show_relationship`
  * Actions and related Authorization docs for `Calcinator.Controller`
  * Use `Ecto.Repo` `config/0` instead of requiring `sandboxed?/0` to be defined.

### Bug Fixes
* [#10](https://github.com/C-S-D/calcinator/pull/10) - [@KronicDeth](https://github.com/KronicDeth)
  * Add missing renames for README controllers
    * `alias InterpreterServerWeb.Controller` -> `alias Calcinator.Controller`
    * `use Controller.Resources,` -> `use Controller,`
  * Replace `use MyApp.Web, :view` with `use JaSerializer.PhoenixView`, so it doesn't require `MyApp.Web.view/0` to include `use JaSerializer.PhoenixView`
  * Renamed second `Author` `Ecto.Schema` modules to `Post`
  * Don't require `user` assign in `Calcinator.Controller`
  * Fix Elixir 1.4 `()` warnings.
* [#11](https://github.com/C-S-D/calcinator/pull/11) - `Code.ensure_loaded?(Phoenix.Controller)` can be used to protect `Calcinator.Controller.Error` and `Calcinator.Controller`, so that it is not defined when its dependency, `Phoenix.Controller` is not available.  Without this change, `(CompileError) lib/calcinator/controller/error.ex:12: module Phoenix.Controller is not loaded and could not be found` is raised in retort. - [@KronicDeth](https://github.com/KronicDeth)

### Incompatible Changes
* [#10](https://github.com/C-S-D/calcinator/pull/10) - Instead of requiring user assign in `Plug.Conn` to get `subject` for `%Calcinator{}`, a private key, `:calcinator_subject`, will be used using `Plug.Conn.put_private`.  The `subject` will be stored using `Calcinator.Controller.put_subject` and retrieved with `Calcinator.Controller.get_subject`.  Calling `put_subject` in a plug is shown in README and `Calcinator.Controller` examples. - [@KronicDeth](https://github.com/KronicDeth)

## v1.7.0

### Enhancements
* [#9](https://github.com/C-S-D/calcinator/pull/9) - Examples for how to `use Calcinator.Resources.Ecto.Repo` in `Calcinator.Resources.Ecto.Repo`'s `@moduledoc` - [@KronicDeth](https://github.com/KronicDeth)

### Bug Fixes
* [#9](https://github.com/C-S-D/calcinator/pull/9) - Add missing `ecto_schema_module/0` callback to `README` example of `use Calcinator.Resources.Ecto.Repo` - [@KronicDeth](https://github.com/KronicDeth)

## v1.6.0

### Enhancements
* [#8](https://github.com/C-S-D/calcinator/pull/8) - [@KronicDeth](https://github.com/KronicDeth)
  * `use Calcinator.Controller` can be used inside a `Phoenix` controller to define JSONAPI actions.
  * `Calcinator.Controller.Error` defines functions for JSONAPI formatted errors that `Calcinator.Controller` may respond with.
  * Document how to use `Calcinator.Controller` to access `Retort.Client.Generic` backed `Calcinator.Resource`
  * Document how to use `Calcinator.Controller` to access `Calcinator.Resources.Ecto.Repo`

## v1.5.1

### Bug Fixes
* [#7](https://github.com/C-S-D/calcinator/pull/7) - `preload(module, queryable, opts)` returns `{:ok, query}` instead of just `query` now. - [@KronicDeth](https://github.com/KronicDeth)

## v1.5.0

### Enhancements
* [#6](https://github.com/C-S-D/calcinator/pull/6) - [@KronicDeth](https://github.com/KronicDeth)
  * Add `{:error, :ownership}` ∀ `Calcinator.Resources` callbacks
  * Add `{:error, :ownership}` ∀ `Calcinator` actions

### Bug Fixes
* [#6](https://github.com/C-S-D/calcinator/pull/6) - Previously `get` and `list` were the only `Calcinator.Resources.Ecto.Repo` functions that converted `DBConnection.OwnershipError` to `{:error, :ownership}`, but the other `Ecto.Repo` calls could also throw the Error, so all calls need to be protected for consistency. - [@KronicDeth](https://github.com/KronicDeth)

## v1.4.0

### Enhancements
* [#4](https://github.com/C-S-D/calcinator/pull/4) - `use Calcinator.Resources.Ecto.Repo` will define the callbacks for `Calcinator.Resources` backed by an `Ecto.Repo`.  The only callbacks that are required then are `ecto_schema_module/0`, `full_associations/1` and `repo/0`. - [@KronicDeth](https://github.com/KronicDeth)
* [#5](https://github.com/C-S-D/calcinator/pull/5) - [@KronicDeth](https://github.com/KronicDeth)
  * Update to `credo` `0.5.3`
  * Update to `ja_serializer` `0.11.2`

## v1.3.0

### Enhancements
* [#3](https://github.com/C-S-D/calcinator/pull/3) - [@KronicDeth](https://github.com/KronicDeth)
  * `Calcinator.Authorization` implementations
    * `Calcinator.Authorization.SubjectLess` allows all `action`s on all `target`s, but only if the passed `subject` is `nil`.  Use it for when you don't actually want authorization checks.
  * Document Steps and Returns of `Calcinator` actions.  Steps make it clearer which parts of `state` are used when.  Returns explain why a given return happens.
  * Document and clarify `Calcinator.Authorization` calling patterns
    * Document each callback with the target shape for each action.
   * Break up the callbacks into multiple signatures for the different call site


### Bug Fixes
* [#3](https://github.com/C-S-D/calcinator/pull/3) - [@KronicDeth](https://github.com/KronicDeth)
  * Add missing related `Calcinator.View` callbacks, `get_related_resource` and `show_relationship`, that are needed for their respective functions in `Calcinator`.
  * Add missing newline at end of file.
  * Remove `argN` arguments in docs by naming arguments in specs
  * Remove extra blank line

## v1.2.0

### Enhancements
* [#2](https://github.com/C-S-D/calcinator/pull/2) - Doctests for `Calcinator.Resources.attribute_to_field/2` - [@KronicDeth](https://github.com/KronicDeth)

### Bug Fixes
* [#2](https://github.com/C-S-D/calcinator/pull/2) - `Calcinator.Resources.attribute_to_field/2` now works with virtual fields. - [@KronicDeth](https://github.com/KronicDeth)

## v1.1.0

### Enhancements
* [#1](https://github.com/C-S-D/calcinator/pull/1) - Expose `attribute_to_field` that was used in `Calcinator.Resources.Sort` as it is useful in other places instead of using `String.to_existing_atom`, which doesn't handle the hyphenation and can fail if the atom hasn't been loaded yet. - [@KronicDeth](https://github.com/KronicDeth)


### Bug Fixes
* [#1](https://github.com/C-S-D/calcinator/pull/1) - [@KronicDeth](https://github.com/KronicDeth)
  * Add missing top-level files to extras:
    * `CHANGELOG.md`
    * `CODE_OF_CONDUCT.md`
    * `CONTRIBUTING.md`
    * `LICENSE.md`
