defmodule Blog.PostsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Blog.Posts` context.
  """

  @doc """
  Generate a post.
  """
  def post_fixture(attrs \\ %{}) do
    {:ok, post} =
      attrs
      |> Enum.into(%{
        body: "some body",
        title: "some title"
      })
      |> Blog.Posts.create_post()

    post
  end

  @doc """
  Generate a comment for the given post.
  """
  def comment_fixture(post, attrs \\ %{}) do
    {:ok, comment} =
      attrs
      |> Enum.into(%{
        author: "some author",
        body: "some body"
      })
      |> then(&Blog.Posts.create_comment(post, &1))

    comment
  end
end
