---@diagnostic disable: undefined-global, lowercase-global, assign-type-mismatch, unused-local
-- Test script: runs outside WoW with standard Lua and stubs WoW globals.
-- Options page (Blizzard settings API), sound choice/channel and window
-- appearance, driven through the real addon files.
local dir, stub = arg[1], arg[2]

local PLAYED = {}
local OPENED
local REGISTERED = {} -- variable -> { get, set, kind, options }
local INITIALIZERS = {}
local ADDON_CATEGORY

local function SettingsStub()
  local category = { ID = 4242 }
  local layout = {
    AddInitializer = function(_, init) table.insert(INITIALIZERS, init) end,
  }
  local api = {
    VarType = { Boolean = "boolean", Number = "number", String = "string" },
  }
  function api.RegisterVerticalLayoutCategory(name) category.name = name; return category, layout end
  function api.RegisterAddOnCategory(cat) ADDON_CATEGORY = cat end
  function api.RegisterProxySetting(cat, variable, varType, name, default, get, set)
    assert(cat == category, "proxy setting registered on the addon category")
    local s = { variable = variable, varType = varType, name = name, default = default, get = get, set = set }
    REGISTERED[variable] = s
    return s
  end
  function api.CreateCheckbox(_, s, tooltip) s.kind = "checkbox"; s.tooltip = tooltip end
  function api.CreateSlider(_, s, options, tooltip) s.kind = "slider"; s.options = options; s.tooltip = tooltip end
  function api.CreateDropdown(_, s, options, tooltip) s.kind = "dropdown"; s.options = options; s.tooltip = tooltip end
  function api.CreateSliderOptions(minValue, maxValue, rate)
    return { minValue = minValue, maxValue = maxValue, rate = rate, SetLabelFormatter = function(self, _, fn) self.formatter = fn end }
  end
  function api.CreateControlTextContainer()
    local c = { data = {} }
    function c:Add(value, label) table.insert(self.data, { value = value, label = label }) end
    function c:GetData() return self.data end
    return c
  end
  function api.OpenToCategory(id) OPENED = id end
  return api
end

local function Boot(locale, withSharedMedia, savedDB)
  isiBlightfallTrackerDB = savedDB
  PLAYED, OPENED, REGISTERED, INITIALIZERS, ADDON_CATEGORY = {}, nil, {}, {}, nil
  issecretvalue = function() return false end
  GetTime = function() return 1000 end
  date = os.date
  GetBuildInfo = function() return "12.1.0", "69933" end
  UnitClass = function() return "x", "DEATHKNIGHT" end
  UnitName = function() return "Pinto" end
  GetRealmName = function() return "Malfurion" end
  GetLocale = function() return locale end
  GetSpecialization = function() return 3 end
  GetSpecializationInfo = function() return 252 end
  GetInstanceInfo = function() return "Welt", "none", 0, 0, 0, 0, false, 0 end
  InCombatLockdown = function() return false end
  UnitGUID = function() return "Player-1" end
  UnitExists = function() return false end
  C_Timer = { After = function() end }
  C_Spell = { GetSpellDescription = function() return "im Verlauf von 18 Sek. 10.000 Schattenschaden." end }
  SOUNDKIT = { RAID_WARNING = 8959, READY_CHECK = 8960, ALARM_CLOCK_WARNING_3 = 12889, UI_RAID_BOSS_WHISPER_WARNING = 37666 }
  PlaySound = function(id, channel) table.insert(PLAYED, { kind = "kit", id = id, channel = channel }); return true end
  PlaySoundFile = function(path, channel) table.insert(PLAYED, { kind = "file", path = path, channel = channel }); return true end
  MinimalSliderWithSteppersMixin = { Label = { Right = 2 } }
  CreateSettingsButtonInitializer = function(name, text, click, tooltip, tags)
    assert(tags ~= nil, "Blizzard asserts addSearchTags ~= nil")
    return { button = text, name = name, click = click }
  end
  CreateSettingsListSectionHeaderInitializer = function(name) return { header = name } end
  Settings = SettingsStub()
  if withSharedMedia then
    local lib = {
      List = function() return { "None", "Airhorn", "Bell" } end,
      Fetch = function(_, _, name) return "Interface\\Sounds\\" .. name .. ".ogg" end,
    }
    LibStub = setmetatable({}, { __call = function(_, name) if name == "LibSharedMedia-3.0" then return lib end end })
  else
    LibStub = nil
  end
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
  events.scripts.OnEvent(events, "PLAYER_LOGIN")
  events.scripts.OnEvent(events, "PLAYER_ENTERING_WORLD")
  return ns, display
end

local fail = 0
local function check(cond, msg) io.write((cond and "PASS " or "FAIL ") .. msg .. "\n"); if not cond then fail = fail + 1 end end
local function V(key) return "isiBlightfallTracker_" .. key end

-- Registration and defaults ----------------------------------------------------
local ns, display = Boot("deDE", true)
check(ADDON_CATEGORY ~= nil and ADDON_CATEGORY.name == "isiBlightfallTracker", "options page registered as addon category")
local expected = { language = "dropdown", soundEnabled = "checkbox", soundChoice = "dropdown", soundChannel = "dropdown", combatOnly = "checkbox",
  readyOnly = "checkbox", locked = "checkbox", showBorder = "checkbox", scale = "slider", bgTransparency = "slider", logEnabled = "checkbox" }
for key, kind in pairs(expected) do
  local s = REGISTERED[V(key)]
  check(s ~= nil and s.kind == kind and type(s.name) == "string" and s.name ~= "", "control " .. key .. " (" .. kind .. ")")
end
local buttons = 0
for _, init in ipairs(INITIALIZERS) do if init.button then buttons = buttons + 1 end end
check(buttons == 2, "two buttons: test sound and reset position")
check(REGISTERED[V("soundEnabled")].get() == true and REGISTERED[V("soundChannel")].get() == "Master", "defaults: cue on, channel Master")
check(display.scale == 1.0 and math.abs(display.bgAlpha - 0.7) < 1e-9 and display.borderAlpha == 1 and display.mouseEnabled == true,
  "default appearance: scale 1, background 70 % opaque, border on, movable")

-- Sound dropdown: own cue, 4 built-in sounds, shared-media sounds (without "None").
local choices = REGISTERED[V("soundChoice")].options()
local values = {}
for _, c in ipairs(choices) do values[#values + 1] = c.value end
check(table.concat(values, ",") == "gogo,raidwarning,readycheck,alarm,bosswhisper,lsm:Airhorn,lsm:Bell", "sound choices: " .. table.concat(values, ","))
local channels = REGISTERED[V("soundChannel")].options()
check(#channels == 5 and channels[2].label == "Effekte", "five channels, localized labels")

-- Language ---------------------------------------------------------------------
local function FontWithText(text)
  for _, fs in ipairs(FONTS) do if fs.text == text then return fs end end
end
local languages = REGISTERED[V("language")].options()
check(#languages == 3 and languages[1].value == "auto" and languages[1].label == "Automatisch (Spielsprache)"
  and languages[2].label == "English" and languages[3].label == "Deutsch", "language choices: auto, English, Deutsch")
check(REGISTERED[V("language")].get() == "auto", "language default: automatic")
local dtLabel = FontWithText("Dunkle Verwandlung")
check(dtLabel ~= nil and FontWithText("Ist (geschätzt)") ~= nil, "German client: German labels, written out")
REGISTERED[V("language")].set("enUS")
check(dtLabel.text == "Dark Transformation" and FontWithText("Actual (estimated)") ~= nil, "switch to English relabels the window at once")
check(ns.L.HELP:find("/ibt options", 1, true) == 1, "chat text follows the switch")
REGISTERED[V("language")].set("xxXX")
check(REGISTERED[V("language")].get() == "enUS", "unknown language is rejected")
REGISTERED[V("language")].set("auto")
check(dtLabel.text == "Dunkle Verwandlung", "automatic follows the client again")

-- Playback ---------------------------------------------------------------------
ns.Sound.Play(false)
check(#PLAYED == 1 and PLAYED[1].kind == "file" and PLAYED[1].path:find("GoGo.ogg") and PLAYED[1].channel == "Master", "default: GoGo on Master")
REGISTERED[V("soundChoice")].set("raidwarning")
REGISTERED[V("soundChannel")].set("SFX")
PLAYED = {}
ns.Sound.Play(false)
check(PLAYED[1] and PLAYED[1].kind == "kit" and PLAYED[1].id == 8959 and PLAYED[1].channel == "SFX", "built-in sound by SOUNDKIT on the chosen channel")
REGISTERED[V("soundChoice")].set("lsm:Bell")
REGISTERED[V("soundChannel")].set("Dialog")
PLAYED = {}
ns.Sound.Play(false)
check(PLAYED[1] and PLAYED[1].path == "Interface\\Sounds\\Bell.ogg" and PLAYED[1].channel == "Dialog", "shared-media sound played from its path")
REGISTERED[V("soundEnabled")].set(false)
PLAYED = {}
ns.Sound.Play(false)
check(#PLAYED == 0, "cue off: nothing plays on NOW")
for _, init in ipairs(INITIALIZERS) do if init.button == "Abspielen" then init.click() end end
check(#PLAYED == 1, "test button plays even when the cue is off")
REGISTERED[V("soundChannel")].set("Bogus")
check(REGISTERED[V("soundChannel")].get() == "Dialog", "invalid channel is rejected")

-- Appearance -------------------------------------------------------------------
local function LeftTop(fr) return fr:GetLeft() * fr:GetScale(), fr:GetTop() * fr:GetScale() end
local left0, top0 = LeftTop(display)
REGISTERED[V("scale")].set(1.5)
check(display.scale == 1.5, "scale applies immediately")
local left1, top1 = LeftTop(display)
check(display.point[1] == "TOPLEFT" and math.abs(left1 - left0) < 1e-6 and math.abs(top1 - top0) < 1e-6,
  "size change keeps the top-left corner in place")
local pos = isiBlightfallTrackerDB.position
check(type(pos) == "table" and math.abs(pos.left - left0) < 1e-6, "top-left position saved")
REGISTERED[V("scale")].set(0.75)
local left2 = LeftTop(display)
check(math.abs(left2 - left0) < 1e-6, "shrinking keeps the left edge too")
REGISTERED[V("scale")].set(1.5)
REGISTERED[V("scale")].set(5)
check(display.scale == 1.5 and REGISTERED[V("scale")].get() == 1.5, "out-of-range scale is rejected")
REGISTERED[V("bgTransparency")].set(0.8)
check(math.abs(display.bgAlpha - 0.2) < 1e-9, "transparency 80 % -> background alpha 0.2")
local label = FontWithText("Schreckensseuche")
check(label.flags == "OUTLINE" and label.shadowAlpha == 1, "see-through background: labels get outline and shadow")
check(label.color[1] > 0.75, "see-through background: muted labels brighten")
REGISTERED[V("bgTransparency")].set(0.3)
check(label.flags == "" and label.color[1] < 0.6, "solid background: no outline, normal tone")
REGISTERED[V("bgTransparency")].set(0.8)
REGISTERED[V("showBorder")].set(false)
check(display.borderAlpha == 0, "border can be hidden")
REGISTERED[V("locked")].set(true)
check(display.mouseEnabled == false, "locked window ignores the mouse (no drag)")
REGISTERED[V("combatOnly")].set(true)
check(display.shown == false, "combat-only option hides the window out of combat")
REGISTERED[V("logEnabled")].set(true)
check(ns.Log.IsEnabled(), "log checkbox switches the log on")
check(REGISTERED[V("scale")].options.formatter(1.5) == "150%", "slider label shows percent")

-- Settings survive a reload; damaged values fall back to defaults.
isiBlightfallTrackerDB.scale = "huge"
local saved = isiBlightfallTrackerDB
local _, display2 = Boot("enUS", false, saved)
check(display2.scale == 1.0, "damaged scale value falls back to default")
check(display2.point and display2.point[1] == "TOPLEFT", "saved top-left position restored after reload")
check(math.abs(display2.bgAlpha - 0.2) < 1e-9 and display2.mouseEnabled == false, "other settings persist after reload")

-- A damaged SavedVariables file must not break the login (options page,
-- activation): invalid positions fall back to the default, broken factors are
-- ignored.
for _, badPosition in ipairs({
  { left = 0 / 0, top = 100 },
  { left = math.huge, top = 100 },
  { "NOWHERE", "CENTER", 0, 0 },
  { "LEFT", "LEFT", "x", 0 },
}) do
  local ns3, display3 = Boot("enUS", false, { position = badPosition, factors = { version = 2, vp = 0 / 0, dp = 1, samples = 3 } })
  check(ADDON_CATEGORY ~= nil and display3.point and display3.point[1] == "CENTER" and isiBlightfallTrackerDB.position == nil,
    "damaged saved position: default position, login completes")
  check(ns3.Model.factors.vp == ns3.Model.factors.vp and ns3.Model.factors.samples == 0, "damaged saved factors ignored")
end
local ns4 = Boot("enUS", false, { position = { "LEFT", "LEFT", 516.67, -15.56 }, factors = { version = 2, vp = 1.4, dp = 1.4, samples = 5 } })
check(ns4.Model.factors.vp == 1.4 and ns4.Model.factors.samples == 5 and STUB_FRAMES ~= nil, "valid saved factors and pre-0.6 position still load")

-- Without shared media only the built-in choices are offered.
local en = REGISTERED[V("soundChoice")].options()
check(#en == 5 and en[1].label == "Voice: Go! Go!", "no shared-media library: 5 choices, English labels")

-- /ibt options opens the page.
SlashCmdList.ISIBLIGHTFALL("options")
check(OPENED == 4242, "/ibt options opens the settings page")

os.exit(fail == 0 and 0 or 1)
