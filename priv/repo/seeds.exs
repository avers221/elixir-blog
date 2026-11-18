# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Blog.Repo.insert!(%Blog.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

import Ecto.Query

alias Blog.Repo
alias Blog.Accounts
alias Blog.Accounts.User
alias Blog.Posts
alias Blog.Posts.Comment
alias Blog.Posts.Post
alias Blog.Seeds.UserCredentials

# Creates (or updates) a confirmed user with a password and a role.
defmodule Blog.SeedsHelper do
  alias Blog.Repo
  alias Blog.Accounts
  alias Blog.Accounts.User

  def user!(email, password, role) do
    user =
      case Repo.get_by(User, email: email) do
        nil ->
          {:ok, user} = Accounts.register_user(%{email: email})
          user

        user ->
          user
      end

    {:ok, {user, _expired_tokens}} =
      Accounts.update_user_password(user, %{password: password})

    user
    |> User.confirm_changeset()
    |> Ecto.Changeset.change(role: role)
    |> Repo.update!()
  end
end

credentials = UserCredentials.load!()

unless Enum.any?(credentials, &(&1.role == "admin")) do
  raise "Seed credentials must include an admin user"
end

unless Enum.any?(credentials, &(&1.role == "user")) do
  raise "Seed credentials must include a regular user"
end

users = Enum.map(credentials, &Blog.SeedsHelper.user!(&1.email, &1.password, &1.role))

admin = Enum.find(users, &User.admin?/1)
demo_user = Enum.find(users, &(not User.admin?(&1)))

IO.puts("Seeded users: #{admin.email} (#{admin.role}), #{demo_user.email} (#{demo_user.role}).")

# Backfill posts created before authentication: assign them to the
# demo user. Admin-created posts are left untouched.
if posts_without_author = Repo.all(from(p in Post, where: is_nil(p.user_id))) do
  Enum.each(posts_without_author, fn post ->
    post
    |> Ecto.Changeset.change(user_id: demo_user.id)
    |> Repo.update!()
  end)

  IO.puts("Backfilled #{length(posts_without_author)} post(s) to #{demo_user.email}.")
end

# Only seed demo content when the posts table is empty.
unless Repo.exists?(Post) do
  [
    %{
      title: "Welcome to the blog",
      body: """
      This is the first post, written in **Markdown**.

      ## What you can do here

      - Create, edit and delete posts
      - Write bodies in GitHub-Flavored Markdown
      - Watch the preview in the posts list

      > The raw HTML inside Markdown is filtered, so the rendering is XSS-safe.
      """
    },
    %{
      title: "Markdown showcase",
      body: """
      This post demonstrates the Markdown features the blog supports.

      ## Lists and quotes

      1. Headings
      2. Lists — ordered and unordered
      3. Tables and code blocks

      ## Tables

      | Feature   | Supported |
      | --------- | --------- |
      | Headings  | yes       |
      | Tables    | yes       |
      | Raw HTML  | filtered  |

      ## Code

      Here is an Elixir function from `String`:

      ```elixir
      def hello do
        "world"
      end
      ```

      Inline `code` works as well, as do ~~strikethrough~~ and links
      like [Hexdocs](https://hexdocs.pm).
      """
    },
    %{
      title: "How this blog is built",
      body: """
      A quick rundown of the stack:

      - **Phoenix 1.8** — server-rendered HTML with HEEx templates
      - **Ecto + PostgreSQL** — the database runs in Docker
      - **mdex (Comrak)** — GitHub-Flavored Markdown rendering
      - **Tailwind CSS v4 + daisyUI** — styling with light and dark themes

      Try creating your own post with the *New Post* button!
      """
    }
  ]
  |> Enum.each(&Posts.create_post(Blog.Accounts.Scope.for_user(demo_user), &1))

  IO.puts("Seeded demo posts.")
end

# Demo comments for the first post (skipped if any comments exist).
if Repo.exists?(Post) and not Repo.exists?(Comment) do
  first_post = Repo.get_by!(Post, title: "Welcome to the blog")

  [
    %{body: "Great start! Looking forward to more posts."},
    %{body: "The Markdown rendering works nicely, nice to see tables in action."}
  ]
  |> Enum.each(&Posts.create_comment(Blog.Accounts.Scope.for_user(admin), first_post, &1))

  IO.puts("Seeded demo comments.")
end
