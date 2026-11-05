-- A garden for a web page: the page spec for flora grown round a page's
-- content rather than a printed text block. Units are CSS pixels, taken as
-- points, so a 200 px margin grows as a 200 pt one does in print.
--
--   margins  a plant in each side margin of a `width` x `height` viewport
--            whose content column runs from x0 to x1 (the centered layout)
--   band     a crown across the top of a `width` x `height` strip, two
--            plants meeting at a crest (the title layout over a block
--            below the strip, which is cut off)
--
-- The site's worker (site/src/lib/render.worker.js, kind "garden") grows
-- M.spec's page and draws only M.view of it.

local Settings = require("flora.settings")
local Init = require("flora.init")

local M = {}

-- The narrowest margin a plant grows in, and the shortest band.
M.MIN_MARGIN, M.MIN_BAND = 60, 60
-- The height of the hidden block under a band, which its plants crown.
local UNDER = 40
-- The strip kept clear at a margin's head and foot.
local END = 24

-- The page spec for garden `o`:
--   o.mode     "margins" or "band"
--   o.width, o.height  the viewport (margins) or strip (band), px
--   o.x0, o.x1 the content column (margins)
--   o.seed     the garden: a whole number, the same for everyone on a day
--   o.grow     0-1, how far it has grown (1 or nil: in full)
--   o.settings a \florasetup key list over the garden's own (colourway,
--              backdrop, density, mix, ...)
-- Errors name what is wrong.
function M.spec(o)
  local W, H = tonumber(o.width), tonumber(o.height)
  assert(W and H and W > 0 and H > 0, "garden: width and height must be positive")
  local seed = tonumber(o.seed)
  assert(seed and seed == math.floor(seed), "garden: seed must be a whole number")
  local grow = o.grow and tonumber(o.grow)
  assert(grow == nil or (grow >= 0 and grow <= 1), "garden: grow must be from 0 to 1")
  local set = Settings.parse(o.settings or "")
  local spec = {
    seed = Init.seed(seed, 1), page = 1,
    mix = set.mix, ornaments = set.ornaments, palette = set.palette, spin = set.spin,
    gilt = set.gilt, gilt_dpi = set.giltdpi, gilt_env = set.giltenv, gilt_look = set.giltlook,
    backdrop = set.backdrop,
    grow = grow and grow < 1 and grow or nil,
  }
  if o.mode == "margins" then
    local x0, x1 = tonumber(o.x0), tonumber(o.x1)
    assert(x0 and x1 and x0 < x1, "garden: the content column needs x0 < x1")
    -- Both plants come from one page laid out centred, so the column sits
    -- in the middle: the narrower margin sets both.
    local m = math.min(x0, W - x1)
    assert(m >= M.MIN_MARGIN, string.format("garden: margins under %d px", M.MIN_MARGIN))
    local text = { x0 = m, x1 = W - m, y0 = END, y1 = H - END }
    spec.width, spec.height, spec.layout = W, H, "centered"
    -- One line filling the column: nothing grows over the content.
    spec.text, spec.lines = text, { { x0 = text.x0, x1 = text.x1, y0 = text.y0, y1 = text.y1 } }
    return spec, { x = 0, y = 0, width = W, height = H }
  elseif o.mode == "band" then
    assert(H >= M.MIN_BAND, string.format("garden: a band under %d px", M.MIN_BAND))
    local inset = math.min(12, W * 0.03)
    local block = { x0 = inset, x1 = W - inset, y0 = 2, y1 = UNDER }
    spec.width, spec.height, spec.layout = W, H + UNDER, "title"
    spec.text, spec.title = block, block
    spec.lines = { { x0 = block.x0, x1 = block.x1, y0 = block.y0, y1 = block.y1 } }
    -- The band is the page's top H px (y up from the foot: UNDER to H + UNDER).
    return spec, { x = 0, y = UNDER, width = W, height = H }
  end
  error("garden: mode must be margins or band (got " .. tostring(o.mode) .. ")")
end

return M
