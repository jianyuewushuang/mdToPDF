-- Page layouts as frames. compose.lua always grows one plant in a left
-- margin; a layout places one or more such plants on the page by giving
-- each its own frame: a local page whose left margin is the band the plant
-- should fill, and a map from that local page back to the paper.
--
--   left      the outer left margin (the default; the page's own spec)
--   right     the left layout mirrored into the right margin
--   centered  two plants, one in each side margin, on separate seeds
--   split     right on odd pages, left on even ones (two-sided documents)
--   title     two plants crowning a title block, rooted beside it and
--             arching over it to meet at the top centre
--   surround  a wreath: one plant up the left margin and along the foot,
--             another, turned half a circle, down the right and along the top
--
-- A map is an affine matrix {a, b, c, d, e, f}: page = (a x + c y + e,
-- b x + d y + f). Every layout here turns by quarter circles or mirrors, so
-- boxes stay axis-aligned in every frame.

local G = require("flora.geom")
local Tune = require("flora.tune")
local Title = require("flora.orn_title")

local M = {}

M.layouts = { left = true, right = true, centered = true, split = true, title = true, surround = true }

-- Apply matrix m to (x, y).
function M.apply(m, x, y)
  return m[1] * x + m[3] * y + m[5], m[2] * x + m[4] * y + m[6]
end

function M.invert(m)
  local det = m[1] * m[4] - m[2] * m[3]
  assert(math.abs(det) > 1e-9, "frame map is singular")
  local a, b, c, d = m[4] / det, -m[2] / det, -m[3] / det, m[1] / det
  return { a, b, c, d, -(a * m[5] + c * m[6]), -(b * m[5] + d * m[6]) }
end

-- Box {x0, y0, x1, y1} (as a table with those keys) under matrix m.
local function map_box(m, bx)
  local ax, ay = M.apply(m, bx.x0, bx.y0)
  local bx2, by2 = M.apply(m, bx.x1, bx.y1)
  return { x0 = math.min(ax, bx2), y0 = math.min(ay, by2), x1 = math.max(ax, bx2), y1 = math.max(ay, by2) }
end

local function clip(bx, w, h)
  local c = { x0 = math.max(0, bx.x0), y0 = math.max(0, bx.y0), x1 = math.min(w, bx.x1), y1 = math.min(h, bx.y1) }
  if c.x1 <= c.x0 or c.y1 <= c.y0 then return nil end
  return c
end

-- A frame of size w x h whose map to the page is `m`. The page's text block
-- (or `block`, a page box standing in for it) and its measured lines are
-- carried into the frame; lines outside the frame are dropped.
local function frame(spec, m, w, h, opts)
  opts = opts or {}
  local inv = M.invert(m)
  local text = clip(map_box(inv, opts.block or spec.text), w, h)
  assert(text, "layout: the text block lies outside its frame")
  local lines
  if spec.lines then
    lines = {}
    for _, l in ipairs(spec.lines) do
      local c = clip(map_box(inv, l), w, h)
      if c then lines[#lines + 1] = c end
    end
  end
  local s = {}
  for k, v in pairs(spec) do s[k] = v end
  s.width, s.height, s.text, s.lines = w, h, text, lines
  s.header_y = opts.header and spec.header_y or nil
  s.closed = opts.closed
  -- A wreath or a crown frames the text; it does not grow into it.
  s.frame_only = opts.frame_only
  s.layout = nil
  if opts.seed then s.seed = opts.seed end
  return { spec = s, map = m, label = opts.label }
end

local IDENTITY = { 1, 0, 0, 1, 0, 0 }

-- A frame's seed, so the plants of one page differ but each reproduces.
local function seed_of(spec, k)
  return (tonumber(spec.seed) or 1) * 31 + k * 7907
end

-- The hero bloom's radius for a frame whose margin runs from `edge` to
-- text x0 (compose.lua's rule), used to keep two heroes from colliding.
local function hero_radius(spec, x0)
  local mw = x0 - (spec.gutter or 9) - (spec.edge or 16)
  return G.clamp(mw * Tune.compose.hero, 28, 80)
end

-- The frames for a page. With the default layout this is the page itself,
-- unmapped. `spec.layout` names the layout; `spec.page` (for split) the
-- page number; `spec.title` (for title) the title block {x0, y0, x1, y1},
-- defaulting to the measured ink of the top of the text block.
function M.of(spec)
  local layout = spec.layout or "left"
  local W, H = spec.width, spec.height
  assert(M.layouts[layout], "unknown layout " .. tostring(layout))
  if layout == "split" then
    layout = (spec.page or 1) % 2 == 1 and "right" or "left"
  end
  if layout == "left" then
    return { { spec = spec } }
  elseif layout == "right" then
    return { frame(spec, { -1, 0, 0, 1, W, 0 }, W, H, { header = true }) }
  elseif layout == "centered" then
    local half = W / 2
    return {
      frame(spec, IDENTITY, half, H, { label = "left" }),
      frame(spec, { -1, 0, 0, 1, W, 0 }, half, H, { seed = seed_of(spec, 2), label = "right" }),
    }
  elseif layout == "surround" then
    -- Each plant keeps to its own margin and its own end band, so the two
    -- meet in a pinwheel: the first owns the left margin up to the text's
    -- top and the whole foot; the second, turned 180 degrees, owns the
    -- right margin down to the text's foot and the whole top band.
    local a = frame(spec, IDENTITY, W, H, { label = "left", frame_only = true })
    local b = frame(spec, { -1, 0, 0, -1, W, H }, W, H, { seed = seed_of(spec, 2), label = "right", frame_only = true })
    for _, f in ipairs({ a, b }) do
      local ft = f.spec.text
      f.spec.closed = {
        { ft.x1, ft.y0 - 6, W, H },  -- the other plant's margin
        { 0, ft.y1 + 4, W, H },      -- the other plant's end band
      }
    end
    return { a, b }
  elseif layout == "title" then
    local B = spec.title or M.top_block(spec)
    -- The left plant's frame is the page turned a quarter: its left margin
    -- is the band above the title, its foot the strip beside the title, and
    -- its top the page's centre line. The right plant mirrors it.
    -- The two crowns stop short of the centre line, leaving the gap at the
    -- top centre that the crest (orn_title.lua) fills.
    local depth = math.min(H, H - B.y0 + 60)
    local R = hero_radius(spec, H - B.y1)
    local crest = Title.crest_size(spec, R)
    local half = W / 2 - R * 0.47 - crest * 0.45
    local fs = {
      frame(spec, { 0, -1, 1, 0, 0, H }, depth, half, { block = B, label = "left", frame_only = true }),
      frame(spec, { 0, -1, -1, 0, W, H }, depth, half, { block = B, seed = seed_of(spec, 2), label = "right", frame_only = true }),
    }
    -- The plants keep out of the furniture's boxes.
    local plan, keep = Title.plan(spec, B, crest)
    for _, f in ipairs(fs) do
      local closed = {}
      for _, k in ipairs(keep) do
        local c = clip(map_box(M.invert(f.map), { x0 = k[1] - 4, y0 = k[2] - 4, x1 = k[3] + 4, y1 = k[4] + 4 }), depth, half)
        if c then closed[#closed + 1] = { c.x0, c.y0, c.x1, c.y1 } end
      end
      f.spec.closed = closed
    end
    fs.title = plan
    return fs
  end
end

-- The block of measured lines at the top of the text, down to the first
-- gap of more than two line heights: a title, by default.
function M.top_block(spec)
  local t = spec.text
  local ls = {}
  for _, l in ipairs(spec.lines or {}) do
    if l.y1 > t.y0 and l.y0 < t.y1 + 2 then ls[#ls + 1] = l end
  end
  table.sort(ls, function(p, q) return p.y1 > q.y1 end)
  if #ls == 0 then return { x0 = t.x0, y0 = t.y1 - 80, x1 = t.x1, y1 = t.y1 } end
  local B = { x0 = ls[1].x0, y0 = ls[1].y0, x1 = ls[1].x1, y1 = ls[1].y1 }
  for i = 2, #ls do
    local l = ls[i]
    local h = ls[i - 1].y1 - ls[i - 1].y0
    if B.y0 - l.y1 > 2 * h then break end
    B.x0, B.x1, B.y0 = math.min(B.x0, l.x0), math.max(B.x1, l.x1), math.min(B.y0, l.y0)
  end
  return B
end

-- The box around `lines` whose middles lie between heights y_hi and y_lo,
-- or nil when none do.
function M.between(lines, y_hi, y_lo)
  local B
  for _, l in ipairs(lines) do
    local mid = (l.y0 + l.y1) / 2
    if mid <= y_hi and mid >= y_lo then
      if B then
        B.x0, B.x1 = math.min(B.x0, l.x0), math.max(B.x1, l.x1)
        B.y0, B.y1 = math.min(B.y0, l.y0), math.max(B.y1, l.y1)
      else
        B = { x0 = l.x0, x1 = l.x1, y0 = l.y0, y1 = l.y1 }
      end
    end
  end
  return B
end

return M
