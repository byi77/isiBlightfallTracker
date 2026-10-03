local _, ns = ...

-- Real remaining time of Virulent Plague and Dread Plague on the target.
--
-- In combat (and always in Mythic+ and encounters) aura data on enemies is
-- secret: addon code may not read, compare or calculate with it. Blizzard's
-- aura container (Blizzard_AuraContainer, 12.1) runs in a secure environment
-- instead: it matches the player's own debuffs on the target by spell ID
-- (allowed for harmful auras on enemies, Blizzard_AuraContainerUtil.lua) and
-- drives a font string and a status bar we hand it. We only display those
-- widgets and never read anything back. The damage estimate keeps using the
-- modelled plague time (Model.lua), which needs numbers.

local PlagueAuras = {}
ns.PlagueAuras = PlagueAuras

local CONTAINER_ADDON = "Blizzard_AuraContainer"
local FILTER = "HARMFUL|PLAYER"
local REQUIRED_METHODS = { "SetUnit", "AddAuraSlot", "UpdateAllAuras" }

local container
-- "ok", "deferred" (in combat, retried after combat) or a failure reason.
local status = "init"

local function LoadContainerAddOn()
  local addons = rawget(_G, "C_AddOns")
  if type(addons) ~= "table" or type(addons.IsAddOnLoaded) ~= "function" then
    return false, "no-addons-api"
  end
  if addons.IsAddOnLoaded(CONTAINER_ADDON) then
    return true
  end
  -- Loading an addon is not documented as combat-safe; wait for combat end.
  if InCombatLockdown and InCombatLockdown() then
    return false, "deferred"
  end
  if type(addons.LoadAddOn) ~= "function" then
    return false, "no-load-api"
  end
  local ok = pcall(addons.LoadAddOn, CONTAINER_ADDON)
  if ok and addons.IsAddOnLoaded(CONTAINER_ADDON) then
    return true
  end
  return false, "load-failed"
end

-- Anchor host per plague row. Aura buttons carry forbidden aspects
-- (UntrustedLayoutScriptExecution, ScriptedInput, ChangeParent, see
-- Blizzard_AuraButton.xml); anchoring one to a frame propagates its layout
-- restriction into that frame. The host opts in to that restriction at
-- creation (DisableUntrustedLayoutScriptsTemplate) and owns the relationship,
-- so the main window stays free to move, scale and hide in every context.
local function CreateHost(ui, row)
  local ok, host = pcall(CreateFrame, "Frame", nil, ui.frame, "DisableUntrustedLayoutScriptsTemplate")
  if not ok or not host then
    return nil
  end
  host:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", ui.PAD, row.y)
  host:SetPoint("TOPRIGHT", ui.frame, "TOPRIGHT", -ui.PAD, row.y)
  host:SetHeight(row.y - row.barY + 3)
  return host
end

-- Everything the button needs is configured here, before the container
-- returns from AddAuraSlot: afterwards it denies addon code any access to the
-- button while auras are secret (DenyTaintedAccessWhenAurasAreSecret), so the
-- addon never touches the button or its widgets again.
local function InitializeButton(button, host, ui)
  button:ClearAllPoints()
  button:SetAllPoints(host)
  -- The window stays draggable over the plague rows.
  pcall(button.EnableMouse, button, false)

  local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
  text:SetWidth(ui.VALUE_WIDTH)
  ui.AdoptValueText(text)
  button:SetDurationText(text)

  local bar = CreateFrame("StatusBar", nil, button)
  bar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
  bar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
  bar:SetHeight(3)
  bar:SetStatusBarTexture(ui.WHITE)
  bar:SetStatusBarColor(ui.barColor[1], ui.barColor[2], ui.barColor[3], 1)
  local direction = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime
  button:SetDurationBar(bar, { direction = direction })
end

-- Creates the container once. Returns the status for the log. Any failure
-- leaves the container off and the rows on the modelled time.
function PlagueAuras.Setup(ui)
  if container then
    return status
  end
  local loaded, reason = LoadContainerAddOn()
  if not loaded then
    status = reason
    return status
  end
  local ok, created = pcall(CreateFrame, "AuraContainer", nil, ui.frame, "CustomAuraContainerTemplate")
  if not ok or not created then
    status = "create-failed"
    return status
  end
  for _, method in ipairs(REQUIRED_METHODS) do
    if type(created[method]) ~= "function" then
      created:Hide()
      status = "missing-" .. method
      return status
    end
  end
  local hosts = {}
  for _, row in ipairs(ui.plagueRows) do
    hosts[row.key] = CreateHost(ui, row)
    if not hosts[row.key] then
      created:Hide()
      status = "host-failed"
      return status
    end
  end
  created:SetAllPoints(ui.frame)
  created:SetUnit("target")
  local initFailed
  for _, row in ipairs(ui.plagueRows) do
    local host = hosts[row.key]
    local slotOk = pcall(created.AddAuraSlot, created, row.key, FILTER, {
      candidateFilters = { includeSpellIDs = { [row.spellID] = true } },
      initializeFrame = function(button)
        -- Runs inside Blizzard's container code: never let an error escape
        -- into it (it would surface as a Blizzard Lua error).
        if not pcall(InitializeButton, button, host, ui) then
          initFailed = true
        end
      end,
    })
    if not slotOk or initFailed then
      created:Hide()
      status = slotOk and "init-failed" or "slot-failed"
      return status
    end
  end
  if type(created.SetEnabled) == "function" then
    created:SetEnabled(true)
  end
  created:Show()
  container = created
  status = "ok"
  return status
end

function PlagueAuras.Status()
  return status
end

-- A setup that had to wait for the end of combat.
function PlagueAuras.IsDeferred()
  return status == "deferred"
end

function PlagueAuras.OnTargetChanged()
  if container then
    pcall(container.UpdateAllAuras, container)
  end
end

-- True when the plague rows show the container's values: the container runs
-- and the target is an enemy. With a friendly or no target the container
-- shows nothing and the rows fall back to the model.
function PlagueAuras.ShowsTarget()
  if not container then
    return false
  end
  -- Unit queries are not annotated as secret in 12.1; still never test a
  -- secret: an unknown answer keeps the container display.
  local exists = UnitExists("target")
  if ns.IsSecret(exists) then
    return true
  end
  if not exists then
    return false
  end
  local ok, canAttack = pcall(UnitCanAttack, "player", "target")
  if not ok then
    return false
  end
  if ns.IsSecret(canAttack) then
    return true
  end
  return canAttack == true
end
