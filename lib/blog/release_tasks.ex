defmodule Blog.ReleaseTasks do
  @moduledoc """
  Operational tasks executed from a production release.
  """

  alias Blog.Accounts.User

  @doc "Runs all pending database migrations."
  def migrate do
    {:ok, versions, _apps} =
      Ecto.Migrator.with_repo(Blog.Repo, fn repo ->
        Ecto.Migrator.run(repo, :up, all: true)
      end)

    Enum.each(versions, &IO.puts("Migrated version #{&1}"))
  end

  @doc "Grants the admin role to an existing account."
  def admin_grant(email) when is_binary(email) do
    update_role(email, "admin")
  end

  @doc "Revokes the admin role from an existing account."
  def admin_revoke(email) when is_binary(email) do
    update_role(email, "user")
  end

  defp update_role(email, role) do
    {:ok, result, _apps} =
      Ecto.Migrator.with_repo(Blog.Repo, fn repo ->
        case repo.get_by(User, email: email) do
          nil ->
            {:error, :not_found}

          user ->
            repo.update(Ecto.Changeset.change(user, role: role))
        end
      end)

    case result do
      {:ok, _user} -> IO.puts("Set #{email} role to #{role}")
      {:error, :not_found} -> raise "No account found for #{email}"
      {:error, changeset} -> raise "Could not update role: #{inspect(changeset.errors)}"
    end
  end
end
