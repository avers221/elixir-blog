defmodule Blog.Posts.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "comments" do
    # Legacy free-form name for anonymous comments created before
    # authentication was introduced. New comments derive the display
    # name from the associated user instead.
    field :author, :string
    field :body, :string

    belongs_to :post, Blog.Posts.Post
    belongs_to :user, Blog.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body])
    |> validate_required([:body])
    |> validate_length(:body, min: 1, max: 5_000)
    |> foreign_key_constraint(:post_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Returns the display name for the comment author.
  """
  def author_name(%__MODULE__{user: %Blog.Accounts.User{} = user}), do: user.email

  def author_name(%__MODULE__{author: author}) when is_binary(author) and author != "",
    do: author

  def author_name(%__MODULE__{}), do: "Anonymous"
end
