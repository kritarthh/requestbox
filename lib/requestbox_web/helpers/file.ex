defmodule RequestboxWeb.Helpers.Files do
  require Logger

  def action(conn, body) do
    case conn.method do
      m when m in ["GET", "POST", "PUT", "PATCH", "DELETE"] -> serve_file(conn)
      # "PUT" -> put_file(conn, body)
      _ -> {405, "Method not allowed. Allowed methods: [GET, POST, PUT]"}
    end
  end

  defp serve_file(conn) do
    path = Application.get_env(:requestbox, :root_dir) <> "/" <> Enum.join(Enum.drop(conn.script_name, 1) |> List.delete_at(-2) , "/")
    Logger.debug fn -> "#{conn.method} path #{path}" end

    if File.exists?(path) do
      resp = if File.dir?(path) do
        # return ls of the requested path
        :os.cmd('ls -AF #{path}')
      else
        # return the requested file
        path |> File.read!()
      end
      {200, resp}
    else
      {404, "404 - Not Found"}
    end
  end

  defp put_file(conn, body) do
    # 9_000_000_000 bytes == 8583 mb, is our maximum body size
    path = Application.get_env(:requestbox, :root_dir) <> conn.request_path
    Logger.debug fn -> "PUT file to path #{path}" end

    # create subdirs if needed
    File.mkdir_p!(Path.dirname(path))

    # create uploaded file
    case File.write(path, body) do
      {:error, reason} -> {500, "Unable to write file: {:error, #{reason}}"}
      :ok -> {200, "File uploaded"}
    end
  end

  defmacro __using__(_) do
    quote do: import(RequestboxWeb.Helpers.Files)
  end
end
