defmodule NexusAvatars.Generator.Emblem do
  @moduledoc """
  Emblem avatar style.

  Renders a 256x256 avatar consisting of:
    1. A tiled background pattern (rings, grid, hex, stripes, dots, solid)
    2. A floating crest border shape centered on the canvas
       (shield, circle, octagon, diamond, badge, ornate ring, hexagon,
        pentagon, dashed ring, sunburst, starburst, double shield)
    3. An icon centered inside the crest's inner area
       (star5, star6, flame, crown, anchor, lightning, moon, globe,
        shield-within, atom, tree, infinity, eye, sword, skull)

  The crest floats in the center of the canvas. It is not an edge frame,
  so it displays correctly at any border-radius (circle, rounded square,
  hard square) without regeneration.

  All icons are defined in unit-circle space (center 0,0, radius 1.0)
  and placed via translate/scale, guaranteeing they fit any crest's
  inner area regardless of shape.

  The moon icon uses a two-circle overdraw technique (bright circle +
  inner-fill circle offset to carve the crescent bite) so the crescent
  is always solid and visible regardless of background.

  Fully librsvg-safe: pure polygon/circle/path/line geometry.
  No SVG filters, no blur, no gradients, no CSS.

  Canvas: 256x256, viewBox 0 0 256 256. Rasterised to WebP via libvips.

  PRNG: splitmix32 via rng/3, matching the Mech generator convention.
  Bitwise ops use fully-qualified Bitwise.band/bxor/bsr, matching all
  other generators in this extension (no `use Bitwise` import needed).

  Salt map:
    0  -> palette       (16 palettes)
    1  -> background    (6 patterns)
    2  -> crest shape   (12 shapes)
    3  -> icon          (15 icons)
  """

  @size 256

  # ---------------------------------------------------------------------------
  # Palettes — {bg, bg_pattern, frame, frame_hi, inner, icon}
  # bg       : canvas background fill
  # bg_pat   : background pattern stroke color (subtle, same hue family)
  # frame    : crest border fill color
  # frame_hi : crest border highlight / inner ring color
  # inner    : crest inner area fill (very dark)
  # icon     : icon fill color (always bright, contrasts inner)
  # ---------------------------------------------------------------------------
  @palettes [
    {"#0d1b2a", "#1a3a52", "#c9a227", "#f5d96a", "#050d14", "#f5d96a"},
    {"#1a0800", "#300f00", "#ff4800", "#ffb080", "#0d0300", "#ffb080"},
    {"#0f0a1e", "#1e1040", "#7c3aed", "#c4b5fd", "#060410", "#c4b5fd"},
    {"#052e16", "#0d4a22", "#16a34a", "#86efac", "#02100a", "#86efac"},
    {"#1c0533", "#380a5c", "#d946ef", "#f0abfc", "#0e0218", "#f0abfc"},
    {"#1c1917", "#2c2420", "#d97706", "#fcd34d", "#080604", "#fcd34d"},
    {"#0f172a", "#1e3a5f", "#0ea5e9", "#bae6fd", "#04080f", "#bae6fd"},
    {"#1a0a0a", "#300f0f", "#e11d48", "#fda4af", "#0a0204", "#fda4af"},
    {"#042f2e", "#0a4a48", "#0d9488", "#5eead4", "#010f0f", "#5eead4"},
    {"#18181b", "#27272a", "#71717a", "#e4e4e7", "#080808", "#e4e4e7"},
    {"#1e0a00", "#341200", "#ea580c", "#fed7aa", "#0d0400", "#fed7aa"},
    {"#0a0f1e", "#142040", "#3b82f6", "#93c5fd", "#040810", "#93c5fd"},
    {"#0c0a00", "#201a00", "#ca8a04", "#fef08a", "#060500", "#fef08a"},
    {"#0f0c1a", "#1e1830", "#8b5cf6", "#ddd6fe", "#070510", "#ddd6fe"},
    {"#001a0f", "#003020", "#059669", "#6ee7b7", "#000d08", "#6ee7b7"},
    {"#1a0010", "#300020", "#db2777", "#fbcfe8", "#0a0008", "#fbcfe8"},
  ]

  @num_palettes    length(@palettes)
  @num_backgrounds 6
  @num_crests      12
  @num_icons       15

  # ---------------------------------------------------------------------------
  # Public entry point
  # ---------------------------------------------------------------------------

  @doc "Renders a 256x256 Emblem SVG string for the given username."
  def render(username) do
    seed = :erlang.phash2(username)

    {bg, bg_pat, frame, frame_hi, inner, icon_col} =
      Enum.at(@palettes, rng(seed, 0, @num_palettes))

    bg_svg    = background(seed, bg, bg_pat)
    crest_svg = crest(seed, frame, frame_hi, inner)
    {ir, iy}  = crest_inner(seed)
    icon_svg  = icon(seed, 128, 128 + iy, ir, icon_col, inner)

    [
      ~s(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{@size} #{@size}" width="#{@size}" height="#{@size}">),
      bg_svg,
      crest_svg,
      icon_svg,
      "</svg>",
    ]
    |> Enum.join("")
  end

  # ---------------------------------------------------------------------------
  # PRNG — splitmix32, matching Mech generator convention exactly.
  # Uses fully-qualified Bitwise.band/bxor/bsr — no import required.
  # ---------------------------------------------------------------------------

  defp rng(seed, salt, range) do
    h  = Bitwise.band(Bitwise.bxor(seed, salt * 0x9e3779b9), 0xFFFFFFFF)
    z0 = Bitwise.band(h  + 0x9e3779b9, 0xFFFFFFFF)
    z1 = Bitwise.band(Bitwise.bxor(z0, Bitwise.bsr(z0, 16)) * 0x85ebca6b, 0xFFFFFFFF)
    z2 = Bitwise.band(Bitwise.bxor(z1, Bitwise.bsr(z1, 13)) * 0xc2b2ae35, 0xFFFFFFFF)
    z3 = Bitwise.band(Bitwise.bxor(z2, Bitwise.bsr(z2, 16)), 0xFFFFFFFF)
    w0 = Bitwise.band(z3 + 0x9e3779b9, 0xFFFFFFFF)
    w1 = Bitwise.band(Bitwise.bxor(w0, Bitwise.bsr(w0, 16)) * 0x85ebca6b, 0xFFFFFFFF)
    w2 = Bitwise.band(Bitwise.bxor(w1, Bitwise.bsr(w1, 13)) * 0xc2b2ae35, 0xFFFFFFFF)
    w3 = Bitwise.band(Bitwise.bxor(w2, Bitwise.bsr(w2, 16)), 0xFFFFFFFF)
    rem(w3, range)
  end

  # ---------------------------------------------------------------------------
  # Background patterns (salt 1)
  # ---------------------------------------------------------------------------

  defp background(seed, bg, pat) do
    base    = ~s(<rect width="256" height="256" fill="#{bg}"/>)
    overlay = case rng(seed, 1, @num_backgrounds) do
      0 -> bg_rings(pat)
      1 -> bg_grid(pat)
      2 -> bg_hex(pat)
      3 -> bg_stripes(pat)
      4 -> bg_dots(pat)
      _ -> ""
    end
    base <> overlay
  end

  defp bg_rings(col) do
    Enum.map_join([18, 40, 62, 84, 106, 128, 150], "", fn r ->
      ~s(<circle cx="128" cy="128" r="#{r}" fill="none" stroke="#{col}" stroke-width="0.8" opacity="0.22"/>)
    end)
  end

  defp bg_grid(col) do
    h = Enum.map_join(Enum.take_every(0..256, 28), "", fn i ->
      ~s(<line x1="#{i}" y1="0" x2="#{i}" y2="256" stroke="#{col}" stroke-width="0.7" opacity="0.2"/>)
    end)
    v = Enum.map_join(Enum.take_every(0..256, 28), "", fn i ->
      ~s(<line x1="0" y1="#{i}" x2="256" y2="#{i}" stroke="#{col}" stroke-width="0.7" opacity="0.2"/>)
    end)
    h <> v
  end

  defp bg_hex(col) do
    hw = 18
    hh = 20
    for row <- 0..7, col_i <- 0..8 do
      ox  = col_i * hw * 2 + if rem(row, 2) == 1, do: hw, else: 0
      oy  = row * round(hh * 1.5)
      pts = hex_pts(ox, oy + 128, hw, hh)
      ~s(<polygon points="#{pts}" fill="none" stroke="#{col}" stroke-width="0.7" opacity="0.2"/>)
    end
    |> Enum.join("")
  end

  defp hex_pts(ox, oy, hw, hh) do
    [{0, -hh}, {hw, -div(hh, 2)}, {hw, div(hh, 2)},
     {0, hh},  {-hw, div(hh, 2)}, {-hw, -div(hh, 2)}]
    |> Enum.map_join(" ", fn {dx, dy} -> "#{ox + dx},#{oy + dy}" end)
  end

  defp bg_stripes(col) do
    Enum.map_join(-8..16, "", fn i ->
      x1 = i * 20 - 256
      x2 = x1 + 256
      ~s(<line x1="#{x1}" y1="0" x2="#{x2}" y2="256" stroke="#{col}" stroke-width="7" opacity="0.14"/>)
    end)
  end

  defp bg_dots(col) do
    for x <- Enum.take_every(16..240, 24), y <- Enum.take_every(16..240, 24) do
      ~s(<circle cx="#{x}" cy="#{y}" r="1.5" fill="#{col}" opacity="0.28"/>)
    end
    |> Enum.join("")
  end

  # ---------------------------------------------------------------------------
  # Crest border shapes (salt 2)
  # ---------------------------------------------------------------------------

  defp crest(seed, frame, frame_hi, inner) do
    case rng(seed, 2, @num_crests) do
      0  -> crest_shield(frame, frame_hi, inner)
      1  -> crest_circle(frame, frame_hi, inner)
      2  -> crest_octagon(frame, frame_hi, inner)
      3  -> crest_diamond(frame, frame_hi, inner)
      4  -> crest_badge(frame, frame_hi, inner)
      5  -> crest_ornate(frame, frame_hi, inner)
      6  -> crest_hexagon(frame, frame_hi, inner)
      7  -> crest_pentagon(frame, frame_hi, inner)
      8  -> crest_dashed(frame, frame_hi, inner)
      9  -> crest_sunburst(frame, frame_hi, inner)
      10 -> crest_starburst(frame, frame_hi, inner)
      _  -> crest_double_shield(frame, frame_hi, inner)
    end
  end

  # Returns {inner_radius, y_offset} — uses same salt/range as crest/4
  # so both functions always agree on which crest was chosen.
  defp crest_inner(seed) do
    case rng(seed, 2, @num_crests) do
      0  -> {56,  6}
      1  -> {76,  0}
      2  -> {74,  0}
      3  -> {60,  0}
      4  -> {58,  0}
      5  -> {77,  0}
      6  -> {72,  0}
      7  -> {55,  6}
      8  -> {75,  0}
      9  -> {75,  0}
      10 -> {68,  0}
      _  -> {50,  8}
    end
  end

  defp crest_shield(f, f2, ic) do
    ~s(<path d="M128 44 L196 72 L196 148 Q196 200 128 224 Q60 200 60 148 L60 72 Z" fill="#{f}"/>) <>
    ~s(<path d="M128 61 L179 84 L179 146 Q179 192 128 212 Q77 192 77 146 L77 84 Z" fill="#{ic}"/>) <>
    ~s(<path d="M128 44 L196 72 L196 148 Q196 200 128 224 Q60 200 60 148 L60 72 Z" fill="none" stroke="#{f2}" stroke-width="1.5" opacity="0.5"/>)
  end

  defp crest_circle(f, f2, ic) do
    ~s(<circle cx="128" cy="128" r="96" fill="#{f}"/>) <>
    ~s(<circle cx="128" cy="128" r="78" fill="#{ic}"/>) <>
    ~s(<circle cx="128" cy="128" r="87" fill="none" stroke="#{f2}" stroke-width="1.5" opacity="0.55"/>) <>
    ~s(<circle cx="128" cy="128" r="95" fill="none" stroke="#{f2}" stroke-width="1" opacity="0.3"/>)
  end

  defp crest_octagon(f, f2, ic) do
    outer = ngon_pts(8, 96, 128, 128, -22.5)
    mid   = ngon_pts(8, 87, 128, 128, -22.5)
    inner = ngon_pts(8, 78, 128, 128, -22.5)
    ~s(<polygon points="#{outer}" fill="#{f}"/>) <>
    ~s(<polygon points="#{inner}" fill="#{ic}"/>) <>
    ~s(<polygon points="#{mid}" fill="none" stroke="#{f2}" stroke-width="1.5" opacity="0.5"/>)
  end

  defp crest_diamond(f, f2, ic) do
    ~s(<polygon points="128,32 224,128 128,224 32,128" fill="#{f}"/>) <>
    ~s(<polygon points="128,50 206,128 128,206 50,128" fill="#{ic}"/>) <>
    ~s(<polygon points="128,41 219,128 128,215 37,128" fill="none" stroke="#{f2}" stroke-width="1.5" opacity="0.5"/>)
  end

  defp crest_badge(f, f2, ic) do
    ~s(<rect x="36" y="46" width="184" height="164" rx="22" fill="#{f}"/>) <>
    ~s(<rect x="54" y="63" width="148" height="130" rx="13" fill="#{ic}"/>) <>
    ~s(<rect x="45" y="55" width="166" height="146" rx="18" fill="none" stroke="#{f2}" stroke-width="1.5" opacity="0.5"/>)
  end

  defp crest_ornate(f, f2, ic) do
    ticks = Enum.map_join(0..23, "", fn i ->
      a  = i / 24.0 * 2.0 * :math.pi()
      r1 = 82
      r2 = if rem(i, 6) == 0, do: 97, else: 92
      sw = if rem(i, 6) == 0, do: "2", else: "1"
      x1 = rf(128 + r1 * :math.cos(a))
      y1 = rf(128 + r1 * :math.sin(a))
      x2 = rf(128 + r2 * :math.cos(a))
      y2 = rf(128 + r2 * :math.sin(a))
      ~s(<line x1="#{x1}" y1="#{y1}" x2="#{x2}" y2="#{y2}" stroke="#{f2}" stroke-width="#{sw}" opacity="0.75"/>)
    end)
    ~s(<circle cx="128" cy="128" r="98" fill="#{f}"/>) <>
    ~s(<circle cx="128" cy="128" r="80" fill="#{ic}"/>) <>
    ~s(<circle cx="128" cy="128" r="89" fill="none" stroke="#{f}" stroke-width="16"/>) <>
    ~s(<circle cx="128" cy="128" r="97" fill="none" stroke="#{f2}" stroke-width="2"/>) <>
    ~s(<circle cx="128" cy="128" r="80" fill="none" stroke="#{f2}" stroke-width="1.5"/>) <>
    ticks
  end

  defp crest_hexagon(f, f2, ic) do
    outer = ngon_pts(6, 96, 128, 128, -90)
    mid   = ngon_pts(6, 87, 128, 128, -90)
    inner = ngon_pts(6, 79, 128, 128, -90)
    ~s(<polygon points="#{outer}" fill="#{f}"/>) <>
    ~s(<polygon points="#{inner}" fill="#{ic}"/>) <>
    ~s(<polygon points="#{mid}" fill="none" stroke="#{f2}" stroke-width="1.5" opacity="0.5"/>)
  end

  defp crest_pentagon(f, f2, ic) do
    outer = ngon_pts(5, 96, 128, 128, -90)
    mid   = ngon_pts(5, 87, 128, 128, -90)
    inner = ngon_pts(5, 79, 128, 128, -90)
    ~s(<polygon points="#{outer}" fill="#{f}"/>) <>
    ~s(<polygon points="#{inner}" fill="#{ic}"/>) <>
    ~s(<polygon points="#{mid}" fill="none" stroke="#{f2}" stroke-width="1.5" opacity="0.5"/>)
  end

  defp crest_dashed(f, f2, ic) do
    ~s(<circle cx="128" cy="128" r="78" fill="#{ic}"/>) <>
    ~s(<circle cx="128" cy="128" r="95" fill="none" stroke="#{f}" stroke-width="16" stroke-dasharray="18 9"/>) <>
    ~s(<circle cx="128" cy="128" r="78" fill="none" stroke="#{f2}" stroke-width="1.5" opacity="0.7"/>)
  end

  defp crest_sunburst(f, f2, ic) do
    rays = Enum.map_join(0..15, "", fn i ->
      a  = i / 16.0 * 2.0 * :math.pi()
      a2 = (i + 0.5) / 16.0 * 2.0 * :math.pi()
      a3 = a + :math.pi() / 8.0
      x1 = rf(128 + 80 * :math.cos(a))
      y1 = rf(128 + 80 * :math.sin(a))
      x2 = rf(128 + 96 * :math.cos(a2))
      y2 = rf(128 + 96 * :math.sin(a2))
      x3 = rf(128 + 80 * :math.cos(a3))
      y3 = rf(128 + 80 * :math.sin(a3))
      ~s(<polygon points="#{x1},#{y1} #{x2},#{y2} #{x3},#{y3}" fill="#{f}"/>)
    end)
    ~s(<circle cx="128" cy="128" r="96" fill="#{f}" opacity="0.35"/>) <>
    rays <>
    ~s(<circle cx="128" cy="128" r="78" fill="#{ic}"/>) <>
    ~s(<circle cx="128" cy="128" r="78" fill="none" stroke="#{f2}" stroke-width="1.5" opacity="0.6"/>)
  end

  defp crest_starburst(f, f2, ic) do
    pts = Enum.map_join(0..15, " ", fn i ->
      r = if rem(i, 2) == 0, do: 96, else: 80
      a = i / 16.0 * 2.0 * :math.pi() - :math.pi() / 16.0
      "#{rf(128 + r * :math.cos(a))},#{rf(128 + r * :math.sin(a))}"
    end)
    ~s(<polygon points="#{pts}" fill="#{f}"/>) <>
    ~s(<circle cx="128" cy="128" r="72" fill="#{ic}"/>) <>
    ~s(<circle cx="128" cy="128" r="72" fill="none" stroke="#{f2}" stroke-width="1.5" opacity="0.5"/>)
  end

  defp crest_double_shield(f, f2, ic) do
    ~s(<path d="M128 40 L200 70 L200 152 Q200 206 128 228 Q56 206 56 152 L56 70 Z" fill="#{f}" opacity="0.4"/>) <>
    ~s(<path d="M128 52 L188 78 L188 150 Q188 198 128 218 Q68 198 68 150 L68 78 Z" fill="#{f}"/>) <>
    ~s(<path d="M128 67 L175 89 L175 148 Q175 190 128 207 Q81 190 81 148 L81 89 Z" fill="#{ic}"/>) <>
    ~s(<path d="M128 52 L188 78 L188 150 Q188 198 128 218 Q68 198 68 150 L68 78 Z" fill="none" stroke="#{f2}" stroke-width="1.5" opacity="0.5"/>)
  end

  # ---------------------------------------------------------------------------
  # Icons (salt 3)
  # All defined in unit-circle space: center 0,0, fits within radius 1.0.
  # Placed via translate(cx, cy) scale(r) — no offset math needed.
  # icon_col  : bright accent — always visible against inner fill
  # inner_col : crest inner fill — used by moon/eye/skull for contrast details
  # ---------------------------------------------------------------------------

  defp icon(seed, cx, cy, r, icon_col, inner_col) do
    body = case rng(seed, 3, @num_icons) do
      0  -> icon_star5(icon_col)
      1  -> icon_star6(icon_col)
      2  -> icon_flame(icon_col)
      3  -> icon_crown(icon_col)
      4  -> icon_anchor(icon_col)
      5  -> icon_lightning(icon_col)
      6  -> icon_moon(icon_col, inner_col)
      7  -> icon_globe(icon_col)
      8  -> icon_shield(icon_col)
      9  -> icon_atom(icon_col)
      10 -> icon_tree(icon_col)
      11 -> icon_infinity(icon_col)
      12 -> icon_eye(icon_col, inner_col)
      13 -> icon_sword(icon_col)
      _  -> icon_skull(icon_col, inner_col)
    end
    ~s(<g transform="translate(#{cx},#{cy}) scale(#{r})">#{body}</g>)
  end

  defp icon_star5(c) do
    pts = star_pts(5, 0.94, 0.40, -:math.pi() / 2)
    ~s(<polygon points="#{pts}" fill="#{c}"/>)
  end

  defp icon_star6(c) do
    pts = star_pts(6, 0.92, 0.44, -:math.pi() / 2)
    ~s(<polygon points="#{pts}" fill="#{c}"/>)
  end

  # Shifted up 0.06 so visual center aligns with geometric center.
  defp icon_flame(c) do
    ~s(<path transform="translate(0,-0.06)" d="M0,0.60 Q-0.34,0.42-0.34,0.13 Q-0.34,-0.14-0.18,-0.28 Q-0.20,0.00-0.06,0.02 Q-0.17,-0.24-0.10,-0.52 Q0.02,-0.36 0.03,-0.18 Q0.13,-0.36 0.11,-0.58 Q0.33,-0.40 0.33,-0.04 Q0.40,-0.18 0.37,-0.36 Q0.54,-0.18 0.34,0.22 Q0.24,0.42 0,0.60Z" fill="#{c}"/>)
  end

  defp icon_crown(c) do
    ~s(<path d="M-0.52,0.36 L-0.52,0.08 L-0.30,-0.46 L-0.08,0.06 L0,-0.58 L0.08,0.06 L0.30,-0.46 L0.52,0.08 L0.52,0.36Z" fill="#{c}"/>) <>
    ~s(<rect x="-0.52" y="0.28" width="1.04" height="0.16" rx="0.03" fill="#{c}"/>)
  end

  defp icon_anchor(c) do
    ~s(<g fill="none" stroke="#{c}" stroke-width="0.09" stroke-linecap="round">) <>
    ~s(<circle cx="0" cy="-0.44" r="0.14"/>) <>
    ~s(<line x1="0" y1="-0.30" x2="0" y2="0.54"/>) <>
    ~s(<line x1="-0.38" y1="-0.02" x2="0.38" y2="-0.02"/>) <>
    ~s(<path d="M-0.38,-0.02 Q-0.54,0.32-0.38,0.44 Q-0.20,0.54 0,0.46"/>) <>
    ~s(<path d="M0.38,-0.02 Q0.54,0.32 0.38,0.44 Q0.20,0.54 0,0.46"/>) <>
    ~s(<line x1="-0.18" y1="-0.52" x2="0.18" y2="-0.52"/>) <>
    ~s(<circle cx="0" cy="-0.44" r="0.07" fill="#{c}" stroke="none"/>) <>
    ~s(</g>)
  end

  defp icon_lightning(c) do
    ~s(<polygon points="0.18,-0.62 -0.32,0.10 0.04,0.10 -0.18,0.62 0.38,-0.14 0.06,-0.14" fill="#{c}"/>)
  end

  # Large bright circle with an inner_col circle offset to carve the crescent.
  # Always solid and visible regardless of background color.
  defp icon_moon(c, inner_col) do
    ~s(<circle cx="0" cy="0" r="0.60" fill="#{c}"/>) <>
    ~s(<circle cx="0.22" cy="-0.08" r="0.44" fill="#{inner_col}"/>)
  end

  # Globe lines use same icon color at reduced opacity to avoid hardcoded black.
  defp icon_globe(c) do
    ~s(<circle cx="0" cy="0" r="0.62" fill="#{c}"/>) <>
    ~s(<ellipse cx="0" cy="0" rx="0.30" ry="0.62" fill="none" stroke="#{c}" stroke-width="0.06" opacity="0.45"/>) <>
    ~s(<ellipse cx="0" cy="0" rx="0.62" ry="0.25" fill="none" stroke="#{c}" stroke-width="0.06" opacity="0.45"/>) <>
    ~s(<line x1="-0.62" y1="0" x2="0.62" y2="0" stroke="#{c}" stroke-width="0.06" opacity="0.45"/>) <>
    ~s(<line x1="0" y1="-0.62" x2="0" y2="0.62" stroke="#{c}" stroke-width="0.06" opacity="0.45"/>)
  end

  defp icon_shield(c) do
    ~s(<path d="M0,-0.60 L0.50,-0.38 L0.50,0.10 Q0.50,0.46 0,0.62 Q-0.50,0.46-0.50,0.10 L-0.50,-0.38Z" fill="#{c}"/>)
  end

  defp icon_atom(c) do
    ~s(<circle cx="0" cy="0" r="0.14" fill="#{c}"/>) <>
    ~s(<ellipse cx="0" cy="0" rx="0.65" ry="0.26" fill="none" stroke="#{c}" stroke-width="0.08"/>) <>
    ~s(<ellipse cx="0" cy="0" rx="0.65" ry="0.26" fill="none" stroke="#{c}" stroke-width="0.08" transform="rotate(60)"/>) <>
    ~s(<ellipse cx="0" cy="0" rx="0.65" ry="0.26" fill="none" stroke="#{c}" stroke-width="0.08" transform="rotate(120)"/>)
  end

  defp icon_tree(c) do
    ~s(<polygon points="0,-0.62 0.38,-0.18 0.20,-0.18 0.46,0.18 0.22,0.18 0.46,0.46 -0.46,0.46 -0.22,0.18 -0.46,0.18 -0.20,-0.18 -0.38,-0.18" fill="#{c}"/>) <>
    ~s(<rect x="-0.10" y="0.46" width="0.20" height="0.18" fill="#{c}"/>)
  end

  defp icon_infinity(c) do
    ~s(<path d="M0,0 Q-0.14,-0.38-0.44,-0.30 Q-0.70,-0.22-0.70,0 Q-0.70,0.22-0.44,0.30 Q-0.14,0.38 0,0 Q0.14,-0.38 0.44,-0.30 Q0.70,-0.22 0.70,0 Q0.70,0.22 0.44,0.30 Q0.14,0.38 0,0Z" fill="#{c}"/>)
  end

  defp icon_eye(c, inner_col) do
    ~s(<path d="M-0.70,0 Q-0.20,-0.50 0,-0.50 Q0.20,-0.50 0.70,0 Q0.20,0.50 0,0.50 Q-0.20,0.50-0.70,0Z" fill="#{c}" opacity="0.30"/>) <>
    ~s(<path d="M-0.70,0 Q-0.20,-0.50 0,-0.50 Q0.20,-0.50 0.70,0 Q0.20,0.50 0,0.50 Q-0.20,0.50-0.70,0Z" fill="none" stroke="#{c}" stroke-width="0.08"/>) <>
    ~s(<circle cx="0" cy="0" r="0.28" fill="#{c}"/>) <>
    ~s(<circle cx="0" cy="0" r="0.16" fill="#{inner_col}"/>) <>
    ~s(<circle cx="-0.10" cy="-0.08" r="0.06" fill="#{c}" opacity="0.55"/>)
  end

  defp icon_sword(c) do
    ~s(<polygon points="0,-0.70 0.06,-0.58 0.05,0.38 -0.05,0.38 -0.06,-0.58" fill="#{c}"/>) <>
    ~s(<rect x="-0.32" y="0.30" width="0.64" height="0.10" rx="0.04" fill="#{c}"/>) <>
    ~s(<rect x="-0.07" y="0.40" width="0.14" height="0.26" rx="0.03" fill="#{c}" opacity="0.7"/>)
  end

  defp icon_skull(c, inner_col) do
    ~s(<path d="M0,-0.56 Q-0.44,-0.56-0.50,-0.26 Q-0.56,-0.02-0.44,0.20 L-0.40,0.34 L0.40,0.34 L0.44,0.20 Q0.56,-0.02 0.50,-0.26 Q0.44,-0.56 0,-0.56Z" fill="#{c}"/>) <>
    ~s(<ellipse cx="-0.20" cy="-0.06" rx="0.16" ry="0.18" fill="#{inner_col}" opacity="0.85"/>) <>
    ~s(<ellipse cx="0.20" cy="-0.06" rx="0.16" ry="0.18" fill="#{inner_col}" opacity="0.85"/>) <>
    ~s(<rect x="-0.20" y="0.34" width="0.13" height="0.22" rx="0.03" fill="#{c}"/>) <>
    ~s(<rect x="0.07" y="0.34" width="0.13" height="0.22" rx="0.03" fill="#{c}"/>) <>
    ~s(<rect x="-0.20" y="0.34" width="0.40" height="0.08" fill="#{c}"/>)
  end

  # ---------------------------------------------------------------------------
  # Geometry helpers
  # ---------------------------------------------------------------------------

  # Regular n-gon centered at (cx, cy), circumradius r, rotated by rot_deg.
  defp ngon_pts(n, r, cx, cy, rot_deg) do
    rot_rad = rot_deg * :math.pi() / 180.0
    Enum.map_join(0..(n - 1), " ", fn i ->
      a = i / n * 2.0 * :math.pi() + rot_rad
      "#{rf(cx + r * :math.cos(a))},#{rf(cy + r * :math.sin(a))}"
    end)
  end

  # Star polygon: n points, alternating outer radius ro and inner radius ri.
  defp star_pts(n, ro, ri, rot) do
    Enum.map_join(0..(n * 2 - 1), " ", fn i ->
      r = if rem(i, 2) == 0, do: ro, else: ri
      a = i / (n * 2) * 2.0 * :math.pi() + rot
      "#{fp(r * :math.cos(a))},#{fp(r * :math.sin(a))}"
    end)
  end

  # Round to 4 decimal places for compact SVG coordinate output.
  defp fp(v), do: Float.round(v * 1.0, 4)

  # Round to nearest integer for pixel-level coordinates.
  defp rf(v), do: round(v)
end
