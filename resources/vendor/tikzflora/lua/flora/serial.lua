-- Writes plain data (numbers, strings, booleans, nested tables) as a Lua
-- table constructor that `load` reads back. Keys are sorted, so equal data
-- always serializes to equal text.

local S = {}

function S.encode(v)
  local t = type(v)
  if t == "number" then return string.format("%.17g", v) end
  if t == "string" then return string.format("%q", v) end
  if t == "boolean" then return tostring(v) end
  assert(t == "table", "cannot serialize a " .. t)
  local out = {}
  for i = 1, #v do out[#out + 1] = S.encode(v[i]) end
  local keys = {}
  for k in pairs(v) do
    if not (math.type(k) == "integer" and k >= 1 and k <= #v) then keys[#keys + 1] = k end
  end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(keys) do
    local key = type(k) == "string" and k:match("^[%a_][%w_]*$") and k or "[" .. S.encode(k) .. "]"
    out[#out + 1] = key .. " = " .. S.encode(v[k])
  end
  return "{" .. table.concat(out, ", ") .. "}"
end

function S.decode(s)
  return assert(load("return " .. s, "data", "t", {}))()
end

return S
