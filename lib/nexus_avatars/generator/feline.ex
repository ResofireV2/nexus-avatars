defmodule NexusAvatars.Generator.Feline do
  @moduledoc """
  Orc avatar style (replaces the Feline placeholder).

  Renders a 200x200 cartoon orc face on a flat skin-coloured background.
  All features float directly on the background — no head shape drawn.
  The skin colour fills the entire square, acting as both background and face.

  Feature slots (each independently seeded):
    0  -> skin palette       (20 tones)
    1  -> eye colour         (10 colours)
    2  -> war paint palette  (8 palettes)
    3  -> eye type           (6 types)
    4  -> brow type          (6 shapes)
    5  -> tusk type          (6 shapes)
    6  -> mouth type         (6 expressions)
    7  -> war paint pattern  (8 patterns)
    8  -> hair type          (6 styles)
    9  -> scar count         (0-3)
    10 -> scar routes        (up to 3 x 10 routes)
    11 -> hair colour        (7 palettes)

  SVG filter (feTurbulence + feDisplacementMap) displaces each scar line
  so it reads as a jagged organic wound rather than a clean stroke.
  Each scar gets a unique turbulence seed derived from the username hash.

  Canvas: 200x200, viewBox 0 0 200 200. Rasterised to WebP via libvips.
  """

  @size 200

  # ── Skin tones ───────────────────────────────────────────────────────────
  @skins [
    {74, 152, 32},  {58, 138, 28},  {92, 180, 42},  {46, 120, 64},
    {106,158, 16},  {140, 96, 48},  {122, 80, 32},  {160,112, 56},
    {90,  90,104},  {72,  72, 88},  {106,106,122},  {58,106, 80},
    {40,  96, 64},  {74, 122, 90},  {128,104, 40},  {104, 80, 24},
    {40,  88,136},  {30,  72,120},  {136, 48, 40},  {108, 32, 24},
  ]

  # ── Eye colours ──────────────────────────────────────────────────────────
  @eye_cols [
    {255, 96,  0}, {255,200,  0}, {212,226,  0}, {255, 48, 48},
    { 64,208,255}, {128,255, 32}, {224,  0,192}, {255,255,255},
    {255,140,  0}, { 32,224,128},
  ]

  # ── War paint palettes: {dark, light, highlight} ─────────────────────────
  @paint_palettes [
    {{170,  8,  8}, {238, 48, 48}, {255,112, 80}},   # blood red
    {{ 16, 48,204}, { 64, 96,255}, {128,144,255}},   # woad blue
    {{200,200,  0}, {240,240, 32}, {255,255,128}},   # ochre yellow
    {{  8,  8,  8}, { 48, 48, 48}, { 88, 88, 88}},  # charcoal
    {{192, 96,  0}, {224,136, 32}, {240,176, 80}},   # burnt orange
    {{  0, 96, 48}, { 32,160, 96}, { 80,208,144}},   # jungle green
    {{ 96,  0,128}, {160, 32,192}, {208, 96,224}},   # ritual purple
    {{192,192,192}, {232,232,232}, {255,255,255}},   # bone white
  ]

  # ── Hair colour palettes: {dark, mid, highlight} ─────────────────────────
  @hair_palettes [
    {{ 30, 12,  4}, { 58, 24,  8}, { 90, 40, 16}},  # near-black
    {{ 60, 32,  8}, {106, 60, 20}, {138, 84, 32}},  # dark brown
    {{106, 48,  0}, {156, 80, 16}, {192,112, 32}},  # chestnut
    {{ 16, 16, 16}, { 40, 40, 40}, { 64, 64, 64}},  # black
    {{ 96, 32,  0}, {152, 46, 12}, {192, 64, 16}},  # auburn
    {{192,128,  0}, {224,176, 32}, {248,216, 64}},  # blonde
    {{128,  0,  0}, {184, 16, 16}, {224, 48, 48}},  # red war-dyed
  ]

  # Scar route definitions [x1, y1, x2, y2]
  @scar_routes [
    [114, 48, 154, 108],  # across right eye
    [ 46, 52,  80, 110],  # across left eye
    [ 30, 80,  70, 140],  # left cheek diagonal
    [130, 80, 170, 140],  # right cheek diagonal
    [ 80, 30, 120,  70],  # forehead
    [ 70,130, 130, 170],  # across mouth
    [ 88, 90, 112, 130],  # nose bridge
    [ 40,100,  80, 160],  # left jaw
    [120,100, 160, 160],  # right jaw
    [ 60, 60, 100, 130],  # left brow through eye
  ]

  # ── Public entry point ───────────────────────────────────────────────────

  @doc "Renders a 200x200 Orc SVG string for the given username."
  def render(username) do
    seed = :erlang.phash2(username)

    {sr, sg, sb}               = pick(seed, 0, @skins)
    {er, eg, eb}               = pick(seed, 1, @eye_cols)
    {pd, pl, ph}               = pick(seed, 2, @paint_palettes)
    {hd, hm, hh}               = pick(seed, 11, @hair_palettes)

    eye_type    = rng(seed,  3, 6)
    brow_type   = rng(seed,  4, 6)
    tusk_type   = rng(seed,  5, 6)
    mouth_type  = rng(seed,  6, 6)
    paint_type  = rng(seed,  7, 8)
    hair_type   = rng(seed,  8, 6)
    scar_count  = rng(seed,  9, 4)   # 0–3
    scar_seed   = rng(seed, 10, 100)

    skin    = hex(sr, sg, sb)
    skin_d  = hex(scale(sr,0.62), scale(sg,0.62), scale(sb,0.62))
    skin_dd = hex(scale(sr,0.36), scale(sg,0.36), scale(sb,0.36))
    eye_col = hex(er, eg, eb)
    eye_d   = hex(scale(er,0.50), scale(eg,0.50), scale(eb,0.50))
    wp_dk   = hex_t(pd)
    wp_lt   = hex_t(pl)
    wp_hi   = hex_t(ph)
    hair_dk = hex_t(hd)
    hair_md = hex_t(hm)
    hair_hi = hex_t(hh)

    tusk_ivory = "#ece0a4"
    tusk_shd   = "#a89858"
    tusk_hi    = "#fffff4"
    tooth_c    = "#e8e0c0"
    tooth_d    = "#b0a870"
    maw        = "#160404"
    eye_white  = "#f0ecd8"
    pupil      = "#060400"

    eye_y    = 80 + jitter(seed, 20, 8) - 4
    eye_spr  = 64 + jitter(seed, 21, 8) - 4

    parts = [
      svg_open(),
      "",
      "<rect width=\"200\" height=\"200\" fill=\"#{skin}\"/>",
      hair(hair_type, hair_dk, hair_md, hair_hi),
      war_paint(paint_type, wp_dk, wp_lt, wp_hi),
      brow(brow_type, skin_d, skin_dd),
      eyes(seed, eye_type, eye_y, eye_spr, eye_col, eye_d, eye_white, pupil, skin_d, skin_dd),
      scars(seed, scar_count, scar_seed),
      snout(skin, skin_d, skin_dd),
      mouth(mouth_type, skin_d, skin_dd, tooth_c, tooth_d, maw),
      tusks(tusk_type, tusk_ivory, tusk_shd, tusk_hi),
      "</svg>",
    ]

    Enum.join(parts, "\n")
  end

  # ── PRNG helpers ─────────────────────────────────────────────────────────

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

  defp jitter(seed, salt, range), do: rng(seed, salt + 100, range)

  defp pick(seed, salt, list) do
    Enum.at(list, rng(seed, salt, length(list)))
  end

  # ── Colour helpers ────────────────────────────────────────────────────────

  defp scale(c, f), do: min(255, round(c * f))
  defp hex(r, g, b), do: "##{h2(r)}#{h2(g)}#{h2(b)}"
  defp hex_t({r, g, b}), do: hex(r, g, b)
  defp h2(n), do: n |> Integer.to_string(16) |> String.pad_leading(2, "0") |> String.downcase()

  # ── SVG scaffolding ───────────────────────────────────────────────────────

  defp svg_open do
    ~s(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{@size} #{@size}" width="#{@size}" height="#{@size}">)
  end

  # ── Hair ─────────────────────────────────────────────────────────────────

  defp hair(type, dk, md, hi) do
    case type do
      0 -> # 5-spike mohawk
        spikes = [{72,18,14},{86,28,14},{100,38,16},{114,28,14},{128,18,14}]
        Enum.map_join(spikes, "\n", fn {cx, h, w} ->
          [
            ~s(<polygon points="#{cx-w},0 #{cx+w},0 #{cx},#{h}" fill="#{dk}"/>),
            ~s(<polygon points="#{cx-w+3},0 #{cx+w-3},0 #{cx},#{h-4}" fill="#{md}"/>),
            ~s(<polygon points="#{cx-2},0 #{cx+2},0 #{cx},#{h-8}" fill="#{hi}"/>),
          ]
          |> Enum.join("\n")
        end)

      1 -> # wide strip mohawk
        [
          ~s(<polygon points="82,0 118,0 114,32 86,32" fill="#{dk}"/>),
          ~s(<polygon points="86,0 114,0 111,26 89,26" fill="#{md}"/>),
          ~s(<polygon points="96,0 104,0 102,18 98,18" fill="#{hi}"/>),
        ]
        |> Enum.join("\n")

      2 -> # twin spikes
        Enum.map_join([88, 112], "\n", fn cx ->
          [
            ~s(<polygon points="#{cx-10},0 #{cx+10},0 #{cx},28" fill="#{dk}"/>),
            ~s(<polygon points="#{cx-6},0 #{cx+6},0 #{cx},22" fill="#{md}"/>),
            ~s(<polygon points="#{cx-2},0 #{cx+2},0 #{cx},14" fill="#{hi}"/>),
          ]
          |> Enum.join("\n")
        end)

      3 -> # jagged short all-over
        Enum.with_index([64,76,88,100,112,124,136])
        |> Enum.map_join("\n", fn {cx, i} ->
          h = 8 + rem(cx * 13 + i * 7, 16)
          [
            ~s(<polygon points="#{cx-7},0 #{cx+7},0 #{cx},#{h}" fill="#{dk}"/>),
            ~s(<polygon points="#{cx-3},0 #{cx+3},0 #{cx},#{h-4}" fill="#{md}"/>),
          ]
          |> Enum.join("\n")
        end)

      4 -> # off-centre single spike
        cx = 96
        [
          ~s(<polygon points="#{cx-14},0 #{cx+14},0 #{cx},44" fill="#{dk}"/>),
          ~s(<polygon points="#{cx-8},0 #{cx+8},0 #{cx},36" fill="#{md}"/>),
          ~s(<polygon points="#{cx-3},0 #{cx+3},0 #{cx},24" fill="#{hi}"/>),
        ]
        |> Enum.join("\n")

      _ -> "" # bald
    end
  end

  # ── War paint ─────────────────────────────────────────────────────────────

  defp war_paint(type, dk, lt, hi) do
    case type do
      0 -> "" # none

      1 -> # cheek slashes — red, angled upward toward outside
        [
          wp_bar(4,   100, 52, 12, 22, 30, 106, dk, lt, hi),
          wp_bar(8,   116, 48, 12, 22, 32, 122, dk, lt, hi),
          wp_bar(144, 100, 52, 12, -22, 170, 106, dk, lt, hi),
          wp_bar(148, 116, 48, 12, -22, 172, 122, dk, lt, hi),
        ]
        |> Enum.join("\n")

      2 -> # above-eye bands
        [
          ~s(<rect x="38" y="60" width="54" height="10" rx="4" fill="#{dk}"/>),
          ~s(<rect x="40" y="60" width="50" height="5"  rx="2" fill="#{lt}" opacity="0.7"/>),
          ~s(<rect x="108" y="60" width="54" height="10" rx="4" fill="#{dk}"/>),
          ~s(<rect x="110" y="60" width="50" height="5"  rx="2" fill="#{lt}" opacity="0.7"/>),
        ]
        |> Enum.join("\n")

      3 -> # forehead vertical stripe
        [
          ~s(<rect x="93" y="2" width="14" height="56" rx="5" fill="#{dk}"/>),
          ~s(<rect x="96" y="4" width="8"  height="52" rx="3" fill="#{lt}" opacity="0.7"/>),
          ~s(<rect x="98" y="6" width="4"  height="48" rx="2" fill="#{hi}" opacity="0.5"/>),
        ]
        |> Enum.join("\n")

      4 -> # chin stripe
        [
          ~s(<rect x="88" y="158" width="24" height="38" rx="5" fill="#{dk}"/>),
          ~s(<rect x="91" y="160" width="18" height="34" rx="3" fill="#{lt}" opacity="0.7"/>),
        ]
        |> Enum.join("\n")

      5 -> # cheek dots
        [{32,112},{28,128},{168,112},{172,128}]
        |> Enum.map_join("\n", fn {cx, cy} ->
          [
            ~s(<circle cx="#{cx}" cy="#{cy}" r="9" fill="#{dk}"/>),
            ~s(<circle cx="#{cx}" cy="#{cy}" r="5" fill="#{lt}" opacity="0.75"/>),
            ~s(<circle cx="#{cx}" cy="#{cy}" r="2" fill="#{hi}" opacity="0.5"/>),
          ]
          |> Enum.join("\n")
        end)

      6 -> # eye band
        [
          ~s(<rect x="16" y="66" width="168" height="18" rx="6" fill="#{dk}" opacity="0.75"/>),
          ~s(<rect x="18" y="68" width="164" height="8"  rx="4" fill="#{lt}" opacity="0.5"/>),
        ]
        |> Enum.join("\n")

      _ -> # cheek triangles
        [
          ~s(<polygon points="14,80 46,80 30,108" fill="#{dk}"/>),
          ~s(<polygon points="17,82 43,82 30,105" fill="#{lt}" opacity="0.7"/>),
          ~s(<polygon points="154,80 186,80 170,108" fill="#{dk}"/>),
          ~s(<polygon points="157,82 183,82 170,105" fill="#{lt}" opacity="0.7"/>),
        ]
        |> Enum.join("\n")
    end
  end

  defp wp_bar(x, y, w, h, rot, ox, oy, dk, lt, hi) do
    [
      ~s[<rect x="#{x}" y="#{y}" width="#{w}" height="#{h}" rx="5" fill="#{dk}" transform="rotate(#{rot},#{ox},#{oy})"/>],
      ~s[<rect x="#{x}" y="#{y}" width="#{w}" height="#{div(h,2)+1}" rx="3" fill="#{lt}" opacity="0.7" transform="rotate(#{rot},#{ox},#{oy-3})"/>],
      ~s[<rect x="#{x}" y="#{y}" width="#{w}" height="2" rx="1" fill="#{hi}" opacity="0.5" transform="rotate(#{rot},#{ox},#{oy-5})"/>],
    ]
    |> Enum.join("\n")
  end

  # ── Brow ─────────────────────────────────────────────────────────────────

  defp brow(type, skin_d, skin_dd) do
    case type do
      0 -> # heavy flat ledge
        [
          ~s(<ellipse cx="100" cy="52" rx="80" ry="22" fill="#{skin_dd}"/>),
          ~s(<ellipse cx="100" cy="64" rx="58" ry="10" fill="#{skin_d}"/>),
        ]
        |> Enum.join("\n")

      1 -> # knuckled ridge
        bumps = Enum.map_join([54,72,100,128,146], "\n", fn bx ->
          ~s(<ellipse cx="#{bx}" cy="50" rx="16" ry="14" fill="#{skin_dd}"/>)
        end)
        [
          ~s(<ellipse cx="100" cy="52" rx="80" ry="20" fill="#{skin_dd}"/>),
          bumps,
          ~s(<ellipse cx="100" cy="64" rx="56" ry="9" fill="#{skin_d}"/>),
        ]
        |> Enum.join("\n")

      2 -> # V-furrow
        [
          ~s(<polygon points="18,66 100,36 182,66 176,74 100,46 24,74" fill="#{skin_dd}"/>),
          ~s(<ellipse cx="100" cy="66" rx="56" ry="9" fill="#{skin_d}"/>),
        ]
        |> Enum.join("\n")

      3 -> # split plates
        [
          ~s(<ellipse cx="66"  cy="54" rx="38" ry="18" fill="#{skin_dd}"/>),
          ~s(<ellipse cx="134" cy="54" rx="38" ry="18" fill="#{skin_dd}"/>),
          ~s(<ellipse cx="66"  cy="63" rx="26" ry="8"  fill="#{skin_d}"/>),
          ~s(<ellipse cx="134" cy="63" rx="26" ry="8"  fill="#{skin_d}"/>),
        ]
        |> Enum.join("\n")

      4 -> # angled slabs
        [
          ~s(<polygon points="18,46 88,40 96,72 18,74" fill="#{skin_dd}"/>),
          ~s(<polygon points="182,46 112,40 104,72 182,74" fill="#{skin_dd}"/>),
          ~s(<ellipse cx="100" cy="66" rx="54" ry="8" fill="#{skin_d}"/>),
        ]
        |> Enum.join("\n")

      _ -> # low thick unibrow
        [
          ~s(<ellipse cx="100" cy="62" rx="76" ry="16" fill="#{skin_dd}"/>),
          ~s(<path d="M 24,62 Q 100,44 176,62" fill="none" stroke="#{skin_dd}" stroke-width="6"/>),
          ~s(<ellipse cx="100" cy="70" rx="54" ry="8" fill="#{skin_d}"/>),
        ]
        |> Enum.join("\n")
    end
  end

  # ── Eyes ─────────────────────────────────────────────────────────────────

  defp eyes(seed, type, eye_y, eye_spr, eye_col, eye_d, eye_white, pupil, skin_d, skin_dd) do
    [{eye_spr, -1}, {200 - eye_spr, 1}]
    |> Enum.map_join("\n", fn {ex, side} ->
      ew = 20 + jitter(seed, 22, 6) - 3
      eh = 11 + jitter(seed, 23, 5) - 2
      ey = eye_y
      cid = "ec#{seed}_#{ex}"

      socket   = ~s(<path d="M#{ex-ew-5},#{ey} Q#{ex},#{ey-eh-12} #{ex+ew+5},#{ey} Q#{ex},#{ey+eh+6} #{ex-ew-5},#{ey}Z" fill="#{skin_dd}"/>)
      clip_def = ~s(<clipPath id="#{cid}"><path d="M#{ex-ew},#{ey} Q#{ex},#{ey-eh} #{ex+ew},#{ey} Q#{ex},#{ey+eh} #{ex-ew},#{ey}Z"/></clipPath>)
      white    = ~s(<path d="M#{ex-ew},#{ey} Q#{ex},#{ey-eh} #{ex+ew},#{ey} Q#{ex},#{ey+eh} #{ex-ew},#{ey}Z" fill="#{eye_white}"/>)
      iris_svg = iris(type, ex, ey, eye_col, eye_d, pupil, cid)
      glint    = ~s(<ellipse cx="#{ex-7}" cy="#{ey-4}" rx="4" ry="3" fill="white" opacity="0.85"/>)
      lid      = angry_lid(ex, ey, ew, eh, side, skin_d, skin_dd)

      [socket, clip_def, white, iris_svg, glint, lid]
      |> Enum.join("\n")
    end)
  end

  defp iris(type, ex, ey, eye_col, eye_d, pupil, cid) do
    cp = "clip-path=\"url(##{cid})\""
    case type do
      0 -> # large fierce round
        [
          ~s(<circle cx="#{ex}" cy="#{ey}" r="14" fill="#{eye_col}" #{cp}/>),
          ~s(<circle cx="#{ex}" cy="#{ey}" r="9"  fill="#{eye_d}"   #{cp}/>),
          ~s(<ellipse cx="#{ex}" cy="#{ey}" rx="3" ry="11" fill="#{pupil}" #{cp}/>),
        ]
        |> Enum.join("\n")

      1 -> # glowing berserker
        [
          ~s(<circle cx="#{ex}" cy="#{ey}" r="14" fill="#cc0000" #{cp}/>),
          ~s(<circle cx="#{ex}" cy="#{ey}" r="9"  fill="#ff4000" #{cp}/>),
          ~s(<circle cx="#{ex}" cy="#{ey}" r="5"  fill="#ffa000" #{cp}/>),
          ~s(<circle cx="#{ex}" cy="#{ey}" r="2"  fill="white"   #{cp}/>),
        ]
        |> Enum.join("\n")

      2 -> # slit pupil
        [
          ~s(<circle cx="#{ex}" cy="#{ey}" r="13" fill="#{eye_col}" #{cp}/>),
          ~s(<ellipse cx="#{ex}" cy="#{ey}" rx="3" ry="12" fill="#{pupil}" #{cp}/>),
        ]
        |> Enum.join("\n")

      3 -> # small mean
        [
          ~s(<circle cx="#{ex}" cy="#{ey}" r="10" fill="#{eye_col}" #{cp}/>),
          ~s(<circle cx="#{ex}" cy="#{ey}" r="6"  fill="#{eye_d}"   #{cp}/>),
          ~s(<circle cx="#{ex}" cy="#{ey}" r="3"  fill="#{pupil}"   #{cp}/>),
        ]
        |> Enum.join("\n")

      4 -> # wide white-showing
        [
          ~s(<circle cx="#{ex}" cy="#{ey}" r="12" fill="#{eye_col}" #{cp}/>),
          ~s(<circle cx="#{ex}" cy="#{ey}" r="7"  fill="#{eye_d}"   #{cp}/>),
          ~s(<ellipse cx="#{ex}" cy="#{ey}" rx="2" ry="10" fill="#{pupil}" #{cp}/>),
        ]
        |> Enum.join("\n")

      _ -> # dead / hollow
        [
          ~s(<circle cx="#{ex}" cy="#{ey}" r="13" fill="#{eye_d}" #{cp}/>),
          ~s(<circle cx="#{ex}" cy="#{ey}" r="7"  fill="black"    #{cp}/>),
        ]
        |> Enum.join("\n")
    end
  end

  # Menacing lid: inner corner high (toward nose), outer corner low (toward temple)
  defp angry_lid(ex, ey, ew, eh, side, skin_d, skin_dd) do
    {inner_x, outer_x} = if side == -1, do: {ex - ew, ex + ew}, else: {ex + ew, ex - ew}
    inner_y = ey - 10
    outer_y = ey + 4
    [
      ~s(<path d="M#{inner_x},#{inner_y} Q#{ex},#{ey-eh-6} #{outer_x},#{outer_y} L#{outer_x},#{outer_y-14} Q#{ex},#{ey-eh-16} #{inner_x},#{inner_y-12}Z" fill="#{skin_dd}"/>),
      ~s(<path d="M#{inner_x},#{inner_y} Q#{ex},#{ey-eh-4} #{outer_x},#{outer_y}" fill="none" stroke="#{skin_d}" stroke-width="2" opacity="0.7"/>),
    ]
    |> Enum.join("\n")
  end

  # ── Scars ─────────────────────────────────────────────────────────────────

  defp scars(seed, count, _scar_seed) do
    if count == 0 do
      ""
    else
      n = min(count, 3)
      Enum.map_join(0..(n - 1), "", fn i ->
        route_idx = rng(seed, 30 + i, length(@scar_routes))
        [x1, y1, x2, y2] = Enum.at(@scar_routes, route_idx)
        jx = jitter(seed, 40 + i, 14) - 7
        jy = jitter(seed, 50 + i, 10) - 5
        jagged_scar(seed, i, x1 + jx, y1 + jy, x2 + jx, y2 + jy)
      end)
    end
  end

  defp jagged_scar(seed, si, x1, y1, x2, y2) do
    steps = 8
    dx    = x2 - x1
    dy    = y2 - y1
    len   = max(1, :math.sqrt(dx * dx + dy * dy))
    px    = -dy / len
    py    =  dx / len
    points =
      Enum.map(0..steps, fn k ->
        t       = k / steps
        base_x  = x1 + round(dx * t)
        base_y  = y1 + round(dy * t)
        perturb = if k == 0 or k == steps, do: 0,
          else: jitter(seed, si * 20 + k + 200, 13) - 6
        "#{base_x + round(px * perturb)},#{base_y + round(py * perturb)}"
      end)
      |> Enum.join(" ")
    ~s(<polyline points="#{points}" fill="none" stroke="#050302" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>)
  end

  # ── Snout ─────────────────────────────────────────────────────────────────

  defp snout(skin, skin_d, skin_dd) do
    [
      ~s(<ellipse cx="100" cy="120" rx="46" ry="32" fill="#{skin}"/>),
      ~s(<ellipse cx="100" cy="108" rx="30" ry="14" fill="#{skin_d}"/>),
      ~s(<ellipse cx="80"  cy="118" rx="13" ry="11" fill="#{skin_dd}"/>),
      ~s(<ellipse cx="120" cy="118" rx="13" ry="11" fill="#{skin_dd}"/>),
      ~s(<ellipse cx="78"  cy="115" rx="5"  ry="4"  fill="#{skin_d}"/>),
      ~s(<ellipse cx="118" cy="115" rx="5"  ry="4"  fill="#{skin_d}"/>),
    ]
    |> Enum.join("\n")
  end

  # ── Mouth ─────────────────────────────────────────────────────────────────

  defp mouth(type, skin_d, skin_dd, tooth_c, tooth_d, maw) do
    case type do
      0 -> # wide snarl — 4 teeth
        teeth = teeth_row(68, 4, 12, 3, 134, 12, tooth_c, tooth_d)
        [
          ~s(<ellipse cx="100" cy="146" rx="40" ry="16" fill="#{maw}"/>),
          ~s(<rect x="66" y="132" width="68" height="6" rx="2" fill="#{skin_d}"/>),
          teeth,
          ~s(<ellipse cx="100" cy="158" rx="34" ry="8" fill="#{skin_d}"/>),
        ]
        |> Enum.join("\n")

      1 -> # closed sneer
        [
          ~s(<path d="M 68,140 Q 100,136 132,140 Q 136,148 100,152 Q 64,148 68,140Z" fill="#{skin_dd}"/>),
        ]
        |> Enum.join("\n")

      2 -> # open roar — 6 teeth
        teeth = teeth_row(60, 6, 9, 2, 134, 11, tooth_c, tooth_d)
        [
          ~s(<ellipse cx="100" cy="150" rx="46" ry="20" fill="#{maw}"/>),
          ~s(<rect x="58" y="132" width="84" height="6" rx="2" fill="#{skin_d}"/>),
          teeth,
          ~s(<ellipse cx="100" cy="164" rx="38" ry="8" fill="#{skin_d}"/>),
        ]
        |> Enum.join("\n")

      3 -> # lopsided smirk — 3 teeth
        teeth = teeth_row(76, 3, 10, 3, 136, 10, tooth_c, tooth_d)
        [
          ~s(<path d="M 72,138 Q 116,154 142,144 Q 136,154 100,158 Q 68,156 72,138Z" fill="#{maw}"/>),
          ~s(<rect x="74" y="134" width="50" height="6" rx="2" fill="#{skin_d}"/>),
          teeth,
        ]
        |> Enum.join("\n")

      4 -> # thin grimace
        [
          ~s(<ellipse cx="100" cy="142" rx="36" ry="8" fill="#{skin_dd}"/>),
          ~s(<ellipse cx="100" cy="144" rx="28" ry="5" fill="#{maw}"/>),
        ]
        |> Enum.join("\n")

      _ -> # toothy grin — 5 upper + 4 lower
        upper = teeth_row(72, 5, 8, 2, 134, 12, tooth_c, tooth_d)
        lower = teeth_row(74, 4, 8, 2, 150, 9, tooth_c, tooth_d)
        [
          ~s(<path d="M 68,136 Q 100,160 132,136 Q 130,156 100,162 Q 70,156 68,136Z" fill="#{maw}"/>),
          ~s(<rect x="70" y="132" width="60" height="8" rx="2" fill="#{skin_d}"/>),
          upper,
          lower,
        ]
        |> Enum.join("\n")
    end
  end

  defp teeth_row(start_x, count, tw, gap, y, th, tooth_c, tooth_d) do
    Enum.map_join(0..(count - 1), "\n", fn i ->
      tx = start_x + i * (tw + gap)
      [
        ~s(<rect x="#{tx}" y="#{y}" width="#{tw}" height="#{th}" rx="2" fill="#{tooth_c}"/>),
        ~s(<rect x="#{tx}" y="#{y + round(th * 0.67)}" width="#{tw}" height="#{round(th * 0.33)}" rx="1" fill="#{tooth_d}"/>),
      ]
      |> Enum.join("\n")
    end)
  end

  # ── Tusks ─────────────────────────────────────────────────────────────────

  defp tusks(type, ivory, shd, hi) do
    case type do
      0 -> # classic twin splayed
        tusk_pair(74,138,42,178,88,140, 77,138,46,173,87,140, 75,138,44,175,76,139,
                  126,138,158,178,112,140, 123,138,154,173,113,140, 125,138,156,175,124,139,
                  ivory, shd, hi)

      1 -> # single centre tusk
        [
          ~s(<polygon points="88,138 100,182 112,138" fill="#{ivory}"/>),
          ~s(<polygon points="91,138 100,175 109,138" fill="#{shd}"/>),
          ~s(<polygon points="93,138 100,178 94,138"  fill="#{hi}" opacity="0.3"/>),
        ]
        |> Enum.join("\n")

      2 -> # four small tusks
        [{68,70},{84,64},{116,64},{132,70}]
        |> Enum.map_join("\n", fn {tx, th} ->
          [
            ~s(<polygon points="#{tx-7},136 #{tx},#{158+th} #{tx+7},136" fill="#{ivory}"/>),
            ~s(<polygon points="#{tx-4},136 #{tx},#{154+th} #{tx+4},136" fill="#{shd}"/>),
          ]
          |> Enum.join("\n")
        end)

      3 -> # very wide boar tusks
        tusk_pair(76,138,24,172,90,142, 80,138,28,168,89,142, 77,138,26,170,78,139,
                  124,138,176,172,110,142, 120,138,172,168,111,142, 123,138,174,170,122,139,
                  ivory, shd, hi)

      4 -> # short stubby
        [
          ~s(<polygon points="80,138 68,160 92,140"  fill="#{ivory}"/>),
          ~s(<polygon points="82,138 70,157 91,140"  fill="#{shd}"/>),
          ~s(<polygon points="120,138 132,160 108,140" fill="#{ivory}"/>),
          ~s(<polygon points="118,138 130,157 109,140" fill="#{shd}"/>),
        ]
        |> Enum.join("\n")

      _ -> # asymmetric — one large, one small
        [
          ~s(<polygon points="74,138 42,178 88,140"  fill="#{ivory}"/>),
          ~s(<polygon points="77,138 46,173 87,140"  fill="#{shd}"/>),
          ~s(<polygon points="75,138 44,175 76,139"  fill="#{hi}" opacity="0.35"/>),
          ~s(<polygon points="122,138 132,162 112,140" fill="#{ivory}"/>),
          ~s(<polygon points="124,138 130,158 113,140" fill="#{shd}"/>),
        ]
        |> Enum.join("\n")
    end
  end

  defp tusk_pair(lx1,ly1,lx2,ly2,lx3,ly3, ldx1,ldy1,ldx2,ldy2,ldx3,ldy3, lhx1,lhy1,lhx2,lhy2,lhx3,lhy3,
                 rx1,ry1,rx2,ry2,rx3,ry3, rdx1,rdy1,rdx2,rdy2,rdx3,rdy3, rhx1,rhy1,rhx2,rhy2,rhx3,rhy3,
                 ivory, shd, hi) do
    [
      ~s(<polygon points="#{lx1},#{ly1} #{lx2},#{ly2} #{lx3},#{ly3}" fill="#{ivory}"/>),
      ~s(<polygon points="#{ldx1},#{ldy1} #{ldx2},#{ldy2} #{ldx3},#{ldy3}" fill="#{shd}"/>),
      ~s(<polygon points="#{lhx1},#{lhy1} #{lhx2},#{lhy2} #{lhx3},#{lhy3}" fill="#{hi}" opacity="0.35"/>),
      ~s(<polygon points="#{rx1},#{ry1} #{rx2},#{ry2} #{rx3},#{ry3}" fill="#{ivory}"/>),
      ~s(<polygon points="#{rdx1},#{rdy1} #{rdx2},#{rdy2} #{rdx3},#{rdy3}" fill="#{shd}"/>),
      ~s(<polygon points="#{rhx1},#{rhy1} #{rhx2},#{rhy2} #{rhx3},#{rhy3}" fill="#{hi}" opacity="0.35"/>),
    ]
    |> Enum.join("\n")
  end
end
