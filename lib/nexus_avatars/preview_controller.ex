defmodule NexusAvatars.PreviewController do
  @moduledoc """
  GET /preview?username=alice&style=mech

  Returns a 256x256 WebP image directly — used by the JS style picker
  to show live previews without persisting anything. No auth required.
  """

  use Phoenix.Controller, formats: [:json]
  import Plug.Conn

  @valid_styles NexusAvatars.UserStyle.valid_styles()

  def show(conn, params) do
    username = Map.get(params, "username", "preview")
    style    = Map.get(params, "style", "mech")

    if style not in @valid_styles do
      conn
      |> put_status(400)
      |> json(%{error: "Invalid style. Valid: #{Enum.join(@valid_styles, ", ")}"})
    else
      case generate_preview(username, style) do
        {:ok, webp_binary} ->
          conn
          |> put_resp_header("content-type", "image/webp")
          |> put_resp_header("cache-control", "public, max-age=3600")
          |> send_resp(200, webp_binary)

        {:error, reason} ->
          conn
          |> put_status(500)
          |> json(%{error: "Preview generation failed: #{inspect(reason)}"})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private — build SVG and rasterize without storing
  # ---------------------------------------------------------------------------

  defp generate_preview(username, style) do
    svg_module = style_module(style)

    try do
      svg    = svg_module.render(username)
      image  = Image.from_svg!(svg, width: 256)
      binary = Image.write_to_binary!(image, ".webp", quality: 85)
      {:ok, binary}
    rescue
      e -> {:error, inspect(e)}
    end
  end

  defp style_module("mech"),      do: NexusAvatars.Generator.Mech
  defp style_module("feline"),    do: NexusAvatars.Generator.Feline
  defp style_module("canine"),    do: NexusAvatars.Generator.Canine
  defp style_module("inkblot"),   do: NexusAvatars.Generator.Inkblot
  defp style_module("emblem"),    do: NexusAvatars.Generator.Emblem
  defp style_module("snowflake"), do: NexusAvatars.Generator.Snowflake
end
