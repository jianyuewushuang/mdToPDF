-- Seeded pseudo-random streams (mulberry32).
--
-- Every drawing decision draws from a stream so a seed reproduces a page
-- exactly. `fork` derives an independent child stream from a label, which
-- keeps one element's randomness from shifting when another element changes.

local R = {}
R.__index = R

local MASK = 0xffffffff

-- FNV-1a over a string, as a 32-bit integer.
local function hash(s)
  local h = 2166136261
  for i = 1, #s do
    h = ((h ~ s:byte(i)) * 16777619) & MASK
  end
  return h
end
R.hash = hash

function R.new(seed)
  if type(seed) == "string" then
    seed = hash(seed)
  end
  seed = math.floor(seed) & MASK
  return setmetatable({ seed = seed, s = seed }, R)
end

-- Uniform float in [0, 1).
function R:next()
  self.s = (self.s + 0x6D2B79F5) & MASK
  local t = self.s
  t = ((t ~ (t >> 15)) * (t | 1)) & MASK
  t = (t ~ (t + (((t ~ (t >> 7)) * (t | 61)) & MASK))) & MASK
  return ((t ~ (t >> 14)) & MASK) / 4294967296
end

-- Uniform float in [a, b).
function R:range(a, b)
  return a + (b - a) * self:next()
end

-- Uniform integer in [a, b].
function R:int(a, b)
  return a + math.floor(self:next() * (b - a + 1))
end

-- Symmetric jitter in [-a, a).
function R:jit(a)
  return (self:next() * 2 - 1) * a
end

function R:chance(p)
  return self:next() < p
end

-- Normal deviate via Box-Muller.
function R:normal(mean, sd)
  local u = math.max(self:next(), 1e-12)
  local v = self:next()
  return (mean or 0) + (sd or 1) * math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v)
end

function R:pick(t)
  return t[self:int(1, #t)]
end

-- Pick a key from a {key = weight} table. Keys are visited in sorted order so
-- the result does not depend on table iteration order.
function R:weighted(weights)
  local keys, total = {}, 0
  for k, w in pairs(weights) do
    if w > 0 then
      keys[#keys + 1] = k
      total = total + w
    end
  end
  if total <= 0 then
    return nil
  end
  table.sort(keys)
  local x = self:next() * total
  for _, k in ipairs(keys) do
    x = x - weights[k]
    if x < 0 then
      return k
    end
  end
  return keys[#keys]
end

-- An independent copy at the current position: it yields exactly what this
-- stream would yield next.
function R:clone()
  return setmetatable({ seed = self.seed, s = self.s }, R)
end

-- Child stream whose seed depends only on this stream's seed and the label.
function R:fork(label)
  return R.new(hash(tostring(label) .. ":" .. self.seed))
end

return R
