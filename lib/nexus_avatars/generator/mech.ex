defmodule NexusAvatars.Generator.Mech do
  @moduledoc """
  Generates Mech-style robot face SVGs.

  Eight archetypes, each a fundamentally different machine:
    0 — Cyclops     single massive central lens, industrial copper
    1 — Visor       full-width scanner band, military green
    2 — Insectoid   compound multi-facet eyes, mandible mouth
    3 — Damaged     cracked plate, asymmetric, exposed wiring
    4 — Ornate      ceremonial jewel eyes, gold filigree
    5 — Skeletal    minimal wireframe, cold blue
    6 — Artillery   heavy armor, cannon barrel mouth
    7 — Android     almost-human, uncanny silver

  The username hash selects the archetype, then seeds all visual parameters
  within that archetype: color family, panel seam angle, feature positions,
  glow intensity, surface wear level.
  """

  @size 256

  # ---------------------------------------------------------------------------
  # Public entry point
  # ---------------------------------------------------------------------------

  def render(username) do
    seed      = :erlang.phash2(username)
    archetype = rem(seed, 8)
    params    = derive_params(seed, archetype)

    svg(archetype, params)
  end

  # ---------------------------------------------------------------------------
  # Parameter derivation — all visual choices from the seed
  # ---------------------------------------------------------------------------

  defp derive_params(seed, archetype) do
    # Pull independent integers from the seed by hashing with different salts
    s = fn salt -> :erlang.phash2({seed, salt}, 100) end

    # Color families per archetype
    colors = archetype_colors(archetype, s.(1))

    %{
      seed:          seed,
      archetype:     archetype,
      # colors
      bg:            colors.bg,
      plate:         colors.plate,
      plate_mid:     colors.plate_mid,
      accent:        colors.accent,
      accent_bright: colors.accent_bright,
      glow:          colors.glow,
      # panel seam — 0=horizontal, 1=vertical, 2=diagonal, 3=none
      seam_type:     rem(s.(2), 4),
      seam_pos:      40 + rem(s.(3), 40),
      # surface wear — 0=clean, 1=worn, 2=heavy
      wear:          rem(s.(4), 3),
      # eye position offset
      eye_y:         42 + rem(s.(5), 12),
      eye_gap:       rem(s.(6), 8),
      # mouth position
      mouth_y:       @size - 48 - rem(s.(7), 20),
      # detail counts
      vent_count:    3 + rem(s.(8), 3),
      grill_slots:   4 + rem(s.(9), 3),
      # bolt positions
      bolt_y:        36 + rem(s.(10), 30),
      # nose type — 0=sensor box, 1=dual vents, 2=ridge, 3=none
      nose_type:     rem(s.(11), 4),
      # forehead detail — 0=vents, 1=crest, 2=antenna, 3=none
      head_detail:   rem(s.(12), 4),
    }
  end

  defp archetype_colors(archetype, variation) do
    palettes = [
      # 0 Cyclops — copper/gold families
      [
        %{bg: "#0e0800", plate: "#c07020", plate_mid: "#d08030", accent: "#e09040", accent_bright: "#ffb850", glow: "#ff7010"},
        %{bg: "#100a00", plate: "#b06018", plate_mid: "#c07028", accent: "#d08038", accent_bright: "#ffa040", glow: "#ff6008"},
        %{bg: "#0c0600", plate: "#8a4a10", plate_mid: "#a05a20", accent: "#c07030", accent_bright: "#e09040", glow: "#ff6000"},
      ],
      # 1 Visor — military green families
      [
        %{bg: "#060e04", plate: "#1a2a10", plate_mid: "#243a18", accent: "#40c020", accent_bright: "#80ff40", glow: "#20a000"},
        %{bg: "#040c02", plate: "#142008", plate_mid: "#1e3010", accent: "#30a018", accent_bright: "#60e030", glow: "#188000"},
        %{bg: "#080e04", plate: "#203018", plate_mid: "#2a4020", accent: "#50d030", accent_bright: "#90ff60", glow: "#30b010"},
      ],
      # 2 Insectoid — purple families
      [
        %{bg: "#0a0418", plate: "#200c3a", plate_mid: "#2c1050", accent: "#8040e0", accent_bright: "#c080ff", glow: "#6020c0"},
        %{bg: "#080314", plate: "#180830", plate_mid: "#240c42", accent: "#6030c0", accent_bright: "#a060f0", glow: "#5020a0"},
        %{bg: "#0c0520", plate: "#280e48", plate_mid: "#341458", accent: "#9050f0", accent_bright: "#d090ff", glow: "#7030d0"},
      ],
      # 3 Damaged — near-black with red damage
      [
        %{bg: "#060606", plate: "#141414", plate_mid: "#1e1e1e", accent: "#dc2626", accent_bright: "#f87171", glow: "#ef4444"},
        %{bg: "#040404", plate: "#101010", plate_mid: "#1a1a1a", accent: "#b91c1c", accent_bright: "#f87171", glow: "#dc2626"},
        %{bg: "#080808", plate: "#181818", plate_mid: "#222222", accent: "#ef4444", accent_bright: "#fca5a5", glow: "#f87171"},
      ],
      # 4 Ornate — gold/jewel families
      [
        %{bg: "#180c00", plate: "#241400", plate_mid: "#2c1800", accent: "#c08010", accent_bright: "#e0a020", glow: "#d09018"},
        %{bg: "#1a0e00", plate: "#281600", plate_mid: "#341c00", accent: "#d09018", accent_bright: "#f0b030", glow: "#e0a020"},
        %{bg: "#140a00", plate: "#200e00", plate_mid: "#2a1400", accent: "#a07010", accent_bright: "#c09020", glow: "#b08018"},
      ],
      # 5 Skeletal — cold blue families
      [
        %{bg: "#020408", plate: "#04080e", plate_mid: "#060c14", accent: "#2050a0", accent_bright: "#4080ff", glow: "#1e3060"},
        %{bg: "#020306", plate: "#030608", plate_mid: "#040810", accent: "#1840808", accent_bright: "#3060d0", glow: "#142848"},
        %{bg: "#030510", plate: "#060a18", plate_mid: "#080e20", accent: "#2860c0", accent_bright: "#50a0ff", glow: "#2050a0"},
      ],
      # 6 Artillery — dark iron/red families
      [
        %{bg: "#0a0808", plate: "#1a1210", plate_mid: "#282018", accent: "#ff2000", accent_bright: "#ff6040", glow: "#cc1800"},
        %{bg: "#080606", plate: "#141010", plate_mid: "#201818", accent: "#e01800", accent_bright: "#ff4020", glow: "#b01000"},
        %{bg: "#0c0808", plate: "#1e1410", plate_mid: "#2c221c", accent: "#ff3010", accent_bright: "#ff7050", glow: "#dd2000"},
      ],
      # 7 Android — silver/white families
      [
        %{bg: "#0e0e10", plate: "#d8d8dc", plate_mid: "#e0e0e4", accent: "#9090a8", accent_bright: "#c0c0d0", glow: "#8080a0"},
        %{bg: "#0c0c0e", plate: "#d0d0d4", plate_mid: "#d8d8dc", accent: "#8080a0", accent_bright: "#b0b0c8", glow: "#707090"},
        %{bg: "#101012", plate: "#e0e0e4", plate_mid: "#e8e8ec", accent: "#a0a0b8", accent_bright: "#d0d0e0", glow: "#9090b0"},
      ],
    ]

    palette_list = Enum.at(palettes, archetype)
    Enum.at(palette_list, rem(variation, length(palette_list)))
  end

  # ---------------------------------------------------------------------------
  # SVG assembly
  # ---------------------------------------------------------------------------

  defp svg(archetype, p) do
    """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{@size} #{@size}" width="#{@size}" height="#{@size}">
      #{base_fill(p)}
      #{panel_seam(p)}
      #{head_detail(p)}
      #{render_archetype(archetype, p)}
      #{ear_details(p)}
      #{wear_overlay(p)}
    </svg>
    """
  end

  # ---------------------------------------------------------------------------
  # Shared elements
  # ---------------------------------------------------------------------------

  defp base_fill(p) do
    """
    <rect width="#{@size}" height="#{@size}" fill="#{p.bg}"/>
    <ellipse cx="#{@size / 2}" cy="#{@size * 0.48}" rx="#{@size * 0.49}" ry="#{@size * 0.46}" fill="#{p.plate}"/>
    <ellipse cx="#{@size * 0.14}" cy="#{@size * 0.52}" rx="#{@size * 0.18}" ry="#{@size * 0.38}" fill="#{p.bg}" opacity="0.5"/>
    <ellipse cx="#{@size * 0.86}" cy="#{@size * 0.52}" rx="#{@size * 0.18}" ry="#{@size * 0.38}" fill="#{p.bg}" opacity="0.4"/>
    """
  end

  defp panel_seam(%{seam_type: 3}), do: ""
  defp panel_seam(%{seam_type: 0, seam_pos: y, bg: bg, accent: accent}) do
    """
    <rect x="0" y="#{y}" width="#{@size}" height="3" fill="#{bg}" opacity="0.8"/>
    <rect x="0" y="#{y + 1}" width="#{@size}" height="1" fill="#{accent}" opacity="0.3"/>
    """
  end
  defp panel_seam(%{seam_type: 1, seam_pos: x, bg: bg, accent: accent}) do
    """
    <rect x="#{x}" y="0" width="3" height="#{@size}" fill="#{bg}" opacity="0.8"/>
    <rect x="#{x + 1}" y="0" width="1" height="#{@size}" fill="#{accent}" opacity="0.3"/>
    """
  end
  defp panel_seam(%{seam_type: 2, seam_pos: offset, bg: bg, accent: accent}) do
    y1 = offset - 40
    y2 = offset + 100
    """
    <line x1="0" y1="#{y1}" x2="#{@size}" y2="#{y2}" stroke="#{bg}" stroke-width="3" opacity="0.9"/>
    <line x1="0" y1="#{y1 + 1}" x2="#{@size}" y2="#{y2 + 1}" stroke="#{accent}" stroke-width="0.8" opacity="0.35"/>
    """
  end

  defp head_detail(%{head_detail: 0, vent_count: n, plate_mid: pm, accent: acc, bg: bg}) do
    # Vent slots across forehead
    slot_w  = 16
    spacing = 22
    total   = n * spacing
    start_x = div(@size, 2) - div(total, 2)

    slots = Enum.map(0..(n - 1), fn i ->
      x = start_x + i * spacing
      """
      <rect x="#{x}" y="12" width="#{slot_w}" height="6" rx="2" fill="#{bg}" opacity="0.7"/>
      <rect x="#{x + 2}" y="13" width="#{slot_w - 4}" height="2" rx="1" fill="#{acc}" opacity="0.4"/>
      """
    end)
    |> Enum.join()

    """
    <rect x="18" y="10" width="#{@size - 36}" height="10" rx="3" fill="#{pm}" opacity="0.5"/>
    #{slots}
    """
  end
  defp head_detail(%{head_detail: 1, plate_mid: pm, accent: acc, accent_bright: ab}) do
    # Crown crest
    """
    <rect x="42" y="4" width="#{@size - 84}" height="16" rx="3" fill="#{pm}"/>
    <rect x="54" y="2" width="20" height="20" rx="4" fill="#{acc}"/>
    <circle cx="#{@size / 2}" cy="6" r="5" fill="#{ab}"/>
    <circle cx="#{@size / 2}" cy="6" r="2.5" fill="white" opacity="0.8"/>
    """
  end
  defp head_detail(%{head_detail: 2, accent: acc, accent_bright: ab}) do
    # Twin antennas
    """
    <line x1="72" y1="16" x2="60" y2="0" stroke="#{acc}" stroke-width="3"/>
    <circle cx="60" cy="0" r="5" fill="#{ab}"/>
    <circle cx="60" cy="0" r="2.5" fill="white" opacity="0.7"/>
    <line x1="184" y1="16" x2="196" y2="0" stroke="#{acc}" stroke-width="3"/>
    <circle cx="196" cy="0" r="5" fill="#{ab}" opacity="0.8"/>
    """
  end
  defp head_detail(%{head_detail: 3}), do: ""

  defp ear_details(%{bolt_y: by, bg: bg, plate_mid: pm, accent: acc}) do
    """
    <circle cx="6" cy="#{by}" r="9" fill="#{bg}" stroke="#{acc}" stroke-width="1.5"/>
    <circle cx="6" cy="#{by}" r="4.5" fill="#{pm}"/>
    <circle cx="#{@size - 6}" cy="#{by + 10}" r="9" fill="#{bg}" stroke="#{acc}" stroke-width="1.5"/>
    <circle cx="#{@size - 6}" cy="#{by + 10}" r="4.5" fill="#{pm}"/>
    """
  end

  defp wear_overlay(%{wear: 0}), do: ""
  defp wear_overlay(%{wear: 1, bg: bg}) do
    """
    <line x1="52" y1="30" x2="66" y2="68" stroke="#{bg}" stroke-width="1.5" opacity="0.5"/>
    <line x1="180" y1="26" x2="192" y2="58" stroke="#{bg}" stroke-width="1" opacity="0.4"/>
    """
  end
  defp wear_overlay(%{wear: 2, bg: bg, accent: acc}) do
    """
    <line x1="50" y1="20" x2="72" y2="80" stroke="#{bg}" stroke-width="2.5" opacity="0.7"/>
    <line x1="52" y1="21" x2="74" y2="81" stroke="#{acc}" stroke-width="0.8" opacity="0.2"/>
    <line x1="176" y1="24" x2="196" y2="72" stroke="#{bg}" stroke-width="1.5" opacity="0.5"/>
    <line x1="40" y1="88" x2="56" y2="120" stroke="#{bg}" stroke-width="1" opacity="0.4"/>
    """
  end

  # ---------------------------------------------------------------------------
  # Archetype renderers
  # ---------------------------------------------------------------------------

  # 0 — CYCLOPS
  defp render_archetype(0, p) do
    hw   = @size / 2
    ey   = p.eye_y
    er   = 50 + rem(p.seed, 14)  # eye radius varies
    my   = p.mouth_y
    bg   = p.bg
    acc  = p.accent
    ab   = p.accent_bright
    g    = p.glow

    """
    <!-- Cyclops: single massive central lens -->
    <circle cx="#{hw}" cy="#{ey}" r="#{er + 4}" fill="#{bg}"/>
    <circle cx="#{hw}" cy="#{ey}" r="#{er + 1}" fill="#{p.plate_mid}" opacity="0.3"/>
    <circle cx="#{hw}" cy="#{ey}" r="#{er - 2}" fill="#{g}" opacity="0.8"/>
    <circle cx="#{hw}" cy="#{ey}" r="#{er - 8}" fill="#{acc}"/>
    <circle cx="#{hw}" cy="#{ey}" r="#{er - 16}" fill="#{ab}"/>
    <circle cx="#{hw}" cy="#{ey}" r="#{er - 26}" fill="white" opacity="0.85"/>
    <circle cx="#{hw - 12}" cy="#{ey - 14}" r="7" fill="white" opacity="0.35"/>
    <!-- lens rings -->
    <circle cx="#{hw}" cy="#{ey}" r="#{er + 3}" fill="none" stroke="#{acc}" stroke-width="2"/>
    <circle cx="#{hw}" cy="#{ey}" r="#{er - 4}" fill="none" stroke="#{ab}" stroke-width="0.8" opacity="0.5"/>
    <!-- nose sensor -->
    #{nose(p, hw, ey + er + 10)}
    <!-- wide horizontal grill mouth -->
    #{grill_mouth(p, 20, my, @size - 40, 28)}
    """
  end

  # 1 — VISOR
  defp render_archetype(1, p) do
    my  = p.mouth_y
    bg  = p.bg
    acc = p.accent
    ab  = p.accent_bright

    """
    <!-- Visor: full-width scanner band -->
    <rect x="8" y="#{p.eye_y - 14}" width="#{@size - 16}" height="28" rx="7" fill="#{bg}"/>
    <rect x="10" y="#{p.eye_y - 12}" width="#{@size - 20}" height="24" rx="6" fill="#{p.plate_mid}" opacity="0.2"/>
    <!-- visor glow sweep -->
    <rect x="12" y="#{p.eye_y - 4}" width="#{@size - 24}" height="8" rx="4" fill="#{acc}" opacity="0.9"/>
    <rect x="12" y="#{p.eye_y - 4}" width="#{(@size - 24) * 0.35}" height="8" rx="4" fill="#{ab}" opacity="0.95"/>
    <rect x="#{@size * 0.65 - 4}" y="#{p.eye_y - 4}" width="#{(@size - 24) * 0.28}" height="8" rx="4" fill="#{ab}" opacity="0.7"/>
    <!-- visor reflection -->
    <rect x="14" y="#{p.eye_y - 10}" width="#{@size * 0.4}" height="4" rx="2" fill="white" opacity="0.07"/>
    <!-- cheek panels -->
    <rect x="8" y="#{p.eye_y + 18}" width="36" height="24" rx="4" fill="#{p.plate_mid}" opacity="0.5"/>
    <rect x="#{@size - 44}" y="#{p.eye_y + 18}" width="36" height="24" rx="4" fill="#{p.plate_mid}" opacity="0.5"/>
    <rect x="10" y="#{p.eye_y + 20}" width="32" height="6" rx="2" fill="#{acc}" opacity="0.3"/>
    <rect x="#{@size - 42}" y="#{p.eye_y + 20}" width="32" height="6" rx="2" fill="#{acc}" opacity="0.3"/>
    #{nose(p, @size / 2, p.eye_y + 46)}
    <!-- speaker dot grid mouth -->
    #{speaker_mouth(p, 22, my, @size - 44)}
    """
  end

  # 2 — INSECTOID
  defp render_archetype(2, p) do
    my  = p.mouth_y
    bg  = p.bg
    acc = p.accent
    ab  = p.accent_bright
    lx  = 64.0
    rx  = @size - 64.0
    ey  = p.eye_y

    """
    <!-- Insectoid: compound multi-facet eyes -->
    <!-- left compound eye -->
    <ellipse cx="#{lx}" cy="#{ey}" rx="28" ry="26" fill="#{bg}"/>
    <ellipse cx="#{lx}" cy="#{ey}" rx="26" ry="24" fill="#{p.plate_mid}" opacity="0.2"/>
    #{compound_facets(lx, ey, acc, ab, p.seed)}
    <!-- right compound eye -->
    <ellipse cx="#{rx}" cy="#{ey - 2}" rx="28" ry="26" fill="#{bg}"/>
    <ellipse cx="#{rx}" cy="#{ey - 2}" rx="26" ry="24" fill="#{p.plate_mid}" opacity="0.2"/>
    #{compound_facets(rx, ey - 2, acc, ab, p.seed + 1)}
    <!-- head crest -->
    <polygon points="#{@size / 2},4 #{@size / 2 - 14},22 #{@size / 2},18 #{@size / 2 + 14},22" fill="#{acc}"/>
    <polygon points="#{@size / 2},7 #{@size / 2 - 10},20 #{@size / 2},17 #{@size / 2 + 10},20" fill="#{ab}" opacity="0.8"/>
    <!-- proboscis nose -->
    <ellipse cx="#{@size / 2}" cy="#{ey + 36}" rx="10" ry="14" fill="#{p.plate_mid}"/>
    <ellipse cx="#{@size / 2}" cy="#{ey + 38}" rx="6" ry="9" fill="#{acc}" opacity="0.5"/>
    <!-- mandible mouth -->
    #{mandible_mouth(p, my)}
    """
  end

  # 3 — DAMAGED
  defp render_archetype(3, p) do
    my  = p.mouth_y
    bg  = p.bg
    acc = p.accent
    ab  = p.accent_bright
    lx  = 62 + rem(p.seed, 12)

    """
    <!-- Damaged: cracked plate, asymmetric -->
    <!-- major diagonal crack -->
    <polygon points="#{lx - 6},0 #{lx + 8},0 #{lx + 24},#{@size} #{lx + 10},#{@size}" fill="#{bg}" opacity="0.9"/>
    <line x1="#{lx + 1}" y1="0" x2="#{lx + 17}" y2="#{@size}" stroke="#{acc}" stroke-width="1.2" opacity="0.6"/>
    <!-- crack glow -->
    <polygon points="#{lx - 4},0 #{lx + 6},0 #{lx + 22},#{@size} #{lx + 12},#{@size}" fill="#{acc}" opacity="0.08"/>
    <!-- secondary cracks -->
    <line x1="#{lx + 4}" y1="62" x2="#{lx + 50}" y2="44" stroke="#{acc}" stroke-width="0.8" opacity="0.4"/>
    <line x1="#{lx + 8}" y1="110" x2="#{lx + 46}" y2="100" stroke="#{acc}" stroke-width="0.7" opacity="0.35"/>
    <!-- LEFT EYE — intact scanner -->
    <rect x="18" y="#{p.eye_y - 10}" width="#{lx - 28}" height="20" rx="4" fill="#{bg}"/>
    <rect x="20" y="#{p.eye_y - 8}" width="#{lx - 32}" height="16" rx="3" fill="#{p.plate_mid}" opacity="0.3"/>
    <rect x="22" y="#{p.eye_y - 2}" width="#{lx - 36}" height="5" rx="2" fill="#2060c0" opacity="0.9"/>
    <rect x="22" y="#{p.eye_y - 2}" width="#{(lx - 36) * 0.4}" height="5" rx="2" fill="#60a0ff" opacity="0.95"/>
    <!-- RIGHT EYE — cracked, red flicker -->
    <rect x="#{lx + 22}" y="#{p.eye_y - 12}" width="#{@size - lx - 40}" height="22" rx="4" fill="#{bg}"/>
    <line x1="#{lx + 24}" y1="#{p.eye_y - 12}" x2="#{lx + 44}" y2="#{p.eye_y + 10}" stroke="#{acc}" stroke-width="1.5" opacity="0.7"/>
    <line x1="#{lx + 44}" y1="#{p.eye_y - 12}" x2="#{lx + 26}" y2="#{p.eye_y + 8}" stroke="#{acc}" stroke-width="1" opacity="0.5"/>
    <rect x="#{lx + 26}" y="#{p.eye_y - 2}" width="#{@size - lx - 54}" height="5" rx="2" fill="#{acc}" opacity="0.4"/>
    <!-- exposed wiring right side -->
    <path d="M#{lx + 18} #{p.eye_y + 18} Q#{lx + 28} #{p.eye_y + 12} #{lx + 34} #{p.eye_y + 24}" stroke="#fbbf24" stroke-width="1.8" fill="none" opacity="0.7"/>
    <path d="M#{lx + 18} #{p.eye_y + 18} Q#{lx + 24} #{p.eye_y + 22} #{lx + 30} #{p.eye_y + 14}" stroke="#34d399" stroke-width="1.8" fill="none" opacity="0.7"/>
    <path d="M#{lx + 20} #{p.eye_y + 26} Q#{lx + 30} #{p.eye_y + 20} #{lx + 36} #{p.eye_y + 30}" stroke="#{acc}" stroke-width="1.5" fill="none" opacity="0.6"/>
    #{nose(p, (@size / 2) - 10, p.eye_y + 44)}
    #{grill_mouth(p, 14, my, @size - 28, 22)}
    """
  end

  # 4 — ORNATE
  defp render_archetype(4, p) do
    my   = p.mouth_y
    hw   = @size / 2
    ey   = p.eye_y
    acc  = p.accent
    ab   = p.accent_bright
    pm   = p.plate_mid
    bg   = p.bg
    jewel_l = "#c02050"
    jewel_r = "#2050c0"

    """
    <!-- Ornate: ceremonial jewel eyes, filigree -->
    <!-- side filigree panels -->
    <rect x="4" y="24" width="18" height="72" rx="4" fill="#{p.plate_mid}" opacity="0.6"/>
    <path d="M8 30 Q14 40 8 52 Q14 64 8 76 Q14 88 8 96" stroke="#{acc}" stroke-width="1.5" fill="none" opacity="0.7"/>
    <circle cx="14" cy="42" r="4" fill="#{ab}"/>
    <circle cx="14" cy="62" r="4" fill="#{ab}"/>
    <circle cx="14" cy="82" r="4" fill="#{ab}"/>
    <rect x="#{@size - 22}" y="24" width="18" height="72" rx="4" fill="#{pm}" opacity="0.6"/>
    <path d="M#{@size - 8} 30 Q#{@size - 14} 40 #{@size - 8} 52 Q#{@size - 14} 64 #{@size - 8} 76 Q#{@size - 14} 88 #{@size - 8} 96" stroke="#{acc}" stroke-width="1.5" fill="none" opacity="0.7"/>
    <circle cx="#{@size - 14}" cy="42" r="4" fill="#{ab}"/>
    <circle cx="#{@size - 14}" cy="62" r="4" fill="#{ab}"/>
    <circle cx="#{@size - 14}" cy="82" r="4" fill="#{ab}"/>
    <!-- crown -->
    <rect x="22" y="4" width="#{@size - 44}" height="18" rx="4" fill="#{p.plate_mid}"/>
    <rect x="30" y="6" width="16" height="14" rx="2" fill="#{acc}" opacity="0.7"/>
    <rect x="#{hw - 12}" y="3" width="24" height="20" rx="4" fill="#{acc}"/>
    <rect x="#{hw - 8}" y="5" width="16" height="16" rx="3" fill="#{ab}"/>
    <circle cx="#{hw}" cy="8" r="6" fill="#{ab}"/>
    <circle cx="#{hw}" cy="8" r="3.5" fill="white" opacity="0.8"/>
    <rect x="#{@size - 46}" y="6" width="16" height="14" rx="2" fill="#{acc}" opacity="0.7"/>
    <!-- LEFT JEWEL EYE — almond -->
    <path d="M#{hw - 76} #{ey} Q#{hw - 52} #{ey - 20} #{hw - 28} #{ey} Q#{hw - 52} #{ey + 20} #{hw - 76} #{ey}Z" fill="#{bg}"/>
    <path d="M#{hw - 74} #{ey} Q#{hw - 52} #{ey - 17} #{hw - 30} #{ey} Q#{hw - 52} #{ey + 17} #{hw - 74} #{ey}Z" fill="#{jewel_l}"/>
    <path d="M#{hw - 70} #{ey} Q#{hw - 52} #{ey - 13} #{hw - 34} #{ey} Q#{hw - 52} #{ey + 13} #{hw - 70} #{ey}Z" fill="#e03060"/>
    <ellipse cx="#{hw - 52}" cy="#{ey}" rx="10" ry="7" fill="#ff80a0"/>
    <ellipse cx="#{hw - 52}" cy="#{ey}" rx="5" ry="3.5" fill="white" opacity="0.8"/>
    <!-- RIGHT JEWEL EYE — almond -->
    <path d="M#{hw + 28} #{ey - 2} Q#{hw + 52} #{ey - 22} #{hw + 76} #{ey - 2} Q#{hw + 52} #{ey + 18} #{hw + 28} #{ey - 2}Z" fill="#{bg}"/>
    <path d="M#{hw + 30} #{ey - 2} Q#{hw + 52} #{ey - 19} #{hw + 74} #{ey - 2} Q#{hw + 52} #{ey + 15} #{hw + 30} #{ey - 2}Z" fill="#{jewel_r}"/>
    <path d="M#{hw + 34} #{ey - 2} Q#{hw + 52} #{ey - 15} #{hw + 70} #{ey - 2} Q#{hw + 52} #{ey + 11} #{hw + 34} #{ey - 2}Z" fill="#3060e0"/>
    <ellipse cx="#{hw + 52}" cy="#{ey - 2}" rx="10" ry="7" fill="#80a0ff"/>
    <ellipse cx="#{hw + 52}" cy="#{ey - 2}" rx="5" ry="3.5" fill="white" opacity="0.8"/>
    <!-- ornate nose -->
    <rect x="#{hw - 14}" y="#{ey + 26}" width="28" height="16" rx="6" fill="#{bg}"/>
    <rect x="#{hw - 12}" y="#{ey + 28}" width="24" height="12" rx="5" fill="#{acc}"/>
    <rect x="#{hw - 8}" y="#{ey + 30}" width="16" height="8" rx="4" fill="#{ab}"/>
    <circle cx="#{hw}" cy="#{ey + 34}" r="4" fill="white" opacity="0.7"/>
    <!-- ornate mouth -->
    #{ornate_mouth(p, my)}
    """
  end

  # 5 — SKELETAL
  defp render_archetype(5, p) do
    my  = p.mouth_y
    hw  = @size / 2
    ey  = p.eye_y
    acc = p.accent
    ab  = p.accent_bright
    bg  = p.bg

    """
    <!-- Skeletal: minimal wireframe -->
    <!-- outer frame -->
    <rect x="18" y="14" width="#{@size - 36}" height="#{@size - 28}" rx="12" fill="none" stroke="#{acc}" stroke-width="2.5"/>
    <rect x="20" y="16" width="#{@size - 40}" height="#{@size - 32}" rx="11" fill="none" stroke="#{acc}" stroke-width="1" opacity="0.4"/>
    <!-- cross braces -->
    <line x1="18" y1="#{ey}" x2="#{@size - 18}" y2="#{ey}" stroke="#{acc}" stroke-width="1" opacity="0.3"/>
    <line x1="#{hw}" y1="14" x2="#{hw}" y2="#{@size - 14}" stroke="#{acc}" stroke-width="1" opacity="0.3"/>
    <!-- frame corner joints -->
    <circle cx="18" cy="14" r="5" fill="#{acc}"/>
    <circle cx="#{@size - 18}" cy="14" r="5" fill="#{acc}"/>
    <circle cx="18" cy="#{@size - 14}" r="5" fill="#{acc}"/>
    <circle cx="#{@size - 18}" cy="#{@size - 14}" r="5" fill="#{acc}"/>
    <!-- LEFT EYE — horizontal scanner -->
    <rect x="26" y="#{ey - 10}" width="#{hw - 38}" height="20" rx="4" fill="#{bg}"/>
    <rect x="28" y="#{ey - 8}" width="#{hw - 42}" height="16" rx="3" fill="#{p.plate_mid}" opacity="0.15"/>
    <rect x="30" y="#{ey - 2}" width="#{hw - 46}" height="5" rx="2.5" fill="#{ab}" opacity="0.9"/>
    <rect x="30" y="#{ey - 2}" width="#{(hw - 46) * 0.4}" height="5" rx="2.5" fill="white" opacity="0.7"/>
    <!-- RIGHT EYE — horizontal scanner -->
    <rect x="#{hw + 12}" y="#{ey - 10}" width="#{hw - 38}" height="20" rx="4" fill="#{bg}"/>
    <rect x="#{hw + 14}" y="#{ey - 8}" width="#{hw - 42}" height="16" rx="3" fill="#{p.plate_mid}" opacity="0.15"/>
    <rect x="#{hw + 16}" y="#{ey - 2}" width="#{hw - 46}" height="5" rx="2.5" fill="#{ab}" opacity="0.9"/>
    <rect x="#{hw + 36}" y="#{ey - 2}" width="#{(hw - 46) * 0.35}" height="5" rx="2.5" fill="white" opacity="0.7"/>
    <!-- nose dot -->
    <circle cx="#{hw}" cy="#{ey + 36}" r="5" fill="#{bg}" stroke="#{acc}" stroke-width="1.5"/>
    <circle cx="#{hw}" cy="#{ey + 36}" r="2.5" fill="#{ab}" opacity="0.7"/>
    <!-- line mouth with end caps -->
    <line x1="32" y1="#{my}" x2="#{@size - 32}" y2="#{my}" stroke="#{acc}" stroke-width="3"/>
    <circle cx="32" cy="#{my}" r="5" fill="#{acc}"/>
    <circle cx="#{@size - 32}" cy="#{my}" r="5" fill="#{acc}"/>
    <circle cx="#{hw - 28}" cy="#{my}" r="3" fill="#{ab}" opacity="0.6"/>
    <circle cx="#{hw}" cy="#{my}" r="3" fill="#{ab}" opacity="0.8"/>
    <circle cx="#{hw + 28}" cy="#{my}" r="3" fill="#{ab}" opacity="0.6"/>
    """
  end

  # 6 — ARTILLERY
  defp render_archetype(6, p) do
    my   = p.mouth_y
    hw   = @size / 2
    ey   = p.eye_y
    acc  = p.accent
    ab   = p.accent_bright
    bg   = p.bg
    pm   = p.plate_mid

    """
    <!-- Artillery: heavy armor, cannon barrel mouth -->
    <!-- heavy armor top plate with rivets -->
    <rect x="6" y="6" width="#{@size - 12}" height="#{ey + 6}" rx="6" fill="#{pm}"/>
    <rect x="8" y="8" width="#{@size - 16}" height="#{ey + 2}" rx="5" fill="#{p.plate}"/>
    <!-- rivet corners -->
    <circle cx="18" cy="18" r="5.5" fill="#{bg}"/>
    <circle cx="18" cy="18" r="3" fill="#{pm}"/>
    <circle cx="#{@size - 18}" cy="18" r="5.5" fill="#{bg}"/>
    <circle cx="#{@size - 18}" cy="18" r="3" fill="#{pm}"/>
    <circle cx="18" cy="#{ey + 4}" r="5.5" fill="#{bg}"/>
    <circle cx="18" cy="#{ey + 4}" r="3" fill="#{pm}"/>
    <circle cx="#{@size - 18}" cy="#{ey + 4}" r="5.5" fill="#{bg}"/>
    <circle cx="#{@size - 18}" cy="#{ey + 4}" r="3" fill="#{pm}"/>
    <!-- brow overhang -->
    <rect x="6" y="#{ey - 14}" width="#{@size - 12}" height="14" rx="3" fill="#{bg}" opacity="0.8"/>
    <!-- small mean eyes under brow -->
    <rect x="22" y="#{ey - 12}" width="#{hw - 36}" height="14" rx="3" fill="#{bg}"/>
    <rect x="24" y="#{ey - 10}" width="#{hw - 40}" height="10" rx="2" fill="#{pm}" opacity="0.3"/>
    <rect x="26" y="#{ey - 5}" width="#{hw - 44}" height="5" rx="2" fill="#{acc}" opacity="0.9"/>
    <rect x="26" y="#{ey - 5}" width="#{(hw - 44) * 0.38}" height="5" rx="2" fill="#{ab}" opacity="0.95"/>
    <rect x="#{hw + 10}" y="#{ey - 12}" width="#{hw - 36}" height="14" rx="3" fill="#{bg}"/>
    <rect x="#{hw + 12}" y="#{ey - 10}" width="#{hw - 40}" height="10" rx="2" fill="#{pm}" opacity="0.3"/>
    <rect x="#{hw + 14}" y="#{ey - 5}" width="#{hw - 44}" height="5" rx="2" fill="#{acc}" opacity="0.9"/>
    <rect x="#{hw + 34}" y="#{ey - 5}" width="#{(hw - 44) * 0.35}" height="5" rx="2" fill="#{ab}" opacity="0.8"/>
    <!-- heavy jaw -->
    <rect x="4" y="#{ey + 14}" width="#{@size - 8}" height="#{@size - ey - 20}" rx="5" fill="#{pm}"/>
    <rect x="6" y="#{ey + 16}" width="#{@size - 12}" height="#{@size - ey - 24}" rx="4" fill="#{p.plate}"/>
    <!-- jaw seam -->
    <line x1="4" y1="#{ey + 16}" x2="#{@size - 4}" y2="#{ey + 16}" stroke="#{bg}" stroke-width="3"/>
    <!-- dual nose vents above cannon -->
    <rect x="#{hw - 28}" y="#{ey + 22}" width="22" height="10" rx="3" fill="#{bg}"/>
    <circle cx="#{hw - 17}" cy="#{ey + 27}" r="3.5" fill="#{acc}" opacity="0.6"/>
    <rect x="#{hw + 6}" y="#{ey + 22}" width="22" height="10" rx="3" fill="#{bg}"/>
    <circle cx="#{hw + 17}" cy="#{ey + 27}" r="3.5" fill="#{acc}" opacity="0.6"/>
    <!-- CANNON BARREL MOUTH — concentric rings -->
    <circle cx="#{hw}" cy="#{my}" r="28" fill="#{bg}"/>
    <circle cx="#{hw}" cy="#{my}" r="25" fill="#{pm}" opacity="0.3"/>
    <circle cx="#{hw}" cy="#{my}" r="21" fill="#{bg}"/>
    <circle cx="#{hw}" cy="#{my}" r="17" fill="#{pm}" opacity="0.2"/>
    <circle cx="#{hw}" cy="#{my}" r="13" fill="#{bg}"/>
    <circle cx="#{hw}" cy="#{my}" r="9" fill="#{pm}" opacity="0.2"/>
    <circle cx="#{hw}" cy="#{my}" r="5" fill="#{acc}" opacity="0.3"/>
    <!-- rifling rings -->
    <circle cx="#{hw}" cy="#{my}" r="26" fill="none" stroke="#{pm}" stroke-width="2"/>
    <circle cx="#{hw}" cy="#{my}" r="20" fill="none" stroke="#{pm}" stroke-width="1.5"/>
    <circle cx="#{hw}" cy="#{my}" r="14" fill="none" stroke="#{pm}" stroke-width="1.5"/>
    <!-- side vents flanking cannon -->
    <rect x="12" y="#{my - 8}" width="#{hw - 46}" height="7" rx="2" fill="#{bg}"/>
    <rect x="14" y="#{my - 7}" width="#{hw - 50}" height="5" rx="1" fill="#{acc}" opacity="0.3"/>
    <rect x="#{hw + 46}" y="#{my - 8}" width="#{hw - 46}" height="7" rx="2" fill="#{bg}"/>
    <rect x="#{hw + 48}" y="#{my - 7}" width="#{hw - 50}" height="5" rx="1" fill="#{acc}" opacity="0.3"/>
    """
  end

  # 7 — ANDROID
  defp render_archetype(7, p) do
    my  = p.mouth_y
    hw  = @size / 2
    ey  = p.eye_y
    acc = p.accent
    pm  = p.plate_mid
    bg  = p.bg

    """
    <!-- Android: almost-human, uncanny silver -->
    <!-- subtle panel seams — barely visible -->
    <line x1="0" y1="#{ey + 4}" x2="#{@size}" y2="#{ey + 6}" stroke="#{acc}" stroke-width="0.8" opacity="0.4"/>
    <line x1="#{hw - 20}" y1="0" x2="#{hw - 22}" y2="#{@size}" stroke="#{acc}" stroke-width="0.6" opacity="0.3"/>
    <line x1="#{hw + 20}" y1="0" x2="#{hw + 22}" y2="#{@size}" stroke="#{acc}" stroke-width="0.6" opacity="0.3"/>
    <!-- subtle brow ridges -->
    <path d="M#{hw - 80} #{ey - 20} Q#{hw - 52} #{ey - 28} #{hw - 24} #{ey - 22}" stroke="#{acc}" stroke-width="1.5" fill="none" opacity="0.5"/>
    <path d="M#{hw + 24} #{ey - 22} Q#{hw + 52} #{ey - 28} #{hw + 80} #{ey - 20}" stroke="#{acc}" stroke-width="1.5" fill="none" opacity="0.5"/>
    <!-- LEFT EYE — almond, pale iris -->
    <ellipse cx="#{hw - 52}" cy="#{ey}" rx="20" ry="13" fill="white"/>
    <ellipse cx="#{hw - 52}" cy="#{ey}" rx="15" ry="9" fill="#{p.plate_mid}"/>
    <ellipse cx="#{hw - 52}" cy="#{ey}" rx="10" ry="8" fill="#c0c0e0"/>
    <ellipse cx="#{hw - 52}" cy="#{ey}" rx="6" ry="6" fill="#8080c0"/>
    <ellipse cx="#{hw - 52}" cy="#{ey}" rx="3" ry="3.5" fill="#{bg}"/>
    <circle cx="#{hw - 58}" cy="#{ey - 4}" r="2.5" fill="white" opacity="0.7"/>
    <ellipse cx="#{hw - 52}" cy="#{ey}" rx="20" ry="13" fill="none" stroke="#{acc}" stroke-width="1" opacity="0.4"/>
    <!-- RIGHT EYE — almond, pale iris -->
    <ellipse cx="#{hw + 52}" cy="#{ey - 2}" rx="20" ry="13" fill="white"/>
    <ellipse cx="#{hw + 52}" cy="#{ey - 2}" rx="15" ry="9" fill="#{pm}"/>
    <ellipse cx="#{hw + 52}" cy="#{ey - 2}" rx="10" ry="8" fill="#c0c0e0"/>
    <ellipse cx="#{hw + 52}" cy="#{ey - 2}" rx="6" ry="6" fill="#8080c0"/>
    <ellipse cx="#{hw + 52}" cy="#{ey - 2}" rx="3" ry="3.5" fill="#{bg}"/>
    <circle cx="#{hw + 46}" cy="#{ey - 6}" r="2.5" fill="white" opacity="0.7"/>
    <ellipse cx="#{hw + 52}" cy="#{ey - 2}" rx="20" ry="13" fill="none" stroke="#{acc}" stroke-width="1" opacity="0.4"/>
    <!-- subtle nose bridge -->
    <path d="M#{hw - 8} #{ey + 16} Q#{hw} #{ey + 30} #{hw + 8} #{ey + 16}" stroke="#{acc}" stroke-width="1.5" fill="none" opacity="0.6"/>
    <ellipse cx="#{hw - 8}" cy="#{ey + 36}" rx="5" ry="6" fill="#{pm}" opacity="0.5"/>
    <ellipse cx="#{hw + 8}" cy="#{ey + 36}" rx="5" ry="6" fill="#{pm}" opacity="0.5"/>
    <ellipse cx="#{hw - 8}" cy="#{ey + 37}" rx="2.5" ry="3.5" fill="#{acc}" opacity="0.4"/>
    <ellipse cx="#{hw + 8}" cy="#{ey + 37}" rx="2.5" ry="3.5" fill="#{acc}" opacity="0.4"/>
    <!-- thin lip mouth — uncanny valley -->
    <path d="M#{hw - 38} #{my} Q#{hw} #{my - 6} #{hw + 38} #{my}" stroke="#{acc}" stroke-width="2.5" fill="none"/>
    <path d="M#{hw - 38} #{my} Q#{hw} #{my + 8} #{hw + 38} #{my} Q#{hw + 26} #{my + 12} #{hw} #{my + 13} Q#{hw - 26} #{my + 12} #{hw - 38} #{my}Z" fill="#{pm}" opacity="0.35"/>
    <!-- faint center line -->
    <line x1="#{hw}" y1="#{ey - 36}" x2="#{hw}" y2="#{my + 4}" stroke="#{acc}" stroke-width="0.7" opacity="0.2"/>
    """
  end

  # ---------------------------------------------------------------------------
  # Shared feature helpers
  # ---------------------------------------------------------------------------

  defp compound_facets(cx, cy, acc, ab, seed) do
    offsets = [{-10, -10}, {4, -14}, {-16, 2}, {4, 2}, {-10, 14}, {6, 12}]
    |> Enum.with_index()
    |> Enum.map(fn {{dx, dy}, i} ->
      r  = 9 + rem(seed + i, 4)
      op = 0.6 + rem(seed + i, 3) * 0.1
      c  = if rem(seed + i, 2) == 0, do: acc, else: ab
      "<ellipse cx=\"#{cx + dx}\" cy=\"#{cy + dy}\" rx=\"#{r}\" ry=\"#{r}\" fill=\"#{c}\" opacity=\"#{op}\"/>"
    end)
    |> Enum.join()

    center_r = 10 + rem(seed, 6)
    """
    #{offsets}
    <ellipse cx="#{cx}" cy="#{cy}" rx="#{center_r}" ry="#{center_r}" fill="#{ab}" opacity="0.8"/>
    <ellipse cx="#{cx}" cy="#{cy}" rx="#{div(center_r, 2)}" ry="#{div(center_r, 2)}" fill="white" opacity="0.7"/>
    <circle cx="#{cx - 5}" cy="#{cy - 5}" r="2.5" fill="white" opacity="0.5"/>
    """
  end

  defp nose(%{nose_type: 0, bg: bg, accent: acc}, cx, y) do
    "<rect x=\"#{cx - 12}\" y=\"#{y}\" width=\"24\" height=\"10\" rx=\"3\" fill=\"#{bg}\"/><circle cx=\"#{cx}\" cy=\"#{y + 5}\" r=\"4\" fill=\"#{acc}\" opacity=\"0.7\"/>"
  end
  defp nose(%{nose_type: 1, bg: bg, accent: acc, accent_bright: ab}, cx, y) do
    "<ellipse cx=\"#{cx - 10}\" cy=\"#{y + 5}\" rx=\"7\" ry=\"9\" fill=\"#{bg}\"/><ellipse cx=\"#{cx - 10}\" cy=\"#{y + 7}\" rx=\"4\" ry=\"4\" fill=\"#{acc}\" opacity=\"0.6\"/><ellipse cx=\"#{cx + 10}\" cy=\"#{y + 5}\" rx=\"7\" ry=\"9\" fill=\"#{bg}\"/><ellipse cx=\"#{cx + 10}\" cy=\"#{y + 7}\" rx=\"4\" ry=\"4\" fill=\"#{ab}\" opacity=\"0.6\"/>"
  end
  defp nose(%{nose_type: 2, accent: acc, plate_mid: pm}, cx, y) do
    "<rect x=\"#{cx - 14}\" y=\"#{y}\" width=\"28\" height=\"10\" rx=\"3\" fill=\"#{pm}\"/><rect x=\"#{cx - 10}\" y=\"#{y + 2}\" width=\"20\" height=\"6\" rx=\"2\" fill=\"#{acc}\" opacity=\"0.5\"/><line x1=\"#{cx}\" y1=\"#{y}\" x2=\"#{cx}\" y2=\"#{y + 10}\" stroke=\"white\" stroke-width=\"0.8\" opacity=\"0.3\"/>"
  end
  defp nose(%{nose_type: 3}, _cx, _y), do: ""

  defp grill_mouth(%{grill_slots: n, bg: bg, accent: acc, plate_mid: pm}, x, y, w, h) do
    slot_w  = div(w - (n + 1) * 4, n)
    spacing = slot_w + 4

    slots = Enum.map(0..(n - 1), fn i ->
      sx = x + 4 + i * spacing
      hi = if rem(i, 2) == 0, do: "opacity=\"0.6\"", else: "opacity=\"0.35\""
      """
      <rect x="#{sx}" y="#{y + 3}" width="#{slot_w}" height="#{h - 6}" rx="2" fill="#{pm}"/>
      <rect x="#{sx}" y="#{y + 4}" width="#{slot_w}" height="4" rx="1" fill="#{acc}" #{hi}/>
      """
    end)
    |> Enum.join()

    """
    <rect x="#{x}" y="#{y}" width="#{w}" height="#{h}" rx="5" fill="#{bg}"/>
    #{slots}
    """
  end

  defp speaker_mouth(%{bg: bg, accent: acc, glow: glow}, x, y, w) do
    cols = 7
    rows = 2
    dot_r  = 4
    h_gap  = div(w - cols * dot_r * 2, cols + 1)
    v_gap  = 14

    dots = for row <- 0..(rows - 1), col <- 0..(cols - 1) do
      dx = x + h_gap + col * (dot_r * 2 + h_gap)
      dy = y + 8 + row * v_gap
      op = if rem(col + row, 3) == 0, do: "0.8", else: "0.5"
      c  = if rem(col, 2) == 0, do: acc, else: glow
      "<circle cx=\"#{dx}\" cy=\"#{dy}\" r=\"#{dot_r}\" fill=\"#{bg}\"/><circle cx=\"#{dx}\" cy=\"#{dy}\" r=\"#{dot_r - 1.5}\" fill=\"#{c}\" opacity=\"#{op}\"/>"
    end
    |> Enum.join()

    """
    <rect x="#{x}" y="#{y}" width="#{w}" height="#{rows * v_gap + 16}" rx="5" fill="#{bg}"/>
    #{dots}
    """
  end

  defp mandible_mouth(%{bg: bg, accent: acc, plate_mid: pm}, y) do
    hw = @size / 2
    """
    <path d="M#{hw - 72} #{y} Q#{hw - 44} #{y - 10} #{hw} #{y - 8} Q#{hw + 44} #{y - 10} #{hw + 72} #{y}" fill="#{bg}" stroke="#{acc}" stroke-width="1.5"/>
    <path d="M#{hw - 72} #{y} Q#{hw - 84} #{y + 16} #{hw - 76} #{y + 32} Q#{hw - 64} #{y + 20} #{hw - 58} #{y + 14} Q#{hw - 64} #{y + 10} #{hw - 72} #{y}Z" fill="#{acc}"/>
    <path d="M#{hw - 72} #{y} Q#{hw - 80} #{y + 12} #{hw - 74} #{y + 28} Q#{hw - 65} #{y + 18} #{hw - 60} #{y + 14}" fill="#{pm}" opacity="0.6"/>
    <path d="M#{hw + 72} #{y} Q#{hw + 84} #{y + 16} #{hw + 76} #{y + 32} Q#{hw + 64} #{y + 20} #{hw + 58} #{y + 14} Q#{hw + 64} #{y + 10} #{hw + 72} #{y}Z" fill="#{acc}"/>
    <path d="M#{hw + 72} #{y} Q#{hw + 80} #{y + 12} #{hw + 74} #{y + 28} Q#{hw + 65} #{y + 18} #{hw + 60} #{y + 14}" fill="#{pm}" opacity="0.6"/>
    <rect x="#{hw - 32}" y="#{y - 4}" width="12" height="10" rx="2" fill="#{pm}" opacity="0.6"/>
    <rect x="#{hw - 6}" y="#{y - 6}" width="12" height="12" rx="2" fill="#{acc}" opacity="0.8"/>
    <rect x="#{hw + 20}" y="#{y - 4}" width="12" height="10" rx="2" fill="#{pm}" opacity="0.6"/>
    """
  end

  defp ornate_mouth(%{bg: bg, accent: acc, accent_bright: ab, plate_mid: pm}, y) do
    hw = @size / 2
    """
    <rect x="22" y="#{y}" width="#{@size - 44}" height="28" rx="7" fill="#{bg}"/>
    <rect x="24" y="#{y + 2}" width="#{@size - 48}" height="24" rx="6" fill="#{acc}" opacity="0.4"/>
    <rect x="28" y="#{y + 4}" width="#{hw - 46}" height="20" rx="4" fill="#{bg}"/>
    <rect x="#{hw + 2}" y="#{y + 4}" width="#{hw - 32}" height="20" rx="4" fill="#{bg}"/>
    <rect x="32" y="#{y + 6}" width="#{hw - 54}" height="16" rx="3" fill="#{pm}" opacity="0.35"/>
    <rect x="#{hw + 6}" y="#{y + 6}" width="#{hw - 40}" height="16" rx="3" fill="#{pm}" opacity="0.35"/>
    <circle cx="#{hw}" cy="#{y + 14}" r="7" fill="#{acc}"/>
    <circle cx="#{hw}" cy="#{y + 14}" r="4.5" fill="#{ab}"/>
    <circle cx="#{hw - 1}" cy="#{y + 13}" r="2" fill="white" opacity="0.7"/>
    """
  end
end
