defmodule NexusAvatars.Generator.Inkblot do
  @moduledoc """
  Inkblot avatar style — placeholder pending full implementation.
  Renders a simple placeholder SVG in the style's color family.
  """

  def render(username) do
    seed = :erlang.phash2(username)
    hue  = rem(seed, 360)
    """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">
      <rect width="256" height="256" fill="hsl(#{hue},40%,18%)"/>
      <circle cx="128" cy="128" r="80" fill="hsl(#{hue},60%,40%)" opacity="0.8"/>
      <text x="128" y="140" font-family="sans-serif" font-size="28" font-weight="700"
            fill="white" text-anchor="middle" opacity="0.9">Inkblot</text>
    </svg>
    """
  end
end
