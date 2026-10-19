---@diagnostic disable: undefined-global, lowercase-global
-- Test script: runs outside WoW with standard Lua and stubs WoW globals.
-- Talent gate: the tracker stays off on an Unholy build without Blightfall,
-- follows talent changes, fails open when the loadout is unreadable and is
-- switched on by a Blightfall cast even if the loadout check says "no".
local dir, stub = arg[1], arg[2]

local talented = true -- Blightfall node purchased
local loadoutReadable = true

issecretvalue = function() return false end
GetTime = function() return 1000 end
date = os.date
GetBuildInfo = function() return "12.1.5", "70000" end
UnitClass = function() return "x", "DEATHKNIGHT" end
UnitName = function() return "Pinto" end
GetRealmName = function() return "Malfurion" end
GetLocale = function() return "enUS" end
GetSpecialization = function() return 3 end
GetSpecializationInfo = function() return 252 end
GetInstanceInfo = function() return "World", "none", 0, 0, 0, 0, false, 0 end
InCombatLockdown = function() return false end
UnitGUID = function() return "Player-1" end
UnitExists = function() return false end
C_Timer = { After = function() end }
-- The talent's own spell ID (4711) differs from the button spell; the names match.
local NAMES = { [1271967] = "Blightfall", [4711] = "Blightfall", [55090] = "Scourge Strike" }
C_Spell = {
  GetSpellDescription = function() return "over 18 sec. 10,000 Shadow damage." end,
  GetSpellName = function(id) return NAMES[id] end,
}
-- The spellbook never reports the override spell as known.
C_SpellBook = { IsSpellKnown = function() return false end }
C_ClassTalents = { GetActiveConfigID = function() return loadoutReadable and 7 or nil end }
C_Traits = {
  GetConfigInfo = function() return { treeIDs = { 1 } } end,
  GetTreeNodes = function() return { 10, 20 } end,
  GetNodeInfo = function(_, nodeID)
    local rank = (nodeID == 20 and not talented) and 0 or 1
    return { activeRank = rank, activeEntry = { entryID = nodeID } }
  end,
  GetEntryInfo = function(_, entryID) return { definitionID = entryID } end,
  GetDefinitionInfo = function(definitionID) return { spellID = definitionID == 20 and 4711 or 55090 } end,
}
SlashCmdList = {}
local printed = {}
print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end
dofile(stub)
local ns = {}
for _, file in ipairs({ "Locale.lua", "Log.lua", "Settings.lua", "Model.lua", "Sound.lua", "DkSupport.lua", "ActionButtonOverlay.lua", "DkAssist.lua", "Core.lua", "PlagueAuras.lua", "Options.lua" }) do
  assert(loadfile(dir .. "/" .. file))("isiBlightfallTracker", ns)
end
local display, events = STUB_WINDOW(), nil
for _, fr in ipairs(STUB_FRAMES) do
  if fr.scripts.OnEvent then events = fr end
end
local function Fire(event, ...) events.scripts.OnEvent(events, event, ...) end

local fail = 0
local function check(cond, msg) io.write((cond and "PASS " or "FAIL ") .. msg .. "\n"); if not cond then fail = fail + 1 end end

check(ns.Model.HasBlightfallTalent() == true, "talent found by name although its spell ID differs")
talented = false
check(ns.Model.HasBlightfallTalent() == false, "untalented loadout reports false")
loadoutReadable = false
check(ns.Model.HasBlightfallTalent() == nil, "unreadable loadout reports unknown")
loadoutReadable = true

talented = false
Fire("PLAYER_LOGIN")
Fire("PLAYER_ENTERING_WORLD")
check(not display.shown, "no window on an Unholy build without Blightfall")
printed = {}
SlashCmdList.ISIBLIGHTFALL("")
check(printed[#printed] and printed[#printed]:find(ns.L.INACTIVE_NO_TALENT, 1, true) ~= nil, "/ibt says why the tracker is off")

talented = true
Fire("TRAIT_CONFIG_UPDATED", 7)
check(display.shown, "talenting Blightfall switches the tracker on")
talented = false
Fire("PLAYER_TALENT_UPDATE")
check(not display.shown, "removing Blightfall switches the tracker off")

loadoutReadable = false
Fire("TRAIT_CONFIG_UPDATED", 7)
check(display.shown, "unreadable loadout fails open")
loadoutReadable = true
Fire("TRAIT_CONFIG_UPDATED", 7)
check(not display.shown, "readable untalented loadout switches off again")

Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 1271967)
check(display.shown, "a Blightfall cast switches the tracker on despite the loadout check")
Fire("PLAYER_REGEN_DISABLED")
Fire("PLAYER_REGEN_ENABLED")
check(display.shown, "the cast proof holds across combat")
Fire("TRAIT_CONFIG_UPDATED", 7)
check(not display.shown, "a talent change clears the cast proof")

if fail > 0 then os.exit(1) end
