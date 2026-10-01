-- Unit test for ReadEruptsLive with four damage-meter shapes, using the real
-- addon files and the widget stub.
local dir, stub = arg[1], arg[2]
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
local SECRET_STR = {}
setmetatable(SECRET_STR, {
  __concat = function() return SECRET_STR end, -- secret strings concatenate to a secret string
})
issecretvalue = function(v) return v == SECRET or v == SECRET_STR end
GetTime = function() return 1000 end
date = os.date
GetBuildInfo = function() return "12.1.0", "69933" end
UnitClass = function() return "x", "DEATHKNIGHT" end
UnitName = function() return "Pinto" end
GetRealmName = function() return "Malfurion" end
GetLocale = function() return "deDE" end
GetSpecialization = function() return 3 end
GetSpecializationInfo = function() return 252 end
UnitGUID = function() return "Player-1" end
C_Timer = { After = function() end }
SlashCmdList = {}
AbbreviateNumbers = function(v)
  if v == SECRET then return SECRET_STR end
  return tostring(v)
end
dofile(stub)
local ns = {}
for _, file in ipairs({ "Locale.lua", "Log.lua", "Model.lua", "Core.lua" }) do
  assert(loadfile(dir .. "/" .. file))("isiBlightfallTracker", ns)
end

local function DM(spells)
  C_DamageMeter = { GetCombatSessionSourceFromType = function() return spells end }
end
local fail = 0
local function check(cond, msg) print((cond and "PASS " or "FAIL ") .. msg); if not cond then fail = fail + 1 end end

DM({ combatSpells = { { spellID = 1241167, totalAmount = 800000 }, { spellID = 1241171, totalAmount = 1200000 }, { spellID = 55090, totalAmount = 5 } } })
local text, status = ns.ReadEruptsLive()
check(status == "plain" and text == "~2.00M", "plain amounts are summed (" .. tostring(text) .. ")")

DM({ combatSpells = { { spellID = 1241167, totalAmount = SECRET }, { spellID = 1241171, totalAmount = SECRET } } })
text, status = ns.ReadEruptsLive()
check(status == "secret-passthrough" and text == SECRET_STR, "secret amounts pass through as a secret string")

DM({ combatSpells = { { spellID = SECRET, totalAmount = SECRET } } })
text, status = ns.ReadEruptsLive()
check(status == "ids-secret" and text == nil, "secret spell IDs: nothing shown")

DM(setmetatable({}, { __index = function() error("attempted to index a secret table") end }))
text, status = ns.ReadEruptsLive()
check(status == "spells-secret" and text == nil, "masked source table: nothing shown, no error")

C_DamageMeter = nil
text, status = ns.ReadEruptsLive()
check(status == "no-api", "no damage meter API")
os.exit(fail == 0 and 0 or 1)
