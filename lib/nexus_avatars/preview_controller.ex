defmodule NexusAvatars.PreviewController do
  @moduledoc """
  GET /preview?username=alice&style=mech

  Returns the SVG directly — no rasterization, since librsvg may not be
  available. Nexus itself serves SVGs as-is without converting them.
  No auth required.
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
      svg_module = style_module(style)
      svg        = svg_module.render(username)

      conn
      |> put_resp_header("content-type", "image/svg+xml")
      |> put_resp_header("cache-control", "public, max-age=3600")
      |> send_resp(200, svg)
    end
  end

  defp style_module("mech"),      do: NexusAvatars.Generator.Mech
  defp style_module("feline"),    do: NexusAvatars.Generator.Feline
  defp style_module("canine"),    do: NexusAvatars.Generator.Canine
  defp style_module("inkblot"),   do: NexusAvatars.Generator.Inkblot
  defp style_module("emblem"),    do: NexusAvatars.Generator.Emblem
  defp style_module("snowflake"), do: NexusAvatars.Generator.Snowflake
end
