local _, ns = ...

-- Voice cue playback: choice of sound and output channel.
--   - "gogo": the addon's own voice cue (default)
--   - built-in game sounds by SOUNDKIT name (no extra files)
--   - "lsm:<name>": sounds registered with LibSharedMedia-3.0, if another
--     addon provides that library (optional, no dependency)
-- Anything that cannot be resolved falls back to "gogo".

local Sound = {}
ns.Sound = Sound

local GO_SOUND = "Interface\\AddOns\\isiBlightfallTracker\\sounds\\GoGo.ogg"
local LSM_PREFIX = "lsm:"

-- Built-in sounds, looked up in SOUNDKIT at play time.
Sound.BUILTIN = {
  { key = "raidwarning", kit = "RAID_WARNING", labelKey = "SOUND_RAID_WARNING" },
  { key = "readycheck", kit = "READY_CHECK", labelKey = "SOUND_READY_CHECK" },
  { key = "alarm", kit = "ALARM_CLOCK_WARNING_3", labelKey = "SOUND_ALARM" },
  { key = "bosswhisper", kit = "UI_RAID_BOSS_WHISPER_WARNING", labelKey = "SOUND_BOSS_WHISPER" },
}
local BUILTIN_BY_KEY = {}
for _, entry in ipairs(Sound.BUILTIN) do
  BUILTIN_BY_KEY[entry.key] = entry
end

local function SharedMedia()
  local libStub = rawget(_G, "LibStub")
  if type(libStub) ~= "table" and type(libStub) ~= "function" then
    return nil
  end
  local ok, lib = pcall(libStub, "LibSharedMedia-3.0", true)
  if ok and type(lib) == "table" then
    return lib
  end
  return nil
end

-- Names of shared-media sounds (empty when the library is not loaded).
function Sound.SharedMediaNames()
  local lib = SharedMedia()
  if not lib or type(lib.List) ~= "function" then
    return {}
  end
  local ok, list = pcall(lib.List, lib, "sound")
  if not ok or type(list) ~= "table" then
    return {}
  end
  local names = {}
  for _, name in ipairs(list) do
    if type(name) == "string" and name ~= "None" then
      table.insert(names, name)
    end
  end
  return names
end

-- Ordered list of { value, label } for the settings dropdown.
function Sound.Choices(L)
  local choices = { { value = "gogo", label = L.SOUND_GOGO } }
  for _, entry in ipairs(Sound.BUILTIN) do
    table.insert(choices, { value = entry.key, label = L[entry.labelKey] })
  end
  for _, name in ipairs(Sound.SharedMediaNames()) do
    table.insert(choices, { value = LSM_PREFIX .. name, label = name })
  end
  return choices
end

local function PlayFile(path, channel)
  local ok, willPlay = pcall(PlaySoundFile, path, channel)
  return ok and willPlay ~= false, willPlay
end

-- Plays the configured cue. force = true plays it even when the cue is off
-- (test button). Returns played (bool), the choice actually used, and the
-- channel.
function Sound.Play(force)
  local Settings = ns.Settings
  if not force and not Settings.Get("soundEnabled") then
    return false, nil, nil
  end
  local choice = Settings.Get("soundChoice")
  local channel = Settings.Get("soundChannel")

  local builtin = BUILTIN_BY_KEY[choice]
  if builtin then
    local kits = rawget(_G, "SOUNDKIT")
    local id = type(kits) == "table" and kits[builtin.kit] or nil
    if type(id) == "number" and type(PlaySound) == "function" then
      local ok, willPlay = pcall(PlaySound, id, channel)
      if ok and willPlay ~= false then
        return true, choice, channel
      end
    end
  elseif choice:sub(1, #LSM_PREFIX) == LSM_PREFIX then
    local lib = SharedMedia()
    if lib and type(lib.Fetch) == "function" then
      local ok, path = pcall(lib.Fetch, lib, "sound", choice:sub(#LSM_PREFIX + 1), true)
      if ok and type(path) == "string" and path ~= "" and PlayFile(path, channel) then
        return true, choice, channel
      end
    end
  end

  -- Default voice cue, also the fallback for anything unresolvable.
  local played = PlayFile(GO_SOUND, channel)
  return played, "gogo", channel
end
