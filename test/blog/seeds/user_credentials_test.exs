defmodule Blog.Seeds.UserCredentialsTest do
  use ExUnit.Case, async: true

  alias Blog.Seeds.UserCredentials

  describe "decode!/1" do
    test "decodes entries into credential DTOs" do
      json =
        Jason.encode!([
          %{email: "admin@example.com", password: "a-long-test-password", role: "admin"}
        ])

      assert [%UserCredentials{email: "admin@example.com", role: "admin"}] =
               UserCredentials.decode!(json)
    end

    test "rejects missing required fields" do
      assert_raise ArgumentError, ~r/only email, password, and role/, fn ->
        UserCredentials.decode!(~s([{"email":"admin@example.com","role":"admin"}]))
      end
    end

    test "rejects invalid roles" do
      json =
        Jason.encode!([
          %{email: "user@example.com", password: "a-long-test-password", role: "owner"}
        ])

      assert_raise ArgumentError, ~r/invalid role/, fn ->
        UserCredentials.decode!(json)
      end
    end

    test "rejects duplicate emails case-insensitively" do
      json =
        Jason.encode!([
          %{email: "user@example.com", password: "a-long-test-password", role: "admin"},
          %{email: "USER@example.com", password: "another-long-password", role: "user"}
        ])

      assert_raise ArgumentError, ~r/duplicate email/, fn ->
        UserCredentials.decode!(json)
      end
    end

    test "rejects a non-array JSON document" do
      assert_raise ArgumentError, ~r/non-empty array/, fn ->
        UserCredentials.decode!(~s({"email":"admin@example.com"}))
      end
    end

    test "rejects passwords outside the supported length" do
      json =
        Jason.encode!([
          %{email: "user@example.com", password: "short", role: "user"}
        ])

      assert_raise ArgumentError, ~r/password must be between 12 and 72 bytes/, fn ->
        UserCredentials.decode!(json)
      end
    end
  end
end
