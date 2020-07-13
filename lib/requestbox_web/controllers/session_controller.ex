defmodule RequestboxWeb.SessionController do
  use Requestbox.Web, :controller

  use Requestbox.HashID

  alias Requestbox.Request
  alias Requestbox.Session
  alias Requestbox.Vanity
  alias Ecto.Multi

  plug(:scrub_params, "session" when action in [:create, :update])

  def index(conn, _params) do
    changeset = Session.changeset(%Session{})
    render(conn, :index, changeset: changeset)
  end

  def api(conn, _params) do
    changeset = Session.changeset(%Session{}, %{})

    case Repo.insert(changeset) do
      {:ok, session} -> conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{name: conn.request_path <> RequestboxWeb.SessionController.encode(session.id)}))
      _ -> conn
      |> put_resp_content_type("application/json")
      |> send_resp(500, Jason.encode!(%{error: "cannot create session"}))
    end
  end

  def create(conn, %{"session" => params}) do
    file = params["file"]

    session_params = if file != nil do
      Map.take(params, [:token])
      |> Map.put_new(:name, file.filename)
    else
      params
    end

    session_changeset = Session.changeset(%Session{}, session_params)

    multi =
      Multi.new
      |> Multi.insert(:session, session_changeset)
      |> Multi.run(:vanity, fn %{session: session} ->
      vanity_changeset =
        %Vanity{session_id: session.id}
        |> Vanity.changeset(session_params)
      Repo.insert(vanity_changeset)
    end)

    case Repo.transaction(multi) do
      {:ok, result} ->
        if file != nil do
          path = Application.get_env(:requestbox, :root_dir) <> conn.request_path <> "/" <> file.filename
          File.mkdir_p!(Path.dirname(path))
          File.cp(file.path, path)
        end
        conn
        |> redirect(to: Routes.session_path(conn, :show, result.session))
      {:error, :session, _changeset, %{}} ->
        conn
        |> put_flash(:error, "Failed to create session")
        |> redirect(to: Routes.session_path(conn, :index))
      {:error, :vanity, _changeset, %{}} ->
        conn
        |> put_flash(:error, "Failed to create vanity")
        |> redirect(to: Routes.session_path(conn, :index))
    end

  end

  def show(conn, %{"id" => id}) do
    conn = conn |> fetch_query_params
    session = Session.find_session(id)
    render_session(conn, session)
  end

  def delete(conn, %{"id" => id}) do
    conn = conn |> fetch_query_params
    session = Session.find_session(id)
    if session != nil do
      Repo.delete!(session)
    end
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "deleted")
  end

  def fetch_all(conn, %{"session_id" => id}) do
    conn = conn |> fetch_query_params
    session = Session.find_session(id)

    requests = Request.sorted()
    |> where([r], r.session_id == ^session.id)
    |> Repo.all
    |> Jason.encode!
    |> Jason.decode!

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, Enum.reduce(requests, "", fn(x, acc) -> "[#{Jason.encode!(x)}]\n#{acc}" end))
  end

  def get_urls(conn, session) do
    vanity = Vanity
    |> where([v], v.session_id == ^session.id)
    |> Repo.all
    |> Enum.map(fn v -> v.name end)
    |> Enum.join(",")

    root_path = String.replace(Routes.request_url(conn, nil, session), Routes.request_path(conn, nil, session), "")
    session_orig_path = String.replace(Routes.request_path(conn, nil, session), root_path, "")

    Routes.request_url(conn, nil, session) <> "," <> String.replace(Routes.request_url(conn, nil, session), session_orig_path, "/api/v1/bin/#{vanity}")
  end

  defp render_session(conn, %Session{} = session) do
    page =
      Request.sorted()
      |> where([r], r.session_id == ^session.id)
      |> Repo.paginate(conn.query_params)

    render(conn, "show.html", session: session, page: page)
  end

  defp render_session(conn, nil) do
    conn
    |> put_status(:not_found)
    |> render(RequestboxWeb.ErrorView, "404.html")
  end
end
