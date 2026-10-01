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
print = function() end

-- Minimal frame stub that records scripts.
dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/frame_stub.lua")

local ns = {}
for _, file in ipairs({ "Locale.lua", "Log.lua", "Model.lua", "Core.lua" }) do
  assert(loadfile(dir .. "/" .. file))("isiBlightfallTracker", ns)
end
local display, events
for _, fr in ipairs(STUB_FRAMES) do
  if fr.scripts.OnUpdate and not display then display = fr end
  if fr.scripts.OnEvent then events = fr end
end

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

isiBlightfallTrackerDB = { logEnabled = true } -- the log is opt-in; these simulations read it
Fire("PLAYER_LOGIN"); Fire("PLAYER_ENTERING_WORLD"); ns.Model.Evaluate = function() error("injected render fault") end; local realClass = UnitClass; UnitClass = function() error("injected event fault") end; for i = 1, 8 do Fire("PLAYER_SPECIALIZATION_CHANGED") end; UnitClass = realClass
Fire("CHALLENGE_MODE_START", S(658))
for pull = 1, 3 do
  Fire("PLAYER_REGEN_DISABLED"); Fire("ADDON_RESTRICTION_STATE_CHANGED", S(0), S(1))
  local casts = { 77575, 1233448, 55090, 47541, 343294, 433895, 1247378, 207317, 85948 }
  for _, id in ipairs(casts) do Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", id); Advance(1.3) end
  Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", SECRET)
  Fire("ENCOUNTER_START", S(1), S("Boss"), S(8), S(5))
  Advance(12); Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 1271967); Advance(1)
  Fire("PLAYER_REGEN_ENABLED"); Advance(15)
end
Fire("CHALLENGE_MODE_COMPLETED")
SlashCmdList.ISIBLIGHTFALL("test"); SlashCmdList.ISIBLIGHTFALL("")

local db = isiBlightfallTrackerDB
local session = db.sessions[#db.sessions]
local errors, kinds = {}, {}
for _, e in ipairs(session.entries) do
  kinds[e.e] = (kinds[e.e] or 0) + 1
  if e.e == "error" then errors[#errors + 1] = tostring(e.where) .. ": " .. tostring(e.message) end
  for k, v in pairs(e) do if v == SECRET then errors[#errors + 1] = "secret stored in log field " .. k end end
end
local list = {}
for k, v in pairs(kinds) do list[#list + 1] = k .. "=" .. v end
table.sort(list)
print = _G.print
io.write(("[%s] entries=%d escaped=%d loggedErrors=%d  %s\n"):format(MODE, #session.entries, escaped, #errors, table.concat(list, " ")))
for _, e in ipairs(errors) do io.write("  " .. e .. "\n") end
local signal = display and "" or ""
local stopped = 0
for _, e in ipairs(session.entries) do
  if e.e == "error" and e.message == "site disabled after repeated errors" then stopped = stopped + 1; io.write("  disabled: " .. e.where .. "\n") end
end
io.write(("fault-test: escaped=%d loggedErrors=%d disabledSites=%d display=%s\n"):format(escaped, #errors, stopped, tostring(display.scripts.OnUpdate == nil and "stopped" or "running")))
os.exit((escaped == 0 and stopped == 2 and display.scripts.OnUpdate == nil) and 0 or 1)
