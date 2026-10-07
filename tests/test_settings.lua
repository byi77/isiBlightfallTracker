---@diagnostic disable: undefined-global, lowercase-global
-- Test script: runs outside WoW with standard Lua and stubs WoW globals.
-- Settings: log opt-in (/ibt log on|off) and combat-only window
-- (/ibt combat on|off), driven through the real slash command and events.
local dir, stub = arg[1], arg[2]

local function Boot(savedDB)
  isiBlightfallTrackerDB = savedDB
  issecretvalue = function() return false end
  GetTime = function() return 1000 end
  date = os.date
  GetBuildInfo = function() return "12.1.0", "69933" end
  UnitClass = function() return "x", "DEATHKNIGHT" end
  UnitName = function() return "Pinto" end
  GetRealmName = function() return "Malfurion" end
  GetLocale = function() return "deDE" end
  GetSpecialization = function() return 3 end
  GetSpecializationInfo = function() return 252 end
  GetInstanceInfo = function() return "Welt", "none", 0, 0, 0, 0, false, 0 end
  InCombatLockdown = function() return false end
  UnitGUID = function() return "Player-1" end
  UnitExists = function() return false end
  C_Timer = { After = function() end }
  C_Spell = { GetSpellDescription = function() return "im Verlauf von 18 Sek. 10.000 Schattenschaden." end }
  SlashCmdList = {}
  print = function() end
  dofile(stub)
  local ns = {}
  for _, file in ipairs({ "Locale.lua", "Log.lua", "Settings.lua", "Model.lua", "Sound.lua", "Core.lua", "PlagueAuras.lua", "Options.lua" }) do
    assert(loadfile(dir .. "/" .. file))("isiBlightfallTracker", ns)
  end
  local display, events
  for _, fr in ipairs(STUB_FRAMES) do
    if fr.scripts.OnUpdate and not display then display = fr end
    if fr.scripts.OnEvent then events = fr end
  end
  local function Fire(event, ...) events.scripts.OnEvent(events, event, ...) end
  Fire("PLAYER_LOGIN")
  Fire("PLAYER_ENTERING_WORLD")
  return ns, display, Fire
end

local fail = 0
local function check(cond, msg) print = _G.realPrint or print; io.write((cond and "PASS " or "FAIL ") .. msg .. "\n"); if not cond then fail = fail + 1 end end

-- Fresh install: log off, window always visible.
local ns, display, Fire = Boot(nil)
local db = isiBlightfallTrackerDB
check(db ~= nil and db.logEnabled == nil, "settings table exists, log flag unset on a fresh install")
check(not ns.Log.IsEnabled() and #db.sessions == 0, "log is off by default: no session recorded")
check(display.shown, "window visible by default")

SlashCmdList.ISIBLIGHTFALL("log on")
check(ns.Log.IsEnabled() and #db.sessions == 1, "/ibt log on starts a session")
local entries = ns.Log.Count()
check(entries > 0, "log on records entries (self-test)")
SlashCmdList.ISIBLIGHTFALL("log off")
check(not ns.Log.IsEnabled() and db.logEnabled == false, "/ibt log off stops recording")
local before = #db.sessions[1].entries
Fire("PLAYER_REGEN_DISABLED")
Fire("PLAYER_REGEN_ENABLED")
check(#db.sessions[1].entries == before, "nothing is written while the log is off")

SlashCmdList.ISIBLIGHTFALL("combat on")
check(db.combatOnly == true and not display.shown, "/ibt combat on hides the window out of combat")
Fire("PLAYER_REGEN_DISABLED")
check(display.shown, "combat-only window appears when combat starts")
Fire("PLAYER_REGEN_ENABLED")
check(not display.shown, "combat-only window hides when combat ends")
SlashCmdList.ISIBLIGHTFALL("combat aus")
check(db.combatOnly == false and display.shown, "/ibt combat aus (German alias) shows it again")

-- Ready-only window: shown from Dark Transformation until Blightfall.
SlashCmdList.ISIBLIGHTFALL("ready on")
check(db.readyOnly == true and not display.shown, "/ibt ready on hides the window while Blightfall is not ready")
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 1233448) -- Dark Transformation
check(display.shown, "Dark Transformation shows the ready-only window")
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 47541) -- Death Coil
check(display.shown, "other casts keep it visible while Blightfall is ready")
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-3", 1271967) -- Blightfall
check(not display.shown, "casting Blightfall hides the ready-only window")
SlashCmdList.ISIBLIGHTFALL("combat on")
Fire("PLAYER_REGEN_DISABLED")
check(not display.shown, "combat-only + ready-only: hidden in combat until Blightfall is ready")
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-4", 1233448)
check(display.shown, "combat-only + ready-only: shown in combat once ready")
Fire("PLAYER_REGEN_ENABLED")
check(not display.shown, "combat-only + ready-only: hidden out of combat even while ready")
SlashCmdList.ISIBLIGHTFALL("combat off")
check(display.shown, "ready-only alone: Blightfall still ready, window visible out of combat")
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-5", 1271967)
SlashCmdList.ISIBLIGHTFALL("bereit aus") -- German alias
check(db.readyOnly == false and display.shown, "/ibt bereit aus shows the window again")

-- Settings survive a reload.
db.readyOnly = true
local ns3, display3 = Boot(db)
check(not display3.shown and ns3.Settings.Get("readyOnly") == true, "ready-only setting persists after reload")
db.readyOnly = false
db.combatOnly = true
db.logEnabled = true
local ns2, display2 = Boot(db)
check(ns2.Log.IsEnabled() and #isiBlightfallTrackerDB.sessions == 2, "log setting persists: new session after reload")
check(not display2.shown, "combat-only setting persists after reload")

os.exit(fail == 0 and 0 or 1)
