defmodule NexusAvatars.Generator.Canine do
  @moduledoc """
  Canine avatar style — placeholder pending full implementation.
  Renders a simple geometric placeholder in the amber/orange color family.
  """

  def render(username) do
    seed  = :erlang.phash2(username)
    shift = rem(seed, 40)

    bg  = shade_hex(0x1c, 0x0a, 0x00, shift)
    mid = shade_hex(0xd9, 0x77, 0x06, shift)
    hi  = shade_hex(0xfd, 0xe6, 0x8a, shift)

    """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">
      <rect width="256" height="256" fill="#{bg}"/>
      <circle cx="128" cy="128" r="96" fill="#{mid}"/>
      <circle cx="128" cy="128" r="52" fill="#{hi}"/>
      <circle cx="128" cy="128" r="22" fill="#{bg}"/>
    </svg>
    """
  end

  defp shade_hex(r, g, b, shift) do
    r2 = min(255, r + shift)
    g2 = min(255, g + shift)
    b2 = min(255, b + shift)
    "##{hex2(r2)}#{hex2(g2)}#{hex2(b2)}"
  end

  defp hex2(n), do: n |> Integer.to_string(16) |> String.pad_leading(2, "0") |> String.upcase()
end
