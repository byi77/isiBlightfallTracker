---@diagnostic disable: undefined-global, lowercase-global
-- Test script: runs outside WoW with standard Lua and stubs WoW globals.
-- Settings: log opt-in (/ibt log on|off) and combat-only window
-- (/ibt combat on|off), driven through the real slash command and events.
local dir, stub = arg[1], arg[2]

local function Boot(savedDB, lockdown)
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
  InCombatLockdown = function() return lockdown == true end
  UnitGUID = function() return "Player-1" end
  UnitExists = function() return false end
  C_Timer = { After = function() end }
  C_Spell = { GetSpellDescription = function() return "im Verlauf von 18 Sek. 10.000 Schattenschaden." end }
  SlashCmdList = {}
  print = function() end
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
SlashCmdList.ISIBLIGHTFALL("  Log   OFF ")
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

-- A damaged saved file must not break the login.
local ns6, display6 = Boot("garbage")
check(type(isiBlightfallTrackerDB) == "table" and display6.shown and ns6.Settings.Get("scale") == 1.0,
  "non-table SavedVariables are replaced, login completes")
local ns7 = Boot({ sessions = 5, logEnabled = true })
check(type(isiBlightfallTrackerDB.sessions) == "table" and ns7.Log.Count() > 0, "non-table session list is replaced, log works")
isiBlightfallTrackerDB = db

-- The model keeps running while an option hides the window (a hidden frame
-- gets no OnUpdate in the client).
local function Driver()
  for _, fr in ipairs(STUB_FRAMES) do
    if fr.scripts.OnUpdate then return fr end
  end
end
db.combatOnly = false
db.readyOnly = true
local ns4, display4, Fire4 = Boot(db)
Fire4("PLAYER_REGEN_DISABLED")
Fire4("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-6", 77575) -- Outbreak
local driver = Driver()
check(driver ~= display4 and not display4.shown, "ready-only window hidden, model on its own frame")
if driver.shown then driver.scripts.OnUpdate(driver, 1) end
check(ns4.Model.calibration.vpUptime > 0, "calibration keeps integrating while the window is hidden")
Fire4("PLAYER_REGEN_ENABLED")

-- /reload in combat: combat state restored at login, the partial fight is
-- not learned from.
db.readyOnly = false
db.combatOnly = true
local ns5, display5, Fire5 = Boot(db, true)
check(display5.shown, "/reload in combat: combat-only window visible right away")
C_Timer = { After = function(_, fn) fn() end }
C_DamageMeter = { GetCombatSessionSourceFromType = function()
  return { totalAmount = 1, combatSpells = { { spellID = 191587, totalAmount = 900000 }, { spellID = 1240996, totalAmount = 900000 } } }
end }
Fire5("PLAYER_REGEN_ENABLED")
check(not display5.shown, "combat-only window hides when that combat ends")
local skipped
for _, e in ipairs(isiBlightfallTrackerDB.sessions[#isiBlightfallTrackerDB.sessions].entries) do
  if e.e == "calibration" then skipped = e.skipped end
end
check(skipped == "partial-combat" and ns5.Model.factors.samples == 0, "partial combat is not used for calibration")

-- Chain pull: the next combat starts before the post-combat meter read.
local pending = {}
C_Timer = { After = function(_, fn) pending[#pending + 1] = fn end }
Fire5("PLAYER_REGEN_DISABLED")
Fire5("PLAYER_REGEN_ENABLED")
Fire5("PLAYER_REGEN_DISABLED")
for _, fn in ipairs(pending) do fn() end
local entries5 = isiBlightfallTrackerDB.sessions[#isiBlightfallTrackerDB.sessions].entries
local dmStatus
for _, e in ipairs(entries5) do
  if e.e == "dm" then dmStatus = e.status end
end
check(dmStatus == "superseded", "meter read for an old combat is dropped once a new one started")
Fire5("PLAYER_REGEN_ENABLED")
C_Timer = { After = function() end }
C_DamageMeter = nil


-- Voice cue: once per Blightfall window, also when the plagues ran out and
-- were re-applied in between.
local plays = 0
PlaySoundFile = function() plays = plays + 1; return true end
local clock = 2000
db.combatOnly, db.readyOnly = false, false
local ns8, _, Fire8 = Boot(db)
GetTime = function() return clock end
local driver8
for _, fr in ipairs(STUB_FRAMES) do if fr.scripts.OnUpdate then driver8 = fr end end
local function Run(seconds)
  local stop = clock + seconds
  while clock < stop do clock = clock + 0.1; driver8.scripts.OnUpdate(driver8, 0.1) end
end
Fire8("PLAYER_REGEN_DISABLED")
Fire8("UNIT_SPELLCAST_SUCCEEDED", "player", "c1", 77575) -- Outbreak
Fire8("UNIT_SPELLCAST_SUCCEEDED", "player", "c2", 1233448) -- Dark Transformation
Run(14)
check(plays == 1, "cue plays once when the signal turns to NOW")
Run(6)
local expired = ns8.Model.Evaluate(clock)
check(expired.remVP == 0 and expired.remDP == 0, "plagues ran out")
check(expired.signal == "now-dt-ending", "DT-end warning keeps priority after the plagues ran out")
Fire8("UNIT_SPELLCAST_SUCCEEDED", "player", "c3", 77575) -- Outbreak again
Run(1)
check(plays == 1, "no second cue in the same window after re-applying the plagues")
Fire8("UNIT_SPELLCAST_SUCCEEDED", "player", "c4", 1271967) -- Blightfall
Fire8("UNIT_SPELLCAST_SUCCEEDED", "player", "c5", 77575) -- Outbreak
Fire8("UNIT_SPELLCAST_SUCCEEDED", "player", "c5", 1233448) -- new Dark Transformation
Run(14)
check(plays == 2, "a new Dark Transformation window cues again")
Fire8("PLAYER_REGEN_ENABLED")
os.exit(fail == 0 and 0 or 1)
