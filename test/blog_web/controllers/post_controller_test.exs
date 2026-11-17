defmodule BlogWeb.PostControllerTest do
  use BlogWeb.ConnCase

  alias Blog.Posts

  import Blog.PostsFixtures
  import Blog.AccountsFixtures

  @create_attrs %{title: "some title", body: "some body"}
  @update_attrs %{title: "some updated title", body: "some updated body"}
  @invalid_attrs %{title: nil, body: nil}

  describe "index" do
    test "lists all posts publicly", %{conn: conn} do
      _post = post_fixture()
      conn = get(conn, ~p"/posts")
      assert html_response(conn, 200) =~ "Latest stories"
      assert html_response(conn, 200) =~ "some title"
    end

    test "shows empty state when there are no posts", %{conn: conn} do
      conn = get(conn, ~p"/posts")
      assert html_response(conn, 200) =~ "No stories yet"
    end

    test "hides the write link for anonymous visitors", %{conn: conn} do
      conn = get(conn, ~p"/posts")
      refute html_response(conn, 200) =~ ~p"/posts/new"
    end

    test "shows the write link for logged-in users", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture()) |> get(~p"/posts")
      assert html_response(conn, 200) =~ "Write a story"
      assert html_response(conn, 200) =~ ~p"/posts/new"
    end
  end

  describe "show" do
    setup :create_post

    test "renders post publicly", %{conn: conn, post: post} do
      conn = get(conn, ~p"/posts/#{post}")
      assert html_response(conn, 200) =~ "some title"
    end

    test "hides Edit and Delete for visitors who cannot manage the post", %{
      conn: conn,
      post: post
    } do
      conn = get(conn, ~p"/posts/#{post}")
      refute html_response(conn, 200) =~ "Edit"
      refute html_response(conn, 200) =~ "Delete"
    end

    test "shows Edit and Delete for the author", %{conn: conn, post: post} do
      conn =
        conn |> log_in_user(post.user) |> get(~p"/posts/#{post}")

      assert html_response(conn, 200) =~ "Edit"
      assert html_response(conn, 200) =~ "Delete"
    end

    test "shows Edit and Delete for an admin", %{conn: conn, post: post} do
      conn = conn |> log_in_user(admin_user_fixture()) |> get(~p"/posts/#{post}")
      assert html_response(conn, 200) =~ "Edit"
      assert html_response(conn, 200) =~ "Delete"
    end
  end

  describe "new post" do
    test "redirects anonymous visitors to the log-in page", %{conn: conn} do
      conn = get(conn, ~p"/posts/new")
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "renders form for logged-in users", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture()) |> get(~p"/posts/new")
      assert html_response(conn, 200) =~ ~s(id="post-form")
    end
  end

  describe "create post" do
    test "redirects anonymous visitors to the log-in page", %{conn: conn} do
      conn = post(conn, ~p"/posts", post: @create_attrs)
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "creates a post owned by the logged-in user and redirects to show", %{conn: conn} do
      user = user_fixture()
      conn = conn |> log_in_user(user) |> post(~p"/posts", post: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/posts/#{id}"

      conn = get(conn, ~p"/posts/#{id}")
      assert html_response(conn, 200) =~ "some title"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture()) |> post(~p"/posts", post: @invalid_attrs)
      assert html_response(conn, 200) =~ "Write a story"
    end
  end

  describe "edit post" do
    setup [:create_post]

    test "renders form for the author", %{conn: conn, post: post} do
      conn = conn |> log_in_user(post.user) |> get(~p"/posts/#{post}/edit")
      assert html_response(conn, 200) =~ "Edit story"
    end

    test "renders form for an admin", %{conn: conn, post: post} do
      conn = conn |> log_in_user(admin_user_fixture()) |> get(~p"/posts/#{post}/edit")
      assert html_response(conn, 200) =~ "Edit story"
    end

    test "redirects anonymous visitors to the log-in page", %{conn: conn, post: post} do
      conn = get(conn, ~p"/posts/#{post}/edit")
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "redirects other users back to the post with an error flash", %{conn: conn, post: post} do
      conn = conn |> log_in_user(user_fixture()) |> get(~p"/posts/#{post}/edit")

      assert redirected_to(conn) == ~p"/posts/#{post}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not authorized"
    end
  end

  describe "update post" do
    setup [:create_post]

    test "updates the post when the author is logged in", %{conn: conn, post: post} do
      conn = conn |> log_in_user(post.user) |> put(~p"/posts/#{post}", post: @update_attrs)
      assert redirected_to(conn) == ~p"/posts/#{post}"

      conn = get(conn, ~p"/posts/#{post}")
      assert html_response(conn, 200) =~ "some updated title"
    end

    test "updates the post when an admin is logged in", %{conn: conn, post: post} do
      conn =
        conn |> log_in_user(admin_user_fixture()) |> put(~p"/posts/#{post}", post: @update_attrs)

      assert redirected_to(conn) == ~p"/posts/#{post}"

      assert Posts.get_post!(post.id).title == "some updated title"
    end

    test "renders errors when data is invalid", %{conn: conn, post: post} do
      conn = conn |> log_in_user(post.user) |> put(~p"/posts/#{post}", post: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit story"
    end

    test "redirects anonymous visitors to the log-in page", %{conn: conn, post: post} do
      conn = put(conn, ~p"/posts/#{post}", post: @update_attrs)
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "rejects other users and keeps the post unchanged", %{conn: conn, post: post} do
      conn = conn |> log_in_user(user_fixture()) |> put(~p"/posts/#{post}", post: @update_attrs)

      assert redirected_to(conn) == ~p"/posts/#{post}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not authorized"
      assert Posts.get_post!(post.id).title == "some title"
    end
  end

  describe "delete post" do
    setup [:create_post]

    test "deletes chosen post when the author is logged in", %{conn: conn, post: post} do
      conn = conn |> log_in_user(post.user) |> delete(~p"/posts/#{post}")
      assert redirected_to(conn) == ~p"/posts"

      assert_raise Ecto.NoResultsError, fn ->
        get(conn, ~p"/posts/#{post}")
      end
    end

    test "deletes chosen post when an admin is logged in", %{conn: conn, post: post} do
      conn = conn |> log_in_user(admin_user_fixture()) |> delete(~p"/posts/#{post}")
      assert redirected_to(conn) == ~p"/posts"

      assert_raise Ecto.NoResultsError, fn ->
        get(conn, ~p"/posts/#{post}")
      end
    end

    test "redirects anonymous visitors to the log-in page", %{conn: conn, post: post} do
      conn = delete(conn, ~p"/posts/#{post}")
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "rejects other users and keeps the post", %{conn: conn, post: post} do
      conn = conn |> log_in_user(user_fixture()) |> delete(~p"/posts/#{post}")

      assert redirected_to(conn) == ~p"/posts/#{post}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not authorized"
      assert Posts.get_post!(post.id).id == post.id
    end
  end

  defp create_post(_) do
    post = post_fixture(%{title: "some title", body: "some body"})

    %{post: Posts.get_post!(post.id)}
  end
end
