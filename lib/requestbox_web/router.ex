defmodule RequestboxWeb.Helpers.CacheBodyReader do
  def read_body(conn, opts) do
    if conn.method != "PUT" do
      {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
      conn = update_in(conn.assigns[:raw_body], &[body | (&1 || [])])
      {:ok, body, conn}
    else
      {:ok, "", conn}
    end
  end
end

defmodule RequestboxWeb.Router do
  use Requestbox.Web, :router


  pipeline :browser do
    plug(Plug.MethodOverride)

    plug(
      Plug.Session,
      store: :cookie,
      key: Application.fetch_env!(:requestbox, :session_key),
      signing_salt: "i8W95jtn"
    )

    plug(:accepts, ~w(html json))
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :parsers do
    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      body_reader: {RequestboxWeb.Helpers.CacheBodyReader, :read_body, []},
      json_decoder: Jason
    )
  end


  pipeline :api do
    plug(
      Plug.Parsers,
      parsers: [:json, Absinthe.Plug.Parser],
      json_decoder: Jason
    )

    plug(Plug.Head)

    plug(:accepts, ["json"])
  end

  scope "/", RequestboxWeb do
    pipe_through([:parsers, :browser])

    get("/", SessionController, :index)
    post("/", SessionController, :create)
  end

  scope "/", RequestboxWeb do
    pipe_through(:browser)
    get("/:id", SessionController, :show)
    post("/:id", SessionController, :show)
  end

  scope "/", RequestboxWeb do
    delete("/:id", SessionController, :delete)
  end

  scope "/api/v1/bins", RequestboxWeb do
    match(:post, "/", SessionController, :api)

    pipe_through(:browser)
    match(:get, "/:id", SessionController, :show)
  end

  scope "/api/v1/:session_id", RequestboxWeb do
    # Hack a helper for this route
    match(:get, "/requests", SessionController, :fetch_all)
    match(:post, "/requests", SessionController, :fetch_all)

    pipe_through(:parsers)
    forward("/", RequestController)
    match(:get, "/", RequestController, nil)
    match(:post, "/", RequestController, nil)
  end

  scope "/api" do
    pipe_through(:api)

    forward("/graphiql", Absinthe.Plug.GraphiQL,
      schema: RequestboxWeb.Schema,
      interface: :playground
    )

    forward("/", Absinthe.Plug, schema: RequestboxWeb.Schema)
  end
end
