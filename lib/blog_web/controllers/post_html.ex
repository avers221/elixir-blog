defmodule BlogWeb.PostHTML do
  use BlogWeb, :html

  alias Blog.Posts
  alias Blog.Posts.Comment

  embed_templates "post_html/*"

  @doc """
  Renders a post form.

  The form is defined in the template at
  post_html/post_form.html.heex
  """
  attr :form, Phoenix.HTML.Form, required: true
  attr :action, :string, required: true
  attr :return_to, :string, default: nil

  def post_form(assigns)

  @doc """
  Renders the post body (Markdown source) as safe HTML.

  Raw HTML inside the user-provided Markdown is filtered by Comrak
  (`unsafe: false` is the mdex default), so the output is XSS-safe.
  """
  def markdown_to_html(markdown) do
    MDEx.to_html!(markdown,
      extension: [table: true, strikethrough: true, autolink: true, tasklist: true],
      render: [github_pre_lang: true]
    )
    |> Phoenix.HTML.raw()
  end

  @doc """
  Returns a short plain-text preview of the post body for listing pages.
  """
  def body_preview(body) when is_binary(body) do
    first_line =
      body
      |> String.replace("\r\n", "\n")
      |> String.split("\n", trim: true)
      |> List.first("")
      |> String.trim()

    if String.length(first_line) > 160 do
      String.slice(first_line, 0, 159) <> "…"
    else
      first_line
    end
  end
end
