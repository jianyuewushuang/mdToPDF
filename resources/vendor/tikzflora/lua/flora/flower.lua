-- Flowers: parametric petals, frontal blooms, tilted blooms and tiny florets.

local G = require("flora.geom")
local W = require("flora.wash")
local Paint = require("flora.paint")
local Color = require("flora.color")
local Tune = require("flora.tune")
local Mix = require("flora.mix")
local pal = Paint.palette

local F = {}
local sin, cos, pi = math.sin, math.cos, math.pi

-- Petal silhouettes. Half-width at fraction t of the length is
--   W * sin(pi * t^k)^e * smoothstep(0, claw, t)^0.7
-- so k moves the widest point toward the tip and e < 1 rounds the tip.
F.kinds = {
  obovate = { k = 0.72, e = 0.60, claw = 0.46, notch = 0.10, wave = 0.11, freq = 5 },
  lance   = { k = 1.15, e = 1.30, claw = 0.10, notch = 0.00, wave = 0.05, freq = 3 },
  round   = { k = 0.95, e = 0.50, claw = 0.20, notch = 0.05, wave = 0.07, freq = 3 },
  ghost   = { k = 0.85, e = 0.60, claw = 0.20, notch = 0.06, wave = 0.14, freq = 4 },
  -- The reference's flower: widest close to a broad, rounded end.
  fan     = { k = 0.56, e = 0.42, claw = 0.50, notch = 0.04, wave = 0.16, freq = 6 },
  -- Wedge: a narrow claw at the eye whose sides curve out (concave, then
  -- convex; `rise` > 1 pinches the claw) to the shoulder at `shoulder` of
  -- the length, then a broad rounded end with a wavy, slightly scalloped
  -- rim (the reference's hero petals).
  wedge   = { wedge = true, shoulder = 0.74, base = 0.06, rise = 1.3, notch = 0.03, wave = 0.12,
              scallop = 0.035, freq = 6 },
}

-- Half-width at fraction t of the length, as a fraction of the petal's
-- maximum half-width.
local function profile(K, t)
  if K.wedge then
    if t <= K.shoulder then
      return K.base + (1 - K.base) * sin(pi / 2 * t / K.shoulder) ^ K.rise
    end
    local u = (t - K.shoulder) / (1 - K.shoulder)
    return math.sqrt(math.max(0, 1 - u * u))
  end
  return sin(pi * t ^ K.k) ^ K.e * G.smoothstep(0, K.claw, t) ^ 0.7
end

-- Petal outline in local coordinates: base at the origin, tip toward +y.
-- `wave` (optional) overrides the kind's rim waviness. With `slot`, the
-- half-width at distance d from the base never exceeds slot * d, so petals
-- radiating from one eye with slot = tan(pi / n) * (1 - gap) keep a gap of
-- at least `gap` of their sector between them.
function F.petal(rng, kind, L, Wd, bend, wave, slot)
  local K = F.kinds[kind]
  local n = 26
  local nl, nr = G.fbm(rng, 32), G.fbm(rng, 32)
  local al, ar = 1 + rng:jit(0.12), 1 + rng:jit(0.12)
  if slot then
    -- Shrink the whole petal until its (wobbled) outline fits the sector,
    -- so its curves survive; the clamp below only catches what is left.
    local fit = 1
    for i = 4, 20 do
      local t = i / 20
      local need = Wd * profile(K, t) * math.max(al, ar) * (1 + (wave or K.wave) * t ^ 1.5)
      fit = math.min(fit, slot * L * t * (1 - (K.notch or 0)) / math.max(need, 1e-9))
    end
    Wd = Wd * fit
  end
  local left, right = {}, {}
  for i = 0, n do
    local t = i / n
    local w = Wd * profile(K, t)
    local y = L * t - K.notch * L * math.exp(-((1 - t) / 0.045) ^ 2)
    local wobble = (wave or K.wave) * t ^ 1.5
    local bx = (bend or 0) * L * t * t
    local wl, wr = w * al * (1 + wobble * nl(t * K.freq * 3)), w * ar * (1 + wobble * nr(t * K.freq * 3))
    local yl, yr = y, y
    if K.scallop and t > K.shoulder then
      -- The rounded end ripples along its length as well as across it.
      local s = G.smoothstep(K.shoulder, 1, t) * K.scallop * L
      yl, yr = y + s * nl(7 + t * K.freq * 2), y + s * nr(7 + t * K.freq * 2)
    end
    if slot then
      local cap = slot * math.max(0, math.min(yl, yr))
      -- Both edges stay within +-cap of the petal's axis, wherever the bend puts the centre.
      wl, wr = math.min(wl, cap + bx), math.min(wr, cap - bx)
      wl, wr = math.max(wl, 0), math.max(wr, 0)
    end
    left[#left + 1] = { bx - wl, yl }
    right[#right + 1] = { bx + wr, yr }
  end
  local out = {}
  for i = 1, #left do out[#out + 1] = left[i] end
  for i = #right - 1, 2, -1 do out[#out + 1] = right[i] end
  return out
end

-- The eye of a bloom of radius R: a soft, uneven white glow, a faint rose
-- flush, stamens and a small pistil.
--   o.halo     radius of the white glow, as a share of R
--   o.stamens  how many stamens
-- The glow is a stack of deformed blots, so it has no ring edges. Stamens
-- leave at uneven angles on slightly curved, tapering filaments of mixed
-- length, each tipped with a small anther drawn along its filament in a
-- warm tone that varies from stamen to stamen. Loose pollen dots sit near
-- the pistil, which is a rose-brown disc with a darker rim and a highlight.
local ROSE = { 0.72, 0.36, 0.40 }
-- n points on a circle of radius r around c.
local function circle(c, r, n)
  local pts = {}
  for k = 0, n - 1 do
    local t = k * 2 * pi / n
    pts[#pts + 1] = { c[1] + r * cos(t), c[2] + r * sin(t) }
  end
  return pts
end
function F.eye(pt, rng, cx, cy, R, o)
  o = o or {}
  local c = { cx, cy }
  local halo = o.halo or 0.36
  local glow = {}
  for k = 1, 6 do
    local r = R * halo * (1 - (k - 1) / 7)
    glow[#glow + 1] = G.smooth(G.deform(circle(G.polar(c, rng:range(0, 2 * pi), R * 0.012), r, 18), rng, r * 0.12), true)
  end
  for _, b in ipairs(glow) do pt:fill(b, pal.white, 0.18) end
  -- The flush deepens toward the pistil through faint stacked blots.
  for k = 1, 4 do
    local r = R * (0.14 - 0.022 * k)
    pt:fill(G.smooth(G.deform(circle(c, r, 16), rng, r * 0.2), true), ROSE, 0.08, { blend = "multiply" })
  end

  local m = o.stamens or 14
  local fil, anthers, warm, pollen = {}, {}, {}, {}
  local a0 = rng:range(0, 2 * pi)
  for i = 1, m do
    local a = a0 + (i - 1 + rng:jit(0.35)) * 2 * pi / m
    local len = R * rng:range(0.10, 0.21)
    local p0 = G.polar(c, a, R * 0.035)
    local line = G.curve(p0, a + rng:jit(0.12), len, rng:jit(0.6), 0, 6)
    fil[#fil + 1] = line
    local tip, ta = line[#line], G.angle(line[#line - 1], line[#line])
    local ar = R * rng:range(0.007, 0.011)
    local anther = G.transform(circle({ 0, 0 }, 1, 10), 0, 0, 0, ar * 1.5, ar)
    anthers[#anthers + 1] = G.transform(anther, tip[1], tip[2], ta)
    warm[#anthers] = rng:range(0, 1)
  end
  for _ = 1, math.floor(m * 0.6) do
    local q = G.polar(c, rng:range(0, 2 * pi), R * rng:range(0.05, 0.13))
    pollen[#pollen + 1] = { { "o", q[1], q[2], R * rng:range(0.004, 0.008) } }
  end
  -- Filaments are fine and faint: the stamens read by their tips.
  W.hairlines(pt, fil, pal.ink, math.max(0.12, R * 0.0035), 0.32, { head = 0.3, blend = "multiply" })
  -- Anthers in two warm tones: copper and a rosier brown.
  local a1, a2 = {}, {}
  for i, a in ipairs(anthers) do
    local path = G.smooth(a, true)
    if warm[i] < 0.6 then a1[#a1 + 1] = path else a2[#a2 + 1] = path end
  end
  if #a1 > 0 then pt:fill(a1, pal.copper, 0.85, { many = true }) end
  if #a2 > 0 then pt:fill(a2, ROSE, 0.8, { many = true }) end
  if #pollen > 0 then pt:fill(pollen, pal.copper, 0.55, { many = true }) end
  local disc = G.smooth(G.deform(circle(c, R * 0.032, 12), rng, R * 0.005), true)
  pt:fill(disc, { 0.55, 0.26, 0.22 }, 0.95)
  pt:stroke(disc, pal.ink, math.max(0.12, R * 0.004), 0.45)
  pt:fill({ { "o", cx - R * 0.009, cy + R * 0.009, R * 0.010 } }, pal.white, 0.35)
end

-- Wash settings by look. `strength` scales pigment load.
local LOOKS = {
  vivid = { ramp = "vivid", pigment = pal.blue, pool = pal.deep, strength = 1.15, rings = 12, lift = 0.05, streaks = 40, dark = 22, grain = 0.9, outline = 0.55 },
  fan   = { ramp = "fan", pigment = pal.blue, pool = pal.deep, strength = 1.15, rings = 12, lift = 0.05, streaks = 40, dark = 16, grain = 2.0, outline = 0.5 },
  hero  = { ramp = "hero", pigment = pal.blue, pool = pal.deep, strength = 1.15, rings = 12, lift = 0.05, streaks = 40, dark = 22, grain = 2.0, outline = 0.55 },
  soft  = { ramp = "soft", pigment = pal.sky, pool = pal.deep, strength = 0.95, rings = 10, lift = 0.07, streaks = 22, dark = 12, grain = 0.6, outline = 0.70 },
  ghost = { ramp = "ghost", pigment = pal.mist, pool = pal.sky, strength = 0.45, rings = 8, lift = 0.12, streaks = 8, dark = 3, grain = 0.15, outline = 0.45, knockout = 0.35 },
}

-- The petal's tip: the outline point farthest from the flower's eye.
local function tip_of(poly, eye)
  local best, bd = poly[1], -1
  for _, p in ipairs(poly) do
    local d = G.dist(p, eye)
    if d > bd then best, bd = p, d end
  end
  return best
end

local function wash_petal(pt, rng, poly, L, light, look, lost, extra)
  extra = extra or {}
  W.wash(pt, poly, {
    ramp = look.ramp, axis = { light, tip_of(poly, light) },
    rng = rng, size = L, light = light,
    pigment = look.pigment, pool = look.pool, strength = look.strength,
    rings = look.rings, lift = look.lift, bleed = math.min(L * 0.02, 1.6),
    streaks = math.floor(look.streaks * G.clamp(L / 40, 0.35, 1.4)),
    dark_streaks = extra.veins or look.dark, grain = look.grain, rays = extra.rays,
    outline = look.outline, outline_w = math.max(0.25, L * 0.009),
    knockout = look.knockout, lost = lost,
    eye_fade = extra.eye_fade, lifts = extra.lifts,
  })
end

-- Bloom styles (tune.blooms): each names a petal kind and a colour look
-- and carries its own ranges, so blooms of one style still differ.
local STYLE = {
  fan = { kind = "fan", look = "fan" },
  round = { kind = "round", look = "vivid" },
  soft = { kind = "round", look = "soft" },
  obovate = { kind = "obovate", look = "vivid" },
  wedge = { kind = "wedge", look = "vivid" },
}
F.styles = STYLE

-- One of `names` (bloom styles), picked by their tune.blooms weights
-- times the page's mix weight for the style (mix.lua).
function F.pick_style(rng, names)
  local w = {}
  for _, n in ipairs(names) do w[n] = math.max(0, Tune.blooms[n].weight) * Mix.factor(n) end
  local total = 0
  for _, v in pairs(w) do total = total + v end
  if total <= 0 then return names[1] end
  return rng:weighted(w)
end

-- The half-width limit per unit of length (F.petal's `slot`) for n petals
-- that may each turn up to `spacing` radians toward a neighbour: petals
-- fill what is left of their sector after the turn, less `gap` of it, so
-- neighbours stay apart however the jitter falls.
function F.slot(n, gap, spacing)
  return math.tan(math.max(0.05, pi / n - spacing)) * (1 - gap)
end

-- A frontal bloom of radius R centred at (cx, cy).
--   o.style     a bloom style (tune.blooms); sets the petal kind, look,
--               count, width, rim, rays and veins, each drawn per bloom
--   o.kind (petal kind), o.petals, o.rot, o.look ("vivid"|"soft"|"ghost"),
--   o.width (petal width as a fraction of R) override the style; o.lost
--   (share of each petal's outline lost; default tune.wash.lost_edges)
function F.bloom(pt, rng, cx, cy, R, o)
  o = o or {}
  local st = o.style and Tune.blooms[o.style]
  local base = o.style and STYLE[o.style] or {}
  local function pick(range) return rng:range(range[1], range[2]) end
  local n = o.petals or (st and rng:int(st.petals[1], st.petals[2])) or 5
  local width = o.width or (st and pick(st.width)) or 0.34
  local kind = o.kind or base.kind or "obovate"
  local look_name = o.look or base.look or "vivid"
  local look = LOOKS[look_name]
  local ragged = st and st.ragged or 0.08
  local spacing = st and st.spacing or 0.12
  local extra = {}
  if st then
    extra.eye_fade, extra.lifts = st.eye_fade, st.backruns
    extra.veins = math.floor(pick(st.veins) + 0.5)
    local rays = math.floor(pick(st.rays) + 0.5)
    if rays > 0 then
      extra.rays = { count = rays, reach = st.ray_reach, contrast = st.ray_contrast }
    end
  end
  local a0 = o.rot or rng:range(0, 2 * pi)
  -- A style with a gap keeps each petal inside its own sector of the eye.
  local slot = st and st.gap and F.slot(n, st.gap, spacing)
  local petals = {}
  for i = 1, n do
    local r = rng:fork("petal" .. i)
    petals[i] = { r = r, a = a0 + (i - 1) * 2 * pi / n + r:jit(spacing) }
  end
  -- A tilted bloom paints its far (upper) petals first, so the near ones
  -- overlap them.
  if o.far_first then
    table.sort(petals, function(p, q) return sin(p.a) > sin(q.a) end)
  end
  for _, pe in ipairs(petals) do
    local r, a = pe.r, pe.a
    local L = R * r:range(1 - ragged * 1.5, 1 + ragged * 0.5)
    local Wd = R * width * r:range(0.92, 1.08)
    local local_pts = F.petal(r, kind, L, Wd, r:jit(slot and 0.04 or 0.10), st and st.rim, slot)
    local poly = G.transform(local_pts, cx, cy, a - pi / 2)
    wash_petal(pt, r, poly, L, { cx, cy }, look, o.lost, extra)
  end
  -- Fan blooms keep a small white eye; their rays carry the light out.
  local halo = look_name == "ghost" and 0.25 or ((kind == "fan" or kind == "wedge") and 0.2 or 0.36)
  F.eye(pt, rng:fork("eye"), cx, cy, R, { halo = halo,
    stamens = look_name == "ghost" and 8 or 14 })
end

-- A bloom seen at an angle. Petals live in a cupped 3D plane tilted by
-- `tilt` and turned to face `facing`; they are painted back to front.
--   o.kind, o.petals, o.cup (depth of the cup), o.look
-- A calyx tube hangs below the cup. Returns the point where a stem attaches.
function F.tilted(pt, rng, cx, cy, R, facing, tilt, o)
  o = o or {}
  local n = o.petals or 5
  local look = LOOKS[o.look or "vivid"]
  -- The calyx and sepals take the bloom's ink when it is not a blue.
  local calyx = Color.recolor(pal.deep, Color.part_ink(Color.part_of(look.ramp)))
  local cup = o.cup or 0.6
  local ct, st = cos(tilt), sin(tilt)
  local cf, sf = cos(facing - pi / 2), sin(facing - pi / 2)
  local function project(x, y, z)
    z = z or cup * (x * x + y * y) / R
    local y2, z2 = y * ct - z * st, y * st + z * ct
    return { cx + x * cf - y2 * sf, cy + x * sf + y2 * cf }, z2
  end

  -- Calyx: a tapered tube below the cup with small sepals at its mouth.
  local tube = {}
  for i = 0, 8 do
    tube[#tube + 1] = (project(0, 0, -R * 0.42 * i / 8))
  end
  local stem_at = tube[#tube]
  pt:fill(G.smooth(G.ribbon(G.spline_points({ tube[#tube], tube[5], tube[1] }, 4), function(t)
    return R * (0.035 + 0.07 * t ^ 1.5)
  end), true), calyx, 0.92, { blend = "multiply" })
  local sepals = {}
  for k = 1, 3 do
    local b = rng:range(0, 2 * pi)
    local p0 = project(0, 0, -R * 0.05)
    local p1 = project(R * 0.28 * cos(b), R * 0.28 * sin(b), -R * 0.2)
    sepals[#sepals + 1] = { p0[1], p0[2], G.angle(p0, p1), G.dist(p0, p1) * 1.1 + R * 0.08 }
  end
  require("flora.leaf").leaflets(pt, rng:fork("sepals"), sepals, calyx, 0.9)
  local a0 = o.rot or rng:range(0, 2 * pi)
  local petals = {}
  for i = 1, n do
    local r = rng:fork("tp" .. i)
    local a = a0 + (i - 1) * 2 * pi / n + r:jit(0.15)
    local L = R * r:range(0.85, 1.05)
    local Wd = R * (o.width or 0.34) * r:range(0.92, 1.08)
    local pts = G.transform(F.petal(r, o.kind or "lance", L, Wd, r:jit(0.15)), 0, 0, a - pi / 2)
    local poly, zsum = {}, 0
    for j, p in ipairs(pts) do
      local q, z = project(p[1], p[2])
      poly[j] = q
      zsum = zsum + z
    end
    petals[#petals + 1] = { poly = poly, z = zsum / #pts, L = L, r = r }
  end
  table.sort(petals, function(a, b) return a.z < b.z end)
  for _, p in ipairs(petals) do
    wash_petal(pt, p.r, p.poly, p.L, { cx, cy }, look)
  end
  local eye = project(0, 0)
  F.eye(pt, rng:fork("eye"), eye[1], eye[2], R * 0.7, { halo = 0.3, stamens = 9 })
  return stem_at
end

-- Tiny five-petal florets, batched by tint. Each item is {x, y, r, rot, tint}
-- with tint 1 (deep), 2 (blue) or 3 (sky). Florets large enough to read get
-- an ink contour, as in an inked-and-washed drawing.
-- Items {x, y, r, rot, tint, soft}: tint 1-3 is deep, blue or sky. Soft
-- florets (baby's breath) are translucent, sit in a pale halo that blurs
-- their edge, and keep only a faint white eye, so a cloud of them reads as
-- airy rather than as dark specks.
function F.florets(pt, items)
  local tints = { {}, {}, {} }
  local soft = { {}, {}, {} }
  local eyes, specks, rims, halos, soft_eyes = {}, {}, {}, {}, {}
  for _, f in ipairs(items) do
    local x, y, r, rot = f[1], f[2], f[3], f[4] or 0
    local bucket = (f[6] and soft or tints)[f[5] or 2]
    if f[6] then halos[#halos + 1] = { { "o", x, y, 1.05 * r } } end
    for i = 0, 4 do
      local a = rot + i * 2 * pi / 5
      local petal = { { "o", x + 0.55 * r * cos(a), y + 0.55 * r * sin(a), 0.47 * r } }
      bucket[#bucket + 1] = petal
      if r > 1.1 and not f[6] then rims[#rims + 1] = petal end
    end
    if f[6] then
      if r > 1.1 then soft_eyes[#soft_eyes + 1] = { { "o", x, y, 0.22 * r } } end
    elseif r > 0.9 then
      eyes[#eyes + 1] = { { "o", x, y, 0.28 * r } }
      specks[#specks + 1] = { { "o", x, y, 0.12 * r } }
    end
  end
  -- palette.sprays repaints the florets in its ink at the same depths.
  local tint = Color.part_ink("sprays")
  local deep, blue, sky = Color.recolor(pal.deep, tint), Color.recolor(pal.blue, tint), Color.recolor(pal.sky, tint)
  local cols = { deep, blue, sky }
  if #halos > 0 then pt:fill(halos, sky, 0.14, { many = true, blend = "multiply" }) end
  for i = 1, 3 do
    if #tints[i] > 0 then
      pt:fill(tints[i], cols[i], 0.88, { many = true, blend = "multiply" })
    end
    if #soft[i] > 0 then
      pt:fill(soft[i], cols[i], 0.55, { many = true, blend = "multiply" })
    end
  end
  if #soft_eyes > 0 then pt:fill(soft_eyes, pal.white, 0.6, { many = true }) end
  if #rims > 0 then pt:stroke(rims, Paint.mix(Color.recolor(pal.ink, tint), blue, 0.5), 0.14, 0.45, { many = true, blend = "multiply" }) end
  if #eyes > 0 then pt:fill(eyes, pal.white, 0.85, { many = true }) end
  if #specks > 0 then pt:fill(specks, pal.copper, 0.85, { many = true }) end
end

-- A closed teardrop bud pointing along `ang`.
function F.bud(pt, x, y, ang, len, rgb)
  local pts = {}
  for i = 0, 16 do
    local t = i / 16
    local w = len * 0.32 * sin(pi * t ^ 0.7) ^ 0.9
    pts[#pts + 1] = { -w, len * t }
  end
  for i = 15, 1, -1 do
    local t = i / 16
    local w = len * 0.32 * sin(pi * t ^ 0.7) ^ 0.9
    pts[#pts + 1] = { w, len * t }
  end
  local poly = G.transform(pts, x, y, ang - pi / 2)
  pt:fill(G.smooth(poly, true), rgb or pal.deep, 0.9, { blend = "multiply" })
end

-- A bloom of radius R at (cx, cy) seen tilted back by `deg` degrees. The
-- bloom is a shallow cup (its rim rises CUP of R toward the viewer at the
-- petal tips) turned back about its horizontal axis and seen in
-- perspective from VIEW radii away: the far petals stand up behind the eye
-- and shrink, the near ones lean forward, grow and foreshorten. Returns the
-- projection fn(x, y) -> x, y for P:project, and the half-height of the
-- projected rim.
local CUP, VIEW = 0.08, 2.8
function F.tilt(cx, cy, R, deg)
  local t = math.rad(deg or 0)
  local ct, st = cos(t), sin(t)
  local D = VIEW * R
  local function fn(x, y)
    local dx, dy = x - cx, y - cy
    local z = CUP * math.min(dx * dx + dy * dy, 1.6 * R * R) / R
    local sy, depth = dy * ct + z * st, z * ct - dy * st
    local s = D / (D - depth)
    return cx + dx * s, cy + sy * s
  end
  local rh = 0
  for k = 0, 15 do
    local _, y = fn(cx + R * cos(k * pi / 8), cy + R * sin(k * pi / 8))
    rh = math.max(rh, math.abs(y - cy))
  end
  return fn, rh
end

-- Paint the hero bloom at hero = {x, y, R}, tilted by tune.hero.tilt.
function F.hero(pt, rng, hero)
  local hc = Tune.hero
  -- At tilt 0 the bloom is painted as is, with no projection at all.
  local fn = hc.tilt > 0 and F.tilt(hero[1], hero[2], hero[3], hc.tilt) or nil
  pt:project(fn)
  F.bloom(pt, rng, hero[1], hero[2], hero[3], {
    style = hc.style, look = "hero", petals = hc.petals, width = hc.petal_width,
    rot = hc.rotation >= 0 and math.rad(hc.rotation) or nil, lost = hc.lost_edges,
    far_first = hc.tilt > 0,
  })
  pt:project(nil)
end

return F
