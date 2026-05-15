defmodule NexusAvatars.Generator.Mech do
  @moduledoc """
  Generates Mech-style avatar SVGs.

  Design principles:
  - 256x256 canvas; background colour fills the entire square
  - No face-plate or head shape — features float directly on the background
  - All features are positioned within the inscribed circle (cx=128, cy=128,
    r=112) so circular avatar cropping never clips anything meaningful
  - Deterministic: same username always produces the same avatar

  Variation is achieved by independently seeding 10 feature slots from a
  splitmix32 PRNG keyed on the username hash + a per-slot salt. Each slot
  selects one of several named variants, giving ~238 billion distinct
  combinations before accounting for continuous per-feature jitter.

  Slot map (salt -> feature):
    0  -> palette           (28 palettes)
    1  -> bg_texture        (7 variants)
    2  -> eye_layout        (13 variants)
    3  -> eye_variant       (8 variants, called once per eye drawn)
    4  -> brow              (10 variants)
    5  -> nose              (9 variants)
    6  -> cheeks            (10 variants)
    7  -> forehead          (10 variants)
    8  -> mouth             (12 variants)
    9  -> chin              (9 variants)
    10 -> extras            (12 variants)

  Palette tuple layout: {bg, acc, bright, dark, mid, acc2}
  """

  @size 256
  @cx   128
  # @cy is not referenced directly; @cx is used for all horizontal centering

  # Each entry: {bg, acc, bright, dark, mid, acc2}
  @palettes [
    {"#1a0800","#ff4800","#ff9050","#0d0300","#5c2e14","#ffb020"},
    {"#1a0400","#ff2000","#ff7040","#0a0200","#6a1a10","#ff6030"},
    {"#160600","#e03000","#ff8050","#0a0200","#501808","#ffa040"},
    {"#080c14","#40b0ff","#a0e0ff","#040810","#1e3a58","#60c8ff"},
    {"#060a18","#6080ff","#b0c8ff","#030610","#182040","#90a8ff"},
    {"#0a1020","#00c8ff","#80e8ff","#050810","#183050","#40d8ff"},
    {"#030c00","#40ff20","#a0ff60","#010600","#163808","#80ff40"},
    {"#020e02","#20e060","#70ffb0","#010601","#0e3018","#50ff90"},
    {"#041000","#60ff00","#b0ff60","#020600","#1a4000","#90ff30"},
    {"#100800","#e0a000","#ffe060","#060300","#483000","#ffcc30"},
    {"#140a00","#ffc000","#ffe880","#080400","#503800","#ffd840"},
    {"#0e0600","#d08000","#ffc040","#060300","#3c2800","#ffb020"},
    {"#0a0010","#c040ff","#e8a0ff","#050008","#380858","#e060ff"},
    {"#0e0018","#ff40c0","#ffa0e8","#07000c","#480840","#ff70d0"},
    {"#080014","#8040ff","#c0a0ff","#040008","#280848","#a060ff"},
    {"#100000","#e02020","#ff7070","#060000","#3c0808","#ff4040"},
    {"#0e0202","#ff3040","#ff8090","#060101","#3a0810","#ff6070"},
    {"#001010","#00e0c0","#80fff0","#000808","#004840","#30ffd8"},
    {"#001418","#00c0b0","#70f0e0","#000a0c","#004040","#20e8d0"},
    {"#0e0e12","#9090b0","#d0d0e8","#060608","#303048","#b0b0d0"},
    {"#121218","#7070a0","#c0c0e0","#080808","#282840","#9090c0"},
    {"#0c0800","#c08030","#f0c070","#060400","#3c2808","#e0a050"},
    {"#000c10","#00e8ff","#80f8ff","#000508","#002838","#40f0ff"},
    {"#120400","#ff6000","#ffb060","#080200","#401800","#ff8020"},
    {"#050a00","#80c020","#c0f060","#020500","#1c3008","#a0d840"},
    {"#080e18","#a0d0ff","#dff0ff","#040810","#203858","#c0e4ff"},
    {"#140400","#ff8000","#ffcc40","#080200","#502000","#ffa020"},
    {"#04040c","#4040e0","#9090ff","#020208","#101040","#6060f0"},
  ]

  @doc "Renders a 256x256 Mech SVG string for the given username."
  def render(username) do
    seed = :erlang.phash2(username)
    {bg, acc, bright, dark, mid, _acc2} = Enum.at(@palettes, rng(seed, 0, length(@palettes)))
    {eye_y, eyes_svg} = eyes(seed, acc, bright, dark, mid)
    [
      ~s(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{@size} #{@size}" width="#{@size}" height="#{@size}">),
      ~s(<rect width="#{@size}" height="#{@size}" fill="#{bg}"/>),
      bg_texture(seed, dark),
      forehead(seed, acc, bright, dark, mid),
      brow(seed, acc, bright, dark, mid, eye_y),
      eyes_svg,
      nose(seed, acc, bright, dark, eye_y),
      cheeks(seed, acc, bright, dark, mid, eye_y),
      mouth(seed, acc, bright, dark, mid, eye_y),
      chin(seed, acc, bright, dark, mid, eye_y),
      extras(seed, acc, bright, dark, mid, eye_y),
      "</svg>",
    ]
    |> Enum.join("\n")
  end

  # ---------------------------------------------------------------------------
  # splitmix32 PRNG — deterministic integer in 0..(range-1)
  # ---------------------------------------------------------------------------
  defp rng(seed, salt, range) do
    h  = Bitwise.band(Bitwise.bxor(seed, salt * 0x9e3779b9), 0xFFFFFFFF)
    z0 = Bitwise.band(h + 0x9e3779b9, 0xFFFFFFFF)
    z1 = Bitwise.band(Bitwise.bxor(z0, Bitwise.bsr(z0, 16)) * 0x85ebca6b, 0xFFFFFFFF)
    z2 = Bitwise.band(Bitwise.bxor(z1, Bitwise.bsr(z1, 13)) * 0xc2b2ae35, 0xFFFFFFFF)
    z3 = Bitwise.band(Bitwise.bxor(z2, Bitwise.bsr(z2, 16)), 0xFFFFFFFF)
    w0 = Bitwise.band(z3 + 0x9e3779b9, 0xFFFFFFFF)
    w1 = Bitwise.band(Bitwise.bxor(w0, Bitwise.bsr(w0, 16)) * 0x85ebca6b, 0xFFFFFFFF)
    w2 = Bitwise.band(Bitwise.bxor(w1, Bitwise.bsr(w1, 13)) * 0xc2b2ae35, 0xFFFFFFFF)
    w3 = Bitwise.band(Bitwise.bxor(w2, Bitwise.bsr(w2, 16)), 0xFFFFFFFF)
    rem(w3, range)
  end

  # Jitter uses salts >= 100 to avoid collisions with slot salts 0..10
  defp jitter(seed, salt, range), do: rng(seed, salt + 100, range)

  # ---------------------------------------------------------------------------
  # bg_texture (salt 1)
  # ---------------------------------------------------------------------------
  defp bg_texture(seed, dark) do
    case rng(seed, 1, 7) do
      0 -> ""
      1 -> scanlines(dark)
      2 -> corner_rivets(dark)
      3 -> hex_grid(dark)
      4 -> edge_frame(dark)
      5 -> dot_matrix(dark)
      6 -> diagonal_hash(dark)
    end
  end

  defp scanlines(dark) do
    Enum.map_join(Enum.take_every(10..250, 16), "\n", fn y ->
      ~s(<rect x="0" y="#{y}" width="256" height="1.5" fill="#{dark}" opacity="0.5"/>)
    end)
  end

  defp corner_rivets(dark) do
    [{14,14},{242,14},{14,242},{242,242}]
    |> Enum.map_join("\n", fn {x, y} ->
      [
        ~s(<circle cx="#{x}" cy="#{y}" r="8" fill="#{dark}" opacity="0.9"/>),
        ~s(<circle cx="#{x}" cy="#{y}" r="5" fill="none" stroke="#{dark}" stroke-width="1.5"/>),
        ~s(<circle cx="#{x}" cy="#{y}" r="2.5" fill="#{dark}"/>),
      ]
      |> Enum.join("")
    end)
  end

  defp hex_grid(dark) do
    for row <- 0..5, col <- 0..5 do
      ox  = col * 52 + rem(row, 2) * 26 - 10
      oy  = row * 46 - 10
      pts = "#{ox+26},#{oy} #{ox+52},#{oy+15} #{ox+52},#{oy+37} #{ox+26},#{oy+52} #{ox},#{oy+37} #{ox},#{oy+15}"
      ~s(<polygon points="#{pts}" fill="none" stroke="#{dark}" stroke-width="1" opacity="0.35"/>)
    end
    |> Enum.join("\n")
  end

  defp edge_frame(dark) do
    [
      ~s(<rect x="6" y="6" width="244" height="244" fill="none" stroke="#{dark}" stroke-width="3" opacity="0.5"/>),
      ~s(<rect x="12" y="12" width="232" height="232" fill="none" stroke="#{dark}" stroke-width="1" opacity="0.25"/>),
    ]
    |> Enum.join("")
  end

  defp dot_matrix(dark) do
    for y <- Enum.take_every(18..250, 22), x <- Enum.take_every(18..250, 22) do
      ~s(<circle cx="#{x}" cy="#{y}" r="1.2" fill="#{dark}" opacity="0.5"/>)
    end
    |> Enum.join("\n")
  end

  defp diagonal_hash(dark) do
    Enum.map_join((-4)..19, "\n", fn i ->
      ~s(<line x1="#{i*22}" y1="0" x2="#{i*22+256}" y2="256" stroke="#{dark}" stroke-width="1" opacity="0.2"/>)
    end)
  end

  # ---------------------------------------------------------------------------
  # eyes (salts 2, 3) — returns {eye_y, svg}
  # ---------------------------------------------------------------------------
  defp eyes(seed, acc, bright, dark, mid) do
    layout = rng(seed, 2, 13)
    eye_y  = 88 + jitter(seed, 2, 28)
    spread = 36 + jitter(seed, 3, 24)
    sz     = 18 + jitter(seed, 4, 16)

    svg = case layout do
      0  -> twin_eyes(seed, acc, bright, dark, mid, eye_y, spread, sz)
      1  -> twin_eyes(seed, acc, bright, dark, mid, eye_y, spread, sz)
      2  -> cyclops_eye(seed, acc, bright, dark, mid, eye_y)
      3  -> visor_eye(seed, acc, bright, dark, mid, eye_y)
      4  -> triple_eyes(seed, acc, bright, dark, mid, eye_y)
      5  -> quad_eyes(seed, acc, bright, dark, mid, eye_y, spread, sz)
      6  -> wide_rect_eyes(seed, acc, bright, dark, eye_y, spread)
      7  -> stacked_eyes(seed, acc, bright, dark, mid, eye_y, spread, sz)
      8  -> cracked_eyes(seed, acc, bright, dark, mid, eye_y, spread)
      9  -> t_visor_eye(seed, acc, bright, dark, mid, eye_y)
      10 -> orbital_ring(seed, acc, bright, dark, eye_y)
      11 -> five_x_eyes(seed, acc, bright, dark, mid, eye_y, spread, sz)
      12 -> tall_slot_eyes(acc, dark, mid, eye_y, spread)
    end

    {eye_y, svg}
  end

  defp single_eye(seed, salt, cx, cy, sz, acc, bright, dark, mid) do
    case rng(seed, salt, 8) do
      0 -> eye_concentric(cx, cy, sz, acc, bright, dark, mid)
      1 -> eye_hex_iris(cx, cy, sz, acc, bright, dark, mid)
      2 -> eye_vertical_slit(cx, cy, sz, acc, dark, mid)
      3 -> eye_cross_reticle(cx, cy, sz, acc, bright, dark)
      4 -> eye_diamond_iris(cx, cy, sz, acc, bright, dark, mid)
      5 -> eye_scanner_rect(cx, cy, sz, acc, bright, dark, mid)
      6 -> eye_micro_ring(cx, cy, sz, acc, bright, dark, mid)
      7 -> eye_triangle(cx, cy, sz, acc, bright, dark)
    end
  end

  defp eye_concentric(cx, cy, sz, acc, bright, dark, mid) do
    gx = cx - div(sz, 3)
    gy = cy - div(sz, 3)
    gr = max(2, div(sz, 5))
    [
      ~s(<circle cx="#{cx}" cy="#{cy}" r="#{sz+8}" fill="#{dark}"/>),
      ~s(<circle cx="#{cx}" cy="#{cy}" r="#{sz+3}" fill="#{mid}"/>),
      ~s(<circle cx="#{cx}" cy="#{cy}" r="#{sz}" fill="#{acc}"/>),
      ~s(<circle cx="#{cx}" cy="#{cy}" r="#{sz-9}" fill="#{bright}"/>),
      ~s(<circle cx="#{cx}" cy="#{cy}" r="#{sz-18}" fill="#{dark}"/>),
      ~s(<circle cx="#{gx}" cy="#{gy}" r="#{gr}" fill="white" opacity="0.45"/>),
    ]
    |> Enum.join("")
  end

  defp eye_hex_iris(cx, cy, sz, acc, bright, dark, mid) do
    pts = "#{cx},#{cy-sz+4} #{cx+sz-6},#{cy-3} #{cx+sz-6},#{cy+3} #{cx},#{cy+sz-4} #{cx-sz+6},#{cy+3} #{cx-sz+6},#{cy-3}"
    [
      ~s(<circle cx="#{cx}" cy="#{cy}" r="#{sz+8}" fill="#{dark}"/>),
      ~s(<circle cx="#{cx}" cy="#{cy}" r="#{sz+2}" fill="#{mid}"/>),
      ~s(<polygon points="#{pts}" fill="#{acc}"/>),
      ~s(<circle cx="#{cx}" cy="#{cy}" r="#{div(sz*35,100)}" fill="#{dark}"/>),
      ~s(<circle cx="#{cx}" cy="#{cy}" r="#{div(sz*18,100)}" fill="#{bright}" opacity="0.9"/>),
    ]
    |> Enum.join("")
  end

  defp eye_vertical_slit(cx, cy, sz, acc, dark, mid) do
    [
      ~s(<circle cx="#{cx}" cy="#{cy}" r="#{sz+8}" fill="#{dark}"/>),
      ~s(<circle cx="#{cx}" cy="#{cy}" r="#{sz+2}" fill="#{mid}"/>),
      ~s(<ellipse cx="#{cx}" cy="#{cy}" rx="#{div(sz*32,100)}" ry="#{sz}" fill="#{acc}"/>),
      ~s(<ellipse cx="#{cx}" cy="#{cy}" rx="#{div(sz*14,100)}" ry="#{sz-6}" fill="#{dark}"/>),
    ]
    |> Enum.join("")
  end

  defp eye_cross_reticle(cx, cy, sz, acc, bright, dark) do
    [
      ~s(<circle cx="#{cx}" cy="#{cy}" r="#{sz+8}" fill="#{dark}"/>),
      ~s(<circle cx="#{cx}" cy="#{cy}" r="#{sz}" fill="#{acc}" opacity="0.18"/>),
      ~s(<circle cx="#{cx}" cy="#{cy}" r="#{sz}" fill="none" stroke="#{acc}" stroke-width="2.5"/>),
      ~s(<line x1="#{cx-sz}" y1="#{cy}" x2="#{cx+sz}" y2="#{cy}" stroke="#{acc}" stroke-width="2" opacity="0.75"/>),
      ~s(<line x1="#{cx}" y1="#{cy-sz}" x2="#{cx}" y2="#{cy+sz}" stroke="#{acc}" stroke-width="2" opacity="0.75"/>),
      ~s(<circle cx="#{cx}" cy="#{cy}" r="#{div(sz*28,100)}" fill="#{acc}"/>),
      ~s(<circle cx="#{cx}" cy="#{cy}" r="#{div(sz*12,100)}" fill="#{bright}"/>),
    ]
    |> Enum.join("")
  end

  defp eye_diamond_iris(cx, cy, sz, acc, bright, dark, mid) do
    h = div(sz, 2)
    [
      ~s(<circle cx="#{cx}" cy="#{cy}" r="#{sz+8}" fill="#{dark}"/>),
      ~s(<circle cx="#{cx}" cy="#{cy}" r="#{sz+2}" fill="#{mid}"/>),
      ~s(<polygon points="#{cx},#{cy-sz} #{cx+sz},#{cy} #{cx},#{cy+sz} #{cx-sz},#{cy}" fill="#{acc}"/>),
      ~s(<polygon points="#{cx},#{cy-h} #{cx+h},#{cy} #{cx},#{cy+h} #{cx-h},#{cy}" fill="#{bright}"/>),
      ~s(<circle cx="#{cx}" cy="#{cy}" r="4" fill="#{dark}"/>),
    ]
    |> Enum.join("")
  end

  defp eye_scanner_rect(cx, cy, sz, acc, bright, dark, mid) do
    hh = div(sz * 55, 100)
    w  = sz * 2
    [
      ~s(<rect x="#{cx-sz-5}" y="#{cy-hh-5}" width="#{w+10}" height="#{hh*2+10}" rx="8" fill="#{dark}"/>),
      ~s(<rect x="#{cx-sz}" y="#{cy-hh}" width="#{w}" height="#{hh*2}" rx="5" fill="#{mid}"/>),
      ~s(<rect x="#{cx-sz+3}" y="#{cy-5}" width="#{w-6}" height="10" rx="4" fill="#{acc}"/>),
      ~s(<rect x="#{cx-sz+3}" y="#{cy-5}" width="#{div(sz*60,100)}" height="10" rx="4" fill="#{bright}" opacity="0.9"/>),
    ]
    |> Enum.join("")
  end

  defp eye_micro_ring(cx, cy, sz, acc, bright, dark, mid) do
    sensors = Enum.map_join(0..7, "", fn i ->
      a  = i / 8 * :math.pi() * 2
      ex = round(cx + (sz - 2) * :math.cos(a))
      ey = round(cy + (sz - 2) * :math.sin(a))
      ~s(<circle cx="#{ex}" cy="#{ey}" r="4" fill="#{acc}"/>) <>
      ~s(<circle cx="#{ex}" cy="#{ey}" r="2" fill="#{bright}"/>)
    end)
    [
      ~s(<circle cx="#{cx}" cy="#{cy}" r="#{sz+8}" fill="#{dark}"/>),
      sensors,
      ~s(<circle cx="#{cx}" cy="#{cy}" r="#{div(sz*40,100)}" fill="#{mid}"/>),
      ~s(<circle cx="#{cx}" cy="#{cy}" r="#{div(sz*20,100)}" fill="#{acc}"/>),
    ]
    |> Enum.join("")
  end

  defp eye_triangle(cx, cy, sz, acc, bright, dark) do
    h = div(sz, 2)
    [
      ~s(<circle cx="#{cx}" cy="#{cy}" r="#{sz+8}" fill="#{dark}"/>),
      ~s(<polygon points="#{cx},#{cy-sz} #{cx+sz},#{cy+sz} #{cx-sz},#{cy+sz}" fill="#{acc}"/>),
      ~s(<polygon points="#{cx},#{cy-h} #{cx+h},#{cy+h} #{cx-h},#{cy+h}" fill="#{bright}"/>),
      ~s(<circle cx="#{cx}" cy="#{cy+div(sz,4)}" r="#{div(sz,5)}" fill="#{dark}"/>),
    ]
    |> Enum.join("")
  end

  defp twin_eyes(seed, acc, bright, dark, mid, eye_y, spread, sz) do
    single_eye(seed, 3,  @cx-spread, eye_y, sz, acc, bright, dark, mid) <>
    single_eye(seed, 30, @cx+spread, eye_y, sz, acc, bright, dark, mid)
  end

  defp cyclops_eye(seed, acc, bright, dark, mid, eye_y) do
    bs = 36 + jitter(seed, 5, 18)
    single_eye(seed, 3, @cx, eye_y, bs, acc, bright, dark, mid)
  end

  defp visor_eye(seed, acc, bright, dark, mid, eye_y) do
    vh = 14 + jitter(seed, 5, 14)
    vw = 146 + jitter(seed, 6, 28)
    vx = @cx - div(vw, 2)
    [
      ~s(<rect x="#{vx-5}" y="#{eye_y-div(vh,2)-5}" width="#{vw+10}" height="#{vh+10}" rx="12" fill="#{dark}"/>),
      ~s(<rect x="#{vx}" y="#{eye_y-div(vh,2)}" width="#{vw}" height="#{vh}" rx="8" fill="#{mid}"/>),
      ~s(<rect x="#{vx+4}" y="#{eye_y-5}" width="#{vw-8}" height="10" rx="5" fill="#{acc}"/>),
      ~s(<rect x="#{vx+4}" y="#{eye_y-5}" width="#{div(vw*28,100)}" height="10" rx="5" fill="#{bright}" opacity="0.95"/>),
      ~s(<rect x="#{vx+div(vw,2)}" y="#{eye_y-5}" width="#{div(vw*18,100)}" height="10" rx="5" fill="#{bright}" opacity="0.6"/>),
    ]
    |> Enum.join("")
  end

  defp triple_eyes(seed, acc, bright, dark, mid, eye_y) do
    s3 = 13 + jitter(seed, 5, 8)
    [
      single_eye(seed, 3,  @cx-52, eye_y,   s3,   acc, bright, dark, mid),
      single_eye(seed, 30, @cx,    eye_y-4, s3+4, acc, bright, dark, mid),
      single_eye(seed, 31, @cx+52, eye_y,   s3,   acc, bright, dark, mid),
    ]
    |> Enum.join("")
  end

  defp quad_eyes(seed, acc, bright, dark, mid, eye_y, spread, sz) do
    sq = div(sz, 2) + 4
    [
      single_eye(seed, 3,  @cx-spread, eye_y-sq, sz, acc, bright, dark, mid),
      single_eye(seed, 30, @cx+spread, eye_y-sq, sz, acc, bright, dark, mid),
      single_eye(seed, 31, @cx-spread, eye_y+sq, sz, acc, bright, dark, mid),
      single_eye(seed, 32, @cx+spread, eye_y+sq, sz, acc, bright, dark, mid),
    ]
    |> Enum.join("")
  end

  defp wide_rect_eyes(seed, acc, bright, dark, eye_y, spread) do
    ew = 46 + jitter(seed, 5, 18)
    eh = 16 + jitter(seed, 6, 12)
    [-1, 1]
    |> Enum.map_join("", fn s ->
      bx = @cx + s*spread - div(ew, 2)
      [
        ~s(<rect x="#{bx-4}" y="#{eye_y-div(eh,2)-4}" width="#{ew+8}" height="#{eh+8}" rx="8" fill="#{dark}"/>),
        ~s(<rect x="#{bx}" y="#{eye_y-div(eh,2)}" width="#{ew}" height="#{eh}" rx="5" fill="#{acc}" opacity="0.85"/>),
        ~s(<rect x="#{bx+4}" y="#{eye_y-3}" width="#{div(ew*35,100)}" height="6" rx="3" fill="#{bright}"/>),
      ]
      |> Enum.join("")
    end)
  end

  defp stacked_eyes(seed, acc, bright, dark, mid, eye_y, spread, sz) do
    [
      single_eye(seed, 3,  @cx-spread, eye_y-14, sz,   acc, bright, dark, mid),
      single_eye(seed, 30, @cx-spread, eye_y+18, sz-4, acc, bright, dark, mid),
      single_eye(seed, 31, @cx+spread, eye_y,    sz,   acc, bright, dark, mid),
    ]
    |> Enum.join("")
  end

  defp cracked_eyes(seed, acc, bright, dark, mid, eye_y, spread) do
    sz_l  = 24 + jitter(seed, 5, 10)
    sz_r  = 10 + jitter(seed, 6, 7)
    bad_x = @cx - spread
    [
      single_eye(seed, 3, bad_x, eye_y, sz_l, acc, bright, dark, mid),
      ~s(<line x1="#{bad_x-6}" y1="#{eye_y-32}" x2="#{bad_x+14}" y2="#{eye_y+28}" stroke="#{acc}" stroke-width="3" opacity="0.8"/>),
      ~s(<line x1="#{bad_x+4}" y1="#{eye_y-22}" x2="#{bad_x-12}" y2="#{eye_y+18}" stroke="#{acc}" stroke-width="1.8" opacity="0.5"/>),
      single_eye(seed, 30, @cx+spread, eye_y, sz_r, acc, bright, dark, mid),
    ]
    |> Enum.join("")
  end

  defp t_visor_eye(seed, acc, bright, dark, mid, eye_y) do
    ts = 16 + jitter(seed, 5, 8)
    [
      ~s(<rect x="46" y="#{eye_y-14}" width="164" height="22" rx="9" fill="#{dark}"/>),
      ~s(<rect x="50" y="#{eye_y-10}" width="156" height="14" rx="6" fill="#{acc}" opacity="0.7"/>),
      ~s(<rect x="50" y="#{eye_y-10}" width="50" height="14" rx="6" fill="#{bright}" opacity="0.9"/>),
      single_eye(seed, 3, @cx, eye_y+36, ts, acc, bright, dark, mid),
    ]
    |> Enum.join("")
  end

  defp orbital_ring(seed, acc, bright, dark, eye_y) do
    n      = 5 + jitter(seed, 5, 5)
    ring_r = 34 + jitter(seed, 6, 18)
    cs     = 7 + jitter(seed, 7, 5)
    sensors = Enum.map_join(0..(n-1), "", fn i ->
      a  = i / n * :math.pi() * 2 - :math.pi() / 2
      ex = round(@cx + ring_r * :math.cos(a))
      ey = round(eye_y + ring_r * :math.sin(a))
      ~s(<circle cx="#{ex}" cy="#{ey}" r="#{cs}" fill="#{acc}"/>) <>
      ~s(<circle cx="#{ex}" cy="#{ey}" r="#{div(cs*55,100)}" fill="#{bright}"/>)
    end)
    [
      ~s(<circle cx="#{@cx}" cy="#{eye_y}" r="#{ring_r+cs+6}" fill="#{dark}"/>),
      sensors,
      ~s(<circle cx="#{@cx}" cy="#{eye_y}" r="14" fill="#{dark}"/>),
      ~s(<circle cx="#{@cx}" cy="#{eye_y}" r="7" fill="#{acc}"/>),
      ~s(<circle cx="#{@cx}" cy="#{eye_y}" r="3" fill="#{bright}"/>),
    ]
    |> Enum.join("")
  end

  defp five_x_eyes(seed, acc, bright, dark, mid, eye_y, spread, _sz) do
    sc = 11 + jitter(seed, 5, 6)
    [
      single_eye(seed, 3,  @cx,         eye_y,    sc+4, acc, bright, dark, mid),
      single_eye(seed, 30, @cx-spread,  eye_y-22, sc,   acc, bright, dark, mid),
      single_eye(seed, 31, @cx+spread,  eye_y-22, sc,   acc, bright, dark, mid),
      single_eye(seed, 32, @cx-spread,  eye_y+22, sc,   acc, bright, dark, mid),
      single_eye(seed, 33, @cx+spread,  eye_y+22, sc,   acc, bright, dark, mid),
    ]
    |> Enum.join("")
  end

  defp tall_slot_eyes(acc, dark, mid, eye_y, spread) do
    sv = 10
    [-1, 1]
    |> Enum.map_join("", fn s ->
      cx = @cx + s*spread
      [
        ~s(<rect x="#{cx-sv-5}" y="#{eye_y-sv*2-5}" width="#{sv*2+10}" height="#{sv*4+10}" rx="#{sv+4}" fill="#{dark}"/>),
        ~s(<ellipse cx="#{cx}" cy="#{eye_y}" rx="#{sv}" ry="#{sv*2}" fill="#{mid}"/>),
        ~s(<ellipse cx="#{cx}" cy="#{eye_y}" rx="#{div(sv,2)}" ry="#{sv+div(sv,2)}" fill="#{acc}"/>),
        ~s(<ellipse cx="#{cx}" cy="#{eye_y}" rx="#{div(sv,4)}" ry="#{sv}" fill="#{dark}"/>),
      ]
      |> Enum.join("")
    end)
  end

  # ---------------------------------------------------------------------------
  # brow (salt 4)
  # ---------------------------------------------------------------------------
  defp brow(seed, acc, bright, dark, mid, eye_y) do
    by = eye_y - 30
    case rng(seed, 4, 10) do
      0 -> ""
      1 -> brow_flat_ridge(by, dark, mid)
      2 -> brow_v_angle(by, dark, mid)
      3 -> brow_two_plates(by, dark, mid)
      4 -> brow_glow_strip(by, acc, bright)
      5 -> brow_riveted(by, dark, mid)
      6 -> brow_sensor_dots(seed, by, acc, dark)
      7 -> brow_w_shape(by, dark, mid)
      8 -> brow_angled_cuts(by, dark)
      9 -> brow_triple_pip(by, acc, dark)
    end
  end

  defp brow_flat_ridge(by, dark, mid) do
    [
      ~s(<rect x="40" y="#{by}" width="176" height="13" rx="6" fill="#{dark}"/>),
      ~s(<rect x="44" y="#{by+3}" width="168" height="5" rx="2" fill="#{mid}" opacity="0.55"/>),
    ]
    |> Enum.join("")
  end

  defp brow_v_angle(by, dark, mid) do
    pts = "44,#{by+14} 128,#{by} 212,#{by+14}"
    [
      ~s(<polyline points="#{pts}" fill="none" stroke="#{dark}" stroke-width="11" stroke-linejoin="round" stroke-linecap="round"/>),
      ~s(<polyline points="#{pts}" fill="none" stroke="#{mid}" stroke-width="4" stroke-linejoin="round" stroke-linecap="round" opacity="0.5"/>),
    ]
    |> Enum.join("")
  end

  defp brow_two_plates(by, dark, mid) do
    [
      ~s(<rect x="40" y="#{by}" width="68" height="12" rx="5" fill="#{dark}"/>),
      ~s(<rect x="148" y="#{by}" width="68" height="12" rx="5" fill="#{dark}"/>),
      ~s(<rect x="43" y="#{by+3}" width="62" height="5" rx="2" fill="#{mid}" opacity="0.5"/>),
      ~s(<rect x="151" y="#{by+3}" width="62" height="5" rx="2" fill="#{mid}" opacity="0.5"/>),
    ]
    |> Enum.join("")
  end

  defp brow_glow_strip(by, acc, bright) do
    [
      ~s(<rect x="48" y="#{by+2}" width="160" height="8" rx="4" fill="#{acc}" opacity="0.22"/>),
      ~s(<rect x="52" y="#{by+4}" width="56" height="4" rx="2" fill="#{acc}" opacity="0.85"/>),
      ~s(<rect x="148" y="#{by+4}" width="56" height="4" rx="2" fill="#{acc}" opacity="0.85"/>),
      ~s(<rect x="115" y="#{by+4}" width="26" height="4" rx="2" fill="#{bright}" opacity="0.4"/>),
    ]
    |> Enum.join("")
  end

  defp brow_riveted(by, dark, mid) do
    rivets = [56, 84, 128, 172, 200]
    |> Enum.map_join("", fn x ->
      ~s(<circle cx="#{x}" cy="#{by+7}" r="5" fill="#{mid}"/>) <>
      ~s(<circle cx="#{x}" cy="#{by+7}" r="2.5" fill="#{dark}"/>)
    end)
    [
      ~s(<rect x="36" y="#{by-2}" width="184" height="18" rx="6" fill="#{dark}"/>),
      rivets,
    ]
    |> Enum.join("")
  end

  defp brow_sensor_dots(_seed, by, acc, dark) do
    dots = Enum.map_join(0..10, "", fn i ->
      opacity = Float.round(0.35 + i * 0.055, 2)
      ~s(<circle cx="#{52+i*15}" cy="#{by+7}" r="3.5" fill="#{acc}" opacity="#{opacity}"/>)
    end)
    [
      ~s(<rect x="42" y="#{by}" width="172" height="15" rx="6" fill="#{dark}"/>),
      dots,
    ]
    |> Enum.join("")
  end

  defp brow_w_shape(by, dark, mid) do
    pts = "40,#{by+14} 66,#{by} 100,#{by+10} 128,#{by} 156,#{by+10} 190,#{by} 216,#{by+14}"
    [
      ~s(<polyline points="#{pts}" fill="none" stroke="#{dark}" stroke-width="9" stroke-linejoin="round" stroke-linecap="round"/>),
      ~s(<polyline points="#{pts}" fill="none" stroke="#{mid}" stroke-width="3.5" stroke-linejoin="round" stroke-linecap="round" opacity="0.45"/>),
    ]
    |> Enum.join("")
  end

  defp brow_angled_cuts(by, dark) do
    [-1, 1]
    |> Enum.map_join("", fn s ->
      ~s(<polygon points="#{@cx+s*8},#{by+12} #{@cx+s*46},#{by+12} #{@cx+s*58},#{by}" fill="#{dark}"/>)
    end)
  end

  defp brow_triple_pip(by, acc, dark) do
    [-36, 0, 36]
    |> Enum.map_join("", fn dx ->
      [
        ~s(<rect x="#{@cx+dx-14}" y="#{by}" width="28" height="12" rx="4" fill="#{dark}"/>),
        ~s(<rect x="#{@cx+dx-11}" y="#{by+3}" width="22" height="6" rx="2" fill="#{acc}" opacity="0.7"/>),
      ]
      |> Enum.join("")
    end)
  end

  # ---------------------------------------------------------------------------
  # nose (salt 5)
  # ---------------------------------------------------------------------------
  defp nose(seed, acc, bright, dark, eye_y) do
    ny = eye_y + 40
    case rng(seed, 5, 9) do
      0 -> ""
      1 -> nose_sensor_pair(ny, acc, dark)
      2 -> nose_triangle(ny, dark)
      3 -> nose_rect_sensor(ny, acc, bright, dark)
      4 -> nose_twin_vents(ny, acc, dark)
      5 -> nose_glow_orb(ny, acc, dark)
      6 -> nose_chevron(ny, acc, dark)
      7 -> nose_hbar(ny, acc, dark)
      8 -> nose_three_dots(ny, acc, dark)
    end
  end

  defp nose_sensor_pair(ny, acc, dark) do
    [-10, 10]
    |> Enum.map_join("", fn dx ->
      ~s(<circle cx="#{@cx+dx}" cy="#{ny}" r="6" fill="#{dark}"/>) <>
      ~s(<circle cx="#{@cx+dx}" cy="#{ny}" r="3" fill="#{acc}" opacity="0.9"/>)
    end)
  end

  defp nose_triangle(ny, dark) do
    ~s(<polygon points="#{@cx},#{ny-10} #{@cx-10},#{ny+8} #{@cx+10},#{ny+8}" fill="#{dark}"/>)
  end

  defp nose_rect_sensor(ny, acc, bright, dark) do
    [
      ~s(<rect x="#{@cx-14}" y="#{ny-7}" width="28" height="14" rx="5" fill="#{dark}"/>),
      ~s(<rect x="#{@cx-11}" y="#{ny-4}" width="22" height="8" rx="3" fill="#{acc}" opacity="0.75"/>),
      ~s(<circle cx="#{@cx-3}" cy="#{ny}" r="2" fill="#{bright}" opacity="0.8"/>),
    ]
    |> Enum.join("")
  end

  defp nose_twin_vents(ny, acc, dark) do
    [-1, 1]
    |> Enum.map_join("", fn s ->
      bx   = @cx + s*12 - 5
      bars = Enum.map_join(0..2, "", fn i ->
        ~s(<rect x="#{bx+1}" y="#{ny-4+i*4}" width="8" height="2" rx="1" fill="#{acc}" opacity="0.65"/>)
      end)
      [~s(<rect x="#{bx}" y="#{ny-6}" width="10" height="12" rx="3" fill="#{dark}"/>), bars]
      |> Enum.join("")
    end)
  end

  defp nose_glow_orb(ny, acc, dark) do
    [
      ~s(<circle cx="#{@cx}" cy="#{ny}" r="10" fill="#{dark}"/>),
      ~s(<circle cx="#{@cx}" cy="#{ny}" r="6" fill="#{acc}" opacity="0.9"/>),
      ~s(<circle cx="#{@cx-3}" cy="#{ny-2}" r="2.5" fill="white" opacity="0.45"/>),
    ]
    |> Enum.join("")
  end

  defp nose_chevron(ny, acc, dark) do
    pts = "#{@cx-10},#{ny+8} #{@cx},#{ny-6} #{@cx+10},#{ny+8}"
    [
      ~s(<polyline points="#{pts}" fill="none" stroke="#{dark}" stroke-width="6" stroke-linejoin="round" stroke-linecap="round"/>),
      ~s(<polyline points="#{pts}" fill="none" stroke="#{acc}" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round" opacity="0.8"/>),
    ]
    |> Enum.join("")
  end

  defp nose_hbar(ny, acc, dark) do
    [
      ~s(<rect x="#{@cx-18}" y="#{ny-4}" width="36" height="8" rx="4" fill="#{dark}"/>),
      ~s(<rect x="#{@cx-14}" y="#{ny-2}" width="28" height="4" rx="2" fill="#{acc}" opacity="0.7"/>),
    ]
    |> Enum.join("")
  end

  defp nose_three_dots(ny, acc, dark) do
    [-14, 0, 14]
    |> Enum.map_join("", fn dx ->
      ~s(<circle cx="#{@cx+dx}" cy="#{ny}" r="4" fill="#{dark}"/>) <>
      ~s(<circle cx="#{@cx+dx}" cy="#{ny}" r="2" fill="#{acc}" opacity="0.8"/>)
    end)
  end

  # ---------------------------------------------------------------------------
  # cheeks (salt 6)
  # ---------------------------------------------------------------------------
  defp cheeks(seed, acc, bright, dark, mid, eye_y) do
    cy = eye_y + 28
    case rng(seed, 6, 10) do
      0 -> ""
      1 -> cheek_vent_slats(cy, dark, mid)
      2 -> cheek_bolted_panel(cy, dark, mid)
      3 -> cheek_circular_sensor(cy, acc, bright, dark)
      4 -> cheek_exhaust_nozzles(cy, dark, mid)
      5 -> cheek_antenna(eye_y, acc, bright, dark)
      6 -> cheek_speaker_rings(cy, acc, dark)
      7 -> cheek_warning_lights(cy, acc, dark)
      8 -> cheek_data_strips(seed, cy, acc, dark)
      9 -> cheek_camera_lens(cy, acc, dark, mid)
    end
  end

  defp cheek_vent_slats(cy, dark, mid) do
    [-1, 1]
    |> Enum.map_join("", fn s ->
      bx    = @cx + s*76 - if s > 0, do: 4, else: 24
      slats = Enum.map_join(0..3, "", fn i ->
        ~s(<rect x="#{bx+3}" y="#{cy-13+i*9}" width="22" height="5" rx="2" fill="#{mid}" opacity="0.75"/>)
      end)
      [~s(<rect x="#{bx}" y="#{cy-18}" width="28" height="38" rx="5" fill="#{dark}"/>), slats]
      |> Enum.join("")
    end)
  end

  defp cheek_bolted_panel(cy, dark, mid) do
    [-1, 1]
    |> Enum.map_join("", fn s ->
      cx    = @cx + s*80
      bolts = [[-8,-8],[8,-8],[-8,8],[8,8]]
      |> Enum.map_join("", fn [dx, dy] ->
        ~s(<circle cx="#{cx+dx}" cy="#{cy+dy}" r="4.5" fill="#{mid}"/>) <>
        ~s(<circle cx="#{cx+dx}" cy="#{cy+dy}" r="2" fill="#{dark}"/>)
      end)
      [~s(<rect x="#{cx-17}" y="#{cy-22}" width="34" height="44" rx="7" fill="#{dark}" opacity="0.75"/>), bolts]
      |> Enum.join("")
    end)
  end

  defp cheek_circular_sensor(cy, acc, bright, dark) do
    [-1, 1]
    |> Enum.map_join("", fn s ->
      cx = @cx + s*82
      [
        ~s(<circle cx="#{cx}" cy="#{cy}" r="18" fill="#{dark}"/>),
        ~s(<circle cx="#{cx}" cy="#{cy}" r="13" fill="#{acc}" opacity="0.28"/>),
        ~s(<circle cx="#{cx}" cy="#{cy}" r="7" fill="#{acc}" opacity="0.9"/>),
        ~s(<circle cx="#{cx}" cy="#{cy}" r="3.5" fill="#{bright}"/>),
        ~s(<circle cx="#{cx-3}" cy="#{cy-3}" r="1.5" fill="white" opacity="0.45"/>),
      ]
      |> Enum.join("")
    end)
  end

  defp cheek_exhaust_nozzles(cy, dark, mid) do
    [-1, 1]
    |> Enum.map_join("", fn s ->
      bx = if s > 0, do: 200, else: 26
      Enum.map_join(0..2, "", fn i ->
        ox = if s > 0, do: bx-16, else: bx
        [
          ~s(<rect x="#{ox}" y="#{cy-16+i*14}" width="20" height="10" rx="5" fill="#{dark}"/>),
          ~s(<rect x="#{ox+2}" y="#{cy-13+i*14}" width="16" height="6" rx="3" fill="#{mid}" opacity="0.65"/>),
        ]
        |> Enum.join("")
      end)
    end)
  end

  defp cheek_antenna(eye_y, acc, bright, dark) do
    [-1, 1]
    |> Enum.map_join("", fn s ->
      ax = @cx + s*76
      ay = eye_y - 24
      [
        ~s(<rect x="#{ax-3}" y="#{ay-34}" width="7" height="34" rx="3" fill="#{dark}"/>),
        ~s(<circle cx="#{ax}" cy="#{ay-38}" r="8" fill="#{dark}"/>),
        ~s(<circle cx="#{ax}" cy="#{ay-38}" r="5" fill="#{acc}"/>),
        ~s(<circle cx="#{ax}" cy="#{ay-38}" r="2.5" fill="#{bright}"/>),
      ]
      |> Enum.join("")
    end)
  end

  defp cheek_speaker_rings(cy, acc, dark) do
    [-1, 1]
    |> Enum.map_join("", fn s ->
      cx    = @cx + s*82
      rings = [17, 13, 9, 5]
      |> Enum.map_join("", fn rr ->
        color = if rem(rr, 4) == 1, do: acc, else: dark
        ~s(<circle cx="#{cx}" cy="#{cy}" r="#{rr}" fill="none" stroke="#{color}" stroke-width="1.5" opacity="0.75"/>)
      end)
      [
        ~s(<circle cx="#{cx}" cy="#{cy}" r="20" fill="#{dark}"/>),
        rings,
        ~s(<circle cx="#{cx}" cy="#{cy}" r="3" fill="#{acc}"/>),
      ]
      |> Enum.join("")
    end)
  end

  defp cheek_warning_lights(cy, acc, dark) do
    [-1, 1]
    |> Enum.map_join("", fn s ->
      cx = @cx + s*80
      [
        ~s(<rect x="#{cx-16}" y="#{cy-12}" width="32" height="24" rx="5" fill="#{dark}"/>),
        ~s(<rect x="#{cx-12}" y="#{cy-8}" width="10" height="16" rx="3" fill="#{acc}"/>),
        ~s(<rect x="#{cx+2}" y="#{cy-8}" width="10" height="16" rx="3" fill="#{acc}" opacity="0.35"/>),
      ]
      |> Enum.join("")
    end)
  end

  defp cheek_data_strips(seed, cy, acc, dark) do
    [-1, 1]
    |> Enum.map_join("", fn s ->
      bx     = @cx + s*72 - if s > 0, do: 0, else: 28
      strips = Enum.map_join(0..3, "", fn i ->
        bw = 8 + jitter(seed, i+40, 12)
        ~s(<rect x="#{bx+3}" y="#{cy-12+i*8}" width="#{bw}" height="4" rx="2" fill="#{acc}" opacity="0.7"/>)
      end)
      [~s(<rect x="#{bx}" y="#{cy-16}" width="28" height="32" rx="5" fill="#{dark}"/>), strips]
      |> Enum.join("")
    end)
  end

  defp cheek_camera_lens(cy, acc, dark, mid) do
    [-1, 1]
    |> Enum.map_join("", fn s ->
      cx = @cx + s*84
      [
        ~s(<rect x="#{cx-14}" y="#{cy-14}" width="28" height="28" rx="6" fill="#{dark}"/>),
        ~s(<circle cx="#{cx}" cy="#{cy}" r="10" fill="#{mid}"/>),
        ~s(<circle cx="#{cx}" cy="#{cy}" r="6" fill="#{acc}" opacity="0.85"/>),
        ~s(<circle cx="#{cx}" cy="#{cy}" r="3" fill="#{dark}"/>),
        ~s(<circle cx="#{cx-3}" cy="#{cy-3}" r="1.5" fill="white" opacity="0.4"/>),
      ]
      |> Enum.join("")
    end)
  end

  # ---------------------------------------------------------------------------
  # forehead (salt 7)
  # ---------------------------------------------------------------------------
  defp forehead(seed, acc, bright, dark, mid) do
    case rng(seed, 7, 10) do
      0 -> ""
      1 -> forehead_jewel(acc, bright, dark)
      2 -> forehead_vent_row(dark, mid)
      3 -> forehead_three_bolts(dark, mid)
      4 -> forehead_sensor_bar(seed, acc, dark, mid)
      5 -> forehead_fin_crest(acc, dark, mid)
      6 -> forehead_tri_antenna(acc, bright, dark)
      7 -> forehead_glow_band(acc, bright, dark)
      8 -> forehead_scope(acc, dark)
      9 -> forehead_data_ticker(seed, acc, dark)
    end
  end

  defp forehead_jewel(acc, bright, dark) do
    [
      ~s(<circle cx="#{@cx}" cy="42" r="15" fill="#{dark}"/>),
      ~s(<circle cx="#{@cx}" cy="42" r="10" fill="#{acc}"/>),
      ~s(<circle cx="#{@cx}" cy="42" r="5" fill="#{bright}"/>),
      ~s(<circle cx="#{@cx-4}" cy="39" r="2.5" fill="white" opacity="0.5"/>),
    ]
    |> Enum.join("")
  end

  defp forehead_vent_row(dark, mid) do
    vents = Enum.map_join(0..7, "", fn i ->
      ~s(<rect x="#{66+i*15}" y="30" width="9" height="12" rx="2" fill="#{mid}" opacity="0.7"/>)
    end)
    [~s(<rect x="58" y="26" width="140" height="20" rx="7" fill="#{dark}"/>), vents]
    |> Enum.join("")
  end

  defp forehead_three_bolts(dark, mid) do
    [64, 128, 192]
    |> Enum.map_join("", fn x ->
      [
        ~s(<circle cx="#{x}" cy="40" r="9" fill="#{dark}"/>),
        ~s(<circle cx="#{x}" cy="40" r="5.5" fill="#{mid}"/>),
        ~s(<circle cx="#{x}" cy="40" r="2.5" fill="#{dark}"/>),
      ]
      |> Enum.join("")
    end)
  end

  defp forehead_sensor_bar(_seed, acc, dark, mid) do
    dots = Enum.map_join(0..6, "", fn i ->
      opacity = Float.round(0.35 + i * 0.09, 2)
      ~s(<circle cx="#{80+i*14}" cy="39" r="3.5" fill="#{acc}" opacity="#{opacity}"/>)
    end)
    [
      ~s(<rect x="68" y="28" width="120" height="22" rx="9" fill="#{dark}"/>),
      ~s(<rect x="72" y="32" width="112" height="14" rx="6" fill="#{mid}"/>),
      dots,
    ]
    |> Enum.join("")
  end

  defp forehead_fin_crest(acc, dark, mid) do
    [
      ~s(<polygon points="106,54 128,20 150,54" fill="#{dark}"/>),
      ~s(<polygon points="111,54 128,28 145,54" fill="#{mid}" opacity="0.55"/>),
      ~s(<line x1="128" y1="20" x2="128" y2="54" stroke="#{acc}" stroke-width="2.5" opacity="0.8"/>),
    ]
    |> Enum.join("")
  end

  defp forehead_tri_antenna(acc, _bright, dark) do
    [-30, 0, 30]
    |> Enum.with_index()
    |> Enum.map_join("", fn {dx, i} ->
      base_y  = 24 - i*6
      stem_h  = 26 + i*6
      [
        ~s(<rect x="#{@cx+dx-3}" y="#{base_y}" width="6" height="#{stem_h}" rx="3" fill="#{dark}"/>),
        ~s(<circle cx="#{@cx+dx}" cy="#{base_y-2}" r="5" fill="#{dark}"/>),
        ~s(<circle cx="#{@cx+dx}" cy="#{base_y-2}" r="3" fill="#{acc}"/>),
      ]
      |> Enum.join("")
    end)
  end

  defp forehead_glow_band(acc, bright, dark) do
    [
      ~s(<rect x="44" y="30" width="168" height="14" rx="6" fill="#{dark}"/>),
      ~s(<rect x="48" y="34" width="160" height="6" rx="3" fill="#{acc}" opacity="0.55"/>),
      ~s(<rect x="48" y="34" width="50" height="6" rx="3" fill="#{bright}" opacity="0.85"/>),
    ]
    |> Enum.join("")
  end

  defp forehead_scope(acc, dark) do
    [
      ~s(<circle cx="#{@cx}" cy="44" r="18" fill="#{dark}"/>),
      ~s(<circle cx="#{@cx}" cy="44" r="13" fill="none" stroke="#{acc}" stroke-width="2"/>),
      ~s(<circle cx="#{@cx}" cy="44" r="5" fill="#{acc}"/>),
      ~s(<line x1="#{@cx-18}" y1="44" x2="#{@cx-13}" y2="44" stroke="#{acc}" stroke-width="1.5" opacity="0.7"/>),
      ~s(<line x1="#{@cx+13}" y1="44" x2="#{@cx+18}" y2="44" stroke="#{acc}" stroke-width="1.5" opacity="0.7"/>),
      ~s(<line x1="#{@cx}" y1="26" x2="#{@cx}" y2="31" stroke="#{acc}" stroke-width="1.5" opacity="0.7"/>),
      ~s(<line x1="#{@cx}" y1="57" x2="#{@cx}" y2="62" stroke="#{acc}" stroke-width="1.5" opacity="0.7"/>),
    ]
    |> Enum.join("")
  end

  defp forehead_data_ticker(seed, acc, dark) do
    Enum.map_join(0..13, "", fn i ->
      bh      = 6 + jitter(seed, i+50, 8)
      bw      = 6 + jitter(seed, i+70, 6)
      opacity = Float.round(0.3 + jitter(seed, i+60, 50) / 100, 2)
      [
        ~s(<rect x="#{16+i*16}" y="28" width="#{bw}" height="#{bh+6}" rx="2" fill="#{dark}" opacity="0.85"/>),
        ~s(<rect x="#{17+i*16}" y="30" width="#{max(1, bw-2)}" height="#{bh}" rx="1" fill="#{acc}" opacity="#{opacity}"/>),
      ]
      |> Enum.join("")
    end)
  end

  # ---------------------------------------------------------------------------
  # mouth (salt 8)
  # ---------------------------------------------------------------------------
  defp mouth(seed, acc, bright, dark, mid, eye_y) do
    my = eye_y + 76 + jitter(seed, 8, 18)
    mw = 72 + jitter(seed, 80, 54)
    mx = @cx - div(mw, 2)
    case rng(seed, 8, 12) do
      0  -> mouth_grill(seed, my, mw, mx, acc, dark)
      1  -> mouth_dot_speaker(seed, my, mw, mx, acc, dark)
      2  -> mouth_single_slot(my, mw, mx, acc, bright, dark, mid)
      3  -> mouth_teeth(seed, my, mw, mx, acc, dark)
      4  -> mouth_exhaust_slats(seed, my, mw, mx, dark, mid)
      5  -> mouth_glowing_maw(my, mw, acc, bright, dark)
      6  -> mouth_segmented_jaw(seed, my, mw, mx, acc, dark, mid)
      7  -> mouth_precision_line(my, mw, mx, acc, dark)
      8  -> mouth_circular_intake(seed, my, acc, dark, mid)
      9  -> mouth_dual_slots(my, mw, mx, acc, bright, dark, mid)
      10 -> mouth_chevron(seed, my, mw, mx, acc, dark, mid)
      11 -> ""
    end
  end

  defp mouth_grill(seed, my, mw, mx, acc, dark) do
    bars = 4 + jitter(seed, 81, 5)
    mh   = 22 + jitter(seed, 82, 12)
    gap  = div(mh, bars)
    bar_svgs = Enum.map_join(0..(bars-1), "", fn i ->
      ~s(<rect x="#{mx}" y="#{my+i*gap}" width="#{mw}" height="#{gap-2}" rx="1.5" fill="#{acc}" opacity="0.8"/>)
    end)
    [~s(<rect x="#{mx-5}" y="#{my-5}" width="#{mw+10}" height="#{mh+10}" rx="9" fill="#{dark}"/>), bar_svgs]
    |> Enum.join("")
  end

  defp mouth_dot_speaker(seed, my, mw, mx, acc, dark) do
    cols = 7 + jitter(seed, 81, 5)
    rows = 3 + jitter(seed, 82, 2)
    mh   = rows * 10
    cg   = div(mw, cols)
    dots = for row <- 0..(rows-1), col <- 0..(cols-1) do
      cx = mx + col*cg + div(cg, 2)
      cy = my + row*10 + 5
      ~s(<circle cx="#{cx}" cy="#{cy}" r="2.8" fill="#{acc}" opacity="0.85"/>)
    end
    |> Enum.join("")
    [~s(<rect x="#{mx-5}" y="#{my-5}" width="#{mw+10}" height="#{mh+10}" rx="9" fill="#{dark}"/>), dots]
    |> Enum.join("")
  end

  defp mouth_single_slot(my, mw, mx, acc, bright, dark, mid) do
    [
      ~s(<rect x="#{mx-5}" y="#{my-5}" width="#{mw+10}" height="26" rx="11" fill="#{dark}"/>),
      ~s(<rect x="#{mx}" y="#{my}" width="#{mw}" height="16" rx="8" fill="#{mid}"/>),
      ~s(<rect x="#{mx+4}" y="#{my+3}" width="#{div(mw*32,100)}" height="8" rx="4" fill="#{acc}" opacity="0.95"/>),
      ~s(<rect x="#{mx+div(mw,2)}" y="#{my+3}" width="#{div(mw*18,100)}" height="8" rx="4" fill="#{bright}" opacity="0.6"/>),
    ]
    |> Enum.join("")
  end

  defp mouth_teeth(seed, my, mw, mx, acc, dark) do
    n  = 6 + jitter(seed, 81, 5)
    tw = div(mw, n)
    teeth = Enum.map_join(0..(n-1), "", fn i ->
      fill    = if rem(i, 2) == 0, do: acc, else: dark
      opacity = if rem(i, 2) == 0, do: "0.88", else: "1"
      ~s(<rect x="#{mx+i*tw+1}" y="#{my}" width="#{tw-2}" height="25" rx="3" fill="#{fill}" opacity="#{opacity}"/>)
    end)
    [~s(<rect x="#{mx-5}" y="#{my-5}" width="#{mw+10}" height="34" rx="8" fill="#{dark}"/>), teeth]
    |> Enum.join("")
  end

  defp mouth_exhaust_slats(seed, my, mw, mx, dark, mid) do
    n   = 5 + jitter(seed, 81, 4)
    mh  = 26
    gap = div(mh, n)
    slats = Enum.map_join(0..(n-1), "", fn i ->
      ~s(<rect x="#{mx}" y="#{my+i*gap}" width="#{mw}" height="#{gap-2}" rx="1" fill="#{mid}" opacity="0.65"/>)
    end)
    [~s(<rect x="#{mx-5}" y="#{my-5}" width="#{mw+10}" height="#{mh+10}" rx="9" fill="#{dark}"/>), slats]
    |> Enum.join("")
  end

  defp mouth_glowing_maw(my, mw, acc, bright, dark) do
    r1 = div(mw, 2)
    [
      ~s(<ellipse cx="#{@cx}" cy="#{my+14}" rx="#{r1}" ry="18" fill="#{dark}"/>),
      ~s(<ellipse cx="#{@cx}" cy="#{my+14}" rx="#{r1-5}" ry="12" fill="#{acc}" opacity="0.28"/>),
      ~s(<ellipse cx="#{@cx}" cy="#{my+14}" rx="#{r1-11}" ry="7" fill="#{acc}" opacity="0.75"/>),
      ~s(<ellipse cx="#{@cx}" cy="#{my+14}" rx="#{r1-20}" ry="3" fill="#{bright}"/>),
    ]
    |> Enum.join("")
  end

  defp mouth_segmented_jaw(seed, my, mw, mx, acc, dark, mid) do
    n  = 3 + jitter(seed, 81, 3)
    sw = div(mw, n)
    cells = Enum.map_join(0..(n-1), "", fn i ->
      [
        ~s(<rect x="#{mx+i*sw+2}" y="#{my}" width="#{sw-4}" height="20" rx="4" fill="#{mid}"/>),
        ~s(<rect x="#{mx+i*sw+5}" y="#{my+3}" width="#{sw-10}" height="8" rx="2" fill="#{acc}" opacity="0.75"/>),
      ]
      |> Enum.join("")
    end)
    [~s(<rect x="#{mx-5}" y="#{my-5}" width="#{mw+10}" height="30" rx="9" fill="#{dark}"/>), cells]
    |> Enum.join("")
  end

  defp mouth_precision_line(my, mw, mx, acc, dark) do
    [
      ~s(<rect x="#{mx}" y="#{my+7}" width="#{mw}" height="7" rx="3" fill="#{dark}"/>),
      ~s(<rect x="#{mx+6}" y="#{my+9}" width="#{mw-12}" height="3" rx="1.5" fill="#{acc}" opacity="0.85"/>),
    ]
    |> Enum.join("")
  end

  defp mouth_circular_intake(seed, my, acc, dark, mid) do
    cr = 22 + jitter(seed, 81, 14)
    cy = my + cr + 2
    blades = Enum.map_join(0..5, "", fn i ->
      a  = i / 6 * :math.pi() * 2
      ex = round(@cx + (cr-8) * :math.cos(a))
      ey = round(cy + (cr-8) * :math.sin(a))
      ~s[<rect x="#{ex-3}" y="#{ey-7}" width="6" height="14" rx="2" fill="#{dark}" transform="rotate(#{i*60+15},#{ex},#{ey})"/>]
    end)
    [
      ~s(<circle cx="#{@cx}" cy="#{cy}" r="#{cr+9}" fill="#{dark}"/>),
      ~s(<circle cx="#{@cx}" cy="#{cy}" r="#{cr}" fill="#{mid}"/>),
      ~s(<circle cx="#{@cx}" cy="#{cy}" r="#{cr-6}" fill="#{acc}" opacity="0.22"/>),
      blades,
      ~s(<circle cx="#{@cx}" cy="#{cy}" r="9" fill="#{dark}"/>),
      ~s(<circle cx="#{@cx}" cy="#{cy}" r="5" fill="#{acc}"/>),
    ]
    |> Enum.join("")
  end

  defp mouth_dual_slots(my, mw, mx, acc, bright, dark, mid) do
    [
      ~s(<rect x="#{mx-5}" y="#{my-5}" width="#{mw+10}" height="38" rx="9" fill="#{dark}"/>),
      ~s(<rect x="#{mx}" y="#{my}" width="#{mw}" height="11" rx="5" fill="#{mid}"/>),
      ~s(<rect x="#{mx+4}" y="#{my+2}" width="#{div(mw*30,100)}" height="7" rx="3" fill="#{acc}" opacity="0.9"/>),
      ~s(<rect x="#{mx}" y="#{my+17}" width="#{mw}" height="11" rx="5" fill="#{mid}"/>),
      ~s(<rect x="#{mx+div(mw,2)}" y="#{my+19}" width="#{div(mw*25,100)}" height="7" rx="3" fill="#{bright}" opacity="0.9"/>),
    ]
    |> Enum.join("")
  end

  defp mouth_chevron(seed, my, mw, mx, acc, dark, mid) do
    n  = 4 + jitter(seed, 81, 4)
    sw = div(mw, n)
    chevrons = Enum.map_join(0..(n-1), "", fn i ->
      bx   = mx + i*sw
      fill = if rem(i, 2) == 0, do: acc, else: mid
      ~s(<polygon points="#{bx},#{my+25} #{bx+div(sw,2)},#{my} #{bx+sw},#{my+25}" fill="#{fill}" opacity="0.8"/>)
    end)
    [~s(<rect x="#{mx-5}" y="#{my-5}" width="#{mw+10}" height="30" rx="9" fill="#{dark}"/>), chevrons]
    |> Enum.join("")
  end

  # ---------------------------------------------------------------------------
  # chin (salt 9)
  # ---------------------------------------------------------------------------
  defp chin(seed, acc, bright, dark, mid, eye_y) do
    cy = eye_y + 120 + jitter(seed, 9, 12)
    case rng(seed, 9, 9) do
      0 -> ""
      1 -> chin_bolt_row(cy, dark, mid)
      2 -> chin_jaw_plate(cy, dark, mid)
      3 -> chin_exhaust_trio(cy, dark, mid)
      4 -> chin_data_bar(seed, cy, acc, dark)
      5 -> chin_glow_strip(cy, acc, bright, dark)
      6 -> chin_segmented_cells(seed, cy, acc, dark, mid)
      7 -> chin_wide_intake(cy, acc, dark, mid)
      8 -> chin_corner_tabs(cy, acc, dark)
    end
  end

  defp chin_bolt_row(cy, dark, mid) do
    [-36, -18, 0, 18, 36]
    |> Enum.map_join("", fn dx ->
      [
        ~s(<circle cx="#{@cx+dx}" cy="#{cy}" r="7" fill="#{dark}"/>),
        ~s(<circle cx="#{@cx+dx}" cy="#{cy}" r="4" fill="#{mid}"/>),
        ~s(<line x1="#{@cx+dx-3}" y1="#{cy}" x2="#{@cx+dx+3}" y2="#{cy}" stroke="#{dark}" stroke-width="1.5"/>),
        ~s(<line x1="#{@cx+dx}" y1="#{cy-3}" x2="#{@cx+dx}" y2="#{cy+3}" stroke="#{dark}" stroke-width="1.5"/>),
      ]
      |> Enum.join("")
    end)
  end

  defp chin_jaw_plate(cy, dark, mid) do
    [
      ~s(<rect x="62" y="#{cy-9}" width="132" height="20" rx="8" fill="#{dark}"/>),
      ~s(<rect x="68" y="#{cy-5}" width="120" height="12" rx="5" fill="#{mid}" opacity="0.65"/>),
    ]
    |> Enum.join("")
  end

  defp chin_exhaust_trio(cy, dark, mid) do
    [-28, 0, 28]
    |> Enum.map_join("", fn dx ->
      [
        ~s(<rect x="#{@cx+dx-9}" y="#{cy-5}" width="18" height="22" rx="7" fill="#{dark}"/>),
        ~s(<rect x="#{@cx+dx-6}" y="#{cy-2}" width="12" height="16" rx="5" fill="#{mid}" opacity="0.65"/>),
      ]
      |> Enum.join("")
    end)
  end

  defp chin_data_bar(_seed, cy, acc, dark) do
    Enum.map_join(0..11, "", fn i ->
      fill    = if rem(i, 3) == 0, do: acc, else: dark
      opacity = if rem(i, 3) == 0, do: "0.85", else: "0.45"
      ~s(<rect x="#{72+i*10}" y="#{cy-5}" width="7" height="12" rx="2" fill="#{fill}" opacity="#{opacity}"/>)
    end)
  end

  defp chin_glow_strip(cy, acc, bright, dark) do
    [
      ~s(<rect x="74" y="#{cy-5}" width="108" height="10" rx="5" fill="#{dark}"/>),
      ~s(<rect x="78" y="#{cy-3}" width="100" height="6" rx="3" fill="#{acc}" opacity="0.65"/>),
      ~s(<rect x="78" y="#{cy-3}" width="34" height="6" rx="3" fill="#{bright}" opacity="0.9"/>),
    ]
    |> Enum.join("")
  end

  defp chin_segmented_cells(_seed, cy, acc, dark, mid) do
    Enum.map_join(0..3, "", fn i ->
      fill = if rem(i, 2) == 0, do: acc, else: mid
      [
        ~s(<rect x="#{84+i*22}" y="#{cy-7}" width="18" height="16" rx="4" fill="#{dark}"/>),
        ~s(<rect x="#{86+i*22}" y="#{cy-5}" width="14" height="12" rx="3" fill="#{fill}" opacity="0.75"/>),
      ]
      |> Enum.join("")
    end)
  end

  defp chin_wide_intake(cy, acc, dark, mid) do
    [
      ~s(<rect x="78" y="#{cy-6}" width="100" height="18" rx="7" fill="#{dark}"/>),
      ~s(<rect x="82" y="#{cy-2}" width="92" height="10" rx="4" fill="#{mid}"/>),
      ~s(<rect x="86" y="#{cy}" width="30" height="6" rx="3" fill="#{acc}" opacity="0.8"/>),
    ]
    |> Enum.join("")
  end

  defp chin_corner_tabs(cy, acc, dark) do
    [-1, 1]
    |> Enum.map_join("", fn s ->
      bx = @cx + s*40 - if s > 0, do: 0, else: 20
      [
        ~s(<rect x="#{bx}" y="#{cy-8}" width="20" height="18" rx="5" fill="#{dark}"/>),
        ~s(<rect x="#{bx+2}" y="#{cy-6}" width="16" height="14" rx="3" fill="#{acc}" opacity="0.7"/>),
      ]
      |> Enum.join("")
    end)
  end

  # ---------------------------------------------------------------------------
  # extras (salt 10)
  # ---------------------------------------------------------------------------
  defp extras(seed, acc, _bright, dark, mid, eye_y) do
    case rng(seed, 10, 12) do
      0  -> ""
      1  -> extras_corner_fans(acc, dark, mid)
      2  -> extras_side_pipe(seed, dark, mid)
      3  -> extras_head_cables(eye_y, dark, mid)
      4  -> extras_circuit_traces(acc, dark, mid)
      5  -> extras_status_column(seed, acc, dark, mid)
      6  -> extras_neck_bolts(eye_y, dark, mid)
      7  -> extras_temple_screws(eye_y, dark, mid)
      8  -> extras_hazard_stripes(acc, dark)
      9  -> extras_charge_bars(seed, acc, dark, mid)
      10 -> extras_scan_bands(acc, dark)
      11 -> extras_corner_brackets(acc, dark)
    end
  end

  defp fan_svg(cx, cy, acc, dark, mid) do
    blades = Enum.map_join(0..5, "", fn i ->
      a  = i / 6 * :math.pi() * 2
      x1 = cx + round(5  * :math.cos(a))
      y1 = cy + round(5  * :math.sin(a))
      x2 = cx + round(16 * :math.cos(a - 0.45))
      y2 = cy + round(16 * :math.sin(a - 0.45))
      ~s(<line x1="#{x1}" y1="#{y1}" x2="#{x2}" y2="#{y2}" stroke="#{acc}" stroke-width="4.5" stroke-linecap="round" opacity="0.75"/>)
    end)
    [
      ~s(<circle cx="#{cx}" cy="#{cy}" r="24" fill="#{dark}"/>),
      ~s(<circle cx="#{cx}" cy="#{cy}" r="18" fill="#{mid}" opacity="0.35"/>),
      blades,
      ~s(<circle cx="#{cx}" cy="#{cy}" r="5.5" fill="#{dark}"/>),
      ~s(<circle cx="#{cx}" cy="#{cy}" r="3" fill="#{acc}"/>),
    ]
    |> Enum.join("")
  end

  defp extras_corner_fans(acc, dark, mid) do
    [{36,36},{220,36},{36,220},{220,220}]
    |> Enum.map_join("", fn {cx, cy} -> fan_svg(cx, cy, acc, dark, mid) end)
  end

  defp extras_side_pipe(seed, dark, mid) do
    side  = if jitter(seed, 10, 2) == 0, do: 1, else: -1
    bx    = if side > 0, do: 212, else: 16
    px    = if side > 0, do: 220, else: 20
    rings = Enum.map_join([82, 112, 144, 174], "", fn y ->
      ~s(<circle cx="#{px}" cy="#{y}" r="7.5" fill="#{mid}"/>) <>
      ~s(<circle cx="#{px}" cy="#{y}" r="4" fill="#{dark}"/>)
    end)
    [~s(<rect x="#{bx}" y="58" width="14" height="140" rx="7" fill="#{dark}"/>), rings]
    |> Enum.join("")
  end

  defp extras_head_cables(eye_y, dark, mid) do
    [{56, 18, 86, 52, 76, eye_y-42},
     {200, 18, 170, 52, 180, eye_y-42}]
    |> Enum.map_join("", fn {x1, y1, qx, qy, x2, y2} ->
      [
        ~s(<path d="M #{x1} #{y1} Q #{qx} #{qy} #{x2} #{y2}" stroke="#{dark}" stroke-width="9" fill="none" stroke-linecap="round"/>),
        ~s(<path d="M #{x1} #{y1} Q #{qx} #{qy} #{x2} #{y2}" stroke="#{mid}" stroke-width="4" fill="none" stroke-linecap="round" opacity="0.6"/>),
      ]
      |> Enum.join("")
    end)
  end

  defp extras_circuit_traces(acc, dark, mid) do
    [
      ~s(<line x1="18" y1="128" x2="48" y2="128" stroke="#{dark}" stroke-width="3.5"/>),
      ~s(<line x1="18" y1="128" x2="18" y2="96" stroke="#{dark}" stroke-width="3.5"/>),
      ~s(<circle cx="18" cy="96" r="5" fill="#{acc}" opacity="0.8"/>),
      ~s(<circle cx="18" cy="128" r="3" fill="#{mid}"/>),
      ~s(<line x1="238" y1="128" x2="208" y2="128" stroke="#{dark}" stroke-width="3.5"/>),
      ~s(<line x1="238" y1="128" x2="238" y2="96" stroke="#{dark}" stroke-width="3.5"/>),
      ~s(<circle cx="238" cy="96" r="5" fill="#{acc}" opacity="0.8"/>),
      ~s(<circle cx="238" cy="128" r="3" fill="#{mid}"/>),
      ~s(<line x1="128" y1="16" x2="128" y2="42" stroke="#{dark}" stroke-width="3.5"/>),
      ~s(<circle cx="128" cy="16" r="5" fill="#{acc}" opacity="0.8"/>),
    ]
    |> Enum.join("")
  end

  defp extras_status_column(seed, acc, dark, mid) do
    sx = if jitter(seed, 10, 2) == 0, do: 222, else: 16
    Enum.map_join(0..5, "", fn i ->
      fill    = if i in [2, 4], do: acc, else: mid
      opacity = if i in [2, 4], do: "0.9", else: "0.35"
      [
        ~s(<rect x="#{sx-6}" y="#{64+i*26}" width="14" height="16" rx="3" fill="#{dark}"/>),
        ~s(<rect x="#{sx-4}" y="#{66+i*26}" width="10" height="12" rx="2" fill="#{fill}" opacity="#{opacity}"/>),
      ]
      |> Enum.join("")
    end)
  end

  defp extras_neck_bolts(eye_y, dark, mid) do
    ny = eye_y + 132
    [-44, -22, 0, 22, 44]
    |> Enum.map_join("", fn dx ->
      [
        ~s(<circle cx="#{@cx+dx}" cy="#{ny}" r="8" fill="#{dark}"/>),
        ~s(<circle cx="#{@cx+dx}" cy="#{ny}" r="5" fill="#{mid}"/>),
        ~s(<line x1="#{@cx+dx-3}" y1="#{ny}" x2="#{@cx+dx+3}" y2="#{ny}" stroke="#{dark}" stroke-width="2"/>),
        ~s(<line x1="#{@cx+dx}" y1="#{ny-3}" x2="#{@cx+dx}" y2="#{ny+3}" stroke="#{dark}" stroke-width="2"/>),
      ]
      |> Enum.join("")
    end)
  end

  defp extras_temple_screws(eye_y, dark, mid) do
    [-1, 1]
    |> Enum.map_join("", fn s ->
      tx = @cx + s*90
      ty = eye_y - 8
      [
        ~s(<circle cx="#{tx}" cy="#{ty}" r="11" fill="#{dark}"/>),
        ~s(<circle cx="#{tx}" cy="#{ty}" r="7.5" fill="#{mid}" opacity="0.6"/>),
        ~s(<line x1="#{tx-5}" y1="#{ty}" x2="#{tx+5}" y2="#{ty}" stroke="#{dark}" stroke-width="2.5"/>),
        ~s(<line x1="#{tx}" y1="#{ty-5}" x2="#{tx}" y2="#{ty+5}" stroke="#{dark}" stroke-width="2.5"/>),
      ]
      |> Enum.join("")
    end)
  end

  defp extras_hazard_stripes(acc, dark) do
    stripes = Enum.map_join((-3)..15, "", fn i ->
      ~s[<rect x="#{i*22-2}" y="224" width="11" height="32" fill="#{acc}" opacity="0.45" transform="skewX(-22)"/>]
    end)
    [~s(<rect x="0" y="224" width="256" height="32" fill="#{dark}" opacity="0.85"/>), stripes]
    |> Enum.join("")
  end

  defp extras_charge_bars(seed, acc, dark, mid) do
    level    = (28 + jitter(seed, 10, 100) * 64 / 100) / 100
    bh       = 84
    by       = 84
    [-1, 1]
    |> Enum.map_join("", fn s ->
      bx       = if s > 0, do: 222, else: 14
      filled_h = round(bh * level)
      filled_y = by + bh - filled_h
      [
        ~s(<rect x="#{bx}" y="#{by}" width="13" height="#{bh}" rx="5" fill="#{dark}"/>),
        ~s(<rect x="#{bx+1}" y="#{filled_y}" width="11" height="#{filled_h-1}" rx="4" fill="#{acc}" opacity="0.85"/>),
        ~s(<rect x="#{bx+2}" y="#{by+2}" width="9" height="5" rx="2" fill="#{mid}" opacity="0.4"/>),
      ]
      |> Enum.join("")
    end)
  end

  defp extras_scan_bands(acc, dark) do
    [
      ~s(<rect x="0" y="8" width="256" height="12" fill="#{dark}" opacity="0.6"/>),
      ~s(<rect x="4" y="10" width="248" height="8" fill="#{acc}" opacity="0.3"/>),
      ~s(<rect x="0" y="236" width="256" height="12" fill="#{dark}" opacity="0.6"/>),
      ~s(<rect x="4" y="238" width="248" height="8" fill="#{acc}" opacity="0.3"/>),
    ]
    |> Enum.join("")
  end

  defp extras_corner_brackets(acc, dark) do
    bsz = 28
    [{8,8},{256-8-bsz,8},{8,256-8-bsz},{256-8-bsz,256-8-bsz}]
    |> Enum.map_join("", fn {x, y} ->
      [
        ~s(<polyline points="#{x+bsz},#{y} #{x},#{y} #{x},#{y+bsz}" fill="none" stroke="#{dark}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>),
        ~s(<polyline points="#{x+bsz},#{y} #{x},#{y} #{x},#{y+bsz}" fill="none" stroke="#{acc}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" opacity="0.7"/>),
      ]
      |> Enum.join("")
    end)
  end
end
