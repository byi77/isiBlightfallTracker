---@diagnostic disable: undefined-global, lowercase-global
-- Test script: runs outside WoW with standard Lua and stubs WoW globals.
-- Real plague time via Blizzard's aura container (PlagueAuras.lua), driven
-- through the real addon files: setup, slot filters, widget hand-over, the
-- model fallback, the in-combat deferral and target changes. The container
-- itself is Blizzard code (secure environment) and is stubbed: the stub
-- records what the addon hands it, like the client's inbound API.
-- COMPONENT-ONLY for the container: its secure aura matching cannot run here.
local dir, stub = arg[1], arg[2]

local CONTAINER, SLOTS, LOADS, UPDATES, HOSTS, TOUCHES
local fail = 0
local function check(cond, msg) io.write((cond and "PASS " or "FAIL ") .. msg .. "\n"); if not cond then fail = fail + 1 end end

local function Boot(opts)
  isiBlightfallTrackerDB = nil
  CONTAINER, SLOTS, LOADS, UPDATES, HOSTS, TOUCHES = nil, {}, 0, 0, {}, 0
  local inLockdown = opts.inCombatAtLogin == true
  issecretvalue = function(v) return v == "SECRET" end
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
  InCombatLockdown = function() return inLockdown end
  UnitGUID = function() return "Player-1" end
  UnitExists = function(u) return u == "target" and opts.target ~= nil end
  UnitCanAttack = function() return opts.target == "enemy" and true or (opts.target == "secret" and "SECRET" or false) end
  C_Timer = { After = function() end }
  C_Spell = { GetSpellDescription = function() return "im Verlauf von 18 Sek. 10.000 Schattenschaden." end }
  Enum = { StatusBarTimerDirection = { RemainingTime = 1, ElapsedTime = 0 } }
  local loaded = false
  if opts.noAddOnsApi then
    C_AddOns = nil
  else
    C_AddOns = {
      IsAddOnLoaded = function(name) return name == "Blizzard_AuraContainer" and loaded end,
      LoadAddOn = function(name)
        if name == "Blizzard_AuraContainer" then LOADS = LOADS + 1; loaded = true end
        return loaded
      end,
    }
  end
  SlashCmdList = {}
  print = function() end
  dofile(stub)
  local baseCreate = CreateFrame
  CreateFrame = function(kind, name, parent, template)
    if template == "DisableUntrustedLayoutScriptsTemplate" then
      local host = baseCreate(kind, name, parent, template)
      host.template, host.parent = template, parent
      table.insert(HOSTS, host)
      return host
    end
    if kind ~= "AuraContainer" then return baseCreate(kind, name, parent, template) end
    assert(template == "CustomAuraContainerTemplate", "container template")
    local c = baseCreate("Frame")
    c.SetUnit = function(self, unit) self.unit = unit end
    c.UpdateAllAuras = function() UPDATES = UPDATES + 1 end
    c.SetEnabled = function(self, on) self.enabled = on end
    c.AddAuraSlot = function(_, key, filter, options)
      local button = baseCreate("Frame")
      button.SetDurationText = function(self, fs) self.durationText = fs end
      button.SetDurationBar = function(self, bar, o) self.durationBar = bar; self.barOptions = o end
      button.EnableMouse = function(self, on) self.mouse = on end
      button.SetAllPoints = function(self, target) self.anchor = target end
      if opts.failInit then
        button.SetDurationText = function() error("simulated failure") end
      end
      SLOTS[key] = { filter = filter, options = options, button = button }
      -- Errors in the callback would surface inside Blizzard's code.
      local ok = pcall(options.initializeFrame, button)
      SLOTS[key].callbackRaised = not ok
      -- From here on the client denies addon code access while auras are
      -- secret (DenyTaintedAccessWhenAurasAreSecret): count every touch.
      local function Seal(obj)
        if type(obj) ~= "table" then return end
        local mt = getmetatable(obj)
        local index = mt.__index
        setmetatable(obj, { __index = function(t, k) TOUCHES = TOUCHES + 1; return type(index) == "function" and index(t, k) or index[k] end })
      end
      Seal(button); Seal(rawget(button, "durationText")); Seal(rawget(button, "durationBar"))
      return button
    end
    CONTAINER = c
    return c
  end
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
  local function leaveCombat()
    inLockdown = false
    events.scripts.OnEvent(events, "PLAYER_REGEN_DISABLED")
    events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED")
  end
  return ns, display, events, leaveCombat
end

-- Value text of a table row: created right after its label (TableRow).
local function RowValue(label)
  for i, fs in ipairs(FONTS) do
    if fs.text == label then return FONTS[i + 1] end
  end
end

local function Render(display)
  display.scripts.OnUpdate(display, 1)
end

-- Setup with an enemy target ------------------------------------------------------
local ns, display, events = Boot({ target = "enemy" })
check(ns.PlagueAuras.Status() == "ok" and LOADS == 1, "container addon loaded and set up out of combat")
check(CONTAINER and CONTAINER.unit == "target" and CONTAINER.enabled == true and CONTAINER.shown == true, "container watches the target, enabled and shown")
local vp, dp = SLOTS.vp, SLOTS.dp
check(vp and dp and vp.filter == "HARMFUL|PLAYER" and dp.filter == "HARMFUL|PLAYER", "two slots, own harmful auras only")
local function OnlyID(slot, id)
  local ids = slot.options.candidateFilters.includeSpellIDs
  local n = 0
  for k in pairs(ids) do n = n + 1 end
  return n == 1 and ids[id] == true
end
check(OnlyID(vp, 191587) and OnlyID(dp, 1240996), "slots match Virulent Plague 191587 and Dread Plague 1240996 by spell ID")
check(vp.button.durationText and vp.button.durationText.kind == "FontString" and vp.button.durationBar
  and vp.button.durationBar.kind == "StatusBar" and vp.button.barOptions.direction == 1,
  "duration text and remaining-time bar handed to the container")
check(vp.button.mouse == false, "slot buttons do not block dragging the window")
check(rawget(vp.button.durationText, "shadowAlpha") == 1 and rawget(vp.button.durationText, "flags") == "OUTLINE",
  "container text styled once, outline for every transparency")
check(#HOSTS == 2 and HOSTS[1].parent ~= nil and rawget(vp.button, "anchor") == HOSTS[1] and rawget(dp.button, "anchor") == HOSTS[2],
  "buttons anchored to layout-restricted hosts, not to the main window")

-- Enemy target: the model values stay empty under the container's widgets.
ns.Model.OnPlayerCast(77575, 1000) -- Outbreak: the model has 18 s
Render(display)
local vpValue = RowValue("Virulente Seuche")
check(vpValue and vpValue.text == "", "enemy target: modelled time hidden, container shows the real time")

-- Mythic+: the addon never touches the handed-over widgets again, not on
-- render, target change, transparency, size or language changes.
TOUCHES = 0
for _ = 1, 5 do Render(display) end
events.scripts.OnEvent(events, "PLAYER_TARGET_CHANGED")
ns.Settings.Set("bgTransparency", 0.9); ns.UI.ApplyAppearance()
ns.Settings.Set("scale", 1.4); ns.UI.ApplyAppearance()
ns.Settings.Set("language", "enUS"); ns.UI.ApplyLanguage()
events.scripts.OnEvent(events, "PLAYER_REGEN_DISABLED")
events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED")
check(TOUCHES == 0, "no access to the container's widgets after the hand-over (" .. TOUCHES .. ")")
ns.Settings.Set("language", "auto"); ns.UI.ApplyLanguage()

-- Target change refreshes the container.
local before = UPDATES
events.scripts.OnEvent(events, "PLAYER_TARGET_CHANGED")
check(UPDATES == before + 1, "PLAYER_TARGET_CHANGED refreshes the container")

-- No target: the model fills the rows.
ns, display = Boot({ target = nil })
ns.Model.OnPlayerCast(77575, 1000)
Render(display)
vpValue = RowValue("Virulente Seuche")
check(vpValue and vpValue.text == "18 s", "no target: modelled plague time shown (" .. tostring(vpValue and vpValue.text) .. ")")

-- A secret attackability answer is never tested; the container is trusted.
ns, display = Boot({ target = "secret" })
check(ns.PlagueAuras.ShowsTarget() == true, "secret UnitCanAttack: container display kept")

-- Reload in combat: setup waits for the end of combat.
local leaveCombat
ns, display, events, leaveCombat = Boot({ target = "enemy", inCombatAtLogin = true })
check(ns.PlagueAuras.Status() == "deferred" and LOADS == 0 and CONTAINER == nil, "in combat: no addon load, setup deferred")
leaveCombat()
check(ns.PlagueAuras.Status() == "ok" and LOADS == 1 and SLOTS.vp ~= nil, "after combat: container set up")

-- Client without the container API: model only, no error.
ns, display = Boot({ target = "enemy", noAddOnsApi = true })
check(ns.PlagueAuras.Status() == "no-addons-api" and CONTAINER == nil, "no addon API: no container")
ns.Model.OnPlayerCast(77575, 1000)
Render(display)
vpValue = RowValue("Virulente Seuche")
check(vpValue and vpValue.text == "18 s", "no container: modelled plague time shown")

-- A failing button setup never escapes into Blizzard's code and leaves the
-- model in charge.
ns, display = Boot({ target = "enemy", failInit = true })
check(SLOTS.vp and SLOTS.vp.callbackRaised == false, "error inside initializeFrame is caught by the addon")
check(ns.PlagueAuras.Status() == "init-failed" and ns.PlagueAuras.ShowsTarget() == false and CONTAINER.shown == false,
  "failed setup: container hidden, model display")

os.exit(fail == 0 and 0 or 1)
