local _, ns = ...

-- Persistent session log. Written to SavedVariables on logout/reload so the
-- entries can be analysed offline. Secret values are never stored: callers
-- pass them through ns.Plain(), which turns them into the marker "SECRET".

local Log = {}
ns.Log = Log

local MAX_SESSIONS = 10
local MAX_ENTRIES_PER_SESSION = 6000

local session

function ns.IsSecret(value)
  local check = rawget(_G, "issecretvalue")
  if type(check) ~= "function" then
    return false
  end
  local ok, result = pcall(check, value)
  return ok and result == true
end

-- Returns a value that is safe to compare, store and print.
function ns.Plain(value)
  if ns.IsSecret(value) then
    return "SECRET"
  end
  return value
end

local function Round(value, digits)
  local factor = 10 ^ (digits or 2)
  return math.floor(value * factor + 0.5) / factor
end
ns.Round = Round

-- Creates the SavedVariables table (settings live here even with the log off).
function Log.InitDB()
  -- The SavedVariables table must be a global named as in the .toc.
  _G.isiBlightfallTrackerDB = _G.isiBlightfallTrackerDB or {}
  local db = _G.isiBlightfallTrackerDB
  db.schema = 1
  db.sessions = db.sessions or {}
end

-- The log is off by default (opt-in via /ibt log on).
function Log.IsEnabled()
  local db = _G.isiBlightfallTrackerDB
  return db ~= nil and db.logEnabled == true
end

-- Switches recording on (starts a new session) or off (stops recording; the
-- sessions already stored stay in SavedVariables).
function Log.SetEnabled(enabled)
  local db = _G.isiBlightfallTrackerDB
  if not db then
    return
  end
  db.logEnabled = enabled == true
  if db.logEnabled and not session then
    Log.StartSession()
  elseif not db.logEnabled then
    session = nil
  end
end

function Log.StartSession()
  local db = _G.isiBlightfallTrackerDB
  if not db then
    return
  end

  local version, build = GetBuildInfo()
  local _, className = UnitClass("player")
  session = {
    startedAt = date("%Y-%m-%d %H:%M:%S"),
    startTime = GetTime(),
    char = UnitName("player"),
    realm = GetRealmName(),
    class = className,
    gameVersion = version,
    build = build,
    locale = GetLocale(),
    addonVersion = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("isiBlightfallTracker", "Version"),
    dropped = 0,
    entries = {},
  }
  table.insert(db.sessions, session)
  while #db.sessions > MAX_SESSIONS do
    table.remove(db.sessions, 1)
  end
end

-- Single access point for the SavedVariables table, so only this file (which
-- also creates it) touches the global. nil until PLAYER_LOGIN.
function Log.DB()
  return _G.isiBlightfallTrackerDB
end

function Log.Add(kind, fields)
  if not session then
    return
  end
  if #session.entries >= MAX_ENTRIES_PER_SESSION then
    session.dropped = session.dropped + 1
    return
  end
  local entry = fields or {}
  entry.e = kind
  entry.t = Round(GetTime() - session.startTime, 2)
  table.insert(session.entries, entry)
end

function Log.Count()
  return session and #session.entries or 0, session and session.dropped or 0
end
