defmodule NexusAvatars.Generator.Canine do
  @moduledoc """
  Zombie avatar style (replaces the Canine placeholder).

  Renders a 200x200 zombie face on a flat pallid skin-coloured background.
  Skin fills the entire square — no head shape drawn. All features float
  directly on the background colour.

  Feature slots (each independently seeded):
    0  -> skin palette       (30 pallid corpse tones)
    1  -> brow type          (7 shapes)
    2  -> left eye type      (8 types — independent from right)
    3  -> right eye type     (8 types — independent from left)
    4  -> nose type          (7 types)
    5  -> mouth type         (7 expressions)
    6  -> wound count        (0–4)
    7  -> decomp spot count  (0–4)
    8  -> skeletal feature   (5 types)
    9  -> wound seed         (turbulence variation)

  Eye types: glazed cataract, rot-green off-centre, rolled-back bloodshot,
    half-shut drooping, jaundiced yellow, supernatural pale glow,
    dark/dead small iris, fully missing socket.

  Nose types: flesh pulled back, mostly missing with bone, fully skeletal
    nasal cavity, sunken intact, torn one side, bloated/swollen,
    cartilage-only beak.

  Mouth types: slack hanging jaw, wide dislocated scream, partial snarl,
    rotted closed, fully exposed jaw bone with double teeth, lopsided
    broken jaw with fang, barely-open slit.

  Wounds use feTurbulence + feDisplacementMap to produce jagged organic
  lines. Each wound gets a unique turbulence seed.

  Canvas: 200x200, viewBox 0 0 200 200. Rasterised to WebP via libvips.
  """

  @size 200

  # ── Skin palettes — all desaturated, pallid, corpse-toned ───────────────
  @skins [
    # grey-greens
    {106,136, 96}, { 88,118, 78}, { 72,100, 62},
    { 60, 86, 52}, {124,152,108},
    # blue-greys
    { 88, 96,108}, { 72, 80, 94}, { 96,104,116},
    { 60, 68, 82}, {108,116,128},
    # ash / near-white
    {148,148,140}, {164,162,152}, {138,136,128},
    {120,118,110}, {172,170,160},
    # putrid yellows
    {130,128, 80}, {118,116, 68}, {144,140, 92},
    {106,104, 60}, {152,148,100},
    # corpse browns
    {108, 96, 78}, { 92, 80, 64}, {124,110, 88},
    { 80, 68, 54}, {136,122, 98},
    # lavender-grey (long-dead)
    {110, 98,118}, { 96, 84,104}, {124,112,132},
    { 82, 70, 90}, {138,126,146},
  ]

  # Wound routes {x1, y1, x2, y2}
  @wound_routes [
    { 48, 38,152, 52},   # forehead slash
    { 42, 52, 78,108},   # left brow to cheek
    {122, 54,168,110},   # right brow to cheek
    { 30, 90, 72,148},   # left jaw
    {128, 90,170,148},   # right jaw
    { 72,126,128,172},   # across mouth
    { 60, 60,104,130},   # left eye diagonal
    {100, 38,148, 96},   # right eye diagonal
    { 36,116, 76,158},   # left cheek
    {124,116,172,162},   # right cheek
    { 80, 44,120, 80},   # forehead centre
    { 44,140, 96,186},   # chin left
  ]

  # Decomp spot positions {cx, cy, rx, ry}
  @spot_positions [
    { 36, 70, 18, 14}, {164, 58, 14, 10}, {158,132, 12,  9},
    { 44,150, 10,  8}, { 80, 42, 12,  8}, {148, 90, 10,  7},
    { 58,110,  8,  6}, {170,150,  9,  7},
  ]

  # Fixed colours
  @bone    "#d4c8a0"
  @bone_d  "#a49870"
  @bone_dd "#706040"
  @rot     "#1e1008"
  @blood   "#380808"
  @gum     "#5c2828"
  @maw     "#140606"
  @eye_milk "#d4d8c4"
  @eye_vein "#6a1010"

  # ── Public entry point ───────────────────────────────────────────────────

  @doc "Renders a 200x200 Zombie SVG string for the given username."
  def render(username) do
    seed = :erlang.phash2(username)

    {sr, sg, sb} = pick(seed, 0, @skins)
    skin    = hex(sr, sg, sb)
    skin_d  = hex(scale(sr,0.64), scale(sg,0.64), scale(sb,0.64))
    skin_dd = hex(scale(sr,0.38), scale(sg,0.38), scale(sb,0.38))
    skin_l  = hex(min(255,sr+22), min(255,sg+22), min(255,sb+22))

    brow_type   = rng(seed, 1, 7)
    eye_l       = rng(seed, 2, 8)
    eye_r       = rng(seed, 3, 8)
    nose_type   = rng(seed, 4, 7)
    mouth_type  = rng(seed, 5, 7)
    wound_count = rng(seed, 6, 5)   # 0–4
    spot_count  = rng(seed, 7, 5)   # 0–4
    skel_type   = rng(seed, 8, 5)   # 0–4
    w_seed      = rng(seed, 9, 100)

    eye_yl  = 82 + jitter(seed, 10, 10) - 5
    eye_yr  = 82 + jitter(seed, 11, 10) - 5
    ex_l    = 62 + jitter(seed, 12,  8) - 4
    ex_r    = 138 + jitter(seed, 13,  8) - 4

    nw = min(wound_count, 4)

    parts = [
      svg_open(),
      "",
      ~s(<rect width="200" height="200" fill="#{skin}"/>),
      decomp_spots(seed, spot_count, skin_dd, skin_l),
      skeletal(skel_type),
      brow(brow_type, skin_d, skin_dd),
      draw_eye(seed, ex_l, eye_yl, eye_l, -1, 0, skin_dd),
      draw_eye(seed, ex_r, eye_yr, eye_r,  1, 1, skin_dd),
      nose(seed, nose_type, skin_d, skin_dd, skin_l),
      mouth(mouth_type, skin_d, skin_dd),
      wounds(seed, nw, w_seed),
      "</svg>",
    ]

    Enum.join(parts, "\n")
  end

  # ── PRNG ──────────────────────────────────────────────────────────────────

  defp rng(seed, salt, range) do
    h  = Bitwise.band(Bitwise.bxor(seed, salt * 0x9e3779b9), 0xFFFFFFFF)
    z0 = Bitwise.band(h  + 0x9e3779b9, 0xFFFFFFFF)
    z1 = Bitwise.band(Bitwise.bxor(z0, Bitwise.bsr(z0,16)) * 0x85ebca6b, 0xFFFFFFFF)
    z2 = Bitwise.band(Bitwise.bxor(z1, Bitwise.bsr(z1,13)) * 0xc2b2ae35, 0xFFFFFFFF)
    z3 = Bitwise.band(Bitwise.bxor(z2, Bitwise.bsr(z2,16)), 0xFFFFFFFF)
    w0 = Bitwise.band(z3  + 0x9e3779b9, 0xFFFFFFFF)
    w1 = Bitwise.band(Bitwise.bxor(w0, Bitwise.bsr(w0,16)) * 0x85ebca6b, 0xFFFFFFFF)
    w2 = Bitwise.band(Bitwise.bxor(w1, Bitwise.bsr(w1,13)) * 0xc2b2ae35, 0xFFFFFFFF)
    w3 = Bitwise.band(Bitwise.bxor(w2, Bitwise.bsr(w2,16)), 0xFFFFFFFF)
    rem(w3, range)
  end

  defp jitter(seed, salt, range), do: rng(seed, salt + 100, range)

  defp pick(seed, salt, list),
    do: Enum.at(list, rng(seed, salt, length(list)))

  # ── Colour helpers ────────────────────────────────────────────────────────

  defp scale(c, f), do: min(255, round(c * f))
  defp hex(r, g, b), do: "##{h2(r)}#{h2(g)}#{h2(b)}"
  defp h2(n), do: n |> Integer.to_string(16) |> String.pad_leading(2, "0") |> String.downcase()

  # ── SVG scaffolding ───────────────────────────────────────────────────────

  defp svg_open do
    ~s(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{@size} #{@size}" width="#{@size}" height="#{@size}">)
  end

  # ── Wound filters ─────────────────────────────────────────────────────────



  # ── Decomp spots ─────────────────────────────────────────────────────────

  defp decomp_spots(seed, count, skin_dd, skin_l) do
    if count == 0 do
      ""
    else
      Enum.map_join(0..(count - 1), "\n", fn i ->
        {sx, sy, sw, sh} = pick(seed, 20 + i, @spot_positions)
        op = Float.round(0.35 + jitter(seed, 30 + i, 20) / 100, 2)
        ring = if jitter(seed, 40 + i, 3) == 0 do
          ~s(<ellipse cx="#{sx}" cy="#{sy}" rx="#{sw+4}" ry="#{sh+3}" fill="none" stroke="#{skin_l}" stroke-width="2" opacity="0.2"/>)
        else
          ""
        end
        ~s(<ellipse cx="#{sx}" cy="#{sy}" rx="#{sw}" ry="#{sh}" fill="#{skin_dd}" opacity="#{op}"/>) <> ring
      end)
    end
  end

  # ── Skeletal features ─────────────────────────────────────────────────────

  defp skeletal(0), do: ""
  defp skeletal(1) do   # cheekbone showing
    [
      ~s(<ellipse cx="34" cy="118" rx="16" ry="10" fill="#{@bone}"   opacity="0.4"/>),
      ~s(<ellipse cx="34" cy="118" rx="10" ry="6"  fill="#{@bone_d}" opacity="0.3"/>),
    ]
    |> Enum.join("")
  end
  defp skeletal(2) do   # forehead bone patch
    [
      ~s(<ellipse cx="100" cy="42" rx="22" ry="12" fill="#{@bone}"   opacity="0.38"/>),
      ~s(<ellipse cx="100" cy="42" rx="14" ry="7"  fill="#{@bone_d}" opacity="0.28"/>),
    ]
    |> Enum.join("")
  end
  defp skeletal(3) do   # exposed jaw bone
    [
      ~s(<ellipse cx="100" cy="178" rx="36" ry="14" fill="#{@bone}"   opacity="0.4"/>),
      ~s(<ellipse cx="100" cy="178" rx="24" ry="8"  fill="#{@bone_d}" opacity="0.3"/>),
      ~s(<rect x="72" y="174" width="56" height="6" rx="2" fill="#{@bone_d}" opacity="0.25"/>),
    ]
    |> Enum.join("")
  end
  defp skeletal(4) do   # temple crack
    [
      ~s(<ellipse cx="170" cy="72" rx="14" ry="18" fill="#{@bone}" opacity="0.35"/>),
      ~s(<path d="M166,60 L168,80 L174,86" fill="none" stroke="#{@bone_dd}" stroke-width="2" opacity="0.5"/>),
    ]
    |> Enum.join("")
  end

  # ── Brow ─────────────────────────────────────────────────────────────────

  defp brow(type, skin_d, skin_dd) do
    case type do
      0 -> # slack drooping — outer ends hang low
        [
          ~s(<path d="M36,66 Q68,56 96,72" fill="none" stroke="#{skin_dd}" stroke-width="12" stroke-linecap="round"/>),
          ~s(<path d="M104,70 Q132,57 164,66" fill="none" stroke="#{skin_dd}" stroke-width="12" stroke-linecap="round"/>),
        ]
        |> Enum.join("")

      1 -> # furrowed — freshly turned
        [
          ~s(<polygon points="18,68 100,40 182,68 176,76 100,50 24,76" fill="#{skin_dd}"/>),
          ~s(<ellipse cx="100" cy="68" rx="56" ry="8" fill="#{skin_d}"/>),
        ]
        |> Enum.join("")

      2 -> # asymmetric damage — one high one low
        [
          ~s(<path d="M36,58 Q68,50 96,64"   fill="none" stroke="#{skin_dd}" stroke-width="11" stroke-linecap="round"/>),
          ~s(<path d="M104,72 Q132,62 164,72" fill="none" stroke="#{skin_dd}" stroke-width="13" stroke-linecap="round"/>),
        ]
        |> Enum.join("")

      3 -> # heavy flat ridge — intact
        [
          ~s(<ellipse cx="100" cy="52" rx="80" ry="20" fill="#{skin_dd}"/>),
          ~s(<ellipse cx="100" cy="63" rx="58" ry="9"  fill="#{skin_d}"/>),
        ]
        |> Enum.join("")

      4 -> # barely there — just shadow
        [
          ~s(<ellipse cx="66"  cy="68" rx="34" ry="10" fill="#{skin_dd}" opacity="0.7"/>),
          ~s(<ellipse cx="134" cy="68" rx="34" ry="10" fill="#{skin_dd}" opacity="0.7"/>),
        ]
        |> Enum.join("")

      5 -> # missing left — bare bone patch
        [
          ~s(<path d="M104,70 Q132,58 164,66" fill="none" stroke="#{skin_dd}" stroke-width="12" stroke-linecap="round"/>),
          ~s(<ellipse cx="66" cy="62" rx="30" ry="8" fill="#{@bone}" opacity="0.3"/>),
        ]
        |> Enum.join("")

      _ -> # split / torn
        [
          ~s(<path d="M36,66 Q60,57 80,66"    fill="none" stroke="#{skin_dd}" stroke-width="10" stroke-linecap="round"/>),
          ~s(<path d="M88,68 Q96,60 96,72"    fill="none" stroke="#{skin_dd}" stroke-width="10" stroke-linecap="round"/>),
          ~s(<path d="M104,70 Q132,58 164,66" fill="none" stroke="#{skin_dd}" stroke-width="12" stroke-linecap="round"/>),
        ]
        |> Enum.join("")
    end
  end

  # ── Eyes ─────────────────────────────────────────────────────────────────
  # Each eye is drawn independently — left and right can be different types.

  defp draw_eye(seed, ex, ey, type, side, ci, skin_dd) do
    ew  = 20 + jitter(seed, 50 + ci, 6) - 3
    eh  = 11 + jitter(seed, 51 + ci, 5) - 2
    cid = "zec#{seed}c#{ci}"

    socket = ~s(<path d="M#{ex-ew-5},#{ey} Q#{ex},#{ey-eh-12} #{ex+ew+5},#{ey} Q#{ex},#{ey+eh+6} #{ex-ew-5},#{ey}Z" fill="#{skin_dd}"/>)

    if type == 7 do
      # Fully missing socket — dark cavity with dried matter
      socket <>
      ~s(<path d="M#{ex-ew},#{ey} Q#{ex},#{ey-eh} #{ex+ew},#{ey} Q#{ex},#{ey+eh} #{ex-ew},#{ey}Z" fill="#{@rot}"/>) <>
      ~s(<ellipse cx="#{ex}" cy="#{ey+2}" rx="#{round(ew*0.55)}" ry="#{round(eh*0.7)}" fill="#{@blood}" opacity="0.5"/>) <>
      ~s(<ellipse cx="#{ex-4}" cy="#{ey-2}" rx="5" ry="3" fill="#{@bone}" opacity="0.3"/>)
    else
      cp      = "clip-path=\"url(##{cid})\""
      clip    = "<clipPath id=\"#{cid}\"><path d=\"M#{ex-ew},#{ey} Q#{ex},#{ey-eh} #{ex+ew},#{ey} Q#{ex},#{ey+eh} #{ex-ew},#{ey}Z\"/></clipPath>"
      white   = ~s(<path d="M#{ex-ew},#{ey} Q#{ex},#{ey-eh} #{ex+ew},#{ey} Q#{ex},#{ey+eh} #{ex-ew},#{ey}Z" fill="#{@eye_milk}"/>)
      iris_s  = iris(type, ex, ey, cp, seed, ci)
      veins_s = if type in [0, 2, 3, 4], do: veins(ex, ey, ew, cp), else: ""
      lid_s   = drooping_lid(ex, ey, ew, eh, side, seed, ci, skin_dd)

      [socket, clip, white, iris_s, veins_s, lid_s]
      |> Enum.join("")
    end
  end

  defp iris(type, ex, ey, cp, _seed, _ci) do
    case type do
      0 -> # glazed milky cataract
        ~s(<circle cx="#{ex}" cy="#{ey+2}" r="12" fill="#b8bca8" #{cp}/>) <>
        ~s(<circle cx="#{ex}" cy="#{ey+2}" r="7"  fill="#d0d4c0" #{cp}/>) <>
        ~s(<circle cx="#{ex+2}" cy="#{ey+3}" r="4" fill="#888c78" #{cp}/>)

      1 -> # rot-green off-centre
        ~s(<circle cx="#{ex-3}" cy="#{ey+3}" r="11" fill="#7a9830" #{cp}/>) <>
        ~s(<circle cx="#{ex-3}" cy="#{ey+3}" r="6"  fill="#4a6018" #{cp}/>) <>
        ~s(<circle cx="#{ex-3}" cy="#{ey+3}" r="3"  fill="#{@rot}" #{cp}/>) <>
        ~s(<circle cx="#{ex-7}" cy="#{ey-1}" r="3"  fill="white" opacity="0.4" #{cp}/>)

      2 -> # rolled back — whites only with veins
        ~s(<circle cx="#{ex}" cy="#{ey+12}" r="14" fill="#c0c4b0" #{cp}/>)

      3 -> # half-shut, iris very low
        ~s(<circle cx="#{ex}" cy="#{ey+6}" r="11" fill="#8a9860" #{cp}/>) <>
        ~s(<circle cx="#{ex}" cy="#{ey+6}" r="6"  fill="#506030" #{cp}/>) <>
        ~s(<circle cx="#{ex}" cy="#{ey+6}" r="3"  fill="#{@rot}" #{cp}/>)

      4 -> # jaundiced yellow
        ~s(<circle cx="#{ex+2}" cy="#{ey+1}" r="12" fill="#c8b860" #{cp}/>) <>
        ~s(<circle cx="#{ex+2}" cy="#{ey+1}" r="7"  fill="#907830" #{cp}/>) <>
        ~s(<circle cx="#{ex+2}" cy="#{ey+1}" r="4"  fill="#{@rot}" #{cp}/>) <>
        ~s(<circle cx="#{ex-3}" cy="#{ey-3}" r="3"  fill="white" opacity="0.35" #{cp}/>)

      5 -> # supernatural pale glow
        ~s(<circle cx="#{ex}" cy="#{ey}" r="13" fill="#a0c8a0" #{cp}/>) <>
        ~s(<circle cx="#{ex}" cy="#{ey}" r="8"  fill="#c8f0c8" #{cp}/>) <>
        ~s(<circle cx="#{ex}" cy="#{ey}" r="4"  fill="white"   #{cp}/>)

      _ -> # dark / dead — very small iris
        ~s(<circle cx="#{ex}" cy="#{ey}" r="12" fill="#888880" #{cp}/>) <>
        ~s(<circle cx="#{ex}" cy="#{ey}" r="5"  fill="#404038" #{cp}/>) <>
        ~s(<circle cx="#{ex}" cy="#{ey}" r="2"  fill="#{@rot}" #{cp}/>)
    end
  end

  defp veins(ex, ey, ew, cp) do
    ~s(<line x1="#{ex-ew+4}" y1="#{ey+4}" x2="#{ex-4}" y2="#{ey-2}" stroke="#{@eye_vein}" stroke-width="1.2" opacity="0.5" #{cp}/>) <>
    ~s(<line x1="#{ex+8}" y1="#{ey+5}" x2="#{ex+ew-4}" y2="#{ey+1}" stroke="#{@eye_vein}" stroke-width="1" opacity="0.45" #{cp}/>)
  end

  defp drooping_lid(ex, ey, ew, eh, side, seed, ci, skin_dd) do
    {inner_x, outer_x} = if side == -1, do: {ex - ew, ex + ew}, else: {ex + ew, ex - ew}
    droop = 6 + jitter(seed, 52 + ci, 10)
    ~s(<path d="M#{inner_x},#{ey-4} Q#{ex},#{ey-eh-4} #{outer_x},#{ey+droop} L#{outer_x},#{ey+droop-12} Q#{ex},#{ey-eh-14} #{inner_x},#{ey-4-12}Z" fill="#{skin_dd}"/>)
  end

  # ── Nose ─────────────────────────────────────────────────────────────────

  defp nose(_seed, type, skin_d, skin_dd, skin_l) do
    # skin_l used for bloated variant tint
    # Bloat tint: slightly darker/cooler than skin_l for swollen look
    <<_::binary-size(1), r2::binary-size(2), g2::binary-size(2), b2::binary-size(2)>> = skin_l
    bloat_col = hex(
      min(255, round(String.to_integer(r2, 16) * 96 |> div(100))),
      min(255, round(String.to_integer(g2, 16) * 94 |> div(100))),
      min(255, round(String.to_integer(b2, 16) * 97 |> div(100)))
    )

    case type do
      0 -> # flesh pulled back, nostrils visible
        [
          ~s(<ellipse cx="100" cy="122" rx="28" ry="18" fill="#{skin_d}"/>),
          ~s(<ellipse cx="88"  cy="124" rx="11" ry="10" fill="#{@rot}"/>),
          ~s(<ellipse cx="112" cy="126" rx="10" ry="9"  fill="#{@rot}"/>),
          ~s(<ellipse cx="100" cy="110" rx="6"  ry="8"  fill="#{@bone}" opacity="0.28"/>),
        ]
        |> Enum.join("")

      1 -> # mostly missing, bone visible
        [
          ~s(<ellipse cx="100" cy="120" rx="20" ry="12" fill="#{skin_d}" opacity="0.5"/>),
          ~s(<ellipse cx="90"  cy="122" rx="12" ry="11" fill="#{@rot}"/>),
          ~s(<ellipse cx="110" cy="122" rx="11" ry="10" fill="#{@rot}"/>),
          ~s(<ellipse cx="100" cy="112" rx="8"  ry="6"  fill="#{@bone}"   opacity="0.55"/>),
          ~s(<ellipse cx="100" cy="112" rx="4"  ry="3"  fill="#{@bone_d}" opacity="0.4"/>),
        ]
        |> Enum.join("")

      2 -> # fully skeletal nasal cavity
        [
          ~s(<ellipse cx="100" cy="120" rx="16" ry="20" fill="#{@rot}"/>),
          ~s(<path d="M90,108 Q100,100 110,108 L108,128 Q100,132 92,128Z" fill="#{@rot}"/>),
          ~s(<ellipse cx="100" cy="110" rx="12" ry="8"  fill="#{@bone_d}" opacity="0.6"/>),
          ~s(<path d="M93,104 Q100,98 107,104" fill="none" stroke="#{@bone}" stroke-width="3" opacity="0.5"/>),
        ]
        |> Enum.join("")

      3 -> # sunken but intact
        [
          ~s(<ellipse cx="100" cy="118" rx="22" ry="16" fill="#{skin_d}"/>),
          ~s(<ellipse cx="88"  cy="120" rx="9"  ry="8"  fill="#{skin_dd}"/>),
          ~s(<ellipse cx="112" cy="120" rx="9"  ry="8"  fill="#{skin_dd}"/>),
          ~s(<ellipse cx="88"  cy="118" rx="4"  ry="3"  fill="#{skin_d}"/>),
          ~s(<ellipse cx="112" cy="118" rx="4"  ry="3"  fill="#{skin_d}"/>),
        ]
        |> Enum.join("")

      4 -> # torn — one side missing
        [
          ~s(<ellipse cx="96"  cy="120" rx="24" ry="16" fill="#{skin_d}"/>),
          ~s(<ellipse cx="86"  cy="122" rx="10" ry="9"  fill="#{@rot}"/>),
          ~s(<ellipse cx="110" cy="122" rx="9"  ry="8"  fill="#{@rot}"/>),
          ~s(<ellipse cx="76"  cy="118" rx="10" ry="8"  fill="#{@rot}" opacity="0.7"/>),
          ~s(<ellipse cx="74"  cy="116" rx="6"  ry="5"  fill="#{@bone}" opacity="0.4"/>),
        ]
        |> Enum.join("")

      5 -> # bloated / swollen
        [
          ~s(<ellipse cx="100" cy="124" rx="34" ry="22" fill="#{skin_d}"/>),
          ~s(<ellipse cx="100" cy="124" rx="28" ry="16" fill="#{bloat_col}"/>),
          ~s(<ellipse cx="86"  cy="126" rx="12" ry="11" fill="#{@rot}"/>),
          ~s(<ellipse cx="114" cy="126" rx="12" ry="11" fill="#{@rot}"/>),
        ]
        |> Enum.join("")

      _ -> # cartilage-only beak
        [
          ~s(<path d="M90,108 Q100,96 110,108 L114,126 Q100,132 86,126Z"  fill="#{@bone}"   opacity="0.6"/>),
          ~s(<path d="M93,110 Q100,100 107,110 L111,124 Q100,128 89,124Z" fill="#{@bone_d}" opacity="0.45"/>),
          ~s(<ellipse cx="89"  cy="124" rx="9" ry="8" fill="#{@rot}"/>),
          ~s(<ellipse cx="111" cy="124" rx="9" ry="8" fill="#{@rot}"/>),
        ]
        |> Enum.join("")
    end
  end

  # ── Mouth ─────────────────────────────────────────────────────────────────

  defp mouth(type, skin_d, skin_dd) do
    case type do
      0 -> # slack jaw hanging open — 6 upper teeth, 3 lower, missing gap
        upper = teeth_row(64, 6, [10,11,9,12,10,9], 140)
        lower = [
          ~s(<rect x="76"  y="160" width="10" height="8"  rx="2" fill="#{@bone}" opacity="0.8"/>),
          ~s(<rect x="100" y="160" width="9"  height="7"  rx="2" fill="#{@bone}" opacity="0.75"/>),
          ~s(<rect x="122" y="160" width="8"  height="9"  rx="2" fill="#{@bone}" opacity="0.8"/>),
        ]
        |> Enum.join("")
        [
          ~s(<ellipse cx="100" cy="154" rx="42" ry="22" fill="#{@maw}"/>),
          ~s(<rect x="62" y="138" width="76" height="7" rx="2" fill="#{@gum}"/>),
          upper,
          ~s(<rect x="88" y="140" width="2" height="10" fill="#{@maw}"/>),
          lower,
          ~s(<ellipse cx="100" cy="170" rx="38" ry="10" fill="#{skin_d}"/>),
        ]
        |> Enum.join("")

      1 -> # wide dislocated scream — 8 upper teeth
        upper = teeth_row(56, 8, [9,10,8,11,9,10,9,8], 139)
        [
          ~s(<ellipse cx="100" cy="158" rx="50" ry="28" fill="#{@maw}"/>),
          ~s(<rect x="54" y="136" width="92" height="8" rx="3" fill="#{@gum}"/>),
          upper,
          ~s(<ellipse cx="100" cy="175" rx="44" ry="10" fill="#{skin_d}"/>),
        ]
        |> Enum.join("")

      2 -> # partial snarl — 5 teeth
        upper = teeth_row(70, 5, [10,10,10,10,10], 142)
        [
          ~s(<path d="M68,148 Q100,158 132,148 Q130,166 100,170 Q70,166 68,148Z" fill="#{@maw}"/>),
          ~s(<rect x="68" y="140" width="64" height="8" rx="2" fill="#{@gum}"/>),
          upper,
        ]
        |> Enum.join("")

      3 -> # rotted closed — sealed but sunken
        [
          ~s(<ellipse cx="100" cy="148" rx="38" ry="10" fill="#{skin_dd}"/>),
          ~s(<ellipse cx="100" cy="150" rx="28" ry="6"  fill="#{@maw}"/>),
          ~s(<rect x="66" y="145" width="8" height="8" rx="2" fill="#{@bone}" opacity="0.7"/>),
          ~s(<rect x="126" y="145" width="8" height="8" rx="2" fill="#{@bone}" opacity="0.7"/>),
          ~s(<ellipse cx="100" cy="158" rx="30" ry="8" fill="#{skin_d}"/>),
        ]
        |> Enum.join("")

      4 -> # fully exposed jaw bone — double rows
        upper = teeth_row(66, 6, [9,9,9,9,9,9], 138)
        lower = teeth_row(64, 7, [8,8,8,8,8,8,8], 158)
        [
          ~s(<ellipse cx="100" cy="156" rx="44" ry="24" fill="#{@maw}"/>),
          ~s(<ellipse cx="100" cy="168" rx="38" ry="16" fill="#{@bone}" opacity="0.45"/>),
          ~s(<rect x="64" y="136" width="72" height="7" rx="2" fill="#{@gum}"/>),
          upper,
          lower,
        ]
        |> Enum.join("")

      5 -> # lopsided broken jaw — 4 upper + one long fang
        upper = teeth_row(74, 4, [10,10,10,10], 138)
        [
          ~s(<path d="M72,142 Q118,158 146,150 Q140,168 100,172 Q68,168 72,142Z" fill="#{@maw}"/>),
          ~s(<rect x="72" y="136" width="58" height="7" rx="2" fill="#{@gum}"/>),
          upper,
          ~s(<rect x="138" y="145" width="8" height="16" rx="3" fill="#{@bone}"/>),
          ~s(<rect x="138" y="157" width="8" height="4"  rx="1" fill="#{@bone_d}"/>),
          ~s(<ellipse cx="100" cy="172" rx="38" ry="9" fill="#{skin_d}"/>),
        ]
        |> Enum.join("")

      _ -> # barely open slit — 6 teeth
        upper = teeth_row(70, 6, [9,9,9,9,9,9], 141)
        [
          ~s(<ellipse cx="100" cy="148" rx="36" ry="8" fill="#{@maw}"/>),
          ~s(<rect x="68" y="140" width="64" height="6" rx="2" fill="#{@gum}"/>),
          upper,
          ~s(<ellipse cx="100" cy="155" rx="30" ry="7" fill="#{skin_d}"/>),
        ]
        |> Enum.join("")
    end
  end

  # Renders a row of teeth starting at start_x, each with its own width from the list
  defp teeth_row(start_x, _count, widths, y) do
    widths
    |> Enum.with_index()
    |> Enum.map_join("", fn {w, i} ->
      x  = start_x + Enum.sum(Enum.take(widths, i)) + i * 2
      th = 10 + round((w - 9) * 1.4)
      ~s(<rect x="#{x}" y="#{y}" width="#{w}" height="#{th}" rx="2" fill="#{@bone}"/>) <>
      ~s(<rect x="#{x}" y="#{y + th - 3}" width="#{w}" height="3" rx="1" fill="#{@bone_d}"/>)
    end)
  end

  # ── Wounds ────────────────────────────────────────────────────────────────

  defp wounds(_seed, 0, _w_seed), do: ""
  defp wounds(seed, nw, _w_seed) do
    routes_count = length(@wound_routes)
    {parts, _used} =
      Enum.reduce(0..(nw - 1), {[], MapSet.new()}, fn i, {acc, used} ->
        ri0 = rng(seed, 70 + i, routes_count)
        ri  = if MapSet.member?(used, ri0), do: rem(ri0 + 1, routes_count), else: ri0
        {x1, y1, x2, y2} = Enum.at(@wound_routes, ri)
        jx = jitter(seed, 80 + i, 12) - 6
        jy = jitter(seed, 90 + i, 10) - 5
        svg = jagged_line(seed, i, x1 + jx, y1 + jy, x2 + jx, y2 + jy)
        {[svg | acc], MapSet.put(used, ri)}
      end)
    Enum.join(parts, "")
  end

  # Draws a jagged wound line using manually jittered waypoints.
  # Divides the line into 8 segments, perturbing each midpoint
  # perpendicular to the line direction to create an organic scar.
  defp jagged_line(seed, wi, x1, y1, x2, y2) do
    steps = 8
    dx    = x2 - x1
    dy    = y2 - y1
    # Perpendicular unit vector scaled to max jitter
    len   = max(1, :math.sqrt(dx * dx + dy * dy))
    px    = -dy / len
    py    =  dx / len

    points =
      Enum.map(0..steps, fn k ->
        t    = k / steps
        base_x = x1 + round(dx * t)
        base_y = y1 + round(dy * t)
        # Perturb middle points; leave endpoints clean
        perturb = if k == 0 or k == steps do
          0
        else
          (jitter(seed, wi * 20 + k + 200, 13) - 6)
        end
        jx2 = round(px * perturb)
        jy2 = round(py * perturb)
        "#{base_x + jx2},#{base_y + jy2}"
      end)
      |> Enum.join(" ")

    ~s(<polyline points="#{points}" fill="none" stroke="#060302" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/>)
  end
end
