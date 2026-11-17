defmodule BlogWeb.HealthController do
  use BlogWeb, :controller

  def show(conn, _params) do
    result = Blog.Repo.query("SELECT 1")

    case result do
      {:ok, _result} -> send_status(conn, :ok, "ok\n")
      {:error, _error} -> send_status(conn, :service_unavailable, "unavailable\n")
    end
  rescue
    DBConnection.ConnectionError -> send_status(conn, :service_unavailable, "unavailable\n")
  end

  defp send_status(conn, status, body) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(status, body)
  end
end
