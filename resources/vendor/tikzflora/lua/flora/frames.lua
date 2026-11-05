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
--   flank     two plants up the sides of a title page, round its contents,
--             their roots meeting at the foot round a centre piece
--   wreath    an open oval garland round the title: two plants laid along
--             an oval (oval.lua), rooted at its foot, meeting at its top
--   bouquet   one upright bouquet behind the title, as two plants that hug
--             its centre line, each title line on a ribbon (orn_ribbon.lua)
--   scrollwork  a gilt scroll frame on an oval round the title
--             (orn_scrollwork.lua), with lighter plants twined over it
--
-- A map is an affine matrix {a, b, c, d, e, f}: page = (a x + c y + e,
-- b x + d y + f). The affine layouts turn by quarter circles or mirrors, so
-- boxes stay axis-aligned in every frame. A curved frame (the wreath's)
-- carries its map as functions instead: `fn` to the page, `inv` back.

local G = require("flora.geom")
local Tune = require("flora.tune")
local Title = require("flora.orn_title")
local Oval = require("flora.oval")
local Ribbon = require("flora.orn_ribbon")
local Scrollwork = require("flora.orn_scrollwork")

local M = {}

M.order = { "left", "right", "centered", "split", "title", "surround", "flank", "wreath", "bouquet", "scrollwork" }
M.layouts = {}
for _, k in ipairs(M.order) do M.layouts[k] = true end

-- What each layout does, for the guide (catalog.lua).
M.about = {
  left = "The left margin. The default.",
  right = "The right margin.",
  centered = "Both side margins, with a different plant on each side.",
  split = "The outer margin of a two-sided document: on the right of odd pages and the left of even ones.",
  title = "A crown over a title. Wrap the title in the floratitle environment; without it the first block of lines on the page is crowned.",
  surround = "A wreath round the text block, for title pages and contents.",
  flank = "A title page: a plant up each side of its contents, their roots meeting at the foot round a crest.",
  wreath = "A title page: an open oval garland round the title, tied at its foot.",
  bouquet = "A title page: one upright bouquet tied with a bow, behind the title, each title line on a ribbon.",
  scrollwork = "A title page: an oval gilt scroll frame round the title, with a crest at its head and the flora twined over it.",
}

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
  return { spec = s, map = m, fn = function(x, y) return M.apply(m, x, y) end, label = opts.label }
end

-- The frame box round page box `bx` under a curved frame's inverse map,
-- sampled every 4 pt along the box's edges; nil when it misses the frame.
local function inv_box(inv, bx, w, h)
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  local function add(px, py)
    local x, y = inv(px, py)
    x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y)
  end
  local nx = math.max(1, math.ceil((bx.x1 - bx.x0) / 4))
  local ny = math.max(1, math.ceil((bx.y1 - bx.y0) / 4))
  for i = 0, nx do
    local x = bx.x0 + (bx.x1 - bx.x0) * i / nx
    add(x, bx.y0)
    add(x, bx.y1)
  end
  for j = 1, ny - 1 do
    local y = bx.y0 + (bx.y1 - bx.y0) * j / ny
    add(bx.x0, y)
    add(bx.x1, y)
  end
  return clip({ x0 = x0, y0 = y0, x1 = x1, y1 = y1 }, w, h)
end

-- A curved frame of size w x h, mapped to the page by fn and back by inv,
-- whose text block is `text` (in frame coordinates). The page's measured
-- lines are carried in through inv. It only frames the text.
local function curved(spec, fn, inv, w, h, text, opts)
  local lines
  if spec.lines then
    lines = {}
    for _, l in ipairs(spec.lines) do
      local c = inv_box(inv, l, w, h)
      if c then lines[#lines + 1] = c end
    end
  end
  local s = {}
  for k, v in pairs(spec) do s[k] = v end
  s.width, s.height, s.text, s.lines = w, h, text, lines
  s.header_y, s.layout, s.frame_only, s.bare = nil, nil, true, true
  if opts.seed then s.seed = opts.seed end
  if opts.density then
    s.mix = {}
    for k, v in pairs(spec.mix or {}) do s.mix[k] = v end
    s.mix.density = (s.mix.density or Tune.mix.density or 1) * opts.density
  end
  return { spec = s, fn = fn, inv = inv, label = opts.label }
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
  elseif layout == "flank" then
    return M.flank(spec)
  elseif layout == "wreath" then
    return M.wreath(spec)
  elseif layout == "bouquet" then
    return M.bouquet(spec)
  elseif layout == "scrollwork" then
    return M.scrollwork(spec)
  end
end

-- The measured lines' extent across the page, made symmetric about its
-- centre: the column a title page's contents fill. Nil with no lines.
local function column(spec)
  local W, t = spec.width, spec.text
  local half
  for _, l in ipairs(spec.lines or {}) do
    if l.y1 > t.y0 - 2 and l.y0 < t.y1 + 2 and l.x1 > l.x0 then
      half = math.max(half or 0, W / 2 - l.x0, l.x1 - W / 2)
    end
  end
  return half
end

-- Flank: a plant up each side of the contents, in the side margins the
-- contents' column leaves, rooted along the foot so the two roots meet
-- under the middle of the page. A crest sits in the column's lowest gap,
-- or in the foot band under it (orn_title.lua).
function M.flank(spec)
  local W, H, t = spec.width, spec.height, spec.text
  local edge, gutter = spec.edge or 16, spec.gutter or 9
  -- Each margin is kept between a narrow plant's width and a third of the
  -- page, whatever the column.
  local mw_max, mw_min = W * 0.34, 46
  local half = G.clamp((column(spec) or (t.x1 - t.x0) / 2) + 12,
    W / 2 - edge - gutter - mw_max, W / 2 - edge - gutter - mw_min)
  local block = { x0 = W / 2 - half, x1 = W / 2 + half, y0 = t.y0, y1 = t.y1 }
  local fs = {
    frame(spec, IDENTITY, W / 2, H, { block = block, label = "left", frame_only = true }),
    frame(spec, { -1, 0, 0, 1, W, 0 }, W / 2, H, { block = block, seed = seed_of(spec, 2), label = "right", frame_only = true }),
  }
  local piece = Title.foot(spec, block)
  if piece then
    for _, f in ipairs(fs) do
      local k = piece.box
      local c = clip(map_box(M.invert(f.map), { x0 = k[1] - 6, y0 = k[2] - 6, x1 = k[3] + 6, y1 = k[4] + 6 }), W / 2, H)
      if c then f.spec.closed = { { c.x0, c.y0, c.x1, c.y1 } } end
    end
    fs.title = { piece }
  end
  return fs
end

-- The oval a wreath or scroll frame follows round title block B, and its
-- band: a margin `mw` wide whose curve runs `xc` in from the frame's outer
-- edge. The oval spans the page's width, is centred on the block and is
-- at least tall enough that the band's inner side clears the block's
-- corners. Beyond that it grows, up to 1.3 times as tall as wide, into the
-- room between the block and the nearest lines above and below it, less
-- `inset` at each end. A line it cannot clear joins the block, so the
-- oval frames it too rather than cross it.
function M.oval(spec, B, inset)
  local W, H = spec.width, spec.height
  local edge, gutter = spec.edge or 16, spec.gutter or 9
  local mw = G.clamp(W * 0.15, 56, 100)
  local xc = edge + mw * 0.4
  local d = edge + mw + gutter - xc
  local a = W / 2 - xc - 4
  local ring = xc + 4 + (inset or 0)
  B = { x0 = B.x0, y0 = B.y0, x1 = B.x1, y1 = B.y1 }
  local b, cy
  for _ = 1, #(spec.lines or {}) + 1 do
    local hx = math.max(W / 2 - B.x0, B.x1 - W / 2) + 8
    local hy = (B.y1 - B.y0) / 2 + 8
    local u = math.min(0.95, hx / (a - d))
    cy = (B.y0 + B.y1) / 2
    local lo, hi = 0, H
    for _, l in ipairs(spec.lines or {}) do
      if l.y1 < B.y0 - 0.5 then lo = math.max(lo, l.y1 + 6) end
      if l.y0 > B.y1 + 0.5 then hi = math.min(hi, l.y0 - 6) end
    end
    b = math.max(d + hy / math.sqrt(1 - u * u), math.min(a * 1.3, cy - lo - ring, hi - cy - ring))
    local grown = false
    for _, l in ipairs(spec.lines or {}) do
      local outside = l.y1 < B.y0 - 0.5 or l.y0 > B.y1 + 0.5
      if outside and l.y1 > cy - b - ring and l.y0 < cy + b + ring then
        B.x0, B.x1 = math.min(B.x0, l.x0), math.max(B.x1, l.x1)
        B.y0, B.y1 = math.min(B.y0, l.y0), math.max(B.y1, l.y1)
        grown = true
      end
    end
    if not grown then break end
  end
  return Oval.new(W / 2, cy, a, b), mw, xc
end

-- Two plants laid along oval `ov` with its band (M.oval), each up one
-- side from arclength s0 past the foot to s1 short of the top, at
-- `density` times the margin's.
local function along(spec, ov, mw, xc, s0, s1, density)
  local edge, gutter = spec.edge or 16, spec.gutter or 9
  local xi = edge + mw + gutter
  local w, h = xi + 40, s1 - s0
  local text = { x0 = xi, y0 = 0, x1 = w, y1 = h }
  local fs = {}
  for i, side in ipairs({ "left", "right" }) do
    local fn, inv = ov:maps(s0, xc, side == "right")
    fs[i] = curved(spec, fn, inv, w, h, text, { label = side, seed = i == 2 and seed_of(spec, 2) or nil, density = density })
  end
  fs.oval = ov
  return fs
end

-- Wreath: two plants laid along an oval round the title, each up one
-- side from the oval's foot to its top, where their heroes meet. Each
-- frame starts a little past the foot, so the two roots cross there as a
-- tied wreath's do; the garland grows at 0.75 of the margin's density.
function M.wreath(spec)
  local B = spec.title or M.top_block(spec)
  local ov, mw, xc = M.oval(spec, B)
  local edge, gutter = spec.edge or 16, spec.gutter or 9
  local R = hero_radius(spec, edge + mw + gutter)
  return along(spec, ov, mw, xc, -(edge + 10), ov.len / 2 - R * 0.35, 0.75)
end

-- Scrollwork: a gilt scroll frame on an oval round the title
-- (orn_scrollwork.lua), with lighter plants twined over its band up each
-- side, between the pieces at its foot and its head.
function M.scrollwork(spec)
  local B = spec.title or M.top_block(spec)
  local ov, mw, xc = M.oval(spec, B, 40)
  local plan = Scrollwork.plan(spec, ov)
  local foot, head = plan.foot, plan.head
  -- The plants start beside the foot piece and stop short of the head's.
  local fs = along(spec, ov, mw, xc, (foot[3] - foot[1]) * 0.45, ov.len / 2 - (head[3] - head[1]) * 0.7, 0.55)
  fs.before = function(pt) Scrollwork.under(pt, spec, ov, plan) end
  fs.after = function(pt) Scrollwork.over(pt, spec, ov, plan) end
  fs.scrollwork = plan
  return fs
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

-- The measured lines whose middles lie inside block B, top first.
function M.lines_in(spec, B)
  local out = {}
  for _, l in ipairs(spec.lines or {}) do
    local my = (l.y0 + l.y1) / 2
    if my >= B.y0 - 0.5 and my <= B.y1 + 0.5 and l.x1 > B.x0 and l.x0 < B.x1 then out[#out + 1] = l end
  end
  table.sort(out, function(p, q) return p.y1 > q.y1 end)
  return out
end

-- Bouquet: one upright bouquet centred on the title, from 230 pt below it
-- to 170 pt above, short of the nearest lines below and above it (its
-- stems would cross them). Its two halves are plants whose outer edge is the
-- bouquet's centre line: their main stems rise from it, gathered, and
-- leave it over the lowest third, so the bouquet fans out from a tied
-- foot; the right half stands lower, so the two heroes stagger.
-- The title's lines are carried into both frames, so blooms and leaves
-- grow between them while stems pass behind, and each line is painted
-- on a ribbon over the finished bouquet.
function M.bouquet(spec)
  local W, H = spec.width, spec.height
  local B = spec.title or M.top_block(spec)
  local gutter = spec.gutter or 9
  local cx = W / 2
  local mw = G.clamp((B.x1 - B.x0) * 0.6, 80, W * 0.32)
  local hw = 4 + mw + gutter
  local lo, hi = 40, H - 16
  for _, l in ipairs(spec.lines or {}) do
    if l.y1 < B.y0 - 0.5 then lo = math.max(lo, l.y1 + 10) end
    if l.y0 > B.y1 + 0.5 then hi = math.min(hi, l.y0 - 10) end
  end
  local base = math.max(lo, B.y0 - 230)
  local top = math.min(hi, B.y1 + 170)
  local fs = {}
  for i, side in ipairs({ "left", "right" }) do
    local s = side == "left" and -1 or 1
    local h = (top - base) * (i == 1 and 1 or 0.84)
    local wf = side == "left" and cx or W - cx
    local block = side == "left" and { x0 = 0, x1 = cx - hw, y0 = base, y1 = base + h }
      or { x0 = cx + hw, x1 = W, y0 = base, y1 = base + h }
    local f = frame(spec, { s, 0, 0, 1, cx, base }, wf, h, { block = block, label = side, frame_only = true,
      seed = i == 2 and seed_of(spec, 2) or nil })
    f.spec.bare, f.spec.edge, f.spec.gather = true, 4, h * 0.3
    -- The bouquet's outline: a quarter of its width at the tie, full from
    -- just past halfway, rounding over at the top.
    local closed = {}
    for y = 0, h, 6 do
      local u = y / h
      local k = 0.25 + 0.75 * G.smoothstep(0, 0.55, u) - 0.25 * G.smoothstep(0.82, 1, u)
      closed[#closed + 1] = { 4 + mw * k + 2, y, wf, y + 6 }
    end
    f.spec.closed = closed
    fs[i] = f
  end
  local lines = M.lines_in(spec, B)
  -- The bow's tails hang about its own size below the knot, and stay
  -- above the bouquet's foot.
  local bow = G.clamp(mw * 0.6, 34, 56)
  local tie = { cx, math.max(base + (top - base) * 0.11, base + bow) }
  fs.after = function(pt)
    Ribbon.bow(pt, tie[1], tie[2], bow)
    Ribbon.paint(pt, lines)
  end
  fs.tie = tie
  return fs
end

return M
