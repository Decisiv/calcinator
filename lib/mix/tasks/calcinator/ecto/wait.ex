if Code.ensure_loaded?(Ecto.Adapters.Postgres.Connection) do
  defmodule Mix.Tasks.Calcinator.Ecto.Wait do
    @moduledoc """
    Waits for connection to work to the given repository.

    The repositry must be set under `:ecto_repos` in the
    current app configuration.

    ## Example

        mix do calcinator.ecto.wait, ecto.create

    """

    use Mix.Task

    require Ecto.Query
    require Logger

    import Mix.Ecto

    @shortdoc "Waits for database to be ready"
    @recursive true

    # Constats

    # ms
    @wait_for_connection_sleep 5_000

    # Functions

    @doc false
    def run(args) do
      args
      |> parse_repo()
      |> Enum.each(fn repo ->
        ensure_repo(repo, args)

        ensure_implements(
          repo.__adapter__,
          Ecto.Adapter.Storage,
          "to connect to storage for #{inspect(repo)}"
        )

        wait_for_connection(repo.config)
      end)
    end

    ## Private Functions

    defp connect(opts) do
      {:ok, _} = Application.ensure_all_started(:postgrex)

      opts =
        opts
        |> Keyword.drop([:name, :log])
        |> Keyword.put(:database, "postgres")
        |> Keyword.put(:pool, DBConnection.Connection)

      {:ok, conn} = Postgrex.start_link(opts)

      value =
        try do
          # repo.all(Ecto.Query.from(a in "pg_stat_activity", select: a.pid))
          Ecto.Adapters.Postgres.Connection.execute(conn, "SELECT * FROM pg_stat_activity", [], opts)
        rescue
          DBConnection.ConnectionError ->
            :error
        else
          _ ->
            :ok
        end

      GenServer.stop(conn)

      value
    end

    defp wait_for_connection(opts) do
      with :error <- connect(opts) do
        Logger.warn(fn ->
          [
            "Could not connect.  Retrying in ",
            @wait_for_connection_sleep
            |> div(1000)
            |> to_string(),
            " seconds."
          ]
        end)

        Process.sleep(@wait_for_connection_sleep)

        wait_for_connection(opts)
      end
    end
  end
end
