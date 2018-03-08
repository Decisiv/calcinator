defmodule Calcinator.JaSerializer.PhoenixView do
  @moduledoc """
  An adapter between `JaSerializer.PhoenixView` modules and `Calcinator.View`
  """

  alias Alembic.Fetch.Includes
  alias Alembic.Pagination
  alias JaSerializer.Formatter.Utils
  alias Plug.Conn

  # Constants

  @render_opts ~w(fields include)a

  # Macros

  defmacro __using__(opts) when is_list(opts) do
    phoenix_view_module = Keyword.fetch!(opts, :phoenix_view_module)

    quote bind_quoted: [
            phoenix_view_module: phoenix_view_module
          ],
          location: :keep do
      alias Calcinator.JaSerializer.PhoenixView

      # Behaviours

      @behaviour Calcinator.View

      # Functions

      ## Calcinator.View callbacks

      @impl Calcinator.View
      def get_related_resource(data, options) do
        PhoenixView.get_related_resource(unquote(phoenix_view_module), data, options)
      end

      @impl Calcinator.View
      def index(data, options), do: PhoenixView.index(unquote(phoenix_view_module), data, options)

      @impl Calcinator.View
      def show(data, options), do: PhoenixView.show(unquote(phoenix_view_module), data, options)

      @impl Calcinator.View
      def show_relationship(data, options),
        do: PhoenixView.show_relationship(unquote(phoenix_view_module), data, options)
    end
  end

  # Functions

  def get_related_resource(phoenix_view_module, data, options = %{related: related, source: source})
      when is_list(data) or is_map(data) or is_nil(data) do
    params = Map.get(options, :params, %{})
    subject = Map.get(options, :subject, nil)
    opts = params_to_render_opts(params)

    phoenix_view_module.render("get_related_resource.json-api", %{
      conn: %Conn{
        assigns: %{
          subject: subject
        }
      },
      data: data,
      opts: opts,
      params: params,
      related: related,
      source: source
    })
  end

  def index(phoenix_view_module, data, options) do
    pagination = Map.get(options, :pagination, nil)
    params = Map.get(options, :params, %{})
    subject = Map.get(options, :subject, nil)

    opts =
      []
      |> Keyword.merge(params_to_render_opts(params))
      |> Keyword.merge(pagination_to_render_opts(pagination, options))

    # Only `:conn` option is passed to `attributes/2` callback, so have to fake `%Plug.Conn{}`
    phoenix_view_module.render(
      "show.json-api",
      conn: %Conn{
        assigns: %{
          subject: subject
        }
      },
      data: data,
      opts: opts
    )
  end

  def show(phoenix_view_module, data = %_{}, options) do
    params = Map.get(options, :params, %{})
    subject = Map.get(options, :subject, nil)
    opts = params_to_render_opts(params)

    phoenix_view_module.render(
      "show.json-api",
      conn: %Conn{
        assigns: %{
          subject: subject
        }
      },
      data: data,
      opts: opts
    )
  end

  def show_relationship(phoenix_view_module, data, options = %{related: related, source: source}) do
    params = Map.get(options, :params, %{})
    subject = options.calcinator.subject
    opts = params_to_render_opts(params)

    phoenix_view_module.render("show_relationship.json-api", %{
      conn: %Conn{
        assigns: %{
          subject: subject
        }
      },
      data: data,
      opts: opts,
      params: params,
      related: related,
      source: source
    })
  end

  ## Private Functions

  defp associations_to_includes(associations) when is_list(associations) do
    Enum.map(associations, &associations_to_includes/1)
  end

  defp associations_to_includes({parent, child}) do
    %{associations_to_includes(parent) => associations_to_includes(child)}
  end

  defp associations_to_includes(association) when is_atom(association) do
    Utils.format_key(association)
  end

  defp links_to_render_opts_page(links) when is_map(links) do
    Enum.into(links, %{}, fn {string_key, value} ->
      {String.to_existing_atom(string_key), value}
    end)
  end

  defp pagination_to_render_opts(nil, _), do: []

  defp pagination_to_render_opts(pagination, options) do
    []
    |> Keyword.merge(pagination_to_render_opts_meta(pagination))
    |> Keyword.merge(pagination_to_render_opts_page(pagination, options))
  end

  defp pagination_to_render_opts_meta(%Pagination{total_size: record_count}) do
    [
      meta: %{
        "record-count" => record_count
      }
    ]
  end

  defp pagination_to_render_opts_page(pagination, %{
         base_uri: base_uri,
         calcinator: calcinator,
         query_options: query_options
       }) do
    render_opts_page =
      pagination
      |> Pagination.to_links(base_uri)
      |> append_query_options_to_links(query_options, calcinator)
      |> links_to_render_opts_page

    [page: render_opts_page]
  end

  defp append_query_options_to_links(links, query_options, calcinator) do
    encoded_query =
      query_options
      |> query_options_to_decoded_query(calcinator)
      |> URI.encode_query()

    Enum.into(links, %{}, fn {name, value} -> {name, "#{value}&#{encoded_query}"} end)
  end

  defp query_option_to_decoded_query({:associations, association_or_associations}, _) do
    association_or_associations
    |> List.wrap()
    |> case do
      [] ->
        %{}

      associations ->
        include_value =
          associations
          |> associations_to_includes()
          |> Includes.to_string()

        %{"include" => include_value}
    end
  end

  defp query_option_to_decoded_query({:filters, filters}, _) do
    Enum.into(filters, %{}, fn {name, value} -> {"filter[#{name}]", value} end)
  end

  defp query_option_to_decoded_query({:meta, meta}, _) do
    Enum.into(meta, %{}, fn {name, value} -> {"meta[#{name}]", value} end)
  end

  # handled by Pagination.to_links
  defp query_option_to_decoded_query({:page, _}, _), do: %{}

  defp query_option_to_decoded_query({:sorts, sorts}, %Calcinator{resources_module: resources_module}) do
    {:ok, alembic_fetch_sorts} = Calcinator.Resources.Sorts.to_alembic_fetch_sorts(sorts, resources_module)
    sort_value = Alembic.Fetch.Sorts.to_string(alembic_fetch_sorts)

    case sort_value do
      "" -> %{}
      _ -> %{"sort" => sort_value}
    end
  end

  defp query_options_to_decoded_query(query_options, configuration) do
    Enum.reduce(query_options, %{}, fn query_option, acc ->
      Map.merge(acc, query_option_to_decoded_query(query_option, configuration))
    end)
  end

  defp params_to_render_opts(nil), do: []

  defp params_to_render_opts(params) when is_map(params) do
    # must only add opts if in params so that defaults don't get overridden
    Enum.reduce(@render_opts, [], fn render_opts_key, render_opts ->
      case Map.fetch(params, to_string(render_opts_key)) do
        {:ok, render_opts_value} -> [{render_opts_key, render_opts_value} | render_opts]
        :error -> render_opts
      end
    end)
  end
end
