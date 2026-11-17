defmodule Blog.Posts.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "comments" do
    field :author, :string
    field :body, :string

    belongs_to :post, Blog.Posts.Post

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:author, :body])
    |> validate_required([:body])
    |> validate_length(:author, max: 100)
    |> validate_length(:body, min: 1, max: 5_000)
    |> foreign_key_constraint(:post_id)
  end
end
