local addonName, ns = ...

-- Options page in Esc > Options > AddOns, built with Blizzard's settings API
-- (vertical layout, proxy settings). Proxy getters/setters read and write the
-- addon's own SavedVariables through ns.Settings, and every change is applied
-- immediately.

local Options = {}
ns.Options = Options

local category

local function Api()
  local api = rawget(_G, "Settings")
  if type(api) ~= "table" then
    return nil
  end
  for _, name in ipairs({
    "RegisterVerticalLayoutCategory",
    "RegisterAddOnCategory",
    "RegisterProxySetting",
    "CreateCheckbox",
    "CreateSlider",
    "CreateSliderOptions",
    "CreateDropdown",
    "CreateControlTextContainer",
  }) do
    if type(api[name]) ~= "function" then
      return nil
    end
  end
  return api
end

local function Variable(key)
  return addonName .. "_" .. key
end

-- Boolean/number/string setting stored via ns.Settings.
local function Proxy(api, varType, key, label, onChange)
  local Settings = ns.Settings
  return api.RegisterProxySetting(category, Variable(key), varType, label, Settings.DEFAULTS[key], function()
    return Settings.Get(key)
  end, function(value)
    if Settings.Set(key, value) and onChange then
      onChange(value)
    end
  end)
end

local function AddButton(layout, label, buttonText, onClick, tooltip)
  local create = rawget(_G, "CreateSettingsButtonInitializer")
  if type(create) == "function" and layout and type(layout.AddInitializer) == "function" then
    layout:AddInitializer(create(label, buttonText, onClick, tooltip, true))
  end
end

local function AddHeader(layout, text)
  local create = rawget(_G, "CreateSettingsListSectionHeaderInitializer")
  if type(create) == "function" and layout and type(layout.AddInitializer) == "function" then
    layout:AddInitializer(create(text))
  end
end

local function PercentFormatter(value)
  return string.format("%d%%", math.floor(value * 100 + 0.5))
end

-- Registers the page once (after PLAYER_LOGIN, when the settings exist).
function Options.Register()
  if category then
    return true
  end
  local api = Api()
  if not api then
    return false
  end
  local L = ns.L
  local UI = ns.UI
  local VarType = api.VarType or {}
  local layout
  category, layout = api.RegisterVerticalLayoutCategory(addonName)

  -- General --------------------------------------------------------------------
  -- Language names are shown in their own language, so they stay findable.
  AddHeader(layout, L.OPT_SECTION_GENERAL)
  local LANGUAGE_NAMES = { enUS = "English", deDE = "Deutsch" }
  api.CreateDropdown(category, Proxy(api, VarType.String, "language", L.OPT_LANGUAGE, UI.ApplyLanguage), function()
    local container = api.CreateControlTextContainer()
    for _, choice in ipairs(ns.LANGUAGES) do
      container:Add(choice, LANGUAGE_NAMES[choice] or L.LANGUAGE_AUTO)
    end
    return container:GetData()
  end, L.OPT_LANGUAGE_TIP)

  -- Voice cue ------------------------------------------------------------------
  AddHeader(layout, L.OPT_SECTION_SOUND)
  api.CreateCheckbox(category, Proxy(api, VarType.Boolean, "soundEnabled", L.OPT_SOUND_ENABLED), L.OPT_SOUND_ENABLED_TIP)

  api.CreateDropdown(category, Proxy(api, VarType.String, "soundChoice", L.OPT_SOUND_CHOICE), function()
    local container = api.CreateControlTextContainer()
    for _, choice in ipairs(ns.Sound.Choices(L)) do
      container:Add(choice.value, choice.label)
    end
    return container:GetData()
  end, L.OPT_SOUND_CHOICE_TIP)

  api.CreateDropdown(category, Proxy(api, VarType.String, "soundChannel", L.OPT_SOUND_CHANNEL), function()
    local container = api.CreateControlTextContainer()
    for _, channel in ipairs(ns.Settings.CHANNELS) do
      container:Add(channel, L["CHANNEL_" .. channel:upper()] or channel)
    end
    return container:GetData()
  end, L.OPT_SOUND_CHANNEL_TIP)

  AddButton(layout, L.OPT_SOUND_TEST, L.OPT_SOUND_TEST_BUTTON, function()
    ns.Sound.Play(true)
  end, L.OPT_SOUND_TEST_TIP)

  -- Window ---------------------------------------------------------------------
  AddHeader(layout, L.OPT_SECTION_WINDOW)
  api.CreateCheckbox(
    category,
    Proxy(api, VarType.Boolean, "combatOnly", L.OPT_COMBAT_ONLY, UI.UpdateVisibility),
    L.OPT_COMBAT_ONLY_TIP
  )
  api.CreateCheckbox(
    category,
    Proxy(api, VarType.Boolean, "readyOnly", L.OPT_READY_ONLY, UI.UpdateVisibility),
    L.OPT_READY_ONLY_TIP
  )
  api.CreateCheckbox(category, Proxy(api, VarType.Boolean, "locked", L.OPT_LOCKED, UI.ApplyAppearance), L.OPT_LOCKED_TIP)
  api.CreateCheckbox(
    category,
    Proxy(api, VarType.Boolean, "showBorder", L.OPT_BORDER, UI.ApplyAppearance),
    L.OPT_BORDER_TIP
  )

  local labelRight = rawget(_G, "MinimalSliderWithSteppersMixin")
  labelRight = type(labelRight) == "table" and type(labelRight.Label) == "table" and labelRight.Label.Right or nil

  local scaleOptions = api.CreateSliderOptions(ns.Settings.SCALE_MIN, ns.Settings.SCALE_MAX, 0.05)
  if labelRight and type(scaleOptions.SetLabelFormatter) == "function" then
    scaleOptions:SetLabelFormatter(labelRight, PercentFormatter)
  end
  api.CreateSlider(category, Proxy(api, VarType.Number, "scale", L.OPT_SCALE, UI.ApplyAppearance), scaleOptions, L.OPT_SCALE_TIP)

  local alphaOptions = api.CreateSliderOptions(0, 1, 0.05)
  if labelRight and type(alphaOptions.SetLabelFormatter) == "function" then
    alphaOptions:SetLabelFormatter(labelRight, PercentFormatter)
  end
  api.CreateSlider(
    category,
    Proxy(api, VarType.Number, "bgTransparency", L.OPT_TRANSPARENCY, UI.ApplyAppearance),
    alphaOptions,
    L.OPT_TRANSPARENCY_TIP
  )

  AddButton(layout, L.OPT_RESET_POSITION, L.OPT_RESET_POSITION_BUTTON, UI.ResetPosition, L.OPT_RESET_POSITION_TIP)

  -- Log ------------------------------------------------------------------------
  AddHeader(layout, L.OPT_SECTION_LOG)
  local logSetting = api.RegisterProxySetting(category, Variable("logEnabled"), VarType.Boolean, L.OPT_LOG, false, function()
    return ns.Log.IsEnabled()
  end, function(value)
    ns.Log.SetEnabled(value == true)
  end)
  api.CreateCheckbox(category, logSetting, L.OPT_LOG_TIP)

  api.RegisterAddOnCategory(category)
  return true
end

-- Opens the page; returns false when the settings API is unavailable.
function Options.Open()
  local api = rawget(_G, "Settings")
  if not category or type(api) ~= "table" or type(api.OpenToCategory) ~= "function" then
    return false
  end
  local id = category.ID
  if id == nil and type(category.GetID) == "function" then
    id = category:GetID()
  end
  local ok = pcall(api.OpenToCategory, id)
  return ok
end
