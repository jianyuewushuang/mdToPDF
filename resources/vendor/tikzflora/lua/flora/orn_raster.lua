-- Raster gilt, the default: an ornament's gold computed pixel by pixel
-- and placed as an image (tune.lua's gilt; \florasetup{gilt=vector}
-- paints the vector relief of orn_relief.lua instead).
--
-- While an ornament draws, its gilt shapes are collected in page
-- coordinates instead of painted. Any other paint, or the ornament's end,
-- turns the shapes collected so far into one image, so gold keeps its
-- place among the ornament's inks. Each image is built in four steps:
--   coverage   every shape rasterised, anti-aliased (raster.lua)
--   relief     each shape's own surface, from its distance to its edge
--              (raster_relief.lua), laid down in painting order
--   light      normals from the relief reflect an environment, "studio"
--              (a hard horizon, a soft window to the upper left, dark
--              ground below) or "mirror" (the vector relief's), plus a
--              sharp highlight; the brightness reads through a gold ramp
--              (a copper one for shaded faces)
--   texture    faint brushed grain and rare sparkle from hashed noise
-- A soft umber shadow falls away from the light. The image is RGB with a
-- soft mask for alpha. Every number of the look is a parameter of
-- tune.lua's gilt_looks (gilt_look.lua).

local Raster = require("flora.raster")
local Relief = require("flora.raster_relief")
local Look = require("flora.gilt_look")
local Tune = require("flora.tune")

local M = {}

local sqrt, floor, max, min, abs = math.sqrt, math.floor, math.max, math.min, math.abs
local cos, sin, pi = math.cos, math.sin, math.pi
local char, concat, unpack = string.char, table.concat, table.unpack

-- A ramp of stops {brightness, {r, g, b}} as a 256-entry lookup of
-- {r, g, b} bytes, built once per ramp.
local luts = setmetatable({}, { __mode = "k" })
local function lut(stops)
  if luts[stops] then return luts[stops] end
  local out = {}
  for i = 0, 255 do
    local t, j = i / 255, 1
    while j < #stops - 1 and t > stops[j + 1][1] do j = j + 1 end
    local a, b = stops[j], stops[j + 1]
    local u = (t - a[1]) / (b[1] - a[1])
    u = u < 0 and 0 or (u > 1 and 1 or u)
    local c = {}
    for k = 1, 3 do c[k] = floor((a[2][k] + (b[2][k] - a[2][k]) * u) * 255 + 0.5) end
    out[i] = c
  end
  luts[stops] = out
  return out
end

-- Grain and sparkle; tests turn them off to see the relief alone.
M.texture = true

-- Pixels per inch of the computed gold.
function M.dpi(pt)
  return pt.gilt_dpi or Tune.gilt_dpi or 600
end

-- The pending shapes of painter pt, created on first use.
local function pending(pt)
  local p = pt.gilt_pending
  if not p then
    p = { shapes = {}, x0 = math.huge, y0 = math.huge, x1 = -math.huge, y1 = -math.huge, shadow = 0 }
    pt.gilt_pending = p
  end
  return p
end

-- How much pt's frame and projection scale lengths near (x, y).
local function scale_at(pt, x, y)
  local pj = pt:_pj()
  if not pj then return 1 end
  local ox, oy = pj(x, y)
  local ax, ay = pj(x + 1, y)
  local bx, by = pj(x, y + 1)
  return sqrt(abs((ax - ox) * (by - oy) - (bx - ox) * (ay - oy)))
end

-- Collect shapes. kind is "fill" (closed paths) or "stroke" (open paths
-- `width` pt wide); o.tone = "shade" for copper faces, o.bevel the bevel
-- width in pt and o.shadow the shadow offset, both in the ornament's own
-- lengths. Each filled path is a piece with its own relief (a leaf of a
-- wreath), unless o.whole keeps them one piece (a row of beads).
function M.add(pt, kind, paths, o)
  o = o or {}
  local p = pending(pt)
  local Paint = require("flora.paint")
  local pj = pt:_pj()
  local page = {}
  for i, cmds in ipairs(paths) do
    -- Record extents (and probes) as painting the shape would.
    pt:_path(cmds, {})
    page[i] = pj and Paint.projected(cmds, pj) or cmds
  end
  local b = require("flora.orn_gild").bbox(page)
  if b[1] > b[3] then return end
  local k = scale_at(pt, (b[1] + b[3]) / 2, (b[2] + b[4]) / 2)
  local half = kind == "stroke" and o.width * k / 2 or 0
  p.x0, p.y0 = min(p.x0, b[1] - half), min(p.y0, b[2] - half)
  p.x1, p.y1 = max(p.x1, b[3] + half), max(p.y1, b[4] + half)
  p.shadow = max(p.shadow, (o.shadow or 0) * k)
  local pieces = (kind == "stroke" or o.whole) and { page } or {}
  if #pieces == 0 then for i, cmds in ipairs(page) do pieces[i] = { cmds } end end
  p.calls = (p.calls or 0) + 1
  for _, piece in ipairs(pieces) do
    p.shapes[#p.shapes + 1] = {
      kind = kind, paths = piece, evenodd = o.evenodd, half = half, call = p.calls,
      bevel = o.bevel and o.bevel * k, tone = o.tone == "shade" and 1 or 0,
    }
  end
end

local function smooth(a, b, x)
  local t = (x - a) / (b - a)
  t = t < 0 and 0 or (t > 1 and 1 or t)
  return t * t * (3 - 2 * t)
end

-- The studio's brightness seen along reflected ray (rx, ry, rz), for
-- look L lit from page direction (lx, ly).
local function studio(L, lx, ly)
  local H0, DIP, SOFT = L.horizon, L.horizon_dip, L.horizon_soft
  local SKY, GLOW, LIT, FAR = L.sky, L.sky_glow, L.sky_lit, L.sky_far
  local WIN, TOP, FOOT = L.window, L.window_top, L.window_foot
  local SPAN = TOP - FOOT
  local G0, FALL, GLIT = L.ground, L.ground_fall, L.ground_lit
  return function(rx, ry, rz)
    local hl = sqrt(rx * rx + ry * ry)
    local a = hl > 1e-6 and (rx * lx + ry * ly) / hl or 0
    -- The horizon dips on the lit side, so more of it shows sky, and
    -- rises on the far side, which sees more ground.
    local horizon = H0 - DIP * a
    local e = rz - horizon
    -- Sky: brighter toward the horizon and toward the light; it stays
    -- under white, which only the highlight reaches.
    local sky = SKY + GLOW * (1 - rz) * (1 - rz) + (a > 0 and LIT or FAR) * a * hl
    if a > 0 then
      -- The window: a broad bright patch low in the lit quarter.
      local wnd = a * a * (rz > TOP and 0 or (rz < FOOT and 1 or (TOP - rz) / SPAN))
      sky = sky + WIN * wnd
    end
    local ground = G0 + FALL * (-rz) + GLIT * a
    if e >= SOFT then return sky end
    if e <= -SOFT then return ground end
    local u = (e + SOFT) / (SOFT + SOFT)
    u = u * u * (3 - 2 * u)
    return ground + (sky - ground) * u
  end
end

-- The "mirror" environment, as the vector relief (orn_relief.lua
-- M.mirror) sees it: sky toward the light past a sharp horizon with a
-- bright band, dark ground, and the front (straight up) a mid gold.
local function mirror(L, lx, ly)
  local H0, SOFT, SKY, GLOW = L.horizon, L.horizon_soft, L.sky, L.sky_glow
  local BAND, BW, G0, GFAR, FRONT = L.band, L.band_width, L.ground, L.ground_far, L.front
  return function(rx, ry)
    local u = rx * lx + ry * ly
    local v = G0 + GFAR * smooth(-0.3, -1, u)
    v = v + (SKY + GLOW * smooth(0.25, 0.95, u) - v) * smooth(H0 - SOFT, H0 + SOFT, u)
    v = v + BAND * math.exp(-((u - H0 - 0.06) / BW) ^ 2)
    return FRONT + (v - FRONT) * smooth(0.05, 0.6, sqrt(rx * rx + ry * ry))
  end
end

-- Shade the relief R (Relief.layers) into RGB and alpha bytes, rows top
-- down, in look L of environment `kind` ("studio" or "mirror"), lit from
-- angle `light`.
local function shade(g, R, shadow_px, light, L, kind)
  local C, SX, SY, T, Z, WA, BX, BY, BT = unpack(R, 1, 9)
  local GL, CL = lut(L.gold), lut(L.copper)
  local W, Hh = g.w, g.h
  local lx, ly = cos(light), sin(light)
  local env = (kind == "mirror" and mirror or studio)(L, lx, ly)
  local HL, CUT, HS = L.highlight, 1 - L.highlight_size, L.highlight_size
  local GRAIN, GS, SPARK, GLINT = L.grain, L.grain_scale, L.sparkle, L.sparkle_glint
  local SHADOW = L.shadow
  -- Highlight half-vector between the view (straight on) and a light
  -- 50 degrees above the page.
  local le = 0.64
  local hx, hy, hz = lx * le, ly * le, 1 + 0.77
  local hn = sqrt(hx * hx + hy * hy + hz * hz)
  hx, hy, hz = hx / hn, hy / hn, hz / hn
  -- The shadow: coverage moved away from the light, softened.
  local A = Raster.zeros(g.n)
  local sx, sy = floor(-lx * shadow_px + 0.5), floor(ly * shadow_px + 0.5)
  if shadow_px > 0 then
    for row = 1, Hh do
      local rs = row - sy
      if rs >= 1 and rs <= Hh then
        for col = 1, W do
          local cs = col - sx
          if cs >= 1 and cs <= W then A[(row - 1) * W + col] = C[(rs - 1) * W + cs] end
        end
      end
    end
    Raster.blur(g, A, 2)
  end
  local s, gx, gy = g.s, g.x0, g.y1
  -- The eye hangs over the image's centre, near enough that flat gold
  -- reflects a sweep of sky from the lit corner to the far one, as a
  -- gilded panel does when seen from a reading distance.
  local ecx, ecy = W / 2, Hh / 2
  local eye = L.eye * sqrt(W * W + Hh * Hh)
  -- Brushed grain runs across the light.
  local bc, bs = cos(light + pi / 2), sin(light + pi / 2)
  local rgb, alpha = {}, {}
  local rowbuf, abuf = {}, {}
  local um = L.umber
  for row = 1, Hh do
    local base = (row - 1) * W
    local y = gy - (row - 0.5) * s
    local nb = 0
    for col = 1, W do
      local k = base + col
      local c = C[k]
      local sh = A[k] * SHADOW * (1 - c)
      local a = c + sh
      local r, gg, b = 0, 0, 0
      if c > 0.002 then
        local x = gx + (col - 0.5) * s
        -- Grain strokes no longer than the piece is thick, so a small
        -- leaf is not smeared.
        local z = Z[k]
        local len = (z < 2.5 and 0.1 + 0.32 * z or 0.9) * GS
        local u, v = (x * bc + y * bs) / len, (-x * bs + y * bc) / (0.11 * GS)
        local tex = 0
        if M.texture then
          tex = GRAIN * (0.6 * Raster.noise(u, v, 7) + 0.4 * Raster.noise(x / (0.35 * GS), y / (0.35 * GS), 11))
        end
        -- Sparkle: a rare lattice cell flashes at its centre pixel.
        local cx, cy = floor(x / 0.3), floor(y / 0.3)
        local spark = M.texture and Raster.hash(cx, cy, 23) % 1000 < SPARK
          and floor(((cx + 0.5) * 0.3 - gx) / s) == col - 1 and floor((gy - (cy + 0.5) * 0.3) / s) == row - 1
        -- The pixel's main surface, and where it shares the pixel with a
        -- second surface (an edge between two), that one too: each is lit
        -- on its own and their colours mix.
        local wa = WA[k]
        local sxk, syk, t = SX[k], SY[k], T[k]
        for pass = 1, wa < 0.999 and 2 or 1 do
          if pass == 2 then sxk, syk, t = BX[k], BY[k], BT[k] end
          -- Slopes per px, rows running down the page.
          local nx, ny, nz = -sxk, syk, 1
          local nn = sqrt(nx * nx + ny * ny + 1)
          nx, ny, nz = nx / nn, ny / nn, nz / nn
          local vx, vy, vz = ecx - col, row - ecy, eye
          local vn = sqrt(vx * vx + vy * vy + vz * vz)
          vx, vy, vz = vx / vn, vy / vn, vz / vn
          local nv = 2 * (nx * vx + ny * vy + nz * vz)
          local rx, ry, rz = nv * nx - vx, nv * ny - vy, nv * nz - vz
          local I = env(rx, ry, rz)
          local sp = nx * hx + ny * hy + nz * hz
          if sp > CUT then
            sp = (sp - CUT) / HS
            I = I + HL * sp ^ 6
          end
          I = I + tex
          if spark and nz > 0.9 then I = I + GLINT end
          local i = floor((I < 0 and 0 or (I > 1 and 1 or I)) * 255 + 0.5)
          local g1, c1 = GL[i], CL[i]
          local w = pass == 1 and wa or 1 - wa
          r = r + (g1[1] + (c1[1] - g1[1]) * t) * w
          gg = gg + (g1[2] + (c1[2] - g1[2]) * t) * w
          b = b + (g1[3] + (c1[3] - g1[3]) * t) * w
        end
        if wa >= 0.999 and wa < 1 then r, gg, b = r / wa, gg / wa, b / wa end
        -- Composite over the shadow, unpremultiplied.
        if sh > 0 then
          local wc = c / a
          r = r * wc + um[1] * 255 * (1 - wc)
          gg = gg * wc + um[2] * 255 * (1 - wc)
          b = b * wc + um[3] * 255 * (1 - wc)
        end
      elseif sh > 0 then
        r, gg, b = um[1] * 255, um[2] * 255, um[3] * 255
      end
      rowbuf[nb + 1] = floor(r + 0.5)
      rowbuf[nb + 2] = floor(gg + 0.5)
      rowbuf[nb + 3] = floor(b + 0.5)
      nb = nb + 3
      local av = floor((a > 1 and 1 or a) * 255 + 0.5)
      abuf[col] = av
    end
    for i = 1, nb, 3000 do rgb[#rgb + 1] = char(unpack(rowbuf, i, min(nb, i + 2999))) end
    for i = 1, W, 3000 do alpha[#alpha + 1] = char(unpack(abuf, i, min(W, i + 2999))) end
  end
  return concat(rgb), concat(alpha)
end

-- Compute the pending shapes as an image: returns {x0, y0, x1, y1 (page
-- pt), w, h (px), rgb, alpha (byte strings)}, or nil when nothing is
-- pending. `look` names a look of tune.lua's gilt_looks (default
-- gilt_env) and `over` changes keys of it (gilt_look.lua); `light`, in
-- radians, overrides the look's. Exposed for tests.
function M.render(p, dpi, light, look, over)
  if not p or #p.shapes == 0 then return nil end
  look = look or Tune.gilt_env
  local L = Look.resolve(look, over)
  local s = 72.27 / dpi
  local shadow = p.shadow * L.shadow_offset
  local pad = shadow + 3 * s
  local g = Raster.grid(p.x0 - pad, p.y0 - pad, p.x1 + pad, p.y1 + pad, s)
  local R = { Relief.layers(g, p.shapes, L) }
  local rgb, alpha = shade(g, R, shadow / s, light or math.rad(L.light), L, look)
  return { x0 = g.x0, y0 = g.y1 - g.h * s, x1 = g.x0 + g.w * s, y1 = g.y1, w = g.w, h = g.h,
    rgb = rgb, alpha = alpha, coverage = R[1] }
end

-- Paint the shapes pt has collected as one image, and forget them.
function M.flush(pt)
  local p = pt.gilt_pending
  if not p then return end
  pt.gilt_pending = nil
  local im = M.render(p, M.dpi(pt), nil, pt.gilt_env, pt.gilt_look)
  if im then M.place(pt, im) end
end

local BP = 72 / 72.27

-- Under LuaTeX: the object holding every image's XObject resource entry.
-- PGF keeps no list of XObjects, so this one dictionary joins the page
-- resources of every page (as PGF's own dictionaries do) when the first
-- image is placed, and is written when the PDF is finished.
local xobjects

local function luatex_resource(name, obj)
  if not xobjects then
    xobjects = { obj = pdf.reserveobj(), entries = {} }
    pdf.setpageresources((pdf.getpageresources() or "") .. string.format(" /XObject %d 0 R", xobjects.obj))
    local x = xobjects
    luatexbase.add_to_callback("finish_pdffile", function()
      pdf.immediateobj(x.obj, "<< " .. concat(x.entries, " ") .. " >>")
    end, "flora.xobjects")
  end
  xobjects.entries[#xobjects.entries + 1] = string.format("/%s %d 0 R", name, obj)
end

-- Paint image `im` (M.render) on pt as an image XObject: RGB with a soft
-- mask for alpha, both compressed by LuaTeX.
function M.place(pt, im)
  local Paint = require("flora.paint")
  local name = Paint.register_xobject({ nil, image = im })
  if pdf and pdf.immediateobj and not Paint.standalone then
    local head = string.format("/Type /XObject /Subtype /Image /Width %d /Height %d /BitsPerComponent 8", im.w, im.h)
    local mask = pdf.immediateobj("stream", im.alpha, head .. " /ColorSpace /DeviceGray")
    local img = pdf.immediateobj("stream", im.rgb, head .. string.format(" /ColorSpace /DeviceRGB /SMask %d 0 R", mask))
    luatex_resource(name, img)
  end
  pt:emit(string.format("q %.4f 0 0 %.4f %.4f %.4f cm /%s Do Q",
    (im.x1 - im.x0) * BP, (im.y1 - im.y0) * BP, im.x0 * BP, im.y0 * BP, name))
  pt.count = pt.count + 1
end

return M
