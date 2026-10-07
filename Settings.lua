local _, ns = ...

-- User settings with defaults and validation. Values live in the
-- SavedVariables table (isiBlightfallTrackerDB); a missing or invalid value
-- falls back to its default, so a damaged file can never break the addon.

local Settings = {}
ns.Settings = Settings

local DEFAULTS = {
  language = "auto", -- "auto" follows the game client
  soundEnabled = true,
  soundChoice = "gogo",
  soundChannel = "Master",
  combatOnly = false,
  readyOnly = false, -- show the window only while Blightfall is available
  locked = false,
  scale = 1.0,
  bgTransparency = 0.3, -- 0 = opaque, 1 = invisible background
  showBorder = true,
}
Settings.DEFAULTS = DEFAULTS

Settings.CHANNELS = { "Master", "SFX", "Dialog", "Ambience", "Music" }
local VALID_CHANNEL = {}
for _, channel in ipairs(Settings.CHANNELS) do
  VALID_CHANNEL[channel] = true
end

Settings.SCALE_MIN, Settings.SCALE_MAX = 0.5, 2.0

local VALID_LANGUAGE = {}
for _, choice in ipairs(ns.LANGUAGES) do
  VALID_LANGUAGE[choice] = true
end

local VALIDATORS = {
  language = function(v)
    return VALID_LANGUAGE[v] == true
  end,
  soundEnabled = function(v)
    return type(v) == "boolean"
  end,
  soundChoice = function(v)
    return type(v) == "string" and v ~= ""
  end,
  soundChannel = function(v)
    return VALID_CHANNEL[v] == true
  end,
  combatOnly = function(v)
    return type(v) == "boolean"
  end,
  readyOnly = function(v)
    return type(v) == "boolean"
  end,
  locked = function(v)
    return type(v) == "boolean"
  end,
  scale = function(v)
    return type(v) == "number" and v >= Settings.SCALE_MIN and v <= Settings.SCALE_MAX
  end,
  bgTransparency = function(v)
    return type(v) == "number" and v >= 0 and v <= 1
  end,
  showBorder = function(v)
    return type(v) == "boolean"
  end,
}

function Settings.Get(key)
  local db = ns.Log.DB()
  local value = db and db[key]
  local validate = VALIDATORS[key]
  if value == nil or (validate and not validate(value)) then
    return DEFAULTS[key]
  end
  return value
end

-- Returns true when the value was accepted and stored.
function Settings.Set(key, value)
  local db = ns.Log.DB()
  local validate = VALIDATORS[key]
  if not db or (validate and not validate(value)) then
    return false
  end
  db[key] = value
  return true
end
