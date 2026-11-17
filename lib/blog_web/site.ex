defmodule BlogWeb.Site do
  @moduledoc """
  Site-wide values sourced from configuration.
  """

  @doc """
  The human-readable name of the site.

  Read from the `BLOG_NAME` variable in `.env` / environment
  (see `config/runtime.exs`). Changing it requires a server restart.
  """
  def site_name, do: Application.fetch_env!(:blog, :site_name)

  @doc """
  Estimated reading time for a text in whole minutes (words / 200, at least 1).
  """
  def reading_time(text) when is_binary(text) do
    words =
      text
      |> String.split(~r/\s+/, trim: true)
      |> length()

    div(words + 199, 200)
    |> max(1)
  end
end
