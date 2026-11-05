-- Page planning: the growing region, the vine's strands and runners, and the
-- slots along them. compose.lua runs the passes in this order:
--   1. region: the margin column, the foot band and the outer foot corner are
--      opened; text lines are blocked (short and indented lines leave room);
--   2. strands: the line of action (gesture) is laid out, then the plant
--      grows: its main stem from the root at the foot's right end along the
--      gesture to the hero, and long shoots that climb with it (plant.lua);
--   3. features: the hero bloom crowns the main strand, then the other
--      blooms and umbels take the roomiest slots along the strands, then
--      leaves take what remains;
--   4. ornaments: compass star, edge chain, corner medallion, the star panel;
--   5. fill: sprays grow into the remaining gaps, largest first, each on a
--      hairline stem from the nearest existing stem; sparkles go last.
-- Painting happens afterward in depth order.

local G = require("flora.geom")
local Space = require("flora.space")
local Tune = require("flora.tune")

local M = {}
local pi = math.pi

-- Open the growing region and block text. `spec.lines` (optional) lists
-- measured content boxes; without it the whole text block is blocked.
function M.region(spec)
  local W, H, t = spec.width, spec.height, spec.text
  local g = Space.new(W, H, 3)
  local edge = spec.edge or 16
  local gutter = spec.gutter or 9
  local m = {
    x0 = edge, x1 = t.x0 - gutter,
    y0 = edge + 4, y1 = H - edge - 6,
    foot = t.y0 - gutter * 0.8,
  }
  g:open(m.x0, m.y0, m.x1, m.y1)
  g:open(m.x0, m.y0, W - edge, m.foot)
  g:open(t.x1 + 5, m.y0, W - edge * 0.6, t.y0 + (t.y1 - t.y0) * 0.22)
  if spec.lines and #spec.lines > 0 then
    -- Room the text leaves inside its block is opened, except for layouts
    -- that only frame the text (frames.lua).
    if not spec.frame_only then M.open_short_lines(g, spec, gutter) end
    for _, l in ipairs(spec.lines) do
      g:block_text(l.x0 - 4, l.y0 - 3, l.x1 + 4, l.y1 + 3)
    end
  end
  if spec.header_y then
    g:block_text(t.x0 - 4, spec.header_y - 4, t.x1, spec.header_y + 12)
  end
  -- Rectangles another plant of the same page owns (frames.lua).
  for _, r in ipairs(spec.closed or {}) do g:close(r[1], r[2], r[3], r[4]) end
  return g, m
end

-- A vertical gap between lines at least this tall (pt) is a clearing:
-- room left for a figure, a break between sections or a \vspace.
M.CLEARING = 40

-- Inside the text block, open the space left of each line's first ink, and
-- the empty stretch below the last line. Gaps between lines inherit the
-- narrower of their neighbours so flora does not fill paragraph breaks, but
-- a clearing (M.CLEARING) opens across the whole width, kept 10 pt from the
-- lines around it, so the flora grows into it.
function M.open_short_lines(g, spec, gutter)
  local t, pad = spec.text, 5
  local lines = {}
  for _, l in ipairs(spec.lines) do
    if l.x1 > l.x0 and l.y1 > t.y0 - 2 then lines[#lines + 1] = l end
  end
  if #lines == 0 then return end
  table.sort(lines, function(a, b) return a.y1 > b.y1 end)
  local lowest = lines[#lines].y0
  local cap = t.x0 + (t.x1 - t.x0) * 0.42
  for y = t.y0, t.y1, g.c do
    local reach
    if y < lowest - 14 then
      reach = t.x1
    else
      for _, l in ipairs(lines) do
        if y + g.c > l.y0 - 1 and y < l.y1 + 1 then
          reach = math.min(reach or math.huge, l.x0)
        end
      end
      if not reach then
        local above, below
        for _, l in ipairs(lines) do
          if l.y0 >= y and (not above or l.y0 < above.y0) then above = l end
          if l.y1 <= y and (not below or l.y1 > below.y1) then below = l end
        end
        if above and below and above.y0 - below.y1 >= M.CLEARING
          and above.y0 - y >= 10 and y + g.c - below.y1 >= 10 then
          reach = t.x1 + pad
        else
          reach = math.min(above and above.x0 or t.x0, below and below.x0 or t.x0, cap)
        end
      else
        reach = math.min(reach, cap)
      end
    end
    if reach - pad > t.x0 - gutter then
      g:open(t.x0 - gutter, y, reach - pad, y + g.c)
    end
  end
end

-- The star cartouche's width and height for margin width mw, scaled by k:
-- the reference's panel, about 40 x 54 pt over its frame, in a margin
-- about 148 pt wide.
function M.cartouche_size(mw, k)
  k = k or 1
  return G.clamp(mw * 0.27 * k, 16, 48), G.clamp(mw * 0.365 * k, 22, 66)
end

-- The border's line of action. Strands hug the outer margin at `edge` and
-- bow inward toward the text two or three times; each bow is a raised-cosine
-- window, so the heading stays continuous. Bows are where the border
-- gathers: `density` peaks there, at the hero bloom and at the foot corner,
-- and falls to a floor in the quiet stretches between, where the stems run
-- nearly bare. `quiet` lists the heights midway between bows.
function M.gesture(rng, m, hero)
  local cfg = Tune.gesture
  local mw = m.x1 - m.x0
  local lo = m.y0 + mw * 0.75 + 40
  local hi = hero[2] - hero[3] * 1.2
  local n = cfg.bows
  local band = (hi - lo) / n
  local bows, quiet = {}, {}
  for i = 1, n do
    bows[i] = {
      y = lo + band * (i - 0.5 + rng:jit(0.18)),
      amp = mw * rng:range(cfg.bow_amp[1], cfg.bow_amp[2]),
      h = band * rng:range(cfg.bow_width[1], cfg.bow_width[2]),
    }
    if i > 1 then quiet[#quiet + 1] = (bows[i - 1].y + bows[i].y) / 2 end
  end
  local edge = m.x0 + mw * cfg.edge
  -- Clusters {x, y, radius, peak}: the border is densest around the hero
  -- and along the foot, as the reference's is, and swells more gently at
  -- each bow (cfg.bow_density).
  local clusters = {
    { hero[1], hero[2], hero[3] * cfg.end_reach },
    { m.x0 + mw * 0.6, m.y0 + 30, 110 * cfg.end_reach / 2.2 },
    { m.x0 + mw * 0.35, m.y0 + mw * 0.9, mw * 0.6 },
  }
  for _, b in ipairs(bows) do
    -- Clusters stay tighter than the bows, so the stretches between them
    -- read as quiet even where wide bows overlap.
    clusters[#clusters + 1] = { edge + b.amp * 0.7, b.y, band * 0.32, cfg.bow_density }
  end
  local floor = cfg.density_floor
  return {
    edge = edge, bows = bows, quiet = quiet,
    -- Inward offset of the line of action at height y, bows shifted by dy.
    bow = function(y, dy, gain)
      local x = 0
      for i, b in ipairs(bows) do
        local u = (y - b.y - (dy or 0)) / b.h
        if math.abs(u) < 1 then
          x = x + b.amp * (gain and gain[i] or 1) * 0.5 * (1 + math.cos(pi * u))
        end
      end
      return x
    end,
    density = function(x, y)
      local best = 0
      for _, c in ipairs(clusters) do
        local dx, dy = (x - c[1]) / c[3], (y - c[2]) / c[3]
        best = math.max(best, (c[4] or 1) * math.exp(-(dx * dx + dy * dy)))
      end
      return floor + (1 - floor) * best
    end,
  }
end

-- The plant's stems (plant.lua): the main stem first, then the long shoots,
-- then the shoots fanning from the foot and corner.
-- Returns them, the corner point where the main stem starts to rise, and
-- the gesture. Each stem's width function reads its forks when called, so
-- shoots added later still narrow it. Stems bend around rectangle `avoid`
-- ({x0, y0, x1, y1}, optional), kept for the cartouche.
function M.strands(rng, m, hero, W, gest, avoid)
  local Plant = require("flora.plant")
  gest = gest or M.gesture(rng:fork("gesture"), m, hero)
  local main, corner = Plant.main(rng:fork("main"), m, hero, W, gest, avoid)
  local out = { main }
  for _, st in ipairs(Plant.long_shoots(rng:fork("shoots"), main, m, hero, gest, avoid)) do out[#out + 1] = st end
  for _, st in ipairs(Plant.foot_shoots(rng:fork("foot shoots"), main, m, corner, avoid)) do out[#out + 1] = st end
  for _, st in ipairs(Plant.crown(rng:fork("crown"), main, m, hero)) do out[#out + 1] = st end
  for _, st in ipairs(out) do st.width = Plant.width_fn(st) end
  return out, corner, gest
end

-- The outer-corner sprig: a shoot that leaves the plant's root, sweeps up
-- the outer edge and ends in a volute.
function M.runners(rng, m, root, W, edge)
  local S = require("flora.sprig")
  local cx = W - edge - 6
  local a = root
  local b = { cx, m.y0 + 70 }
  local stem = G.link(a, 0.05, b, pi / 2 + 0.08, 0.6)
  local tip = S.tendril(b, pi / 2 + 0.08, 46, 1)
  for i = 2, #tip do stem[#stem + 1] = tip[i] end
  return { { pts = stem, width = function(t) return 0.8 - 0.6 * t end } }
end

-- When the text stops well short of the foot, a strand leaves the root and
-- wanders up into the empty part of the text block. Returns nil otherwise.
function M.excursion(rng, spec, root)
  local t = spec.text
  local lowest = t.y1
  for _, l in ipairs(spec.lines or {}) do
    if l.x1 > t.x0 and l.x0 < t.x1 and l.y0 > t.y0 - 2 and l.y1 < t.y1 + 2 then
      lowest = math.min(lowest, l.y0)
    end
  end
  local room = lowest - t.y0
  if not spec.lines or room < 140 then return nil end
  local w = t.x1 - t.x0
  local ceiling = lowest - 30
  local pts = { root, { root[1] + 22, root[2] + 4 }, { t.x0 - 4, root[2] + rng:range(18, 30) } }
  local n = 5
  local phase = rng:range(0, 2 * pi)
  for i = 1, n do
    local u = i / n
    local x = t.x0 + w * (0.08 + 0.78 * u)
    local y = t.y0 + room * (0.18 + 0.55 * u) + room * 0.10 * math.sin(phase + u * 5)
    pts[#pts + 1] = { x, math.min(y, ceiling) }
  end
  return { pts = G.spline_points(pts, 6), width = function(t) return 1.3 - 0.9 * t end }
end

return M
