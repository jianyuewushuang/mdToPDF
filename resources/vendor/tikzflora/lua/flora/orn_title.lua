-- Title-page furniture for the title layout: a crest in the gap at the top
-- centre where the two crowning plants meet, a flourish under the title
-- block, a tailpiece under the page's last line and a piece in each foot
-- corner. Each slot's kind is drawn by weight (ornaments.lua); a slot whose
-- kinds all weigh 0, or whose place has no room, is left out. Boxes are
-- page boxes {x0, y0, x1, y1}, y up.

local Orn = require("flora.ornaments")
local Rng = require("flora.rng")
local G = require("flora.geom")

local M = {}

local PAD = 10

-- The kind for `slot` on this page, or nil.
local function choose(spec, slot)
  return Orn.pick(Rng.new(tonumber(spec.seed) or 1):fork("choose title " .. slot), slot, spec.ornaments)
end

-- The crest's side for a crown whose heroes have radius R, or 0 with no
-- crest. The frames leave this much more of the top centre open.
function M.crest_size(spec, R)
  if not choose(spec, "crest") then return 0 end
  return G.clamp(R * 1.2, 44, 84)
end

-- The highest measured line wholly below height y, or nil.
local function next_below(lines, y)
  local best
  for _, l in ipairs(lines or {}) do
    if l.y1 < y and (not best or l.y1 > best.y1) then best = l end
  end
  return best
end

-- The furniture for a title page with title block B (frames.lua), whose
-- crown left a gap `crest` wide at the top centre. Returns a list of
-- {slot, kind, box, o} and the boxes the plants must keep out of.
function M.plan(spec, B, crest)
  local W, H = spec.width, spec.height
  local t = spec.text
  local cx = (B.x0 + B.x1) / 2
  local out, keep = {}, {}
  local function add(slot, box, o, reserve)
    local kind = choose(spec, slot)
    if not kind then return end
    out[#out + 1] = { slot = slot, kind = kind, box = box, o = o or {} }
    if reserve then keep[#keep + 1] = box end
  end
  if crest > 0 then
    add("crest", { W / 2 - crest / 2, H - PAD - crest, W / 2 + crest / 2, H - PAD })
  end
  -- The flourish hangs under the title block when the gap down to the next
  -- line holds it with room either side.
  local below = next_below(spec.lines, B.y0)
  local fw = math.min(280, (B.x1 - B.x0) * 1.15, t.x1 - t.x0)
  local fh = fw * 46 / 280
  local floor = below and below.y1 or t.y0
  if B.y0 - floor >= fh + 2 * PAD then
    local y1 = B.y0 - PAD * 0.6
    add("flourish", { cx - fw / 2, y1 - fh, cx + fw / 2, y1 }, nil, true)
  end
  -- The tailpiece sits under the lowest line, inside the text block, when
  -- any text follows the title.
  local last
  for _, l in ipairs(spec.lines or {}) do
    if not last or l.y0 < last.y0 then last = l end
  end
  if last and last.y1 < B.y0 then
    local tw = math.min(140, (t.x1 - t.x0) * 0.4)
    local th = tw * 88 / 140
    local y1 = last.y0 - PAD * 1.6
    if y1 - th >= t.y0 then
      local tx = (t.x0 + t.x1) / 2
      add("tailpiece", { tx - tw / 2, y1 - th, tx + tw / 2, y1 }, nil, true)
    end
  end
  -- A piece in each foot corner, inside the side margins.
  local s = math.min(72, t.x0 - 24, W - t.x1 - 24, t.y0 - 24)
  if s >= 28 then
    local kind = choose(spec, "corner")
    if kind then
      out[#out + 1] = { slot = "corner", kind = kind, box = { 16, 16, 16 + s, 16 + s }, o = { flip = { 1, 1 } } }
      out[#out + 1] = { slot = "corner", kind = kind, box = { W - 16 - s, 16, W - 16, 16 + s }, o = { flip = { -1, 1 } } }
    end
  end
  return out, keep
end

-- The flank layout's foot piece: a crest-slot kind in the lowest gap of
-- column `block` (frames.lua) that holds it, else in the foot band under
-- the column. Returns a plan entry, or nil when no kind or no room.
function M.foot(spec, block)
  local kind = choose(spec, "crest")
  if not kind then return nil end
  local W, t = spec.width, spec.text
  local s = G.clamp((block.x1 - block.x0) * 0.32, 44, 84)
  local ls = {}
  for _, l in ipairs(spec.lines or {}) do
    if l.x1 > block.x0 and l.x0 < block.x1 and l.y1 > t.y0 - 2 then ls[#ls + 1] = l end
  end
  table.sort(ls, function(p, q) return p.y0 < q.y0 end)
  local y0
  -- From the bottom up: the first gap between lines that holds the piece.
  for i = 1, #ls - 1 do
    if ls[i + 1].y0 - ls[i].y1 >= s + 2 * PAD then y0 = ls[i].y1 + PAD break end
  end
  if not y0 then
    local floor = 18
    local top = (#ls > 0 and math.min(ls[1].y0, t.y0) or t.y0) - PAD
    if top - floor < 28 then return nil end
    s = math.min(s, top - floor)
    y0 = floor
  end
  return { slot = "crest", kind = kind, box = { W / 2 - s / 2, y0, W / 2 + s / 2, y0 + s }, o = {} }
end

-- Paint the planned furniture onto pt, in page coordinates.
function M.paint(pt, spec, plan)
  local rng = Rng.new(tonumber(spec.seed) or 1)
  for i, p in ipairs(plan) do
    -- The two corner pieces are one design mirrored, so they share a
    -- stream.
    Orn.draw(p.kind, pt, rng:fork("title " .. p.slot .. (p.slot == "corner" and "" or i)), p.box, p.o)
  end
end

return M
