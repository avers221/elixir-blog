defmodule BlogWeb.CommentControllerTest do
  use BlogWeb.ConnCase

  alias Blog.Posts

  import Blog.PostsFixtures
  import Blog.AccountsFixtures

  @comment_attrs %{body: "nice post"}

  describe "create comment" do
    setup :create_post

    test "redirects anonymous visitors to the log-in page", %{conn: conn, post: post} do
      conn = post(conn, ~p"/posts/#{post}/comments", comment: @comment_attrs)
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "adds a comment owned by the logged-in user", %{conn: conn, post: post} do
      user = user_fixture()

      conn =
        conn |> log_in_user(user) |> post(~p"/posts/#{post}/comments", comment: @comment_attrs)

      assert redirected_to(conn) == ~p"/posts/#{post}"

      conn = get(conn, ~p"/posts/#{post}")
      assert html_response(conn, 200) =~ "nice post"
      assert html_response(conn, 200) =~ "Comments (1)"
    end

    test "renders errors when comment data is invalid", %{conn: conn, post: post} do
      conn =
        conn
        |> log_in_user(user_fixture())
        |> post(~p"/posts/#{post}/comments", comment: %{body: nil})

      assert html_response(conn, 200) =~ "Add a comment"
    end
  end

  describe "delete comment" do
    setup :create_post

    test "redirects anonymous visitors to the log-in page", %{conn: conn, post: post} do
      comment = comment_fixture(post)

      conn = delete(conn, ~p"/posts/#{post}/comments/#{comment}")
      assert redirected_to(conn) == ~p"/users/log-in"
      assert Posts.list_comments(post) != []
    end

    test "deletes the comment when its author is logged in", %{conn: conn, post: post} do
      user = user_fixture()
      comment = comment_fixture(post, %{user: user, body: "comment to delete"})

      conn = conn |> log_in_user(user) |> delete(~p"/posts/#{post}/comments/#{comment}")
      assert redirected_to(conn) == ~p"/posts/#{post}"

      conn = get(conn, ~p"/posts/#{post}")
      refute html_response(conn, 200) =~ "comment to delete"
    end

    test "deletes the comment when the post author is logged in", %{conn: conn, post: post} do
      comment = comment_fixture(post, %{body: "comment to delete"})

      conn = conn |> log_in_user(post.user) |> delete(~p"/posts/#{post}/comments/#{comment}")
      assert redirected_to(conn) == ~p"/posts/#{post}"
      assert Posts.list_comments(post) == []
    end

    test "deletes the comment when an admin is logged in", %{conn: conn, post: post} do
      comment = comment_fixture(post, %{body: "comment to delete"})

      conn =
        conn
        |> log_in_user(admin_user_fixture())
        |> delete(~p"/posts/#{post}/comments/#{comment}")

      assert redirected_to(conn) == ~p"/posts/#{post}"
      assert Posts.list_comments(post) == []
    end

    test "rejects other users and keeps the comment", %{conn: conn, post: post} do
      comment = comment_fixture(post, %{body: "comment stays"})

      conn = conn |> log_in_user(user_fixture()) |> delete(~p"/posts/#{post}/comments/#{comment}")

      assert redirected_to(conn) == ~p"/posts/#{post}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not authorized"
      assert Posts.list_comments(post) != []
    end
  end

  defp create_post(_) do
    post = post_fixture(%{title: "some title", body: "some body"})

    %{post: Posts.get_post!(post.id)}
  end
end
