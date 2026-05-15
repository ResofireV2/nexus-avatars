defmodule NexusAvatars.Generator.Mech do
  @moduledoc """
  Generates Mech-style robot face SVGs.

  Design constraints:
  - 256x256 canvas, background fills entire square
  - All face content stays within inscribed circle (cx=128, cy=128, r=118)
  - Corner zones are background-only (safe for circular avatar cropping)
  - Bold shapes readable at 40px

  Eight archetypes:
    0 — Cyclops     single massive central lens
    1 — Visor       full-width horizontal scanner band
    2 — Duo         two large symmetrical eyes
    3 — Damaged     cracked plate, red warning eye
    4 — Ornate      jewelled triple-eye ceremonial mask
    5 — Skeletal    wireframe skull, cold blue
    6 — Artillery   heavy iron, single barrel mouth
    7 — Android     near-human silver face
  """

  @size    256
  @cx      128
  @cy      128
  @r       118   # inscribed circle radius — no features outside this

  def render(username) do
    seed      = :erlang.phash2(username)
    archetype = rem(seed, 8)
    s         = fn salt -> :erlang.phash2({seed, salt}, 100) end
    colors    = palette(archetype, rem(s.(1), 3))
    p         = %{
      seed:      seed,
      archetype: archetype,
      colors:    colors,
      s:         s,
    }
    build(archetype, p)
  end

  # ---------------------------------------------------------------------------
  # Palettes — each archetype has 3 color variants
  # bg: full square background
  # face: main head plate (fills most of circle)
  # mid: secondary plate tone
  # acc: accent / glow color
  # bright: highlight
  # dark: shadow / recess
  # ---------------------------------------------------------------------------

  defp palette(0, v) do  # Cyclops — copper
    Enum.at([
      %{bg: "#1a0e00", face: "#b85c10", mid: "#d07020", acc: "#ff8020", bright: "#ffc060", dark: "#3a1800"},
      %{bg: "#0e1800", face: "#408020", mid: "#50a030", acc: "#80ff40", bright: "#c0ff80", dark: "#102800"},
      %{bg: "#0a0a1a", face: "#2040a0", mid: "#3060c0", acc: "#60a0ff", bright: "#a0c8ff", dark: "#080818"},
    ], v)
  end

  defp palette(1, v) do  # Visor — military
    Enum.at([
      %{bg: "#080e04", face: "#1a2e10", mid: "#243818", acc: "#40d020", bright: "#90ff50", dark: "#060a04"},
      %{bg: "#0a0818", face: "#281848", mid: "#382060", acc: "#8040ff", bright: "#c080ff", dark: "#080614"},
      %{bg: "#180800", face: "#382010", mid: "#503020", acc: "#ff4010", bright: "#ff9060", dark: "#100400"},
    ], v)
  end

  defp palette(2, v) do  # Duo — teal
    Enum.at([
      %{bg: "#020e10", face: "#083038", mid: "#104850", acc: "#20c0d0", bright: "#80f0ff", dark: "#020810"},
      %{bg: "#100408", face: "#381020", mid: "#501830", acc: "#e04080", bright: "#ff90b0", dark: "#0c0306"},
      %{bg: "#0c1000", face: "#203010", mid: "#304018", acc: "#90d020", bright: "#d0ff60", dark: "#080c00"},
    ], v)
  end

  defp palette(3, v) do  # Damaged — dark iron + red
    Enum.at([
      %{bg: "#080808", face: "#1c1c1c", mid: "#2c2c2c", acc: "#e02020", bright: "#ff6060", dark: "#040404"},
      %{bg: "#0c0604", face: "#241810", mid: "#342418", acc: "#ff4000", bright: "#ff8040", dark: "#080402"},
      %{bg: "#060810", face: "#101828", mid: "#182030", acc: "#ff2060", bright: "#ff70a0", dark: "#04060c"},
    ], v)
  end

  defp palette(4, v) do  # Ornate — gold
    Enum.at([
      %{bg: "#140c00", face: "#2c1c00", mid: "#402800", acc: "#d09000", bright: "#ffd040", dark: "#0c0800"},
      %{bg: "#100014", face: "#280030", mid: "#380040", acc: "#c000e0", bright: "#f060ff", dark: "#0c0010"},
      %{bg: "#001410", face: "#003028", mid: "#004038", acc: "#00d090", bright: "#60ffe0", dark: "#00100c"},
    ], v)
  end

  defp palette(5, v) do  # Skeletal — cold blue
    Enum.at([
      %{bg: "#020610", face: "#080e24", mid: "#101830", acc: "#2060e0", bright: "#60a0ff", dark: "#02040c"},
      %{bg: "#100204", face: "#280810", mid: "#381018", acc: "#e02040", bright: "#ff6080", dark: "#0c0204"},
      %{bg: "#040e04", face: "#0c2010", mid: "#142c18", acc: "#20c040", bright: "#60ff80", dark: "#020c02"},
    ], v)
  end

  defp palette(6, v) do  # Artillery — iron
    Enum.at([
      %{bg: "#0c0806", face: "#241c18", mid: "#342824", acc: "#ff3000", bright: "#ff7040", dark: "#080604"},
      %{bg: "#060c0a", face: "#182420", mid: "#243430", acc: "#00e080", bright: "#60ffc0", dark: "#040a08"},
      %{bg: "#0e0c00", face: "#282200", mid: "#383000", acc: "#e0c000", bright: "#ffec40", dark: "#0a0800"},
    ], v)
  end

  defp palette(7, v) do  # Android — silver
    Enum.at([
      %{bg: "#101018", face: "#c0c0cc", mid: "#d8d8e0", acc: "#8080c0", bright: "#e0e0ff", dark: "#303040"},
      %{bg: "#180c0c", face: "#c8b0b0", mid: "#dcc8c8", acc: "#e06060", bright: "#ffc0c0", dark: "#402020"},
      %{bg: "#0c1810", face: "#a0c0a8", mid: "#b8d4bc", acc: "#40d060", bright: "#a0ffc0", dark: "#203828"},
    ], v)
  end

  # ---------------------------------------------------------------------------
  # SVG assembly
  # ---------------------------------------------------------------------------

  defp build(archetype, p) do
    c = p.colors
    """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{@size} #{@size}" width="#{@size}" height="#{@size}">
      <!-- background fills full square including corners -->
      <rect width="#{@size}" height="#{@size}" fill="#{c.bg}"/>
      #{face_plate(p)}
      #{archetype_features(archetype, p)}
    </svg>
    """
  end

  # The face plate — a large circle that fills most of the safe zone
  defp face_plate(p) do
    c = p.colors
    r = @r - 2
    """
    <circle cx="#{@cx}" cy="#{@cy}" r="#{r}" fill="#{c.dark}"/>
    <circle cx="#{@cx}" cy="#{@cy}" r="#{r - 4}" fill="#{c.face}"/>
    <circle cx="#{@cx}" cy="#{@cy}" r="#{r - 4}" fill="none" stroke="#{c.mid}" stroke-width="3"/>
    """
  end

  # ---------------------------------------------------------------------------
  # Archetype feature renderers
  # Each must keep all elements within cx=128, cy=128, r=112
  # ---------------------------------------------------------------------------

  # 0 — CYCLOPS: single massive central lens
  defp archetype_features(0, p) do
    c  = p.colors
    s  = p.s
    er = 44 + rem(s.(2), 12)   # eye radius 44-55
    ey = @cy - 10 + rem(s.(3), 10) - 5  # eye y slightly above center

    """
    <!-- brow ridge -->
    <rect x="#{@cx - 60}" y="#{ey - er - 18}" width="120" height="14" rx="7" fill="#{c.dark}"/>
    <!-- lens housing rings -->
    <circle cx="#{@cx}" cy="#{ey}" r="#{er + 10}" fill="#{c.dark}"/>
    <circle cx="#{@cx}" cy="#{ey}" r="#{er + 6}"  fill="#{c.mid}"/>
    <circle cx="#{@cx}" cy="#{ey}" r="#{er}"      fill="#{c.acc}"/>
    <circle cx="#{@cx}" cy="#{ey}" r="#{er - 10}" fill="#{c.bright}"/>
    <circle cx="#{@cx}" cy="#{ey}" r="#{er - 22}" fill="#{c.dark}"/>
    <circle cx="#{@cx}" cy="#{ey}" r="#{er - 30}" fill="#{c.acc}" opacity="0.6"/>
    <!-- lens glint -->
    <circle cx="#{@cx - div(er, 3)}" cy="#{ey - div(er, 3)}" r="#{div(er, 5)}" fill="white" opacity="0.4"/>
    <!-- mouth grill -->
    <rect x="#{@cx - 44}" y="#{@cy + 42}" width="88" height="28" rx="6" fill="#{c.dark}"/>
    #{grill(@cx - 40, @cy + 46, 80, 20, 8, c.acc)}
    <!-- chin bolt -->
    <circle cx="#{@cx - 30}" cy="#{@cy + 86}" r="5" fill="#{c.mid}"/>
    <circle cx="#{@cx + 30}" cy="#{@cy + 86}" r="5" fill="#{c.mid}"/>
    """
  end

  # 1 — VISOR: full-width horizontal scanner
  defp archetype_features(1, p) do
    c  = p.colors
    vy = @cy - 20  # visor center y

    """
    <!-- brow plate -->
    <rect x="#{@cx - 80}" y="#{vy - 42}" width="160" height="22" rx="8" fill="#{c.dark}"/>
    <!-- visor housing -->
    <rect x="#{@cx - 82}" y="#{vy - 20}" width="164" height="40" rx="10" fill="#{c.dark}"/>
    <rect x="#{@cx - 78}" y="#{vy - 16}" width="156" height="32" rx="8"  fill="#{c.mid}"/>
    <!-- visor glow strip -->
    <rect x="#{@cx - 74}" y="#{vy - 6}"  width="148" height="12" rx="6"  fill="#{c.acc}"/>
    <rect x="#{@cx - 74}" y="#{vy - 6}"  width="50"  height="12" rx="6"  fill="#{c.bright}" opacity="0.9"/>
    <rect x="#{@cx + 14}" y="#{vy - 6}"  width="30"  height="12" rx="6"  fill="#{c.bright}" opacity="0.6"/>
    <!-- visor reflection -->
    <rect x="#{@cx - 72}" y="#{vy - 14}" width="100" height="5"  rx="2"  fill="white" opacity="0.1"/>
    <!-- cheek panels -->
    <rect x="#{@cx - 90}" y="#{vy + 24}" width="38" height="30" rx="6" fill="#{c.dark}"/>
    <rect x="#{@cx + 52}" y="#{vy + 24}" width="38" height="30" rx="6" fill="#{c.dark}"/>
    <rect x="#{@cx - 86}" y="#{vy + 28}" width="30" height="8"  rx="3" fill="#{c.acc}" opacity="0.6"/>
    <rect x="#{@cx + 56}" y="#{vy + 28}" width="30" height="8"  rx="3" fill="#{c.acc}" opacity="0.6"/>
    <!-- mouth speaker grid -->
    <rect x="#{@cx - 52}" y="#{@cy + 44}" width="104" height="34" rx="8" fill="#{c.dark}"/>
    #{dots(@cx - 44, @cy + 52, 88, 18, 7, c.acc)}
    <!-- nose sensor -->
    <rect x="#{@cx - 8}" y="#{vy + 22}" width="16" height="10" rx="4" fill="#{c.acc}" opacity="0.8"/>
    """
  end

  # 2 — DUO: two large symmetrical eyes
  defp archetype_features(2, p) do
    c  = p.colors
    s  = p.s
    er = 28 + rem(s.(2), 8)   # eye radius
    ey = @cy - 16
    ex = 46 + rem(s.(3), 10)  # eye x offset from center

    """
    <!-- brow bar -->
    <rect x="#{@cx - 70}" y="#{ey - er - 16}" width="140" height="12" rx="6" fill="#{c.dark}"/>
    <!-- left eye housing -->
    <circle cx="#{@cx - ex}" cy="#{ey}" r="#{er + 8}" fill="#{c.dark}"/>
    <circle cx="#{@cx - ex}" cy="#{ey}" r="#{er + 4}" fill="#{c.mid}"/>
    <circle cx="#{@cx - ex}" cy="#{ey}" r="#{er}"     fill="#{c.acc}"/>
    <circle cx="#{@cx - ex}" cy="#{ey}" r="#{er - 9}" fill="#{c.bright}"/>
    <circle cx="#{@cx - ex}" cy="#{ey}" r="#{er - 18}" fill="#{c.dark}"/>
    <!-- right eye housing -->
    <circle cx="#{@cx + ex}" cy="#{ey}" r="#{er + 8}" fill="#{c.dark}"/>
    <circle cx="#{@cx + ex}" cy="#{ey}" r="#{er + 4}" fill="#{c.mid}"/>
    <circle cx="#{@cx + ex}" cy="#{ey}" r="#{er}"     fill="#{c.acc}"/>
    <circle cx="#{@cx + ex}" cy="#{ey}" r="#{er - 9}" fill="#{c.bright}"/>
    <circle cx="#{@cx + ex}" cy="#{ey}" r="#{er - 18}" fill="#{c.dark}"/>
    <!-- glints -->
    <circle cx="#{@cx - ex - div(er,3)}" cy="#{ey - div(er,3)}" r="#{div(er,5)}" fill="white" opacity="0.45"/>
    <circle cx="#{@cx + ex - div(er,3)}" cy="#{ey - div(er,3)}" r="#{div(er,5)}" fill="white" opacity="0.45"/>
    <!-- nose bridge -->
    <rect x="#{@cx - 6}" y="#{ey - 8}" width="12" height="20" rx="4" fill="#{c.dark}"/>
    <!-- mouth -->
    <rect x="#{@cx - 48}" y="#{@cy + 42}" width="96" height="22" rx="8" fill="#{c.dark}"/>
    #{grill(@cx - 42, @cy + 47, 84, 12, 7, c.acc)}
    <!-- chin -->
    <rect x="#{@cx - 28}" y="#{@cy + 72}" width="56" height="10" rx="5" fill="#{c.mid}" opacity="0.6"/>
    """
  end

  # 3 — DAMAGED: cracked, asymmetric, warning eye
  defp archetype_features(3, p) do
    c = p.colors
    s = p.s
    # Asymmetric: one working eye, one damaged/cracked
    crack_side = rem(s.(2), 2)  # 0=left damaged, 1=right damaged
    {good_x, bad_x} = if crack_side == 0, do: {@cx + 38, @cx - 38}, else: {@cx - 38, @cx + 38}

    """
    <!-- damage cracks -->
    <line x1="#{bad_x - 10}" y1="#{@cy - 60}" x2="#{bad_x + 20}" y2="#{@cy + 20}" stroke="#{c.acc}" stroke-width="3" opacity="0.8"/>
    <line x1="#{bad_x}"      y1="#{@cy - 40}" x2="#{bad_x - 24}" y2="#{@cy + 10}" stroke="#{c.acc}" stroke-width="2" opacity="0.6"/>
    <line x1="#{bad_x + 8}"  y1="#{@cy - 20}" x2="#{bad_x + 28}" y2="#{@cy + 40}" stroke="#{c.acc}" stroke-width="1.5" opacity="0.5"/>
    <!-- damaged eye socket (dark, cracked) -->
    <circle cx="#{bad_x}"  cy="#{@cy - 18}" r="32" fill="#{c.dark}"/>
    <circle cx="#{bad_x}"  cy="#{@cy - 18}" r="24" fill="#{c.mid}" opacity="0.3"/>
    <circle cx="#{bad_x}"  cy="#{@cy - 18}" r="14" fill="#{c.acc}" opacity="0.4"/>
    <!-- good eye — bright and alert -->
    <circle cx="#{good_x}" cy="#{@cy - 18}" r="32" fill="#{c.dark}"/>
    <circle cx="#{good_x}" cy="#{@cy - 18}" r="26" fill="#{c.mid}"/>
    <circle cx="#{good_x}" cy="#{@cy - 18}" r="20" fill="#{c.acc}"/>
    <circle cx="#{good_x}" cy="#{@cy - 18}" r="12" fill="#{c.bright}"/>
    <circle cx="#{good_x}" cy="#{@cy - 18}" r="6"  fill="#{c.dark}"/>
    <circle cx="#{good_x - 7}" cy="#{@cy - 25}" r="4" fill="white" opacity="0.5"/>
    <!-- warning panel -->
    <rect x="#{@cx - 40}" y="#{@cy + 36}" width="80" height="20" rx="4" fill="#{c.acc}" opacity="0.15"/>
    <rect x="#{@cx - 36}" y="#{@cy + 40}" width="28" height="12" rx="3" fill="#{c.acc}"/>
    <rect x="#{@cx + 8}"  y="#{@cy + 40}" width="28" height="12" rx="3" fill="#{c.acc}" opacity="0.5"/>
    <!-- bolts -->
    <circle cx="#{@cx - 72}" cy="#{@cy - 60}" r="6" fill="#{c.mid}"/>
    <circle cx="#{@cx + 72}" cy="#{@cy - 60}" r="6" fill="#{c.mid}"/>
    <circle cx="#{@cx - 72}" cy="#{@cy + 60}" r="6" fill="#{c.mid}"/>
    <circle cx="#{@cx + 72}" cy="#{@cy + 60}" r="6" fill="#{c.mid}"/>
    """
  end

  # 4 — ORNATE: ceremonial triple-eye jewelled mask
  defp archetype_features(4, p) do
    c = p.colors

    """
    <!-- ornate top crown -->
    <rect x="#{@cx - 50}" y="#{@cy - 106}" width="100" height="16" rx="4" fill="#{c.mid}"/>
    <circle cx="#{@cx}"      cy="#{@cy - 106}" r="9"  fill="#{c.acc}"/>
    <circle cx="#{@cx - 30}" cy="#{@cy - 103}" r="6"  fill="#{c.bright}" opacity="0.8"/>
    <circle cx="#{@cx + 30}" cy="#{@cy - 103}" r="6"  fill="#{c.bright}" opacity="0.8"/>
    <!-- filigree band -->
    <rect x="#{@cx - 76}" y="#{@cy - 34}" width="152" height="8" rx="4" fill="#{c.mid}" opacity="0.5"/>
    <!-- left eye jewel -->
    <circle cx="#{@cx - 42}" cy="#{@cy - 20}" r="22" fill="#{c.dark}"/>
    <circle cx="#{@cx - 42}" cy="#{@cy - 20}" r="17" fill="#{c.acc}"/>
    <circle cx="#{@cx - 42}" cy="#{@cy - 20}" r="10" fill="#{c.bright}"/>
    <circle cx="#{@cx - 42}" cy="#{@cy - 20}" r="5"  fill="white" opacity="0.6"/>
    <!-- right eye jewel -->
    <circle cx="#{@cx + 42}" cy="#{@cy - 20}" r="22" fill="#{c.dark}"/>
    <circle cx="#{@cx + 42}" cy="#{@cy - 20}" r="17" fill="#{c.acc}"/>
    <circle cx="#{@cx + 42}" cy="#{@cy - 20}" r="10" fill="#{c.bright}"/>
    <circle cx="#{@cx + 42}" cy="#{@cy - 20}" r="5"  fill="white" opacity="0.6"/>
    <!-- center third eye -->
    <ellipse cx="#{@cx}" cy="#{@cy - 52}" rx="16" ry="20" fill="#{c.dark}"/>
    <ellipse cx="#{@cx}" cy="#{@cy - 52}" rx="11" ry="15" fill="#{c.acc}"/>
    <ellipse cx="#{@cx}" cy="#{@cy - 52}" rx="6"  ry="9"  fill="#{c.bright}"/>
    <!-- decorative mouth -->
    <rect x="#{@cx - 44}" y="#{@cy + 30}" width="88" height="6" rx="3" fill="#{c.acc}" opacity="0.7"/>
    <rect x="#{@cx - 32}" y="#{@cy + 42}" width="64" height="6" rx="3" fill="#{c.mid}" opacity="0.6"/>
    <rect x="#{@cx - 20}" y="#{@cy + 54}" width="40" height="6" rx="3" fill="#{c.mid}" opacity="0.4"/>
    <!-- side jewels -->
    <circle cx="#{@cx - 82}" cy="#{@cy - 20}" r="10" fill="#{c.acc}" opacity="0.8"/>
    <circle cx="#{@cx + 82}" cy="#{@cy - 20}" r="10" fill="#{c.acc}" opacity="0.8"/>
    <circle cx="#{@cx - 82}" cy="#{@cy - 20}" r="5"  fill="#{c.bright}" opacity="0.6"/>
    <circle cx="#{@cx + 82}" cy="#{@cy - 20}" r="5"  fill="#{c.bright}" opacity="0.6"/>
    """
  end

  # 5 — SKELETAL: wireframe skull
  defp archetype_features(5, p) do
    c = p.colors

    """
    <!-- skull dome outline -->
    <circle cx="#{@cx}" cy="#{@cy - 10}" r="90" fill="none" stroke="#{c.acc}" stroke-width="3" opacity="0.6"/>
    <!-- eye sockets -->
    <ellipse cx="#{@cx - 38}" cy="#{@cy - 20}" rx="28" ry="32" fill="#{c.dark}"/>
    <ellipse cx="#{@cx + 38}" cy="#{@cy - 20}" rx="28" ry="32" fill="#{c.dark}"/>
    <ellipse cx="#{@cx - 38}" cy="#{@cy - 20}" rx="20" ry="24" fill="#{c.acc}" opacity="0.15"/>
    <ellipse cx="#{@cx + 38}" cy="#{@cy - 20}" rx="20" ry="24" fill="#{c.acc}" opacity="0.15"/>
    <!-- eye glow dots -->
    <circle cx="#{@cx - 38}" cy="#{@cy - 20}" r="10" fill="#{c.acc}" opacity="0.9"/>
    <circle cx="#{@cx + 38}" cy="#{@cy - 20}" r="10" fill="#{c.acc}" opacity="0.9"/>
    <circle cx="#{@cx - 38}" cy="#{@cy - 20}" r="5"  fill="#{c.bright}"/>
    <circle cx="#{@cx + 38}" cy="#{@cy - 20}" r="5"  fill="#{c.bright}"/>
    <!-- nasal cavity -->
    <path d="M #{@cx - 8} #{@cy + 16} L #{@cx} #{@cy - 4} L #{@cx + 8} #{@cy + 16} Z" fill="#{c.dark}"/>
    <!-- teeth / jaw -->
    <rect x="#{@cx - 50}" y="#{@cy + 34}" width="100" height="8" rx="2" fill="#{c.acc}" opacity="0.4"/>
    #{teeth(@cx - 44, @cy + 46, 88, 22, 8, c.acc, c.dark)}
    <!-- brow lines -->
    <line x1="#{@cx - 66}" y1="#{@cy - 54}" x2="#{@cx - 14}" y2="#{@cy - 54}" stroke="#{c.acc}" stroke-width="3" stroke-linecap="round" opacity="0.7"/>
    <line x1="#{@cx + 14}" y1="#{@cy - 54}" x2="#{@cx + 66}" y2="#{@cy - 54}" stroke="#{c.acc}" stroke-width="3" stroke-linecap="round" opacity="0.7"/>
    """
  end

  # 6 — ARTILLERY: heavy armour, prominent barrel
  defp archetype_features(6, p) do
    c = p.colors

    """
    <!-- heavy top armor plate -->
    <rect x="#{@cx - 70}" y="#{@cy - 106}" width="140" height="30" rx="8" fill="#{c.mid}"/>
    <rect x="#{@cx - 60}" y="#{@cy - 100}" width="120" height="10" rx="4" fill="#{c.acc}" opacity="0.4"/>
    <!-- two small targeting eyes -->
    <rect x="#{@cx - 62}" y="#{@cy - 50}" width="36" height="20" rx="5" fill="#{c.dark}"/>
    <rect x="#{@cx + 26}" y="#{@cy - 50}" width="36" height="20" rx="5" fill="#{c.dark}"/>
    <rect x="#{@cx - 56}" y="#{@cy - 46}" width="24" height="12" rx="3" fill="#{c.acc}"/>
    <rect x="#{@cx + 32}" y="#{@cy - 46}" width="24" height="12" rx="3" fill="#{c.acc}"/>
    <!-- center targeting reticle -->
    <circle cx="#{@cx}" cy="#{@cy - 40}" r="16" fill="#{c.dark}"/>
    <circle cx="#{@cx}" cy="#{@cy - 40}" r="11" fill="none" stroke="#{c.acc}" stroke-width="2"/>
    <circle cx="#{@cx}" cy="#{@cy - 40}" r="4"  fill="#{c.acc}"/>
    <line x1="#{@cx - 16}" y1="#{@cy - 40}" x2="#{@cx + 16}" y2="#{@cy - 40}" stroke="#{c.acc}" stroke-width="1.5" opacity="0.6"/>
    <line x1="#{@cx}" y1="#{@cy - 56}" x2="#{@cx}" y2="#{@cy - 24}" stroke="#{c.acc}" stroke-width="1.5" opacity="0.6"/>
    <!-- main barrel -->
    <rect x="#{@cx - 18}" y="#{@cy - 6}" width="36" height="80" rx="8" fill="#{c.dark}"/>
    <rect x="#{@cx - 12}" y="#{@cy - 2}" width="24" height="72" rx="6" fill="#{c.mid}"/>
    <rect x="#{@cx - 6}"  y="#{@cy + 2}" width="12" height="64" rx="4" fill="#{c.acc}" opacity="0.3"/>
    <!-- barrel tip -->
    <rect x="#{@cx - 22}" y="#{@cy + 68}" width="44" height="14" rx="6" fill="#{c.mid}"/>
    <rect x="#{@cx - 16}" y="#{@cy + 72}" width="32" height="6"  rx="3" fill="#{c.dark}"/>
    <!-- side vents -->
    <rect x="#{@cx - 86}" y="#{@cy + 10}" width="58" height="10" rx="4" fill="#{c.dark}"/>
    <rect x="#{@cx + 28}" y="#{@cy + 10}" width="58" height="10" rx="4" fill="#{c.dark}"/>
    <rect x="#{@cx - 82}" y="#{@cy + 13}" width="50" height="4"  rx="2" fill="#{c.acc}" opacity="0.5"/>
    <rect x="#{@cx + 32}" y="#{@cy + 13}" width="50" height="4"  rx="2" fill="#{c.acc}" opacity="0.5"/>
    """
  end

  # 7 — ANDROID: near-human proportions, subtle and uncanny
  defp archetype_features(7, p) do
    c = p.colors
    s = p.s
    ex = 36 + rem(s.(2), 8)
    ey = @cy - 22

    """
    <!-- subtle brow ridge -->
    <ellipse cx="#{@cx - ex}" cy="#{ey - 28}" rx="22" ry="7" fill="#{c.dark}" opacity="0.8"/>
    <ellipse cx="#{@cx + ex}" cy="#{ey - 28}" rx="22" ry="7" fill="#{c.dark}" opacity="0.8"/>
    <!-- left eye — almond shaped -->
    <ellipse cx="#{@cx - ex}" cy="#{ey}" rx="26" ry="18" fill="#{c.dark}"/>
    <ellipse cx="#{@cx - ex}" cy="#{ey}" rx="20" ry="13" fill="#{c.mid}"/>
    <circle  cx="#{@cx - ex}" cy="#{ey}" r="10"          fill="#{c.acc}"/>
    <circle  cx="#{@cx - ex}" cy="#{ey}" r="6"           fill="#{c.dark}"/>
    <circle  cx="#{@cx - ex - 4}" cy="#{ey - 4}" r="3"   fill="white" opacity="0.5"/>
    <!-- right eye — almond shaped -->
    <ellipse cx="#{@cx + ex}" cy="#{ey}" rx="26" ry="18" fill="#{c.dark}"/>
    <ellipse cx="#{@cx + ex}" cy="#{ey}" rx="20" ry="13" fill="#{c.mid}"/>
    <circle  cx="#{@cx + ex}" cy="#{ey}" r="10"          fill="#{c.acc}"/>
    <circle  cx="#{@cx + ex}" cy="#{ey}" r="6"           fill="#{c.dark}"/>
    <circle  cx="#{@cx + ex - 4}" cy="#{ey - 4}" r="3"   fill="white" opacity="0.5"/>
    <!-- nose — subtle raised bridge -->
    <ellipse cx="#{@cx}" cy="#{@cy + 8}"  rx="10" ry="16" fill="#{c.mid}" opacity="0.5"/>
    <ellipse cx="#{@cx}" cy="#{@cy + 18}" rx="14" ry="8"  fill="#{c.dark}" opacity="0.6"/>
    <!-- mouth — thin and precise -->
    <ellipse cx="#{@cx}" cy="#{@cy + 46}" rx="34" ry="9" fill="#{c.dark}"/>
    <ellipse cx="#{@cx}" cy="#{@cy + 46}" rx="28" ry="5" fill="#{c.acc}" opacity="0.7"/>
    <rect    x="#{@cx - 2}" y="#{@cy + 41}" width="4" height="10" rx="2" fill="#{c.dark}"/>
    <!-- jaw definition -->
    <ellipse cx="#{@cx}" cy="#{@cy + 76}" rx="52" ry="18" fill="#{c.mid}" opacity="0.3"/>
    <!-- cheekbone highlights -->
    <ellipse cx="#{@cx - 64}" cy="#{@cy + 10}" rx="14" ry="8" fill="#{c.bright}" opacity="0.15"/>
    <ellipse cx="#{@cx + 64}" cy="#{@cy + 10}" rx="14" ry="8" fill="#{c.bright}" opacity="0.15"/>
    """
  end

  # ---------------------------------------------------------------------------
  # Shared helpers
  # ---------------------------------------------------------------------------

  # Horizontal grill bars
  defp grill(x, y, w, h, bar_count, color) do
    gap = div(h, bar_count)
    Enum.map_join(0..(bar_count - 1), "\n", fn i ->
      bar_y = y + i * gap
      "<rect x=\"#{x}\" y=\"#{bar_y}\" width=\"#{w}\" height=\"#{gap - 2}\" rx=\"1\" fill=\"#{color}\" opacity=\"0.7\"/>"
    end)
  end

  # Dot grid
  defp dots(x, y, w, h, cols, color) do
    rows = max(1, div(h, 8))
    col_gap = div(w, cols)
    row_gap = div(h, rows)
    for row <- 0..(rows - 1), col <- 0..(cols - 1) do
      cx = x + col * col_gap + div(col_gap, 2)
      cy = y + row * row_gap + div(row_gap, 2)
      "<circle cx=\"#{cx}\" cy=\"#{cy}\" r=\"2\" fill=\"#{color}\" opacity=\"0.8\"/>"
    end
    |> Enum.join("\n")
  end

  # Skull teeth
  defp teeth(x, y, w, h, count, color, bg) do
    tooth_w = div(w, count)
    Enum.map_join(0..(count - 1), "\n", fn i ->
      tx = x + i * tooth_w
      fill = if rem(i, 2) == 0, do: color, else: bg
      "<rect x=\"#{tx}\" y=\"#{y}\" width=\"#{tooth_w - 1}\" height=\"#{h}\" rx=\"2\" fill=\"#{fill}\" opacity=\"0.8\"/>"
    end)
  end
end
