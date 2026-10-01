local ns = {}
local function load(path) local chunk = assert(loadfile(path)); chunk("isiBlightfallTracker", ns) end
GetTime = function() return 0 end
load(arg[1] .. "/Log.lua"); load(arg[1] .. "/Model.lua")
local cases = {
  {"Eine Krankheit, die sich auf alle Gegner in der Nähe ausbreitet und im Verlauf von 18 Sek. 12.610 Schattenschaden verursacht.", 12610, 18},
  {"Eine boshafte Seuche, die im Verlauf von 18 Sek. 48.168 Schattenschaden verursacht. Explodiert, fügt Gegnern in der Nähe 11.435 Schattenschaden zu und infiziert einen, wenn der Wirt stirbt. Kann nur auf 1 Wirt gleichzeitig angewandt werden.", 48168, 18},
  {"A disease that spreads to all nearby enemies and deals 12,610 Shadow damage over 18 sec.", 12610, 18},
  {"Deals 1,234,567 Shadow damage over 24 sec.", 1234567, 24},
  {"im Verlauf von 18 Sek. 1,25 Mio. Schattenschaden", 1250000, 18},
}
local fail = 0
for i, c in ipairs(cases) do
  local dmg, dur, why = ns.Model.ParsePlagueDescription(c[1])
  local ok = dmg == c[2] and dur == c[3]
  if not ok then fail = fail + 1 end
  print(ok and "PASS" or "FAIL", i, dmg, dur, why)
end
print(ns.Model.ParsePlagueDescription(nil))
os.exit(fail == 0 and 0 or 1)
