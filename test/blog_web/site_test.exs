defmodule BlogWeb.SiteTest do
  use ExUnit.Case, async: true

  alias BlogWeb.Site

  describe "reading_time/1" do
    test "returns at least one minute for empty and short text" do
      assert Site.reading_time("") == 1
      assert Site.reading_time("a few words") == 1
    end

    test "estimates one minute per 200 words" do
      text = List.duplicate("word", 200) |> Enum.join(" ")
      assert Site.reading_time(text) == 1

      longer_text = List.duplicate("word", 401) |> Enum.join(" ")
      assert Site.reading_time(longer_text) == 3
    end
  end

  test "site_name/0 returns the configured site name" do
    assert Site.site_name() == Application.fetch_env!(:blog, :site_name)
  end
end
