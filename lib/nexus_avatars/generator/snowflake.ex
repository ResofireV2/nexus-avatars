defmodule NexusAvatars.Generator.Snowflake do
  @moduledoc """
  Snowflake avatar style.

  Renders a 256x256 hexagonally-symmetric snowflake on a dark background.

  All arm coordinates are pre-computed by rotating a single arm template
  around the canvas center. No SVG transforms are used — every element is
  placed with explicit x,y coordinates, matching the approach used by all
  other generators in this extension and ensuring full librsvg compatibility.

  Variation axes (all seeded from username hash):
    0  -> palette         (8 palettes)
    1  -> arm count       (6, 6, 6, 6, 6, 8, 8, 12 — weighted toward 6)
    2  -> arm length      (short to long)
    3  -> arm width       (wispy to meaty)
    4  -> tier count      (2–5 branch tiers)
    5  -> branch angle    (45–70° from arm axis)
    6  -> tip style       (spike, diamond, hexagon, none)
    7  -> center style    (hexagon medallion or dot)
    8  -> background      (rings or solid)
    9  -> branch decay    (how fast sub-branches shrink toward tip)
    10 -> branch density  (per-tier presence probability)
    11 -> sub-branch      (second-order branches on larger snowflakes)

  Fully librsvg-safe: lines, polygons, circles only.
  No SVG transforms, no filters, no CSS, no stroke-linecap.
  Canvas: 256x256. Rasterised to WebP via libvips + librsvg.
  PRNG: splitmix32 via rng/3, matching all other generators.
  Bitwise ops fully-qualified — no `use Bitwise` import.
  """

  @size 256
  @cx   128.0
  @cy   128.0

  # Palettes — {bg, ring, arm, arm_hi, arm_dim}
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
    density     = max(40, rng(seed, 10, 100))
    sub_branch  = rng(seed, 11, 2) == 0 and tier_count >= 4

    bg_svg     = background(bg, ring_col, bg_rings)
    arms_svg   = all_arms(seed, arm_count, arm_len, arm_width,
                          tier_count, branch_deg, tip_style,
                          decay, density, sub_branch,
                          arm_col, hi_col, dim_col)
    center_svg = center(center_hex, hi_col, bg)

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
  # PRNG — splitmix32. Fully-qualified Bitwise, no import.
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
    lo + (hi - lo) * rng(seed, salt, 100_000) / 100_000.0
  end

  # ---------------------------------------------------------------------------
  # Rotate a point (px, py) by deg degrees around (@cx, @cy)
  # ---------------------------------------------------------------------------

  defp rot(px, py, deg) do
    rad = deg * :math.pi() / 180.0
    dx  = px - @cx
    dy  = py - @cy
    rx  = dx * :math.cos(rad) - dy * :math.sin(rad)
    ry  = dx * :math.sin(rad) + dy * :math.cos(rad)
    {fp(@cx + rx), fp(@cy + ry)}
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
        ~s[<circle cx="#{round(@cx)}" cy="#{round(@cy)}" r="#{r}" fill="none" stroke="#{ring_col}" stroke-width="#{sw}"/>]
      end)
    else
      ""
    end
    base <> rings
  end

  # ---------------------------------------------------------------------------
  # All arms — one arm template rotated to each angle, coordinates
  # pre-computed explicitly. No SVG transform attributes used.
  # ---------------------------------------------------------------------------

  defp all_arms(seed, arm_count, arm_len, arm_width,
                tier_count, branch_deg, tip_style,
                decay, density, sub_branch,
                arm_col, hi_col, dim_col) do
    step_deg = 360.0 / arm_count

    Enum.map_join(0..(arm_count - 1), "", fn i ->
      deg = i * step_deg
      one_arm(seed, deg, arm_len, arm_width, tier_count, branch_deg,
              tip_style, decay, density, sub_branch,
              arm_col, hi_col, dim_col)
    end)
  end

  # ---------------------------------------------------------------------------
  # One arm — all points rotated from the upward template.
  # Template: center=(128,128), tip=(128, 128-arm_len), pointing straight up.
  # ---------------------------------------------------------------------------

  defp one_arm(seed, deg, arm_len, arm_width, tier_count, branch_deg,
               tip_style, decay, density, sub_branch,
               arm_col, hi_col, dim_col) do
    sw     = fp(arm_width)
    tip_y0 = @cy - arm_len                    # unrotated tip y
    {tx, ty} = rot(@cx, tip_y0, deg)
    cx_r = round(@cx)
    cy_r = round(@cy)

    # Main shaft — from center to rotated tip
    shaft = ~s[<line x1="#{cx_r}" y1="#{cy_r}" x2="#{fp(tx)}" y2="#{fp(ty)}" stroke="#{arm_col}" stroke-width="#{sw}"/>]

    # Branch tiers
    branches = Enum.map_join(0..(tier_count - 1), "", fn t ->
      frac = (t + 1) / (tier_count + 1)
      by0  = @cy - arm_len * frac             # unrotated branch root y

      has_branch = t == 0 or rng(seed, 20 + t * 7, 100) < density
      if not has_branch do
        ""
      else
        branch_len = arm_len * (1.0 - frac) * decay
        branch_w   = fp(arm_width * (0.35 + 0.45 * (1.0 - frac)))
        ang_rad    = branch_deg * :math.pi() / 180.0

        # Unrotated branch endpoints (left and right, symmetric)
        lx0 = @cx - branch_len * :math.sin(ang_rad)
        ly0 = by0  - branch_len * :math.cos(ang_rad)
        rx0 = @cx + branch_len * :math.sin(ang_rad)
        ry0 = by0  - branch_len * :math.cos(ang_rad)

        # Rotate all points
        {brx, bry}  = rot(@cx, by0, deg)      # branch root
        {blx, bly}  = rot(lx0, ly0, deg)      # left tip
        {brx2, bry2} = rot(rx0, ry0, deg)     # right tip

        left_line  = ~s[<line x1="#{fp(brx)}" y1="#{fp(bry)}" x2="#{fp(blx)}" y2="#{fp(bly)}" stroke="#{arm_col}" stroke-width="#{branch_w}"/>]
        right_line = ~s[<line x1="#{fp(brx)}" y1="#{fp(bry)}" x2="#{fp(brx2)}" y2="#{fp(bry2)}" stroke="#{arm_col}" stroke-width="#{branch_w}"/>]
        dot_r = fp(branch_w * 0.9)
        dot   = ~s[<circle cx="#{fp(brx)}" cy="#{fp(bry)}" r="#{dot_r}" fill="#{hi_col}"/>]

        sub = if sub_branch and t < tier_count - 1 do
          has_sub = rng(seed, 50 + t * 11, 100) < div(density * 70, 100)
          if has_sub do
            sub_len  = fp(branch_len * 0.38)
            sub_w    = fp(branch_w * 0.5)
            sub_ang  = ang_rad * 0.65
            mid_frac = 0.55

            # Unrotated midpoints along each branch
            mlx0 = @cx  + (lx0 - @cx)  * mid_frac
            mly0 = by0  + (ly0 - by0)  * mid_frac
            mrx0 = @cx  + (rx0 - @cx)  * mid_frac
            mry0 = by0  + (ry0 - by0)  * mid_frac

            # Unrotated sub-branch endpoints
            sl1x0 = mlx0 - sub_len * :math.sin(sub_ang + 0.4)
            sl1y0 = mly0 - sub_len * :math.cos(sub_ang + 0.4)
            sl2x0 = mlx0 + sub_len * :math.sin(sub_ang - 0.2)
            sl2y0 = mly0 - sub_len * :math.cos(sub_ang - 0.2)
            sr1x0 = mrx0 + sub_len * :math.sin(sub_ang + 0.4)
            sr1y0 = mry0 - sub_len * :math.cos(sub_ang + 0.4)
            sr2x0 = mrx0 - sub_len * :math.sin(sub_ang - 0.2)
            sr2y0 = mry0 - sub_len * :math.cos(sub_ang - 0.2)

            # Rotate all sub-branch points
            {mlx, mly}   = rot(mlx0, mly0, deg)
            {mrx, mry}   = rot(mrx0, mry0, deg)
            {sl1x, sl1y} = rot(sl1x0, sl1y0, deg)
            {sl2x, sl2y} = rot(sl2x0, sl2y0, deg)
            {sr1x, sr1y} = rot(sr1x0, sr1y0, deg)
            {sr2x, sr2y} = rot(sr2x0, sr2y0, deg)

            ~s[<line x1="#{fp(mlx)}" y1="#{fp(mly)}" x2="#{fp(sl1x)}" y2="#{fp(sl1y)}" stroke="#{dim_col}" stroke-width="#{sub_w}"/>] <>
            ~s[<line x1="#{fp(mlx)}" y1="#{fp(mly)}" x2="#{fp(sl2x)}" y2="#{fp(sl2y)}" stroke="#{dim_col}" stroke-width="#{sub_w}"/>] <>
            ~s[<line x1="#{fp(mrx)}" y1="#{fp(mry)}" x2="#{fp(sr1x)}" y2="#{fp(sr1y)}" stroke="#{dim_col}" stroke-width="#{sub_w}"/>] <>
            ~s[<line x1="#{fp(mrx)}" y1="#{fp(mry)}" x2="#{fp(sr2x)}" y2="#{fp(sr2y)}" stroke="#{dim_col}" stroke-width="#{sub_w}"/>]
          else
            ""
          end
        else
          ""
        end

        left_line <> right_line <> sub <> dot
      end
    end)

    tip = tip_crystal(tip_style, deg, tip_y0, arm_width, hi_col)

    shaft <> branches <> tip
  end

  # ---------------------------------------------------------------------------
  # Tip crystals — all points rotated from upward template
  # ---------------------------------------------------------------------------

  defp tip_crystal(0, deg, tip_y0, arm_width, col) do
    # Spike — upward triangle
    ts = arm_width * 3.5
    {ax, ay} = rot(@cx,        tip_y0 - ts, deg)
    {bx, by} = rot(@cx - ts * 0.5, tip_y0 + ts * 0.4, deg)
    {cx, cy} = rot(@cx + ts * 0.5, tip_y0 + ts * 0.4, deg)
    ~s[<polygon points="#{fp(ax)},#{fp(ay)} #{fp(bx)},#{fp(by)} #{fp(cx)},#{fp(cy)}" fill="#{col}"/>]
  end

  defp tip_crystal(1, deg, tip_y0, arm_width, col) do
    # Diamond — 4 points
    ts = arm_width * 3.5
    {ax, ay} = rot(@cx,          tip_y0 - ts, deg)
    {bx, by} = rot(@cx + ts * 0.6, tip_y0,   deg)
    {cx, cy} = rot(@cx,          tip_y0 + ts, deg)
    {dx, dy} = rot(@cx - ts * 0.6, tip_y0,   deg)
    ~s[<polygon points="#{fp(ax)},#{fp(ay)} #{fp(bx)},#{fp(by)} #{fp(cx)},#{fp(cy)} #{fp(dx)},#{fp(dy)}" fill="#{col}"/>]
  end

  defp tip_crystal(2, deg, tip_y0, arm_width, col) do
    # Small hexagon at tip
    hr  = arm_width * 2.8
    pts = Enum.map_join(0..5, " ", fn i ->
      a    = i / 6.0 * 2.0 * :math.pi() - :math.pi() / 6.0
      px0  = @cx  + hr * :math.cos(a)
      py0  = tip_y0 + hr * :math.sin(a)
      {rx, ry} = rot(px0, py0, deg)
      "#{fp(rx)},#{fp(ry)}"
    end)
    ~s[<polygon points="#{pts}" fill="#{col}"/>]
  end

  defp tip_crystal(_, _deg, _tip_y0, _arm_width, _col), do: ""

  # ---------------------------------------------------------------------------
  # Center decoration
  # ---------------------------------------------------------------------------

  defp center(true, hi_col, bg) do
    cr  = @size * 0.055
    pts = Enum.map_join(0..5, " ", fn i ->
      a = i / 6.0 * 2.0 * :math.pi() - :math.pi() / 6.0
      "#{fp(@cx + cr * :math.cos(a))},#{fp(@cy + cr * :math.sin(a))}"
    end)
    sw = fp(@size * 0.006)
    ~s[<polygon points="#{pts}" fill="#{hi_col}"/>] <>
    ~s[<polygon points="#{pts}" fill="none" stroke="#{bg}" stroke-width="#{sw}"/>] <>
    ~s[<circle cx="#{round(@cx)}" cy="#{round(@cy)}" r="#{fp(@size * 0.018)}" fill="#{bg}"/>]
  end

  defp center(false, hi_col, bg) do
    ~s[<circle cx="#{round(@cx)}" cy="#{round(@cy)}" r="#{fp(@size * 0.038)}" fill="#{hi_col}"/>] <>
    ~s[<circle cx="#{round(@cx)}" cy="#{round(@cy)}" r="#{fp(@size * 0.016)}" fill="#{bg}"/>]
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp fp(v), do: Float.round(v * 1.0, 2)
end
