defmodule Blog.Seeds.UserCredentials do
  @moduledoc """
  Local-only credentials loaded by the repository seed script.
  """

  @enforce_keys [:email, :password, :role]
  defstruct [:email, :password, :role]

  @type t :: %__MODULE__{
          email: String.t(),
          password: String.t(),
          role: String.t()
        }

  @keys ~w(email password role)
  @credentials_path Application.app_dir(:blog, "priv/repo/seeds.credentials.json")

  @doc "Loads credentials from the local, gitignored JSON file."
  @spec load!() :: [t()]
  def load! do
    case File.read(@credentials_path) do
      {:ok, json} ->
        decode!(json)

      {:error, :enoent} ->
        raise "Seed credentials file is missing: #{@credentials_path}. " <>
                "Create it with a JSON array of objects containing email, password, and role."

      {:error, reason} ->
        raise "Could not read seed credentials file #{@credentials_path}: #{:file.format_error(reason)}"
    end
  end

  @doc "Decodes a JSON array of credential objects into DTO structs."
  @spec decode!(String.t()) :: [t()]
  def decode!(json) when is_binary(json) do
    case Jason.decode!(json) do
      credentials when is_list(credentials) and credentials != [] ->
        credentials
        |> Enum.with_index(1)
        |> Enum.map(fn {attrs, index} -> from_map!(attrs, index) end)
        |> validate_unique_emails!()

      _ ->
        raise ArgumentError, "seed credentials JSON must be a non-empty array of objects"
    end
  rescue
    error in Jason.DecodeError ->
      raise ArgumentError, "seed credentials JSON is invalid: #{Exception.message(error)}"
  end

  defp from_map!(attrs, index) when is_map(attrs) do
    unknown_keys = Map.keys(attrs) -- @keys
    missing_keys = @keys -- Map.keys(attrs)

    if unknown_keys != [] or missing_keys != [] do
      raise ArgumentError,
            "seed credentials entry #{index} must contain only email, password, and role"
    end

    credentials = %__MODULE__{
      email: Map.fetch!(attrs, "email"),
      password: Map.fetch!(attrs, "password"),
      role: Map.fetch!(attrs, "role")
    }

    validate!(credentials, index)
  end

  defp from_map!(_attrs, index) do
    raise ArgumentError, "seed credentials entry #{index} must be a JSON object"
  end

  defp validate!(%__MODULE__{} = credentials, index) do
    unless is_binary(credentials.email) and credentials.email != "" do
      raise ArgumentError, "seed credentials entry #{index} has an invalid email"
    end

    unless is_binary(credentials.password) and byte_size(credentials.password) in 12..72 do
      raise ArgumentError,
            "seed credentials entry #{index} password must be between 12 and 72 bytes"
    end

    unless credentials.role in Blog.Accounts.User.roles() do
      raise ArgumentError, "seed credentials entry #{index} has an invalid role"
    end

    credentials
  end

  defp validate_unique_emails!(credentials) do
    emails = Enum.map(credentials, &String.downcase(&1.email))

    if length(emails) != length(Enum.uniq(emails)) do
      raise ArgumentError, "seed credentials must not contain duplicate email addresses"
    end

    credentials
  end
end
