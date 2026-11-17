defmodule Blog.PostsTest do
  use Blog.DataCase

  alias Blog.Posts

  describe "posts" do
    alias Blog.Posts.Post

    import Blog.PostsFixtures

    @invalid_attrs %{title: nil, body: nil}

    test "list_posts/0 returns all posts" do
      post = post_fixture()
      assert Posts.list_posts() == [post]
    end

    test "list_posts/0 orders posts newest first" do
      _old = post_fixture(%{title: "old post"})
      _new = post_fixture(%{title: "new post"})

      assert [%Post{title: "new post"}, %Post{title: "old post"}] =
               Posts.list_posts()
    end

    test "get_post!/1 returns the post with given id" do
      post = post_fixture()
      assert Posts.get_post!(post.id) == post
    end

    test "create_post/1 with valid data creates a post" do
      valid_attrs = %{title: "some title", body: "some body"}

      assert {:ok, %Post{} = post} = Posts.create_post(valid_attrs)
      assert post.title == "some title"
      assert post.body == "some body"
    end

    test "create_post/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Posts.create_post(@invalid_attrs)
    end

    test "update_post/2 with valid data updates the post" do
      post = post_fixture()
      update_attrs = %{title: "some updated title", body: "some updated body"}

      assert {:ok, %Post{} = post} = Posts.update_post(post, update_attrs)
      assert post.title == "some updated title"
      assert post.body == "some updated body"
    end

    test "update_post/2 with invalid data returns error changeset" do
      post = post_fixture()
      assert {:error, %Ecto.Changeset{}} = Posts.update_post(post, @invalid_attrs)
      assert post == Posts.get_post!(post.id)
    end

    test "delete_post/1 deletes the post" do
      post = post_fixture()
      assert {:ok, %Post{}} = Posts.delete_post(post)
      assert_raise Ecto.NoResultsError, fn -> Posts.get_post!(post.id) end
    end

    test "change_post/1 returns a post changeset" do
      post = post_fixture()
      assert %Ecto.Changeset{} = Posts.change_post(post)
    end
  end

  describe "comments" do
    alias Blog.Posts.Comment

    import Blog.PostsFixtures

    @invalid_comment_attrs %{body: nil}
    @valid_comment_attrs %{author: "some author", body: "some body"}

    test "list_comments/1 returns post comments oldest first" do
      post = post_fixture()
      _second = comment_fixture(post, %{body: "second"})
      _first = comment_fixture(post, %{body: "first"})

      assert [%Comment{body: "second"}, %Comment{body: "first"}] =
               Posts.list_comments(post)
    end

    test "list_comments/1 does not return comments of other posts" do
      post = post_fixture()
      other_post = post_fixture(%{title: "other"})
      comment_fixture(post)

      assert Posts.list_comments(other_post) == []
    end

    test "create_comment/2 with valid data creates a comment" do
      post = post_fixture()

      assert {:ok, %Comment{} = comment} =
               Posts.create_comment(post, @valid_comment_attrs)

      assert comment.author == "some author"
      assert comment.body == "some body"
      assert comment.post_id == post.id
    end

    test "create_comment/2 allows nil author" do
      post = post_fixture()

      assert {:ok, %Comment{author: nil}} =
               Posts.create_comment(post, %{body: "anonymous"})
    end

    test "create_comment/2 with invalid data returns error changeset" do
      post = post_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Posts.create_comment(post, @invalid_comment_attrs)
    end

    test "delete_comment/1 deletes the comment" do
      post = post_fixture()
      comment = comment_fixture(post)

      assert {:ok, %Comment{}} = Posts.delete_comment(comment)
      assert Posts.list_comments(post) == []
    end

    test "change_comment/1 returns a comment changeset" do
      post = post_fixture()
      comment = comment_fixture(post)
      assert %Ecto.Changeset{} = Posts.change_comment(comment)
    end
  end
end
