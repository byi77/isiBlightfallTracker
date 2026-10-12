local _, ns = ...

-- Standalone adapters for the DK helpers migrated from isiLive. No calls
-- into isiLive are needed after the one-time settings import.
local function PlainField(object, key)
  if ns.IsSecret(object) or type(object) ~= "table" then
    return nil
  end
  local ok, value = pcall(function()
    return object[key]
  end)
  if not ok or ns.IsSecret(value) then
    return nil
  end
  return value
end
ns.ReadDkField = PlainField

ns.Validators = {
  IsSecretValue = ns.IsSecret,
  ReadPlainNumber = function(object, key)
    local value = PlainField(object, key)
    if type(value) == "number" then
      return value
    end
  end,
  IsExistingUnit = function(unit)
    local fn = rawget(_G, "UnitExists")
    if type(fn) ~= "function" then
      return false
    end
    local ok, value = pcall(fn, unit)
    return ok and not ns.IsSecret(value) and value == true
  end,
}

ns.SpellUtils = {
  GetSpellCooldownSafe = function(id)
    local api = rawget(_G, "C_Spell")
    if type(api) ~= "table" or type(api.GetSpellCooldown) ~= "function" then
      return nil
    end
    local ok, info = pcall(api.GetSpellCooldown, id)
    if not ok then
      return nil
    end
    return PlainField(info, "startTime"), PlainField(info, "duration"), PlainField(info, "isEnabled")
  end,
}

local SETTING_KEYS = {
  "vipDkSoulReaperWarningEnabled",
  "vipDkPutrefyWarningEnabled",
  "vipDkApocalypseHorseSoundMuted",
  "vipDkGhoulReminderEnabled",
}
local HORSE_SOUND_IDS = { 987917, 987919, 987921 }

local function ImportSettings()
  local db = ns.Log.DB()
  local legacy = rawget(_G, "IsiLiveDB")
  if not db or db.dkSettingsImported == true or type(legacy) ~= "table" then
    return
  end
  for _, key in ipairs(SETTING_KEYS) do
    if db[key] == nil and type(legacy[key]) == "boolean" then
      db[key] = legacy[key]
    end
  end
  if db.vipDkGhoulReminderPosition == nil and type(legacy.vipDkGhoulReminderPosition) == "table" then
    local pos = legacy.vipDkGhoulReminderPosition
    if
      type(pos.point) == "string"
      and type(pos.relativePoint) == "string"
      and type(pos.x) == "number"
      and type(pos.y) == "number"
    then
      db.vipDkGhoulReminderPosition = {
        point = pos.point,
        relativePoint = pos.relativePoint,
        x = pos.x,
        y = pos.y,
      }
    end
  end
  db.dkSettingsImported = true
end

-- Only undo a mute this addon actually applied. An off-by-default tracker
-- must not unmute another addon's sound choice during login.
local mutedByTracker = false
local function ApplyHorseSounds()
  local db = ns.Log.DB()
  if db and db.dkHorseSoundsApplied == true then
    mutedByTracker = true
  end
  local muted = ns.Settings.Get("vipDkApocalypseHorseSoundMuted")
  if not muted and not mutedByTracker then
    return
  end
  local name = muted and "MuteSoundFile" or "UnmuteSoundFile"
  local globalAPI = rawget(_G, name)
  local api = rawget(_G, "C_Sound")
  local namespacedAPI = type(api) == "table" and api[name] or nil
  local applied = false
  for _, id in ipairs(HORSE_SOUND_IDS) do
    if type(globalAPI) == "function" then
      applied = pcall(globalAPI, id) or applied
    end
    if type(namespacedAPI) == "function" and namespacedAPI ~= globalAPI then
      applied = pcall(namespacedAPI, id) or applied
    end
  end
  if applied then
    mutedByTracker = muted
    if db then
      db.dkHorseSoundsApplied = muted
    end
  end
end

function ns.InitializeDkAssist()
  ImportSettings()
  ns.DkAssist.SetDependencies({
    getDB = ns.Log.DB,
    getL = function()
      return ns.L
    end,
  })
  ApplyHorseSounds()
end

function ns.RefreshDkAssistSettings()
  ns.DkAssist.Refresh()
  ApplyHorseSounds()
end
