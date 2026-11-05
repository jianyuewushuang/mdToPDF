-- The border as one plant. It is rooted at the right end of the foot; the
-- main stem runs left along the foot, turns the corner on a wide arc,
-- climbs the margin along the line of action (layout.gesture) and ends
-- under the hero bloom. Everything else grows off it: long shoots leave the
-- main stem low, climb with it, crossing it as they go, and end in a curl;
-- shorter shoots carry each bloom, umbel and leaf. No shoot ends bare. Stems are grown by
-- steering (geom.pursue), so their curvature builds and relaxes smoothly,
-- and they thin at every fork: a parent keeps the share of its section
-- that its child does not take (the pipe model, w^2 = w1^2 + w2^2).

local G = require("flora.geom")
local Tune = require("flora.tune")

local P = {}
local pi = math.pi

-- Push point q right of rectangle `box` ({x0, y0, x1, y1}), fully from
-- 12 pt before the box to 12 pt after it and easing over `ease` pt (60 by
-- default) beyond, so a stem steering along the pushed guide bends around
-- the box instead of cutting into it. Wider swings need a longer ease.
local function clear_of(box, q, gap, ease)
  if not box then return q end
  ease = ease or 60
  local push = G.smoothstep(box[2] - 12 - ease, box[2] - 12, q[2]) * (1 - G.smoothstep(box[4] + 12, box[4] + 12 + ease, q[2]))
  local need = box[3] + gap - q[1]
  if need <= 0 or push <= 0 then return q end
  return { q[1] + need * push, q[2] }
end

-- A stem: its points, cumulative lengths, and width from w0 at its base to
-- w1 at its tip before forks take their share.
function P.stem(pts, w0, w1)
  local cum, total = { 0 }, 0
  for i = 2, #pts do
    total = total + G.dist(pts[i - 1], pts[i])
    cum[i] = total
  end
  return { pts = pts, cum = cum, len = math.max(total, 1e-9), w0 = w0, w1 = w1, forks = {} }
end

-- Full width of stem `st` at arc length s, after the forks below s.
function P.width_at(st, s)
  local t = G.clamp(s / st.len, 0, 1)
  local w = st.w0 + (st.w1 - st.w0) * t
  for _, f in ipairs(st.forks) do
    -- Each fork narrows the parent over a few points rather than in a step.
    local u = G.smoothstep(f.s - 2, f.s + 6, s)
    w = w * (1 - u + u * f.keep)
  end
  return math.max(w, st.min or 0.35)
end

-- The width function stem_by expects: full width at fraction t.
function P.width_fn(st)
  return function(t) return P.width_at(st, t * st.len) end
end

-- Record a child of full width `cw` leaving `st` at fraction t; returns
-- the parent's width there. The parent keeps sqrt(1 - (cw/w)^2) of its
-- width beyond the fork, at least `floor` of it.
function P.fork(st, t, cw, floor)
  local s = t * st.len
  local w = P.width_at(st, s)
  local r = G.clamp(cw / w, 0, 0.95)
  st.forks[#st.forks + 1] = { s = s, keep = math.max(floor or 0.82, math.sqrt(1 - r * r)) }
  return w
end

-- Point and heading of `st` at arc length s.
function P.at(st, s)
  s = G.clamp(s, 0, st.len)
  local pts, cum = st.pts, st.cum
  local i = 2
  while i < #pts and cum[i] < s do i = i + 1 end
  local a, b = pts[i - 1], pts[i]
  local u = (s - cum[i - 1]) / math.max(1e-9, cum[i] - cum[i - 1])
  return G.mix(a, b, u), G.angle(a, b), i
end

-- Wrap target function `follow` so a stem steers clear of rectangle `box`.
-- A stem cannot reverse a bend at once, so it looks ahead: when its heading
-- would carry it into the box within 100 pt (about the distance it needs
-- to move aside under its bend limits), it steers for a point clear of the
-- box's inner side instead.
local function avoiding(follow, box)
  if not box then return follow end
  return function(q, s, a)
    local t = follow(q, s, a)
    if not t then return nil end
    for _, d in ipairs({ 15, 35, 60, 100 }) do
      local f = G.polar(q, a, d)
      if f[1] < box[3] + 6 and f[2] > box[2] - 6 and f[2] < box[4] + 6 then
        return { box[3] + 16, f[2] + 10 }
      end
    end
    return t
  end
end

-- The main stem's guide: the foot run from the root, the corner arc, then
-- the line of action up to the hero bloom's cap. The stem is steered along
-- it rather than through it, so the guide's corners never show.
local function guide(rng, m, hero, W, gest, cfg, avoid)
  local mw = m.x1 - m.x0
  local R = mw * 0.32
  local footy = m.y0 + 6
  local xr = gest.edge
  local rise_y = footy + R
  local pts = {}
  local period = rng:range(120, 170)
  if m.bare then
    -- No foot: the stem rises from the root on its line, or from the
    -- frame's outer edge when it is gathered there.
    rise_y = footy
    pts[1] = { m.gather and 0 or xr, footy }
  else
    local x = W * cfg.root
    while x > xr + R + 12 do
      local ramp = G.smoothstep(xr + R, xr + R + 60, x)
      pts[#pts + 1] = { x, footy + 4 * ramp * math.sin(1 + 2 * pi * x / period) }
      x = x - 20
    end
    for i = 0, 10 do
      local th = -pi / 2 - (pi / 2) * i / 10
      pts[#pts + 1] = { xr + R + R * math.cos(th), rise_y + R * math.sin(th) }
    end
  end
  local sway_len = rng:range(300, 400)
  local amp = mw * rng:range(0.015, 0.03)
  local cap = { hero[1] - hero[3] * 0.1, hero[2] - hero[3] * 0.15 }
  local pull_from = cap[2] - math.max(hero[3] * 2.4, 90)
  local y = rise_y + 16
  while y < cap[2] - 12 do
    local ramp = G.smoothstep(rise_y, rise_y + 80, y)
    local sway = math.sin(2 * pi * (y - rise_y) / sway_len)
    local gx = xr + ramp * (amp * sway + gest.bow(y, 0))
    gx = gx + (cap[1] - gx) * G.smoothstep(pull_from, cap[2], y)
    if m.gather then gx = gx * G.smoothstep(rise_y - m.gather * 0.2, rise_y + m.gather, y) end
    pts[#pts + 1] = clear_of(avoid, { gx, y }, 9)
    y = y + 12
  end
  pts[#pts + 1] = cap
  return pts, { xr, rise_y }, cap
end

-- Grow the main stem, around rectangle `avoid` if given. Returns the
-- stem, the corner point (where the rise begins) and the cap under the
-- hero.
function P.main(rng, m, hero, W, gest, avoid)
  local cfg = Tune.plant
  local gpts, corner, cap = guide(rng, m, hero, W, gest, cfg, avoid)
  local kmax = 1 / cfg.bend_radius
  local target_at = avoiding(G.follow(gpts, cfg.lookahead, 14), avoid)
  local pts = G.pursue(gpts[1], G.angle(gpts[1], gpts[2]), target_at, {
    len = G.length(gpts) * 1.3, kmax = kmax, dk = kmax / cfg.bend_ease, step = 2,
  })
  -- The last stretch arrives at the cap heading for the bloom's centre, so
  -- the stem meets the hero from below whatever its heading was.
  local tail = pts[#pts]
  local a = G.angle(pts[#pts - 1], tail)
  local link = G.link(tail, a, cap, G.angle(cap, { hero[1], hero[2] }), 0.45)
  for i = 2, #link do pts[#pts + 1] = link[i] end
  local st = P.stem(pts, cfg.root_width, cfg.root_width * 0.8)
  st.main, st.min = true, cfg.tip_width
  return st, corner, cap
end

-- The hero's crown: two shoots that leave the main stem well below the
-- hero, cross over it, and climb the opposite side, ending under the rim
-- of its petals. Crossing each other and the main stem, they weave the
-- intertwined stems the reference shows under its hero; leaves and sprays
-- spill out around the hero from them (blooms paint over foliage). Each
-- shoot's tip (st.tip) is left for compose.lua to finish.
function P.crown(rng, main, m, hero)
  local cfg = Tune.plant
  local R = hero[3]
  local s0 = main.len
  for s = main.len, 0, -2 do
    if P.at(main, s)[2] < hero[2] - R * 1.5 then s0 = s break end
  end
  local out = {}
  for k, side in ipairs({ -1, 1 }) do
    local r = rng:fork("crown" .. k)
    local s = math.max(0, s0 - r:range(0, R * 0.9))
    local p0, a0 = P.at(main, s)
    -- The tip sits under the petals' rim, low on the hero's flank.
    local ta = (side < 0 and pi or 0) - side * r:range(0.15, 0.55)
    local to = G.polar(hero, ta, R * r:range(0.85, 0.95))
    to[1] = G.clamp(to[1], m.x0 + 4, m.x1 - 4)
    -- Leave toward the far side, so the shoot crosses the main stem, and
    -- arrive heading up and out, so the last control point sits below and
    -- outside the rim and the curve keeps off the bloom's heart.
    local pts = G.link(p0, a0 - side * 0.55, to, pi / 2 - side * 0.5, 0.6)
    local clear = true
    for _, q in ipairs(pts) do
      if G.dist(q, hero) < R * 0.7 then clear = false break end
    end
    if clear and #pts >= 6 then
      local w = P.fork(main, s / main.len, cfg.root_width * cfg.fork_ratio * 0.6, 0.75)
      local st = P.stem(pts, w * 0.7, 0.35)
      st.min = 0.3
      st.kind = "crown"
      st.tip = { pts[#pts], G.angle(pts[#pts - 1], pts[#pts]) }
      out[#out + 1] = st
    end
  end
  return out
end

-- Long shoots: each leaves the main stem low, runs with it while weaving
-- across it on a slow wave, then over its last third veers off into the
-- roomier side of the margin. Its tip (st.tip: point and heading) is left
-- for compose.lua to finish with a leaf or a spray.
-- They follow the main stem's own path, offset along its normal. They swing
-- widest within the gesture's bows and stay close in the quiet stretches,
-- which keep room for the cartouche.
function P.long_shoots(rng, main, m, hero, gest, avoid)
  local cfg = Tune.plant
  local mw = m.x1 - m.x0
  local out = {}
  local bow_max = 1e-9
  for _, b in ipairs(gest.bows) do bow_max = math.max(bow_max, b.amp) end
  -- The rise: from where the main stem leaves the foot to just below the
  -- hero. The run along the foot is excluded, so shoot ends are spread up
  -- the margin rather than bunched low.
  local rise0 = main.len
  for s = 0, main.len, 4 do
    if P.at(main, s)[2] > m.y0 + mw * 0.5 then rise0 = s break end
  end
  local rise1 = main.len
  for s = main.len, 0, -4 do
    if P.at(main, s)[2] < hero[2] - hero[3] * 0.7 then rise1 = s break end
  end
  local span = math.max(1, rise1 - rise0)
  local n = cfg.long_shoots
  for k = 1, n do
    local r = rng:fork("long" .. k)
    -- Leave within plant.shoot_start of the rise; end at heights spread
    -- evenly over plant.shoot_end of it.
    local ss, se = cfg.shoot_start, cfg.shoot_end
    local s0 = math.max(main.len * 0.15, rise0 + span * r:range(ss[1], ss[2]))
    local f = G.clamp((k - 0.5 + r:jit(0.3)) / n + 0.5 / n, 0, 1)
    -- At least 60 pt of shoot, and never past the top of the rise.
    local s1 = math.min(rise1, math.max(s0 + 60, rise0 + span * (se[1] + (se[2] - se[1]) * f)))
    local A = mw * r:range(cfg.shoot_reach[1], cfg.shoot_reach[2])
    local wave = r:range(cfg.shoot_wave[1], cfg.shoot_wave[2])
    local side = (k % 2 == 0) and 1 or -1
    local ph = r:range(0, 0.5)
    -- The veer goes toward whichever side of the main stem has more room
    -- where it begins; +1 is the stem's left (the outer edge on the rise).
    local pv = P.at(main, s0 + (s1 - s0) * 0.65)
    local veer = (pv[1] - m.x0 > m.x1 - pv[1]) and 1 or -1
    local gpts = {}
    for s = s0 + 6, s1, 8 do
      local p, a = P.at(main, s)
      local u = s - s0
      local env = 0.5 + 0.5 * G.clamp(gest.bow(p[2], 0) / bow_max, 0, 1)
      local off = side * A * env * G.smoothstep(0, 50, u) * math.sin(2 * pi * (ph + u / wave))
      off = off + veer * A * 1.4 * G.smoothstep(0.65, 1, u / (s1 - s0))
      -- Offsets are horizontal, scaled by how upright the main stem runs:
      -- shifting a wide swing along the stem's normal would fold the guide
      -- into loops on the inside of the main stem's bows. Along the foot the
      -- shoot runs with the main stem.
      local upright = G.smoothstep(0.3, 0.7, math.abs(math.sin(a)))
      local dx = (math.cos(a + pi / 2) >= 0 and 1 or -1) * off * upright
      local q = clear_of(avoid, { p[1] + dx, p[2] }, 6, 150)
      gpts[#gpts + 1] = { G.clamp(q[1], m.x0 + 6, m.x1 - 6), q[2] }
    end
    if #gpts >= 4 then
      local p0, a0 = P.at(main, s0)
      local kmax = 1 / (cfg.bend_radius * 0.6)
      -- A short lookahead, tied to the wave, so steering follows the swing
      -- instead of cutting across it.
      local ahead = math.min(cfg.lookahead * 0.7, wave * 0.12)
      local pts, a = G.pursue(p0, a0 + side * 0.08, avoiding(G.follow(gpts, ahead, 10), avoid), {
        len = (s1 - s0) * 1.3, kmax = kmax, dk = kmax / (cfg.bend_ease * 0.7), step = 2,
        -- Steering may overshoot its guide; the shoot stops at the margin.
        stop = function(q) return q[1] > m.x1 - 3 or q[1] < m.x0 + 2 end,
      })
      if #pts >= 6 then
        local w = P.fork(main, s0 / main.len, cfg.root_width * cfg.fork_ratio, 0.75)
        local st = P.stem(pts, w * cfg.fork_ratio, 0.35)
        st.min = 0.3
        st.kind = "long"
        st.tip = { pts[#pts], a }
        out[#out + 1] = st
      end
    end
  end
  return out
end

-- Foot shoots: along the foot and around the corner the main stem puts
-- out shoots that sweep up and back toward the corner, roughly parallel,
-- so the corner fans out the way the reference's does. Each leaves
-- tangentially and arcs up into the space between the foot and the text,
-- stopping where it would meet the text block; its tip (st.tip) is left
-- for a leaf or a spray.
function P.foot_shoots(rng, main, m, corner, avoid)
  local cfg = Tune.plant
  local out = {}
  -- The interior the shoots turn toward: up and in from the corner.
  local inside = { corner[1] + (m.x1 - m.x0) * 0.6, corner[2] + 60 }
  local s_end = main.len * 0.3
  for k = 1, cfg.foot_shoots do
    local r = rng:fork("foot" .. k)
    local s0 = s_end * (k - 0.6 + r:jit(0.25)) / cfg.foot_shoots
    local p0, a0 = P.at(main, s0)
    local nx, ny = math.cos(a0 + pi / 2), math.sin(a0 + pi / 2)
    local sign = (nx * (inside[1] - p0[1]) + ny * (inside[2] - p0[2]) >= 0) and 1 or -1
    local len = r:range(cfg.foot_reach[1], cfg.foot_reach[2])
    -- Swept back along the main stem's growth, up toward the corner.
    local target = G.polar(p0, a0 + sign * r:range(0.55, 0.95), len)
    local kmax = 1 / Tune.plant.shoot_bend
    local pts, a = G.pursue(p0, a0 + sign * 0.1, function(q)
      if G.dist(q, target) < 4 then return nil end
      return target
    end, {
      len = len * 1.6, kmax = kmax, dk = kmax / 20, step = 1.5,
      stop = function(q)
        return (q[1] > m.x1 - 4 and q[2] > m.foot - 8) or q[1] < m.x0 + 3 or q[2] < m.y0 - 2
          or (avoid and q[1] <= avoid[3] + 2 and q[2] >= avoid[2] - 2 and q[2] <= avoid[4] + 2)
      end,
    })
    if #pts >= 8 then
      local w = P.fork(main, s0 / main.len, 1.0, 0.9)
      local st = P.stem(pts, math.min(1.1, w * 0.4), 0.3)
      st.min = 0.3
      st.kind = "foot"
      st.tip = { pts[#pts], a }
      out[#out + 1] = st
    end
  end
  return out
end

-- A shoot from stem point `p` (stem heading `along`) to `target`, leaving
-- tangentially and steering in; it stops `stop_r` short of the target.
-- Returns nil if it cannot get there within its curvature limits.
function P.shoot(p, along, target, stop_r)
  local kmax = 1 / Tune.plant.shoot_bend
  local d = G.dist(p, target)
  local pts = G.pursue(p, G.depart(p, along, target, 0.12), function(q)
    if G.dist(q, target) < stop_r then return nil end
    return target
  end, { len = d * 2.5 + 30, kmax = kmax, dk = kmax / 12, step = 1.5 })
  if #pts < 3 or G.dist(pts[#pts], target) > stop_r + 3 then return nil end
  return pts
end

return P
