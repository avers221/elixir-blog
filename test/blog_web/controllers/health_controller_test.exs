defmodule BlogWeb.HealthControllerTest do
  use BlogWeb.ConnCase

  test "returns healthy when the database is available", %{conn: conn} do
    conn = get(conn, ~p"/health")

    assert response(conn, 200) == "ok\n"
    assert get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]
  end
end
