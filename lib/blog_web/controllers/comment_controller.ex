defmodule BlogWeb.CommentController do
  use BlogWeb, :controller

  import Phoenix.Component, only: [to_form: 1]

  alias Blog.Posts

  def create(conn, %{"post_id" => post_id, "comment" => comment_params}) do
    post = Posts.get_post!(post_id)

    case Posts.create_comment(post, comment_params) do
      {:ok, _comment} ->
        conn
        |> put_flash(:info, "Comment added.")
        |> redirect(to: ~p"/posts/#{post}")

      {:error, %Ecto.Changeset{} = changeset} ->
        comments = Posts.list_comments(post)

        conn
        |> put_view(BlogWeb.PostHTML)
        |> render(:show,
          post: post,
          comments: comments,
          comment_form: to_form(changeset)
        )
    end
  end

  def delete(conn, %{"post_id" => post_id, "id" => id}) do
    comment = Posts.get_comment!(id)
    {:ok, _comment} = Posts.delete_comment(comment)

    conn
    |> put_flash(:info, "Comment deleted.")
    |> redirect(to: ~p"/posts/#{post_id}")
  end
end
