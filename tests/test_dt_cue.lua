---@diagnostic disable: undefined-global, lowercase-global
-- Test script: runs outside WoW with standard Lua and stubs WoW globals.
-- End-to-end harness: loads Log/Model/Core with a stubbed WoW client and
-- replays a key. MODE=plain (dummy) or MODE=secret (worst-case M+).
local dir, MODE = arg[1], arg[2] or "secret"
local now = 1000
local timers = {}
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
local function S(v) if MODE == "secret" then return SECRET end return v end
-- A masked table: passes type()=="table" but raises on any access.
local masked = setmetatable({}, { __index = function() error("attempted to index a secret table") end })

issecretvalue = function(v) return v == SECRET end
GetTime = function() return now end
date = os.date
GetBuildInfo = function() return "12.1.0", "69933" end
UnitClass = function() return "Todesritter", "DEATHKNIGHT" end
UnitName = function() return "Pinto" end
GetRealmName = function() return "Malfurion" end
GetLocale = function() return "deDE" end
GetSpecialization = function() return 3 end
GetSpecializationInfo = function() return 252 end
InCombatLockdown = function() return MODE == "secret" end
GetInstanceInfo = function() return S("Grube"), S("party"), S(8), 0, 5, 0, false, S(658) end
UnitGUID = function() return "Player-1-ABC" end
UnitExists = function(u) return S(u == "nameplate1" or u == "nameplate2") end
UnitCanAttack = function() return S(true) end
UnitIsDead = function() return S(false) end
UnitAffectingCombat = function() return S(true) end
AbbreviateNumbers = function(v) return tostring(math.floor(v)) end
Enum = { AddOnRestrictionType = { Combat = 0, ChallengeMode = 2 } }
C_RestrictedActions = { GetAddOnRestrictionState = function() return S(2) end }
C_Secrets = { GetSpellAuraSecrecy = function() return 2 end, GetSpellCastSecrecy = function() return 2 end,
  ShouldAurasBeSecret = function() return true end, ShouldUnitStatsBeSecret = function() return true end }
C_ChallengeMode = { GetActiveKeystoneInfo = function() return S(12) end }
C_AddOns = { GetAddOnMetadata = function() return "test" end }
C_Timer = { After = function(d, f) table.insert(timers, { at = now + d, f = f }) end }
local tooltipMode = MODE
C_Spell = {
  GetSpellDescription = function(id)
    if tooltipMode == "secret" then return SECRET end
    if id == 191587 then return "im Verlauf von 18 Sek. 12.610 Schattenschaden verursacht." end
    return "im Verlauf von 18 Sek. 48.168 Schattenschaden verursacht. 11.435 Schattenschaden, 1 Wirt."
  end,
  GetSpellName = function(id) return S("Spell" .. id) end,
  GetOverrideSpell = function() return S(1271967) end,
  RequestLoadSpellData = function() end,
}
C_DamageMeter = { GetCombatSessionSourceFromType = function()
  if MODE == "secret" then return masked end
  return { totalAmount = 100, combatSpells = { { spellID = 191587, totalAmount = 300000 }, { spellID = 1240996, totalAmount = 600000 }, { spellID = 1241167, totalAmount = 900000 }, { spellID = 1241171, totalAmount = 1500000 } } }
end }
SlashCmdList = {}
SOUND_PLAYS = {}
PlaySoundFile = function(path, channel) table.insert(SOUND_PLAYS, path .. "@" .. channel); return true end
local before = {}; for k in pairs(_G) do before[k] = true end
print = function() end

-- Minimal frame stub that records scripts.
dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/frame_stub.lua")

local ns = {}
for _, file in ipairs({ "Locale.lua", "Log.lua", "Settings.lua", "Model.lua", "Sound.lua", "DkSupport.lua", "ActionButtonOverlay.lua", "DkAssist.lua", "Core.lua", "PlagueAuras.lua", "Options.lua" }) do
  assert(loadfile(dir .. "/" .. file))("isiBlightfallTracker", ns)
end
local display, events
for _, fr in ipairs(STUB_FRAMES) do
  if fr.scripts.OnUpdate and not display then display = fr end
  if fr.scripts.OnEvent then events = fr end
end
local leaked = {}; for k in pairs(_G) do if not before[k] and k ~= "isiBlightfallTrackerDB" and k ~= "SLASH_ISIBLIGHTFALL1" and k ~= "CreateFrame" and k ~= "UIParent" and k ~= "FONTS" and k ~= "BARS" and k ~= "STUB_FRAMES" then leaked[#leaked+1] = k end end
LEAKED = leaked

local escaped = 0
local function Fire(event, ...)
  local ok, err = pcall(events.scripts.OnEvent, events, event, ...)
  if not ok then escaped = escaped + 1; io.stderr:write("ESCAPED: " .. tostring(err) .. "\n") end
end
local function Advance(seconds)
  local target = now + seconds
  while now < target do
    now = now + 0.05
    if display.shown and display.scripts.OnUpdate then
      local ok, err = pcall(display.scripts.OnUpdate, display, 0.05)
      if not ok then escaped = escaped + 1; io.stderr:write("ESCAPED: " .. tostring(err) .. "\n") end
    end
    for i = #timers, 1, -1 do
      if timers[i].at <= now then local t = table.remove(timers, i); local ok, err = pcall(t.f); if not ok then escaped = escaped + 1; io.stderr:write("ESCAPED timer: " .. tostring(err) .. "\n") end end
    end
  end
end

local function check(cond, name) assert(cond, name); io.write("PASS " .. name .. "\n") end
isiBlightfallTrackerDB = { logEnabled = true, combatOnly = true }
Fire("PLAYER_LOGIN"); Fire("PLAYER_ENTERING_WORLD"); Fire("PLAYER_REGEN_DISABLED")
local function cast(id) Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", id) end
-- Short plagues reproduce playing badly: the early warning must stay silent.
C_Spell.GetSpellDescription = function() return "10000 damage over 5 sec" end
ns.Model.SampleTooltips(); cast(77575); cast(1233448); Advance(2.2)
check(ns.Model.Evaluate(now).signal == "now-plagues-expiring", "early plague warning is visible")
check(#SOUND_PLAYS == 0, "early plague warning cannot consume GoGo")
Advance(3)
check(ns.Model.Evaluate(now).signal == "no-plagues" and #SOUND_PLAYS == 0, "expired plagues remain silent before DT end")
Advance(6.5)
check(#SOUND_PLAYS == 0, "GoGo waits until final three DT seconds")
Advance(0.6)
check(ns.Model.Evaluate(now).signal == "now-dt-ending" and #SOUND_PLAYS == 1, "DT end wins even without plagues")
cast(1247378); Advance(0.3)
check(#SOUND_PLAYS == 1, "reapplying plagues does not repeat GoGo")
-- Extend DT after the cue, leave its final window and return to it.
for i = 1, 6 do cast(47541) end
check(ns.Model.Evaluate(now).dtLeft > 3, "extensions move DT outside its final window")
Advance(7)
check(#SOUND_PLAYS == 1, "returning to final DT window does not repeat GoGo")
cast(1271967); Advance(1)
check(#SOUND_PLAYS == 1 and not ns.Model.Evaluate(now).cueSignal, "Blightfall consumption stops further cues")
C_Spell.GetSpellDescription = function() return "10000 damage over 30 sec" end
ns.Model.SampleTooltips(); cast(77575); cast(1233448)
-- Soul Reaper is intentionally cast too early and expires during DT.
cast(343294); Advance(6)
check(#SOUND_PLAYS == 1, "early Soul Reaper expiry cannot consume GoGo")
Advance(6.2)
check(#SOUND_PLAYS == 2, "new DT phase permits exactly one new GoGo")
Advance(10)
check(#SOUND_PLAYS == 2, "remaining in NOW does not repeat GoGo")
cast(1271967)
-- Enter combat with the same NOW display that was already evaluated outside.
Fire("PLAYER_REGEN_ENABLED"); cast(1233448); cast(77575); Advance(12.2)
check(#SOUND_PLAYS == 2, "out-of-combat NOW remains silent")
Fire("PLAYER_REGEN_DISABLED"); Advance(0.3)
check(#SOUND_PLAYS == 3, "unchanged NOW at combat entry still cues the new DT phase")
cast(1271967); Advance(0.3)
check(#SOUND_PLAYS == 3, "early consumption cannot restart the phase cue")
check(next(ns.disabledSites) == nil, "no guarded handler disabled")