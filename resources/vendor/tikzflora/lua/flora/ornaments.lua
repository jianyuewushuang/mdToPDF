-- The ornament registry. Every ornament kind registers itself here under a
-- unique name, for one slot: a place on the page that can take any kind
-- registered for it. A page picks one kind per slot by weight, from its
-- own random stream, so the choice never moves anything else. Settings
-- change the weights with ornaments={moon=2, sun=0}.
--
-- A kind is a table:
--   name    unique name, the key in ornaments={...}
--   slot    one of M.slots
--   label   a short name for the mixer and the gallery
--   reach   how far past its box it may paint, as a share of the box's
--           larger side (default 0.05); tests hold it to this
--   draw    function(pt, rng, box, o): paint inside box {x0, y0, x1, y1}
--           (page coordinates, y up); o carries slot extras (see slots)
--
-- To try a new kind, put it in a file that calls M.register and add the
-- file to MODULES below; the gallery (gallery.lua) and the tests pick it up
-- without further changes.

local Tune = require("flora.tune")

local M = {}
package.loaded["flora.ornaments"] = M

-- Slot -> what it is, and its box's usual shape (w / h).
M.slots = {
  cartouche = { label = "Cartouche", desc = "An inset panel in the outer margin.", aspect = 0.74 },
  header = { label = "Header", desc = "The gilt mark where the running-head rule starts.", aspect = 1 },
  pendant = { label = "Pendant", desc = "A gilt pendant hanging in the foot's corner; o.cord is its cord.", aspect = 0.7 },
  crest = { label = "Crest", desc = "A centrepiece where the title crown meets.", aspect = 1 },
  flourish = { label = "Flourish", desc = "A swash or rule below the title.", aspect = 6 },
  tailpiece = { label = "Tailpiece", desc = "A closing ornament below the title page's text.", aspect = 1.6 },
  corner = { label = "Corner", desc = "A corner piece; drawn into the lower-left corner of its box (o.flip mirrors it).", aspect = 1 },
  gilt = { label = "Gilt", desc = "The larger gilt scattered in the foliage's gaps, picked for each gap.", aspect = 1 },
}
M.slot_order = { "cartouche", "header", "pendant", "crest", "flourish", "tailpiece", "corner", "gilt" }

M.kinds, M.order = {}, {}

function M.register(k)
  assert(type(k.name) == "string" and k.name:match("^[%a_][%w_]*$"), "ornament needs a name that is a Lua identifier")
  assert(M.slots[k.slot], "ornament " .. k.name .. ": unknown slot " .. tostring(k.slot))
  assert(not M.kinds[k.name], "ornament " .. k.name .. " is registered twice")
  assert(type(k.draw) == "function", "ornament " .. k.name .. " needs a draw function")
  k.label = k.label or k.name
  k.reach = k.reach or 0.05
  M.kinds[k.name] = k
  M.order[#M.order + 1] = k.name
  return k
end

-- The kinds registered for `slot`, in registration order.
function M.of(slot)
  local out = {}
  for _, n in ipairs(M.order) do
    if M.kinds[n].slot == slot then out[#out + 1] = M.kinds[n] end
  end
  return out
end

-- The weight of kind `name` under settings `weights` (name -> weight),
-- else tune.lua's ornaments, else 1.
function M.weight(weights, name)
  local w = weights and weights[name]
  if w == nil then w = Tune.ornaments and Tune.ornaments[name] end
  if w == nil then w = 1 end
  return w
end

-- One kind for `slot`, drawn by weight from `rng` (give it a stream of its
-- own); nil when every kind of the slot weighs 0.
function M.pick(rng, slot, weights)
  local t = {}
  for _, k in ipairs(M.of(slot)) do t[k.name] = M.weight(weights, k.name) end
  local name = rng:weighted(t)
  return name and M.kinds[name]
end

-- Draw kind `name` (or kind table) into box with `o`. Its gold and copper
-- are painted as gilt (paint.lua).
function M.draw(kind, pt, rng, box, o)
  if type(kind) == "string" then kind = assert(M.kinds[kind], "no ornament " .. kind) end
  local was = pt.gilding
  pt.gilding = true
  kind.draw(pt, rng, box, o or {})
  if pt.gilt_pending then require("flora.orn_raster").flush(pt) end
  pt.gilding = was
end

local MODULES = { "flora.orn_classic", "flora.orn_celestial", "flora.orn_scroll", "flora.orn_roundel", "flora.orn_pieces", "flora.orn_flourish", "flora.orn_acanthus", "flora.orn_corner", "flora.orn_gilt" }
for _, m in ipairs(MODULES) do require(m) end

-- Each kind labels its own weight in tune.lua's docs, for the tuner.
for _, name in ipairs(M.order) do
  local k, s = M.kinds[name], M.slots[M.kinds[name].slot]
  Tune._doc["ornaments." .. name] = Tune._doc["ornaments." .. name] or { k.label, s.label .. ": " .. s.desc }
end

return M
