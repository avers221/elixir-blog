defmodule Blog.PostsTest do
  use Blog.DataCase

  alias Blog.Posts

  describe "posts" do
    alias Blog.Posts.Post

    import Blog.PostsFixtures
    import Blog.AccountsFixtures

    @invalid_attrs %{title: nil, body: nil}

    test "list_posts/0 returns all posts with authors preloaded" do
      post = post_fixture()

      assert [%Post{title: "some title", user: %Blog.Accounts.User{}}] = Posts.list_posts()
      assert Posts.list_posts() |> Enum.map(& &1.id) == [post.id]
    end

    test "list_posts/0 orders posts newest first" do
      _old = post_fixture(%{title: "old post"})
      _new = post_fixture(%{title: "new post"})

      assert [%Post{title: "new post"}, %Post{title: "old post"}] =
               Posts.list_posts()
    end

    test "get_post!/1 returns the post with given id" do
      post = post_fixture()

      assert %Post{user: %Blog.Accounts.User{}} = Posts.get_post!(post.id)
      assert Posts.get_post!(post.id).id == post.id
    end

    test "create_post/2 with valid data creates a post owned by the scope user" do
      user = user_fixture()
      valid_attrs = %{title: "some title", body: "some body"}

      assert {:ok, %Post{} = post} =
               Posts.create_post(Blog.Accounts.Scope.for_user(user), valid_attrs)

      assert post.title == "some title"
      assert post.body == "some body"
      assert post.user_id == user.id
    end

    test "create_post/2 ignores user_id in attrs" do
      other_user = user_fixture()
      user = user_fixture()

      assert {:ok, %Post{} = post} =
               Posts.create_post(Blog.Accounts.Scope.for_user(user), %{
                 title: "some title",
                 body: "some body",
                 user_id: other_user.id
               })

      assert post.user_id == user.id
    end

    test "create_post/2 with invalid data returns error changeset" do
      user = user_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Posts.create_post(Blog.Accounts.Scope.for_user(user), @invalid_attrs)
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
      assert Posts.get_post!(post.id).id == post.id
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

  describe "posts authorization" do
    alias Blog.Posts.Post

    import Blog.PostsFixtures
    import Blog.AccountsFixtures

    test "can_manage_post?/2 is true for the author" do
      user = user_fixture()
      post = post_fixture(%{user: user})

      assert Posts.can_manage_post?(Blog.Accounts.Scope.for_user(user), post)
    end

    test "can_manage_post?/2 is true for an admin" do
      admin = admin_user_fixture()
      post = post_fixture()

      assert Posts.can_manage_post?(Blog.Accounts.Scope.for_user(admin), post)
    end

    test "can_manage_post?/2 is false for another user" do
      user = user_fixture()
      post = post_fixture()

      refute Posts.can_manage_post?(Blog.Accounts.Scope.for_user(user), post)
    end

    test "can_manage_post?/2 is false for an anonymous scope" do
      post = post_fixture()

      refute Posts.can_manage_post?(nil, post)
    end
  end

  describe "comments" do
    alias Blog.Posts.Comment

    import Blog.PostsFixtures
    import Blog.AccountsFixtures

    @invalid_comment_attrs %{body: nil}
    @valid_comment_attrs %{body: "some body"}

    test "list_comments/1 returns post comments oldest first with authors preloaded" do
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

    test "create_comment/3 with valid data creates a comment owned by the scope user" do
      user = user_fixture()
      post = post_fixture()

      assert {:ok, %Comment{} = comment} =
               Posts.create_comment(
                 Blog.Accounts.Scope.for_user(user),
                 post,
                 @valid_comment_attrs
               )

      assert comment.body == "some body"
      assert comment.post_id == post.id
      assert comment.user_id == user.id
    end

    test "create_comment/3 with invalid data returns error changeset" do
      user = user_fixture()
      post = post_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Posts.create_comment(
                 Blog.Accounts.Scope.for_user(user),
                 post,
                 @invalid_comment_attrs
               )
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

  describe "comments authorization" do
    alias Blog.Posts.Comment

    import Blog.PostsFixtures
    import Blog.AccountsFixtures

    test "can_delete_comment?/3 is true for the comment author" do
      user = user_fixture()
      post = post_fixture()
      comment = comment_fixture(post, %{user: user})

      assert Posts.can_delete_comment?(Blog.Accounts.Scope.for_user(user), comment, post)
    end

    test "can_delete_comment?/3 is true for the post author" do
      user = user_fixture()
      post = post_fixture(%{user: user})
      comment = comment_fixture(post)

      assert Posts.can_delete_comment?(Blog.Accounts.Scope.for_user(user), comment, post)
    end

    test "can_delete_comment?/3 is true for an admin" do
      admin = admin_user_fixture()
      post = post_fixture()
      comment = comment_fixture(post)

      assert Posts.can_delete_comment?(Blog.Accounts.Scope.for_user(admin), comment, post)
    end

    test "can_delete_comment?/3 is false for another user" do
      user = user_fixture()
      post = post_fixture()
      comment = comment_fixture(post)

      refute Posts.can_delete_comment?(Blog.Accounts.Scope.for_user(user), comment, post)
    end

    test "can_delete_comment?/3 is false for an anonymous scope" do
      post = post_fixture()
      comment = comment_fixture(post)

      refute Posts.can_delete_comment?(nil, comment, post)
    end
  end
end
