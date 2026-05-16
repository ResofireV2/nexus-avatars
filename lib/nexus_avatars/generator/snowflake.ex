defmodule NexusAvatars.Generator.Snowflake do
  @moduledoc """
  Snowflake avatar style.

  Renders a 256x256 hexagonally-symmetric snowflake on a dark background.

  Structure:
    - One arm is drawn pointing straight up (all coordinates are simple
      vertical offsets from the canvas center at 128,128).
    - SVG rotate(N, 128, 128) stamps all arms — perfect symmetry is
      mathematically guaranteed, no per-arm coordinate math needed.
    - Branch sub-branches are drawn in the arm's local coordinate space
      before rotation, so they are symmetric by construction.

  Variation axes (all seeded from username hash):
    0  -> palette         (8 palettes)
    1  -> arm count       (6, 6, 6, 6, 6, 8, 8, 12 — weighted toward 6)
    2  -> arm length      (short to long)
    3  -> arm width       (wispy to meaty)
    4  -> tier count      (2–5 branch tiers)
    5  -> branch angle    (45°–70° from arm axis)
    6  -> tip style       (spike, diamond, hexagon, none)
    7  -> center style    (hexagon medallion or dot)
    8  -> background      (rings or solid)
    9  -> branch decay    (how fast sub-branches shrink toward tip)
    10 -> branch density  (per-tier presence probability, 0–99 out of 100)
    11 -> sub-branch      (second-order branches on larger snowflakes)

  Fully librsvg-safe: lines, polygons, circles only. No filters, no CSS.
  Canvas: 256x256. Rasterised to WebP via libvips + librsvg.
  PRNG: splitmix32 via rng/3, matching all other generators.
  Bitwise ops fully-qualified — no `use Bitwise` import.
  """

  @size    256
  @cx      128.0
  @cy      128.0

  # Palettes — {bg, ring, arm, arm_hi, arm_dim}
  # bg       : canvas fill
  # ring     : subtle background ring color
  # arm      : main arm and branch color
  # arm_hi   : tip crystals and junction dots (brighter)
  # arm_dim  : second-order sub-branch color (slightly dimmer)
  @palettes [
    {"#030c18", "#071428", "#bae6fd", "#e0f9ff", "#7dd3fc"},
    {"#0a0418", "#130828", "#c4b5fd", "#ede9fe", "#a78bfa"},
    {"#021008", "#041a0e", "#86efac", "#dcfce7", "#4ade80"},
    {"#180a04", "#281402", "#fed7aa", "#fff7ed", "#fbbf24"},
    {"#0a0418", "#160828", "#f9a8d4", "#fce7f3", "#f472b6"},
    {"#031010", "#051a1a", "#5eead4", "#ccfbf1", "#2dd4bf"},
    {"#0c0c0c", "#181818", "#d4d4d8", "#f4f4f5", "#a1a1aa"},
    {"#0a0600", "#1a0e00", "#fde68a", "#fefce8", "#f59e0b"},
  ]

  # Arm count table — weighted heavily toward 6 (the classic snowflake)
  @arm_counts [6, 6, 6, 6, 6, 8, 8, 12]

  @num_palettes  length(@palettes)
  @num_arm_table length(@arm_counts)

  # ---------------------------------------------------------------------------
  # Public entry point
  # ---------------------------------------------------------------------------

  @doc "Renders a 256x256 Snowflake SVG string for the given username."
  def render(username) do
    seed = :erlang.phash2(username)

    {bg, ring_col, arm_col, hi_col, dim_col} =
      Enum.at(@palettes, rng(seed, 0, @num_palettes))

    arm_count   = Enum.at(@arm_counts, rng(seed, 1, @num_arm_table))
    arm_len     = rngf(seed, 2, @size * 0.30, @size * 0.46)
    arm_width   = rngf(seed, 3, @size * 0.008, @size * 0.022)
    tier_count  = 2 + rng(seed, 4, 4)
    branch_deg  = 45.0 + rng(seed, 5, 25) * 1.0
    tip_style   = rng(seed, 6, 4)
    center_hex  = rng(seed, 7, 3) > 0
    bg_rings    = rng(seed, 8, 2) == 0
    decay       = rngf(seed, 9, 0.45, 0.70)
    density     = rng(seed, 10, 100)
    sub_branch  = rng(seed, 11, 2) == 0 and tier_count >= 4

    bg_svg      = background(bg, ring_col, bg_rings)
    arms_svg    = arms(seed, arm_count, arm_len, arm_width,
                       tier_count, branch_deg, tip_style,
                       decay, density, sub_branch,
                       arm_col, hi_col, dim_col)
    center_svg  = center(center_hex, arm_width, hi_col, bg)

    [
      ~s[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{@size} #{@size}" width="#{@size}" height="#{@size}">],
      bg_svg,
      arms_svg,
      center_svg,
      "</svg>",
    ]
    |> Enum.join("")
  end

  # ---------------------------------------------------------------------------
  # PRNG — splitmix32, identical to Mech/Emblem generators.
  # Fully-qualified Bitwise calls, no import.
  # rng/3  -> integer in [0, range)
  # rngf/4 -> float in [lo, hi)
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

  defp rngf(seed, salt, lo, hi) do
    t = rng(seed, salt, 100_000)
    lo + (hi - lo) * t / 100_000.0
  end

  # ---------------------------------------------------------------------------
  # Background
  # ---------------------------------------------------------------------------

  defp background(bg, ring_col, bg_rings) do
    base = ~s[<rect width="256" height="256" fill="#{bg}"/>]
    rings = if bg_rings do
      Enum.map_join([0.12, 0.22, 0.32, 0.42, 0.50], "", fn frac ->
        r  = fp(@size * frac)
        sw = fp(@size * 0.055)
        ~s[<circle cx="#{@cx}" cy="#{@cy}" r="#{r}" fill="none" stroke="#{ring_col}" stroke-width="#{sw}" opacity="0.85"/>]
      end)
    else
      ""
    end
    base <> rings
  end

  # ---------------------------------------------------------------------------
  # Arms — stamp one arm template at each rotation angle
  # ---------------------------------------------------------------------------

  defp arms(seed, arm_count, arm_len, arm_width,
            tier_count, branch_deg, tip_style,
            decay, density, sub_branch,
            arm_col, hi_col, dim_col) do
    arm_svg = one_arm(seed, arm_len, arm_width, tier_count, branch_deg,
                      tip_style, decay, density, sub_branch,
                      arm_col, hi_col, dim_col)

    Enum.map_join(0..(arm_count - 1), "", fn i ->
      deg = i * div(360, arm_count)
      ~s[<g transform="rotate(#{deg},#{round(@cx)},#{round(@cy)})">] <> arm_svg <> "</g>"
    end)
  end

  # ---------------------------------------------------------------------------
  # One arm — drawn pointing straight up from center.
  # All x coordinates are relative to @cx (128), y decreases toward tip.
  # The tip is at y = @cy - arm_len.
  # ---------------------------------------------------------------------------

  defp one_arm(seed, arm_len, arm_width, tier_count, branch_deg,
               tip_style, decay, density, sub_branch,
               arm_col, hi_col, dim_col) do
    tip_y  = fp(@cy - arm_len)
    sw     = fp(arm_width)
    cx_r   = round(@cx)

    # Main shaft
    shaft = ~s[<line x1="#{cx_r}" y1="#{round(@cy)}" x2="#{cx_r}" y2="#{tip_y}" stroke="#{arm_col}" stroke-width="#{sw}" stroke-linecap="round"/>]

    # Branch tiers
    branches = Enum.map_join(0..(tier_count - 1), "", fn t ->
      frac = (t + 1) / (tier_count + 1)
      by   = @cy - arm_len * frac

      # Per-tier density gate — use salt 20+t so each tier is independent
      has_branch = rng(seed, 20 + t * 7, 100) < density
      if not has_branch do
        ""
      else
        branch_len = arm_len * (1.0 - frac) * decay
        branch_w   = fp(arm_width * (0.35 + 0.45 * (1.0 - frac)))
        ang_rad    = branch_deg * :math.pi() / 180.0

        # Left and right branch endpoints (symmetric about arm axis)
        lx = fp(@cx - branch_len * :math.sin(ang_rad))
        ly = fp(by   - branch_len * :math.cos(ang_rad))
        rx = fp(@cx + branch_len * :math.sin(ang_rad))
        ry = fp(by   - branch_len * :math.cos(ang_rad))
        by_r = fp(by)

        left_line  = ~s[<line x1="#{cx_r}" y1="#{by_r}" x2="#{lx}" y2="#{ly}" stroke="#{arm_col}" stroke-width="#{branch_w}" stroke-linecap="round"/>]
        right_line = ~s[<line x1="#{cx_r}" y1="#{by_r}" x2="#{rx}" y2="#{ry}" stroke="#{arm_col}" stroke-width="#{branch_w}" stroke-linecap="round"/>]

        # Junction dot
        dot_r = fp(branch_w * 0.9)
        dot   = ~s[<circle cx="#{cx_r}" cy="#{by_r}" r="#{dot_r}" fill="#{hi_col}"/>]

        # Optional second-order sub-branches (on larger, denser snowflakes)
        sub = if sub_branch and t < tier_count - 1 do
          has_sub = rng(seed, 50 + t * 11, 100) < div(density * 70, 100)
          if has_sub do
            sub_len  = fp(branch_len * 0.38)
            sub_w    = fp(branch_w * 0.5)
            sub_ang  = ang_rad * 0.65
            # Midpoint along left branch
            mid_frac = 0.55
            mlx = fp(@cx + (lx - @cx) * mid_frac)
            mly = fp(by   + (ly - by)  * mid_frac)
            mrx = fp(@cx + (rx - @cx) * mid_frac)
            mry = fp(by   + (ry - by)  * mid_frac)
            # Sub-branches angle outward perpendicular to the branch
            sl1x = fp(mlx - sub_len * :math.sin(sub_ang + 0.4))
            sl1y = fp(mly - sub_len * :math.cos(sub_ang + 0.4))
            sl2x = fp(mlx + sub_len * :math.sin(sub_ang - 0.2))
            sl2y = fp(mly - sub_len * :math.cos(sub_ang - 0.2))
            sr1x = fp(mrx + sub_len * :math.sin(sub_ang + 0.4))
            sr1y = fp(mry - sub_len * :math.cos(sub_ang + 0.4))
            sr2x = fp(mrx - sub_len * :math.sin(sub_ang - 0.2))
            sr2y = fp(mry - sub_len * :math.cos(sub_ang - 0.2))
            ~s[<line x1="#{mlx}" y1="#{mly}" x2="#{sl1x}" y2="#{sl1y}" stroke="#{dim_col}" stroke-width="#{sub_w}" stroke-linecap="round"/>] <>
            ~s[<line x1="#{mlx}" y1="#{mly}" x2="#{sl2x}" y2="#{sl2y}" stroke="#{dim_col}" stroke-width="#{sub_w}" stroke-linecap="round"/>] <>
            ~s[<line x1="#{mrx}" y1="#{mry}" x2="#{sr1x}" y2="#{sr1y}" stroke="#{dim_col}" stroke-width="#{sub_w}" stroke-linecap="round"/>] <>
            ~s[<line x1="#{mrx}" y1="#{mry}" x2="#{sr2x}" y2="#{sr2y}" stroke="#{dim_col}" stroke-width="#{sub_w}" stroke-linecap="round"/>]
          else
            ""
          end
        else
          ""
        end

        left_line <> right_line <> sub <> dot
      end
    end)

    # Tip crystal
    tip = tip_crystal(tip_style, tip_y, arm_width, hi_col)

    shaft <> branches <> tip
  end

  # ---------------------------------------------------------------------------
  # Tip crystals
  # ---------------------------------------------------------------------------

  defp tip_crystal(0, tip_y, arm_width, col) do
    # Spike — upward triangle
    ts   = fp(arm_width * 3.5)
    cx_r = round(@cx)
    ~s[<polygon points="#{cx_r},#{fp(tip_y - ts)} #{fp(@cx - ts * 0.5)},#{fp(tip_y + ts * 0.4)} #{fp(@cx + ts * 0.5)},#{fp(tip_y + ts * 0.4)}" fill="#{col}"/>]
  end

  defp tip_crystal(1, tip_y, arm_width, col) do
    # Diamond — 4-point
    ts   = fp(arm_width * 3.5)
    cx_r = round(@cx)
    ~s[<polygon points="#{cx_r},#{fp(tip_y - ts)} #{fp(@cx + ts * 0.6)},#{fp(tip_y)} #{cx_r},#{fp(tip_y + ts)} #{fp(@cx - ts * 0.6)},#{fp(tip_y)}" fill="#{col}"/>]
  end

  defp tip_crystal(2, tip_y, arm_width, col) do
    # Small hexagon
    hr  = fp(arm_width * 2.8)
    pts = Enum.map_join(0..5, " ", fn i ->
      a = i / 6.0 * 2.0 * :math.pi() - :math.pi() / 6.0
      "#{fp(@cx + hr * :math.cos(a))},#{fp(tip_y + hr * :math.sin(a))}"
    end)
    ~s[<polygon points="#{pts}" fill="#{col}"/>]
  end

  defp tip_crystal(_, _tip_y, _arm_width, _col) do
    # Style 3 — no tip ornament, just the rounded linecap
    ""
  end

  # ---------------------------------------------------------------------------
  # Center decoration
  # ---------------------------------------------------------------------------

  defp center(true, _arm_width, hi_col, bg) do
    # Hexagon medallion
    cr  = fp(@size * 0.055)
    pts = Enum.map_join(0..5, " ", fn i ->
      a = i / 6.0 * 2.0 * :math.pi() - :math.pi() / 6.0
      "#{fp(@cx + cr * :math.cos(a))},#{fp(@cy + cr * :math.sin(a))}"
    end)
    sw = fp(@size * 0.006)
    ~s[<polygon points="#{pts}" fill="#{hi_col}" opacity="0.9"/>] <>
    ~s[<polygon points="#{pts}" fill="none" stroke="#{bg}" stroke-width="#{sw}"/>] <>
    ~s[<circle cx="#{round(@cx)}" cy="#{round(@cy)}" r="#{fp(@size * 0.018)}" fill="#{bg}"/>]
  end

  defp center(false, _arm_width, hi_col, bg) do
    # Simple bright dot
    ~s[<circle cx="#{round(@cx)}" cy="#{round(@cy)}" r="#{fp(@size * 0.038)}" fill="#{hi_col}"/>] <>
    ~s[<circle cx="#{round(@cx)}" cy="#{round(@cy)}" r="#{fp(@size * 0.016)}" fill="#{bg}"/>]
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Round float to 2 decimal places for compact SVG coordinate output.
  defp fp(v), do: Float.round(v * 1.0, 2)
end
