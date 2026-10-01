-- Every L.KEY used in Core.lua must exist in both locale tables.
local localePath, corePath = arg[1], arg[2]
local ns = {}
GetLocale = function() return "enUS" end
assert(loadfile(localePath))("x", ns)
local src = io.open(corePath, "rb"):read("a")
local missing, seen = 0, {}
for key in src:gmatch("%f[%w_]L%.([A-Z_]+)") do
  if not seen[key] then
    seen[key] = true
    for tag, t in pairs(ns.LOCALE_TABLES) do
      if t[key] == nil then
        print("MISSING", tag, key)
        missing = missing + 1
      end
    end
  end
end
local unused = {}
for key in pairs(ns.LOCALE_TABLES.enUS) do
  if not seen[key] then unused[#unused + 1] = key end
end
table.sort(unused)
print("unused keys: " .. (#unused > 0 and table.concat(unused, ", ") or "none"))
print(missing == 0 and "all used keys present" or ("missing: " .. missing))
os.exit(missing == 0 and 0 or 1)
