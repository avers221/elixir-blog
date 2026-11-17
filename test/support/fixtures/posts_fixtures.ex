defmodule Blog.PostsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Blog.Posts` context.
  """

  alias Blog.Accounts.Scope

  @doc """
  Generate a post. Accepts an optional `:user` in attrs; a fresh test
  user is created when none is given.
  """
  def post_fixture(attrs \\ %{}) do
    {user, attrs} = Map.pop(attrs, :user)
    user = user || Blog.AccountsFixtures.user_fixture()

    {:ok, post} =
      Enum.into(attrs, %{
        body: "some body",
        title: "some title"
      })
      |> then(&Blog.Posts.create_post(Scope.for_user(user), &1))

    post
  end

  @doc """
  Generate a comment for the given post. Accepts an optional `:user`
  in attrs; a fresh test user is created when none is given.
  """
  def comment_fixture(post, attrs \\ %{}) do
    {user, attrs} = Map.pop(attrs, :user)
    user = user || Blog.AccountsFixtures.user_fixture()

    {:ok, comment} =
      Enum.into(attrs, %{
        body: "some body"
      })
      |> then(&Blog.Posts.create_comment(Scope.for_user(user), post, &1))

    comment
  end
end
