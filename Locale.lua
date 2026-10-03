local _, ns = ...

-- UI strings in English and German. The language follows the game client
-- (German client -> German, every other locale -> English) unless the player
-- picks one on the options page. On-screen strings are written out in full
-- (no abbreviations) and must fit the window (see tests/test_layout.lua).

local enUS = {
  -- signal row
  SIGNAL_IDLE = "not ready",
  SIGNAL_NO_PLAGUES = "no plagues",
  SIGNAL_CHARGING = "charging ...",
  SIGNAL_NOW_DT_ENDING = "NOW: Transformation ends",
  SIGNAL_NOW_SOUL_REAPER = "NOW: Soul Reaper ends",
  SIGNAL_NOW_DT_READY = "NOW: Transformation ready",
  SIGNAL_NOW_PLAGUES_EXPIRING = "NOW: plagues ending",
  SIGNAL_STOPPED = "error (log)",
  -- table rows (label left, value right)
  ROW_ENEMIES = "Enemies",
  ROW_PER_TARGET = "Per target",
  ESTIMATE_OFF = "estimate off",
  BAR_DT = "Dark Transformation",
  BAR_VP = "Virulent Plague",
  BAR_DP = "Dread Plague",
  ROW_SOUL_REAPER = "Soul Reaper",
  ROW_SOUL_REAPER_BONUS = "Soul Reaper +20%",
  ROW_DT_CD = "Next Transformation",
  ROW_ERUPTS = "Erupts",
  ROW_REAL = "Actual (estimated)",
  ROW_PREDICTED = "Predicted",
  SECONDS_FMT = "%.1fs",
  WHOLE_SECONDS_FMT = "%.0fs",
  VALUE_READY = "ready",
  VALUE_LOCKED = "locked",
  -- chat (/ibt)
  DIAG_FMT = "%s  |  Calibration %s  |  Log %s  |  Window: %s",
  MODE_ESTIMATE = "estimate",
  MODE_TIMING = "timing only",
  CALIB_NEW = "new",
  DROPPED_FMT = " (+%d)",
  SOUND_ON = "voice cue on",
  SOUND_OFF = "voice cue off",
  SELFTEST_FMT = "self-test done, tooltip %s/%s",
  SELFTEST_NOLOG = "the log is off - /ibt log on to record it",
  HELP = "/ibt options  ·  /ibt combat on|off  ·  /ibt log on|off  ·  /ibt sound  ·  /ibt test  ·  /ibt reset",
  LOG_ON = "log on (new session; written on /reload or logout)",
  LOG_OFF = "log off",
  COMBAT_ONLY_ON = "window only in combat",
  COMBAT_ONLY_OFF = "window always visible",
  STATE_OFF = "off",
  WINDOW_COMBAT_ONLY = "combat only",
  WINDOW_ALWAYS = "always",
  OPTIONS_UNAVAILABLE = "the options page is not available in this client",
  -- sounds and channels
  SOUND_GOGO = "Voice: Go! Go!",
  SOUND_RAID_WARNING = "Raid warning",
  SOUND_READY_CHECK = "Ready check",
  SOUND_ALARM = "Alarm clock",
  SOUND_BOSS_WHISPER = "Boss whisper",
  CHANNEL_MASTER = "Master",
  CHANNEL_SFX = "Effects",
  CHANNEL_DIALOG = "Dialog",
  CHANNEL_AMBIENCE = "Ambience",
  CHANNEL_MUSIC = "Music",
  -- options page
  OPT_SECTION_GENERAL = "General",
  OPT_LANGUAGE = "Language",
  OPT_LANGUAGE_TIP = "Language of the window and the chat messages. The options page itself switches after the next /reload.",
  LANGUAGE_AUTO = "Automatic (game language)",
  OPT_SECTION_SOUND = "Voice cue",
  OPT_SOUND_ENABLED = "Play cue on NOW",
  OPT_SOUND_ENABLED_TIP = "Plays the cue once when the signal switches to NOW.",
  OPT_SOUND_CHOICE = "Sound",
  OPT_SOUND_CHOICE_TIP = "The voice cue, a built-in game sound, or a sound from an installed shared-media sound pack.",
  OPT_SOUND_CHANNEL = "Sound channel",
  OPT_SOUND_CHANNEL_TIP = "Its volume follows this channel's slider in the game's sound settings. Default: Master.",
  OPT_SOUND_TEST = "Test",
  OPT_SOUND_TEST_BUTTON = "Play sound",
  OPT_SOUND_TEST_TIP = "Plays the selected sound on the selected channel.",
  OPT_SECTION_WINDOW = "Window",
  OPT_COMBAT_ONLY = "Show only in combat",
  OPT_COMBAT_ONLY_TIP = "Hides the window out of combat.",
  OPT_LOCKED = "Lock window",
  OPT_LOCKED_TIP = "The window can no longer be dragged and lets mouse clicks pass through.",
  OPT_BORDER = "Show border",
  OPT_BORDER_TIP = "Thin border around the window.",
  OPT_SCALE = "Size",
  OPT_SCALE_TIP = "Scales the whole window.",
  OPT_TRANSPARENCY = "Background transparency",
  OPT_TRANSPARENCY_TIP = "0% = solid background, 100% = no background. Above 50% the text gets an outline so it stays readable.",
  OPT_RESET_POSITION = "Position",
  OPT_RESET_POSITION_BUTTON = "Reset",
  OPT_RESET_POSITION_TIP = "Moves the window back below the screen centre.",
  OPT_SECTION_LOG = "Log",
  OPT_LOG = "Record log",
  OPT_LOG_TIP = "Writes a local session log (SavedVariables) for checking the estimate. Off by default.",
}

local deDE = {
  -- signal row
  SIGNAL_IDLE = "nicht bereit",
  SIGNAL_NO_PLAGUES = "keine Seuchen",
  SIGNAL_CHARGING = "laden ...",
  SIGNAL_NOW_DT_ENDING = "JETZT: Verwandlung endet",
  SIGNAL_NOW_SOUL_REAPER = "JETZT: Seelenernter endet",
  SIGNAL_NOW_DT_READY = "JETZT: Verwandlung bereit",
  SIGNAL_NOW_PLAGUES_EXPIRING = "JETZT: Seuchen enden",
  SIGNAL_STOPPED = "Fehler (Log)",
  -- table rows (label left, value right)
  ROW_ENEMIES = "Gegner",
  ROW_PER_TARGET = "Pro Ziel",
  ESTIMATE_OFF = "Schätzung aus",
  BAR_DT = "Dunkle Verwandlung",
  BAR_VP = "Virulente Seuche",
  BAR_DP = "Schreckensseuche",
  ROW_SOUL_REAPER = "Seelenernter",
  ROW_SOUL_REAPER_BONUS = "Seelenernter +20%",
  ROW_DT_CD = "Nächste Verwandlung",
  ROW_ERUPTS = "Ausbrüche",
  ROW_REAL = "Ist (geschätzt)",
  ROW_PREDICTED = "Vorhersage",
  SECONDS_FMT = "%.1fs",
  WHOLE_SECONDS_FMT = "%.0fs",
  VALUE_READY = "bereit",
  VALUE_LOCKED = "gesperrt",
  -- chat (/ibt)
  DIAG_FMT = "%s  |  Kalibrierung %s  |  Log %s  |  Fenster: %s",
  MODE_ESTIMATE = "Schätzung",
  MODE_TIMING = "nur Timing",
  CALIB_NEW = "neu",
  DROPPED_FMT = " (+%d)",
  SOUND_ON = "Ansage an",
  SOUND_OFF = "Ansage aus",
  SELFTEST_FMT = "Selbsttest erledigt, Tooltip %s/%s",
  SELFTEST_NOLOG = "das Log ist aus - mit /ibt log on aufzeichnen",
  HELP = "/ibt optionen  ·  /ibt combat an|aus  ·  /ibt log an|aus  ·  /ibt sound  ·  /ibt test  ·  /ibt reset",
  LOG_ON = "Log an (neue Sitzung; gespeichert bei /reload oder Logout)",
  LOG_OFF = "Log aus",
  COMBAT_ONLY_ON = "Fenster nur im Kampf",
  COMBAT_ONLY_OFF = "Fenster immer sichtbar",
  STATE_OFF = "aus",
  WINDOW_COMBAT_ONLY = "nur Kampf",
  WINDOW_ALWAYS = "immer",
  OPTIONS_UNAVAILABLE = "die Einstellungsseite ist in diesem Client nicht verfügbar",
  -- sounds and channels
  SOUND_GOGO = "Sprache: Go! Go!",
  SOUND_RAID_WARNING = "Schlachtzugswarnung",
  SOUND_READY_CHECK = "Bereitschaftscheck",
  SOUND_ALARM = "Wecker",
  SOUND_BOSS_WHISPER = "Boss-Flüstern",
  CHANNEL_MASTER = "Master",
  CHANNEL_SFX = "Effekte",
  CHANNEL_DIALOG = "Dialog",
  CHANNEL_AMBIENCE = "Umgebung",
  CHANNEL_MUSIC = "Musik",
  -- options page
  OPT_SECTION_GENERAL = "Allgemein",
  OPT_LANGUAGE = "Sprache",
  OPT_LANGUAGE_TIP = "Sprache des Fensters und der Chatmeldungen. Die Einstellungsseite selbst wechselt nach dem nächsten /reload.",
  LANGUAGE_AUTO = "Automatisch (Spielsprache)",
  OPT_SECTION_SOUND = "Ansage",
  OPT_SOUND_ENABLED = "Ansage bei JETZT",
  OPT_SOUND_ENABLED_TIP = "Spielt die Ansage einmal, wenn das Signal auf JETZT springt.",
  OPT_SOUND_CHOICE = "Sound",
  OPT_SOUND_CHOICE_TIP = "Die Sprachansage, ein eingebauter Spielsound oder ein Sound aus einem installierten Shared-Media-Soundpaket.",
  OPT_SOUND_CHANNEL = "Soundkanal",
  OPT_SOUND_CHANNEL_TIP = "Die Lautstärke folgt dem Regler dieses Kanals in den Toneinstellungen des Spiels. Standard: Master.",
  OPT_SOUND_TEST = "Test",
  OPT_SOUND_TEST_BUTTON = "Abspielen",
  OPT_SOUND_TEST_TIP = "Spielt den gewählten Sound auf dem gewählten Kanal.",
  OPT_SECTION_WINDOW = "Fenster",
  OPT_COMBAT_ONLY = "Nur im Kampf anzeigen",
  OPT_COMBAT_ONLY_TIP = "Blendet das Fenster außerhalb des Kampfes aus.",
  OPT_LOCKED = "Fenster sperren",
  OPT_LOCKED_TIP = "Das Fenster lässt sich nicht mehr verschieben und Mausklicks gehen hindurch.",
  OPT_BORDER = "Rahmen anzeigen",
  OPT_BORDER_TIP = "Dünner Rahmen um das Fenster.",
  OPT_SCALE = "Größe",
  OPT_SCALE_TIP = "Skaliert das ganze Fenster.",
  OPT_TRANSPARENCY = "Hintergrund-Transparenz",
  OPT_TRANSPARENCY_TIP = "0% = voller Hintergrund, 100% = kein Hintergrund. Ab 50% bekommt die Schrift eine Kontur, damit sie lesbar bleibt.",
  OPT_RESET_POSITION = "Position",
  OPT_RESET_POSITION_BUTTON = "Zurücksetzen",
  OPT_RESET_POSITION_TIP = "Setzt das Fenster wieder unter die Bildschirmmitte.",
  OPT_SECTION_LOG = "Log",
  OPT_LOG = "Log aufzeichnen",
  OPT_LOG_TIP = "Schreibt ein lokales Sitzungslog (SavedVariables), um die Schätzung zu prüfen. Standardmäßig aus.",
}

ns.LOCALE_TABLES = { enUS = enUS, deDE = deDE }
-- Choices of the language setting; "auto" follows the game client.
ns.LANGUAGES = { "auto", "enUS", "deDE" }

local active = enUS

-- "enUS"/"deDE" as chosen, anything else resolves from the client locale.
local function Resolve(choice)
  if ns.LOCALE_TABLES[choice] then
    return choice
  end
  local client = GetLocale and GetLocale() or "enUS"
  return client == "deDE" and "deDE" or "enUS"
end

-- ns.L is a view of the active table, so a language switch reaches every
-- L.KEY lookup without a reload.
ns.L = setmetatable({}, {
  __index = function(_, key)
    return active[key]
  end,
})

-- Activates a language choice ("auto", "enUS", "deDE"); returns the tag.
function ns.SetLanguage(choice)
  local tag = Resolve(choice)
  active = ns.LOCALE_TABLES[tag]
  ns.languageTag = tag
  return tag
end

ns.SetLanguage("auto")
