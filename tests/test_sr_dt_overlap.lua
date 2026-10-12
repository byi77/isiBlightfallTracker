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
isiBlightfallTrackerDB = { logEnabled = true }
Fire("PLAYER_LOGIN"); Fire("PLAYER_ENTERING_WORLD"); Fire("PLAYER_REGEN_DISABLED")
local function cast(id) Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", id) end
C_Spell.GetSpellDescription = function() return "10000 damage over 30 sec" end
IsPlayerSpell = function() return true end
ns.Model.SampleTooltips(); ns.Model.RefreshTalents()
cast(77575); cast(1233448); Advance(6.8); cast(343294); Advance(5.5)
local r=ns.Model.Evaluate(now)
check(r.signal == "now-soul-reaper" and r.cueSignal == r.signal, "overlapping SR and DT share the same displayed and spoken reason")
check(#SOUND_PLAYS == 1, "overlapping windows produce one cue")
Advance(5)
check(#SOUND_PLAYS == 1, "DT expiry after SR cue cannot produce a second cue")
local sounds={}
for _,e in ipairs(isiBlightfallTrackerDB.sessions[1].entries) do if e.e=="sound" then sounds[#sounds+1]=e.signal end end
check(#sounds == 1 and sounds[1] == "now-soul-reaper", "cue log identifies the eligible Soul Reaper trigger")
cast(1271967); cast(77575); cast(1233448); Advance(6.8); cast(343294)
for i=1,5 do cast(47541) end
Advance(5.5)
r=ns.Model.Evaluate(now)
check(r.dtLeft > 3 and r.soulReaperLeft < 3 and not r.cueSignal and r.signal == "charging", "extended DT prevents an early SR cue")
Advance(5)
r=ns.Model.Evaluate(now)
check(#SOUND_PLAYS == 2 and r.signal == "now-dt-ending", "expired SR falls back to DT ending with one new cue")
Advance(5); check(#SOUND_PLAYS == 2, "DT fallback remains once per phase")
cast(1271967); Fire("PLAYER_REGEN_ENABLED")
cast(77575); cast(1233448); Advance(6.8); cast(343294); Advance(5.5)
check(ns.Model.Evaluate(now).cueSignal == "now-soul-reaper" and #SOUND_PLAYS == 2, "out-of-combat overlap remains silent")
for i=1,5 do cast(47541) end
Fire("PLAYER_REGEN_DISABLED"); Advance(0.3)
check(ns.Model.Evaluate(now).dtLeft > 3 and not ns.Model.Evaluate(now).cueSignal and #SOUND_PLAYS == 2, "latched SR cannot bypass DT guard after a later extension")
Advance(5); check(#SOUND_PLAYS == 3, "extended phase still announces exactly once at DT ending")
check(next(ns.disabledSites) == nil and escaped == 0, "no handler errors")