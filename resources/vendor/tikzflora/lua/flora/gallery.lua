-- The ornament gallery: every registered kind (ornaments.lua), slot by
-- slot, each drawn for several seeds in a cell of its slot's usual shape.
-- A sheet for trying new kinds: tex/gallery.tex labels it in LaTeX, the
-- site labels it in HTML, and tests/test_ornaments.lua checks each cell.

local Orn = require("flora.ornaments")
local Rng = require("flora.rng")
local Paint = require("flora.paint")

local M = {}

-- Cell size (w, h) per slot, in pt, and extras its kinds expect.
M.cells = {
  gilt = { 24, 24 }, cartouche = { 58, 78 }, header = { 30, 30 }, pendant = { 30, 42, { cord = 14 } }, crest = { 110, 110 },
  flourish = { 280, 46 }, tailpiece = { 140, 88 }, corner = { 72, 72 },
}

-- Lay the sheet out: rows of kinds, `seeds` columns per kind, top to
-- bottom. Returns the cells {name, label, slot, seed, box, o, lift (room
-- the label leaves for the kind's reach)} and the sheet's
-- width and height. `only` (a set of slot and kind names) keeps just
-- those kinds.
function M.layout(seeds, width, only)
  seeds, width = seeds or 3, width or 560
  local cells, y = {}, 0
  local pad, gap, label = 14, 18, 16
  local rows = {}
  for _, slot in ipairs(Orn.slot_order) do
    local c = M.cells[slot]
    -- As many seeds per row as fit; a kind that does not fit in one row
    -- wraps onto the next.
    local per = math.max(1, math.min(seeds, math.floor((width + pad) / (c[1] + pad))))
    for _, k in ipairs(Orn.of(slot)) do
      for first = 1, (not only or only[slot] or only[k.name]) and seeds or 0, per do
        local n = math.min(per, seeds - first + 1)
        -- The label (\footnotesize label and name, about 4.6pt a
        -- character) sets the least width a kind takes.
        local block = math.max(n * c[1] + (n - 1) * pad, (#k.label + #k.name + 1) * 4.6)
        local row = rows[#rows]
        if not row or row.slot ~= slot or row.x + block > width then
          row = { slot = slot, x = 0, h = c[2], kinds = {}, lift = 0 }
          rows[#rows + 1] = row
        end
        row.kinds[#row.kinds + 1] = { k = k, x = row.x, first = first, n = n }
        row.lift = math.max(row.lift, k.reach * math.max(c[1], c[2]))
        row.x = row.x + block + gap * 2
      end
    end
  end
  for _, row in ipairs(rows) do
    y = y + label + row.lift + row.h
    local c = M.cells[row.slot]
    for _, e in ipairs(row.kinds) do
      for i = 1, e.n do
        local x0 = e.x + (i - 1) * (c[1] + pad)
        cells[#cells + 1] = { name = e.k.name, label = e.k.label, slot = row.slot, seed = e.first + i - 1,
          box = { x0, -y, x0 + c[1], -y + c[2] }, o = c[3], lift = row.lift }
      end
    end
    y = y + gap + row.lift
  end
  -- Flip to y up from the sheet's foot.
  for _, c in ipairs(cells) do c.box = { c.box[1] + 20, c.box[2] + y + 10, c.box[3] + 20, c.box[4] + y + 10 } end
  return cells, width + 40, y + 30
end

-- Paint every cell onto `pt` (a new painter if nil); `base` shifts every
-- cell's seed and `only` limits the kinds (see layout). Returns pt, cells,
-- width, height.
function M.sheet(pt, seeds, width, base, only)
  pt = pt or Paint.new({ backend = os.getenv("FLORA_BACKEND") })
  local cells, w, h = M.layout(seeds, width, only)
  for _, c in ipairs(cells) do
    local o = {}
    for k, v in pairs(c.o or {}) do o[k] = v end
    Orn.draw(c.name, pt, Rng.new((c.seed + (base or 0)) * 7919 + #c.name), c.box, o)
  end
  return pt, cells, w, h
end

return M
