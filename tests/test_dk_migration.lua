local dir, stub = arg[1], arg[2]
local function check(cond, message) assert(cond, message); io.write("PASS " .. message .. "\n") end
local timers, mutes, unmutes, drivers = {}, {}, {}, {}
GetTime = function() return 1000 end
GetLocale = function() return "deDE" end
GetBuildInfo = function() return "12.1", "test" end
date = os.date
UnitClass = function() return "Death Knight", "DEATHKNIGHT" end
UnitName = function() return "test" end
GetRealmName = function() return "test" end
GetSpecialization = function() return 3 end
GetSpecializationInfo = function() return 252 end
UnitExists = function(unit) return unit == "player" end
UnitCanAttack = function() return false end
UnitIsDead = function() return false end
UnitAffectingCombat = function() return false end
UnitGUID = function() return "Player-test" end
InCombatLockdown = function() return false end
GetInstanceInfo = function() return "world", "none", 0 end
issecretvalue = function() return false end
C_Spell = {
  GetSpellDescription = function() return "10000 damage over 18 sec" end,
  GetSpellCooldown = function() return { startTime = 1000, duration = 45, isEnabled = true } end,
  GetSpellCharges = function() return { currentCharges = 1 } end,
}
C_Timer = { NewTimer = function(delay, callback)
  local t = { delay = delay, callback = callback, Cancel = function(self) self.canceled = true end }
  timers[#timers + 1] = t; return t
end, After = function() end }
MuteSoundFile = function(id) mutes[#mutes + 1] = id end
UnmuteSoundFile = function(id) unmutes[#unmutes + 1] = id end
RegisterStateDriver = function(frame, state, driver) drivers[#drivers + 1] = { frame, state, driver } end
UnregisterStateDriver = function() end
SlashCmdList = {}
IsiLiveDB = {
  vipDkSoulReaperWarningEnabled = true, vipDkPutrefyWarningEnabled = true,
  vipDkApocalypseHorseSoundMuted = true, vipDkGhoulReminderEnabled = true,
  vipDkGhoulReminderPosition = { point = "TOP", relativePoint = "TOP", x = 12, y = -80 },
}
isiBlightfallTrackerDB = { vipDkPutrefyWarningEnabled = false }
dofile(stub)
local ns = {}
for line in io.lines(dir .. "/isiBlightfallTracker.toc") do
  local file = line:match("^([%w_]+%.lua)%s*$")
  if file then assert(loadfile(dir .. "/" .. file))("isiBlightfallTracker", ns) end
end
local events
for _, frame in ipairs(STUB_FRAMES) do if frame.scripts.OnEvent then events = frame end end
events.scripts.OnEvent(events, "PLAYER_LOGIN")
local db = isiBlightfallTrackerDB
check(db.dkSettingsImported == true and db.vipDkSoulReaperWarningEnabled == true, "login imports existing Soul Reaper choice")
check(db.vipDkPutrefyWarningEnabled == false, "import preserves an explicit tracker choice")
check(db.vipDkGhoulReminderEnabled == true and db.vipDkApocalypseHorseSoundMuted == true, "login imports ghoul and horse choices")
check(db.vipDkGhoulReminderPosition.x == 12 and db.vipDkGhoulReminderPosition ~= IsiLiveDB.vipDkGhoulReminderPosition, "ghoul position is copied independently")
check(#drivers == 1 and drivers[1][3] == "[spec:3,nopet,nomounted,novehicleui] show; hide", "tracker configures the established ghoul state driver")
check(#mutes == 3 and mutes[1] == 987917 and mutes[3] == 987921, "tracker mutes the three established horse sounds")
events.scripts.OnEvent(events, "UNIT_SPELLCAST_SUCCEEDED", "player", nil, 1233448)
check(#timers == 2 and timers[1].delay == 38 and timers[2].delay == 7, "tracker routes DT casts to both Soul Reaper hold timers")
ns.Settings.Set("vipDkApocalypseHorseSoundMuted", false); ns.DkAssist.RefreshSettings()
check(#unmutes == 3, "tracker setting immediately unmutes its horse sounds")
IsiLiveDB.vipDkSoulReaperWarningEnabled = false
ns.DkAssist.Initialize()
check(db.vipDkSoulReaperWarningEnabled == true, "legacy settings cannot overwrite the tracker after import")
ns.DkAssist.HandleEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
for _, timer in ipairs(timers) do check(timer.canceled == true, "spec refresh invalidates pending warning timers") end
check(next(ns.disabledSites) == nil, "integrated migration triggers no disabled handler")

-- Masked cooldown and charge structs never enter comparisons or arithmetic.
local secret = {}
issecretvalue = function(value) return value == secret end
C_Spell.GetSpellCooldown = function() return secret end
C_Spell.GetSpellCharges = function() return { currentCharges = secret } end
local controller = ns.DkAssist.CreateController({
  isLocalUnholyDeathKnight = function() return true end,
  getDB = function() return { vipDkSoulReaperWarningEnabled = true, vipDkPutrefyWarningEnabled = true } end,
  scanSoulReaperButtons = function() return {} end, scanPutrefyButtons = function() return {} end,
})
local before = #timers
controller.HandleUnitSpellcastSucceeded("player", nil, 1233448)
check(#timers == before + 3 and timers[before + 1].delay == 38 and timers[before + 3].delay == 30, "secret reads retain the documented timing fallback safely")
local button = { GetSpellId = function() return secret end, GetAttribute = function() return secret end }
check(ns.ActionButtonOverlay.GetActionSpellID(button) == nil, "secret button spell and action IDs fail closed")
