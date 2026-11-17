defmodule BlogWeb.PostController do
  use BlogWeb, :controller

  import Phoenix.Component, only: [to_form: 1]

  alias Blog.Posts
  alias Blog.Posts.Comment
  alias Blog.Posts.Post

  plug :fetch_and_authorize_post when action in [:edit, :update, :delete]

  def index(conn, _params) do
    posts = Posts.list_posts()
    render(conn, :index, posts: posts)
  end

  def new(conn, _params) do
    changeset = Posts.change_post(%Post{})
    render(conn, :new, form: to_form(changeset))
  end

  def create(conn, %{"post" => post_params}) do
    case Posts.create_post(conn.assigns.current_scope, post_params) do
      {:ok, post} ->
        conn
        |> put_flash(:info, "Post created successfully.")
        |> redirect(to: ~p"/posts/#{post}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, form: to_form(changeset))
    end
  end

  def show(conn, %{"id" => id}) do
    post = Posts.get_post!(id)
    comments = Posts.list_comments(post)
    comment_form = to_form(Posts.change_comment(%Comment{}))

    render(conn, :show,
      post: post,
      comments: comments,
      comment_form: comment_form
    )
  end

  def edit(conn, _params) do
    post = conn.assigns.post
    changeset = Posts.change_post(post)
    render(conn, :edit, post: post, form: to_form(changeset))
  end

  def update(conn, %{"post" => post_params}) do
    post = conn.assigns.post

    case Posts.update_post(post, post_params) do
      {:ok, post} ->
        conn
        |> put_flash(:info, "Post updated successfully.")
        |> redirect(to: ~p"/posts/#{post}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, post: post, form: to_form(changeset))
    end
  end

  def delete(conn, _params) do
    post = conn.assigns.post
    {:ok, _post} = Posts.delete_post(post)

    conn
    |> put_flash(:info, "Post deleted successfully.")
    |> redirect(to: ~p"/posts")
  end

  # Loads the post for management actions and ensures the current user
  # is its author or an admin. Everyone else is redirected away.
  defp fetch_and_authorize_post(conn, _opts) do
    post = Posts.get_post!(conn.params["id"])

    if Posts.can_manage_post?(conn.assigns.current_scope, post) do
      assign(conn, :post, post)
    else
      conn
      |> put_flash(:error, "You are not authorized to manage this post.")
      |> redirect(to: ~p"/posts/#{post}")
      |> halt()
    end
  end
end
