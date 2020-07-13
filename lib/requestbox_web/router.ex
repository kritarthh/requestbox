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

  pipeline :api_auth do
    plug(:basic_auth, Application.compile_env(:requestbox, :basic_auth))
  end

  scope "/v1", RequestboxWeb do
    pipe_through([:api_auth, :parsers, :browser])

    get("/", SessionController, :index)
    post("/", SessionController, :create)

    get("/:id", SessionController, :show)
  end

  scope "/api/v1", RequestboxWeb do
    pipe_through([:api_auth, :parsers])

    scope "/" do
      # create a new session without file
      post("/", SessionController, :api)
      delete("/:id", SessionController, :delete)
    end
  end

  scope "/api/v1", RequestboxWeb do
    pipe_through(:parsers)

    scope "/bin" do
      scope "/:session_id" do
        # get all requests
        get("/requests", SessionController, :fetch_all)

        # save all get, post and put requests
        forward("/", RequestController)
        get("/", RequestController, nil)
        post("/", RequestController, nil)
        put("/", RequestController, nil)
      end
    end
  end
end
