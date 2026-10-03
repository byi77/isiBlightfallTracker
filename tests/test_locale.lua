---@diagnostic disable: undefined-global, lowercase-global
-- Test script: runs outside WoW with standard Lua and stubs WoW globals.
local ns = {}; GetLocale = function() return "deDE" end
assert(loadfile(arg[1] .. "/Locale.lua"))("x", ns)
local en, de = ns.LOCALE_TABLES.enUS, ns.LOCALE_TABLES.deDE
local fail = 0
local function holders(s) local t = {} for h in s:gmatch("%%[%d%.]*[sdf]") do t[#t + 1] = h end return table.concat(t, ",") end
for k, v in pairs(en) do
  if not de[k] then print("missing deDE key", k); fail = fail + 1
  elseif holders(v) ~= holders(de[k]) then print("placeholder mismatch", k, holders(v), holders(de[k])); fail = fail + 1 end
end
for k in pairs(de) do if not en[k] then print("missing enUS key", k); fail = fail + 1 end end
print(fail == 0 and "locale tables consistent" or "locale FAIL"); os.exit(fail == 0 and 0 or 1)
