defmodule Blog.Repo.Migrations.AddUserIdToComments do
  use Ecto.Migration

  def change do
    alter table(:comments) do
      add :user_id, references(:users, on_delete: :nilify_all)
    end

    create index(:comments, [:user_id])
  end
end
