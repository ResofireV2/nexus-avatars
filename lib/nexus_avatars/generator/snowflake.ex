defmodule NexusAvatars.Generator.Snowflake do
  @moduledoc """
  Snowflake avatar style — placeholder pending full implementation.
  Renders a simple geometric placeholder in the blue color family.
  """

  def render(username) do
    seed  = :erlang.phash2(username)
    shift = rem(seed, 40)

    bg  = shade_hex(0x03, 0x07, 0x12, shift)
    mid = shade_hex(0x02, 0x84, 0xc7, shift)
    hi  = shade_hex(0xba, 0xe6, 0xfd, shift)

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
