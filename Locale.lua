local _, ns = ...

-- UI strings. German for a German client, English for every other locale.
-- The window is narrow (~130 px, labels ~74 px, values 44 px): on-screen
-- strings are kept short; chat output (/ibt) may be longer.

local enUS = {
  -- signal row
  SIGNAL_IDLE = "not ready",
  SIGNAL_NO_PLAGUES = "no plagues",
  SIGNAL_CHARGING = "charging ...",
  SIGNAL_NOW_DT_ENDING = "NOW · DT ending",
  SIGNAL_NOW_SOUL_REAPER = "NOW · SR ending",
  SIGNAL_NOW_DT_READY = "NOW · DT ready",
  SIGNAL_NOW_PLAGUES_EXPIRING = "NOW · plagues",
  SIGNAL_STOPPED = "error (log)",
  -- table rows (label left, value right)
  ROW_ENEMIES = "Enemies",
  ROW_PER_TARGET = "Per target",
  ESTIMATE_OFF = "estimate off",
  BAR_DT = "DT",
  BAR_PLAGUES = "Plagues",
  ROW_SOUL_REAPER = "Soul Reaper",
  ROW_SOUL_REAPER_BONUS = "SR (+20%)",
  ROW_DT_CD = "DT-CD",
  ROW_ERUPTS = "Erupts",
  ROW_REAL = "Real (est.)",
  ROW_PREDICTED = "Predicted",
  SECONDS_FMT = "%.1fs",
  WHOLE_SECONDS_FMT = "%.0fs",
  VALUE_READY = "ready",
  VALUE_LOCKED = "locked",
  -- chat (/ibt)
  DIAG_FMT = "%s  |  Calib. %s  |  Log %s  |  Window: %s",
  MODE_ESTIMATE = "estimate",
  MODE_TIMING = "timing only",
  CALIB_NEW = "new",
  DROPPED_FMT = " (+%d)",
  SOUND_ON = "voice cue on",
  SOUND_OFF = "voice cue off",
  SELFTEST_FMT = "self-test done, tooltip %s/%s",
  SELFTEST_NOLOG = "the log is off - /ibt log on to record it",
  HELP = "/ibt log on|off  ·  /ibt combat on|off  ·  /ibt sound  ·  /ibt test  ·  /ibt reset",
  LOG_ON = "log on (new session; written on /reload or logout)",
  LOG_OFF = "log off",
  COMBAT_ONLY_ON = "window only in combat",
  COMBAT_ONLY_OFF = "window always visible",
  STATE_OFF = "off",
  WINDOW_COMBAT_ONLY = "combat only",
  WINDOW_ALWAYS = "always",
}

local deDE = {
  -- signal row
  SIGNAL_IDLE = "nicht bereit",
  SIGNAL_NO_PLAGUES = "keine Seuchen",
  SIGNAL_CHARGING = "laden ...",
  SIGNAL_NOW_DT_ENDING = "JETZT · DT endet",
  SIGNAL_NOW_SOUL_REAPER = "JETZT · SE endet",
  SIGNAL_NOW_DT_READY = "JETZT · DT bereit",
  SIGNAL_NOW_PLAGUES_EXPIRING = "JETZT · Seuchen",
  SIGNAL_STOPPED = "Fehler (Log)",
  -- table rows (label left, value right)
  ROW_ENEMIES = "Gegner",
  ROW_PER_TARGET = "Pro Ziel",
  ESTIMATE_OFF = "Schätzung aus",
  BAR_DT = "DT",
  BAR_PLAGUES = "Seuchen",
  ROW_SOUL_REAPER = "Seelenernter",
  ROW_SOUL_REAPER_BONUS = "SE (+20%)",
  ROW_DT_CD = "DT-CD",
  ROW_ERUPTS = "Ausbrüche",
  ROW_REAL = "Ist (gesch.)",
  ROW_PREDICTED = "Vorhersage",
  SECONDS_FMT = "%.1fs",
  WHOLE_SECONDS_FMT = "%.0fs",
  VALUE_READY = "bereit",
  VALUE_LOCKED = "gesperrt",
  -- chat (/ibt)
  DIAG_FMT = "%s  |  Kalib. %s  |  Log %s  |  Fenster: %s",
  MODE_ESTIMATE = "Schätzung",
  MODE_TIMING = "nur Timing",
  CALIB_NEW = "neu",
  DROPPED_FMT = " (+%d)",
  SOUND_ON = "Ansage an",
  SOUND_OFF = "Ansage aus",
  SELFTEST_FMT = "Selbsttest erledigt, Tooltip %s/%s",
  SELFTEST_NOLOG = "das Log ist aus - mit /ibt log on aufzeichnen",
  HELP = "/ibt log on|off  ·  /ibt combat on|off  ·  /ibt sound  ·  /ibt test  ·  /ibt reset",
  LOG_ON = "Log an (neue Sitzung; gespeichert bei /reload oder Logout)",
  LOG_OFF = "Log aus",
  COMBAT_ONLY_ON = "Fenster nur im Kampf",
  COMBAT_ONLY_OFF = "Fenster immer sichtbar",
  STATE_OFF = "aus",
  WINDOW_COMBAT_ONLY = "nur Kampf",
  WINDOW_ALWAYS = "immer",
}

local locale = GetLocale and GetLocale() or "enUS"
ns.L = (locale == "deDE") and deDE or enUS
ns.LOCALE_TABLES = { enUS = enUS, deDE = deDE }
