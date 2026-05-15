defmodule NexusAvatars.StyleController do
  @moduledoc """
  POST /style        — save the logged-in user's style choice and regenerate
  POST /generate     — generate an avatar for the current user (lazy fallback)
  """

  use Phoenix.Controller, formats: [:json]
  import Plug.Conn

  @valid_styles NexusAvatars.UserStyle.valid_styles()

  # ---------------------------------------------------------------------------
  # POST /style
  # Body: { "style": "mech" }
  # ---------------------------------------------------------------------------

  def save(conn, params) do
    user  = conn.assigns.current_user
    style = Map.get(params, "style")

    cond do
      is_nil(style) ->
        conn |> put_status(400) |> json(%{error: "style is required"})

      style not in @valid_styles ->
        conn |> put_status(422) |> json(%{error: "Invalid style. Valid: #{Enum.join(@valid_styles, ", ")}"})

      true ->
        case NexusAvatars.Generator.generate_for_user(user, style) do
          {:ok, url} ->
            conn |> json(%{data: %{avatar_url: served_url(url), style: style}})

          {:error, reason} ->
            conn |> put_status(500) |> json(%{error: "Generation failed: #{inspect(reason)}"})
        end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /generate — generate for logged-in user using current settings
  # Used by the JS lazy-generation fallback when user has no avatar_url
  # ---------------------------------------------------------------------------

  def generate_mine(conn, _params) do
    user     = conn.assigns.current_user

    # Only generate if the user has no avatar — avoid overwriting uploads
    if user.avatar_url do
      conn |> json(%{data: %{avatar_url: user.avatar_url, generated: false}})
    else
      settings = NexusAvatars.load_settings()

      # Respect existing style choice if any
      style =
        NexusAvatars.Generator.get_user_style(user.id) ||
        NexusAvatars.Generator.pick_style(user.username, settings)

      if is_nil(style) do
        # No enabled styles — return nil, JS shows Nexus default initials
        conn |> json(%{data: %{avatar_url: nil, generated: false}})
      else
        case NexusAvatars.Generator.generate_for_user(user, style) do
          {:ok, url} ->
            conn |> json(%{data: %{avatar_url: served_url(url), style: style, generated: true}})

          {:error, reason} ->
            conn |> put_status(500) |> json(%{error: "Generation failed: #{inspect(reason)}"})
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp served_url(filename) do
    Nexus.Extensions.Storage.url("nexus-avatars", "avatars/#{filename}")
  end
end
