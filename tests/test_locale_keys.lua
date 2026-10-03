---@diagnostic disable: undefined-global, lowercase-global
-- Test script: runs outside WoW with standard Lua and stubs WoW globals.
-- Every L.KEY used in the addon code must exist in both locale tables.
-- Usage: lua test_locale_keys.lua <Locale.lua> <file.lua> [<file.lua> ...]
-- Keys built at run time (CHANNEL_<NAME>, Sound.BUILTIN labelKey) are checked
-- explicitly below.
local localePath = arg[1]
local ns = {}
GetLocale = function() return "enUS" end
assert(loadfile(localePath))("x", ns)

local parts = {}
for i = 2, #arg do
  parts[#parts + 1] = io.open(arg[i], "rb"):read("a")
end
local src = table.concat(parts, "\n")

local used = {}
for key in src:gmatch("%f[%w_]L%.([A-Z_]+)") do
  used[key] = true
end
-- Dynamic keys.
for _, channel in ipairs({ "MASTER", "SFX", "DIALOG", "AMBIENCE", "MUSIC" }) do
  used["CHANNEL_" .. channel] = true
end
for key in src:gmatch('labelKey%s*=%s*"([A-Z_]+)"') do
  used[key] = true
end
-- Keys passed as strings and resolved later (TableRow, Bar, SIGNAL_TEXT).
-- Only names of real keys count; test_locale.lua checks both tables match.
for key in src:gmatch('"([A-Z][A-Z_]+)"') do
  if ns.LOCALE_TABLES.enUS[key] ~= nil then
    used[key] = true
  end
end

local missing = 0
for key in pairs(used) do
  for tag, t in pairs(ns.LOCALE_TABLES) do
    if t[key] == nil then
      print("MISSING", tag, key)
      missing = missing + 1
    end
  end
end
local unused = {}
for key in pairs(ns.LOCALE_TABLES.enUS) do
  if not used[key] then unused[#unused + 1] = key end
end
table.sort(unused)
print("unused keys: " .. (#unused > 0 and table.concat(unused, ", ") or "none"))
print(missing == 0 and "all used keys present" or ("missing: " .. missing))
os.exit((missing == 0 and #unused == 0) and 0 or 1)
