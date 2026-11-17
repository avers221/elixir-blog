defmodule Blog.Posts do
  @moduledoc """
  The Posts context.
  """

  import Ecto.Query, warn: false
  alias Blog.Repo

  alias Blog.Accounts.Scope
  alias Blog.Accounts.User
  alias Blog.Posts.Post
  alias Blog.Posts.Comment

  @doc """
  Returns the list of posts, newest first, with authors preloaded.

  ## Examples

      iex> list_posts()
      [%Post{}, ...]

  """
  def list_posts do
    Repo.all(from(p in Post, order_by: [desc: p.inserted_at, desc: p.id], preload: [:user]))
  end

  @doc """
  Gets a single post with its author preloaded.

  Raises `Ecto.NoResultsError` if the Post does not exist.

  ## Examples

      iex> get_post!(123)
      %Post{}

      iex> get_post!(456)
      ** (Ecto.NoResultsError)

  """
  def get_post!(id), do: Post |> Repo.get!(id) |> Repo.preload(:user)

  @doc """
  Creates a post owned by the user in the given scope.

  ## Examples

      iex> create_post(scope, %{field: value})
      {:ok, %Post{}}

      iex> create_post(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_post(%Scope{user: %User{} = user}, attrs) do
    %Post{user_id: user.id}
    |> Post.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a post.

  ## Examples

      iex> update_post(post, %{field: new_value})
      {:ok, %Post{}}

      iex> update_post(post, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a post.

  ## Examples

      iex> delete_post(post)
      {:ok, %Post{}}

      iex> delete_post(post)
      {:error, %Ecto.Changeset{}}

  """
  def delete_post(%Post{} = post) do
    Repo.delete(post)
  end

  @doc """
  Checks whether the scope's user may edit or delete the post.

  Only the post author or an admin can manage a post.
  """
  def can_manage_post?(%Scope{user: %User{} = user}, %Post{} = post) do
    post.user_id == user.id or User.admin?(user)
  end

  def can_manage_post?(_scope, _post), do: false

  @doc """
  Checks whether the scope's user may delete the comment.

  The comment author, the post author and admins can delete a comment.
  """
  def can_delete_comment?(%Scope{user: %User{} = user}, %Comment{} = comment, %Post{} = post) do
    comment.user_id == user.id or post.user_id == user.id or User.admin?(user)
  end

  def can_delete_comment?(_scope, _comment, _post), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.

  ## Examples

      iex> change_post(post)
      %Ecto.Changeset{data: %Post{}}

  """
  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end

  @doc """
  Returns the list of comments for a post, oldest first, with authors preloaded.

  ## Examples

      iex> list_comments(post)
      [%Comment{}, ...]

  """
  def list_comments(%Post{} = post) do
    Repo.all(
      from(c in Comment,
        where: c.post_id == ^post.id,
        order_by: [asc: c.inserted_at, asc: c.id],
        preload: [:user]
      )
    )
  end

  @doc """
  Gets a single comment.

  Raises `Ecto.NoResultsError` if the Comment does not exist.
  """
  def get_comment!(id), do: Repo.get!(Comment, id)

  @doc """
  Creates a comment attached to the given post, owned by the scope's user.

  ## Examples

      iex> create_comment(scope, post, %{body: "nice post"})
      {:ok, %Comment{}}

  """
  def create_comment(%Scope{user: %User{} = user}, %Post{} = post, attrs) do
    %Comment{post_id: post.id, user_id: user.id}
    |> Comment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a comment.
  """
  def delete_comment(%Comment{} = comment) do
    Repo.delete(comment)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking comment changes.
  """
  def change_comment(%Comment{} = comment, attrs \\ %{}) do
    Comment.changeset(comment, attrs)
  end
end
