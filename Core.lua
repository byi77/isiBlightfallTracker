local addonName, ns = ...

local Log = ns.Log
local Model = ns.Model
local SPELL = ns.SPELL
local L = ns.L

local UNHOLY_SPEC_ID = 252
local SAMPLE_INTERVAL = 5 -- seconds between periodic log snapshots in combat
local UI_INTERVAL = 0.1

local active = false
local inCombat = false
local lastSignal
local lastSample = 0
local combatIndex = 0

-- Helpers ---------------------------------------------------------------------

local function SpellName(spellID)
  if C_Spell and C_Spell.GetSpellName then
    local ok, name = pcall(C_Spell.GetSpellName, spellID)
    if ok then
      return ns.Plain(name)
    end
  end
  return nil
end

-- Error firewall: no handler of this addon may ever raise into the client.
-- Each failure is logged (first 5 per site); a site that keeps failing is
-- switched off so it cannot spam, and the window shows that it stopped.
local MAX_ERRORS_PER_SITE = 5
local errorCounts = {}
local disabledSites = {}

local function Guard(site, fn)
  return function(...)
    if disabledSites[site] then
      return
    end
    local ok, message = pcall(fn, ...)
    if not ok then
      local count = (errorCounts[site] or 0) + 1
      errorCounts[site] = count
      if count <= MAX_ERRORS_PER_SITE then
        Log.Add("error", { where = site, message = tostring(message), count = count })
      end
      if count >= MAX_ERRORS_PER_SITE then
        disabledSites[site] = true
        Log.Add("error", { where = site, message = "site disabled after repeated errors" })
      end
    end
  end
end
ns.disabledSites = disabledSites

local function SafeCall(fn, ...)
  local ok, a, b, c, d = pcall(fn, ...)
  if not ok then
    Log.Add("error", { where = "SafeCall", message = tostring(a) })
    return nil
  end
  return a, b, c, d
end

local function IsUnholy()
  local _, className = UnitClass("player")
  if className ~= "DEATHKNIGHT" then
    return false
  end
  local index = GetSpecialization and GetSpecialization()
  if not index then
    return false
  end
  local specID = GetSpecializationInfo(index)
  return specID == UNHOLY_SPEC_ID
end

local function RestrictionStates()
  local result = {}
  local api = rawget(_G, "C_RestrictedActions")
  local types = Enum and Enum.AddOnRestrictionType
  if type(api) ~= "table" or type(api.GetAddOnRestrictionState) ~= "function" or type(types) ~= "table" then
    result.available = false
    return result
  end
  for name, value in pairs(types) do
    local ok, stateValue = pcall(api.GetAddOnRestrictionState, value)
    result[name] = ok and ns.Plain(stateValue) or "ERROR"
  end
  return result
end

local function InstanceContext()
  local name, instanceType, difficultyID, _, _, _, _, mapID = GetInstanceInfo()
  local context = {
    instance = ns.Plain(name),
    instanceType = ns.Plain(instanceType),
    difficultyID = ns.Plain(difficultyID),
    mapID = ns.Plain(mapID),
  }
  if C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
    local ok, level = pcall(C_ChallengeMode.GetActiveKeystoneInfo)
    context.keystoneLevel = ok and ns.Plain(level) or nil
  end
  return context
end

-- Compact, locale-neutral number for the narrow window: 950, 38k, 1.27M.
local function FormatAmount(value)
  if not value then
    return "?"
  end
  if value >= 1e6 then
    return string.format("%.2fM", value / 1e6)
  elseif value >= 1e3 then
    return string.format("%.0fk", value / 1e3)
  end
  return tostring(math.floor(value + 0.5))
end

-- Self-test: records what the client allows right now -------------------------

local function SelfTest(reason)
  local secrecy = {}
  local secrets = rawget(_G, "C_Secrets")
  if type(secrets) == "table" then
    for _, id in ipairs({ SPELL.VIRULENT_PLAGUE, SPELL.DREAD_PLAGUE, SPELL.BLIGHTFALL }) do
      local aura = secrets.GetSpellAuraSecrecy and SafeCall(secrets.GetSpellAuraSecrecy, id)
      local cast = secrets.GetSpellCastSecrecy and SafeCall(secrets.GetSpellCastSecrecy, id)
      secrecy[tostring(id)] = { aura = ns.Plain(aura), cast = ns.Plain(cast) }
    end
    if secrets.ShouldAurasBeSecret then
      secrecy.aurasSecretNow = ns.Plain(SafeCall(secrets.ShouldAurasBeSecret))
    end
    if secrets.ShouldUnitStatsBeSecret then
      secrecy.statsSecretNow = ns.Plain(SafeCall(secrets.ShouldUnitStatsBeSecret))
    end
  end

  local override
  if C_Spell and C_Spell.GetOverrideSpell then
    override = ns.Plain(SafeCall(C_Spell.GetOverrideSpell, SPELL.DARK_TRANSFORMATION))
  end

  local tooltip = Model.SampleTooltips()
  local hasReaping = Model.RefreshTalents()
  Log.Add("selftest", {
    reason = reason,
    reaping = hasReaping == nil and "unknown" or hasReaping,
    inCombat = InCombatLockdown(),
    restrictions = RestrictionStates(),
    context = InstanceContext(),
    secrecy = secrecy,
    dtOverride = override,
    tooltip = tooltip,
  })
  return tooltip
end

-- Post-combat damage-meter readout (only plain values are logged) -------------

local readDamageMeterGuarded -- forward declaration, used by the retry timer

-- Damage-meter rows that also carry Blightfall's damage.
local ERUPT_SPELLS = { [1241167] = true, [1241171] = true } -- Virulent / Dread Plague (Erupt)
-- Result of the last post-combat split, shown in the window.
local lastSplit

-- Live erupt total from the built-in damage meter. Returns display text and a
-- status. In combat the amounts are secret: they are never compared or added,
-- only formatted with AbbreviateNumbers and concatenated (both allowed for
-- secrets), then handed to SetText. If the spell IDs themselves are secret
-- the erupt rows cannot be identified and nothing is shown.
local function ReadEruptsLive()
  local api = rawget(_G, "C_DamageMeter")
  if type(api) ~= "table" or type(api.GetCombatSessionSourceFromType) ~= "function" then
    return nil, "no-api"
  end
  local ok, source = pcall(api.GetCombatSessionSourceFromType, 1, 0, UnitGUID("player"))
  if not ok then
    return nil, "call-error"
  end
  if ns.IsSecret(source) or type(source) ~= "table" then
    return nil, "source-secret"
  end
  local okSpells, spells = pcall(function()
    return source.combatSpells
  end)
  if not okSpells or ns.IsSecret(spells) or type(spells) ~= "table" then
    return nil, "spells-secret"
  end

  local plainSum, secretParts, found, idSecret = 0, {}, false, false
  local iterOk = pcall(function()
    for _, spell in ipairs(spells) do
      local id = spell.spellID
      if ns.IsSecret(id) then
        idSecret = true
      elseif ERUPT_SPELLS[id] then
        found = true
        local amount = spell.totalAmount
        if ns.IsSecret(amount) then
          table.insert(secretParts, AbbreviateNumbers(amount))
        else
          plainSum = plainSum + amount
        end
      end
    end
  end)
  if not iterOk then
    return nil, "iterate-error"
  end
  if #secretParts > 0 then
    local text = secretParts[1]
    for index = 2, #secretParts do
      text = text .. "+" .. secretParts[index]
    end
    if plainSum > 0 then
      text = text .. "+" .. FormatAmount(plainSum)
    end
    return text, "secret-passthrough"
  end
  if found then
    return "~" .. FormatAmount(plainSum), "plain"
  end
  if idSecret then
    return nil, "ids-secret"
  end
  return "0", "none-yet"
end
ns.ReadEruptsLive = ReadEruptsLive

local function ReadDamageMeter(attempt, snapshot)
  local api = rawget(_G, "C_DamageMeter")
  if type(api) ~= "table" or type(api.GetCombatSessionSourceFromType) ~= "function" then
    Log.Add("dm", { status = "unavailable" })
    return
  end
  local guid = UnitGUID("player")
  -- (sessionType, type, sourceGUID): 1 = Current session, 0 = DamageDone.
  local ok, source = pcall(api.GetCombatSessionSourceFromType, 1, 0, guid)
  local spells, sourceTotal
  if ok and not ns.IsSecret(source) and type(source) == "table" then
    -- A masked table passes type() and raises on access; read inside pcall.
    local readFields, fieldSpells, fieldTotal = pcall(function()
      return source.combatSpells, source.totalAmount
    end)
    if readFields then
      spells, sourceTotal = fieldSpells, ns.Plain(fieldTotal)
    end
  end
  -- Secret check first: a boolean test on a secret value is not allowed.
  if ns.IsSecret(spells) or type(spells) ~= "table" then
    if attempt < 6 then
      C_Timer.After(2, function()
        readDamageMeterGuarded(attempt + 1, snapshot)
      end)
    else
      Log.Add("dm", { status = ok and "secret-or-empty" or "error", attempt = attempt })
    end
    return
  end

  local rows, masked = {}, 0
  local actualVP, actualDP
  local eruptTotal = 0
  local readOk = pcall(function()
    for _, spell in ipairs(spells) do
      local id, amount = spell.spellID, spell.totalAmount
      if ns.IsSecret(id) or ns.IsSecret(amount) then
        masked = masked + 1
      else
        table.insert(rows, { id = id, name = SpellName(id), amount = amount })
        if id == SPELL.VIRULENT_PLAGUE then
          actualVP = (actualVP or 0) + amount
        elseif id == SPELL.DREAD_PLAGUE then
          actualDP = (actualDP or 0) + amount
        elseif ERUPT_SPELLS[id] then
          eruptTotal = eruptTotal + amount
        end
      end
    end
  end)
  -- Blightfall's share of the erupt rows = total minus the modelled strike
  -- erupts. Average per cast, compared with the average prediction.
  if readOk and snapshot and masked == 0 and (snapshot.blightfallCasts or 0) > 0 then
    local derived = math.max(0, eruptTotal - snapshot.strikeEruptExpected)
    lastSplit = {
      casts = snapshot.blightfallCasts,
      actualPerCast = derived / snapshot.blightfallCasts,
      predictedPerCast = snapshot.blightfallPredicted / snapshot.blightfallCasts,
    }
    Log.Add("blightfall_split", {
      combat = combatIndex,
      eruptTotal = eruptTotal,
      strikeEruptExpected = math.floor(snapshot.strikeEruptExpected),
      derivedBlightfall = math.floor(derived),
      casts = snapshot.blightfallCasts,
      actualPerCast = math.floor(lastSplit.actualPerCast),
      predictedPerCast = math.floor(lastSplit.predictedPerCast),
    })
  end
  if readOk and snapshot and masked == 0 then
    local learned = Model.Learn(snapshot, actualVP, actualDP)
    learned.combat = combatIndex
    learned.actualVP, learned.actualDP = actualVP, actualDP
    Log.Add("calibration", learned)
    if not learned.skipped then
      local factors = Model.factors
      Log.DB().factors =
        { version = Model.FACTORS_VERSION, vp = factors.vp, dp = factors.dp, samples = factors.samples }
    end
  end
  Log.Add("dm", {
    status = readOk and "ok" or "read-error",
    attempt = attempt,
    combat = combatIndex,
    masked = masked,
    total = sourceTotal,
    spells = rows,
  })
end
readDamageMeterGuarded = Guard("ReadDamageMeter", ReadDamageMeter)
local selfTestGuarded = Guard("SelfTest", SelfTest)

-- Display -----------------------------------------------------------------------
-- Compact widget. Calm, structured look: cool blue/white palette, 1px borders,
-- alpha-only pulse with ADD blend.
--
-- Two-column table: labels left-aligned, values right-aligned in a fixed
-- column so all numbers line up. Fixed row grid (y = offset from the top
-- edge); every text is single line without word wrap, so a long value is
-- truncated instead of spilling into the next row. Diagnostics live in the
-- log and in /ibt, not here.
--
-- Readability: every text has a drop shadow. Above 50 % background
-- transparency the text also gets an outline and the muted colours brighten,
-- so the window stays readable over a bright game world.

local WHITE = "Interface\\Buttons\\WHITE8x8"
local FRAME_WIDTH = 170
local PAD = 6
local INNER = FRAME_WIDTH - 2 * PAD
local VALUE_WIDTH = 44
local LABEL_WIDTH = INNER - VALUE_WIDTH
local ROW = {
  number = -8, -- icon + headline estimate (21 pt, right-aligned)
  signal = -38,
  enemies = -54,
  perTarget = -66,
  dt = -80,
  dtBar = -91,
  vp = -97, -- Virulent Plague / Dread Plague: real time on the target
  vpBar = -108, -- (PlagueAuras.lua), modelled time as fallback
  dp = -114,
  dpBar = -125,
  timing = -133,
  separator = -147,
  erupts = -153, -- erupt total (damage meter; locked in combat)
  real = -165, -- last combat: derived Blightfall hit (estimated)
  predicted = -177, -- last combat: average prediction
}
local FRAME_HEIGHT = 193
local COLORS = {
  background = { 0.035, 0.045, 0.065 }, -- alpha from the transparency option
  border = { 0.20, 0.25, 0.34, 1 },
  title = { 0.72, 0.80, 0.92 },
  muted = { 0.55, 0.60, 0.68 }, -- overwritten in place, see TEXT_TONES
  dim = { 0.36, 0.40, 0.46 }, -- overwritten in place, see TEXT_TONES
  number = { 1, 1, 1 },
  numberInactive = { 0.42, 0.45, 0.50 },
  barTrack = { 1, 1, 1, 0.07 },
  barDT = { 0.36, 0.62, 1.00 },
  barPlagues = { 0.60, 0.50, 1.00 },
  now = { 0.55, 0.90, 1.00 },
  warn = { 0.95, 0.70, 0.40 },
}
-- Muted/dim text and bar track on a solid vs. a see-through background.
local TEXT_TONES = {
  solid = { muted = { 0.55, 0.60, 0.68 }, dim = { 0.36, 0.40, 0.46 }, barTrack = 0.07 },
  clear = { muted = { 0.80, 0.84, 0.90 }, dim = { 0.62, 0.66, 0.72 }, barTrack = 0.25 },
}
-- Background transparency above which the see-through tones and outlines apply.
local CLEAR_THRESHOLD = 0.5

local function Color(c)
  return c[1], c[2], c[3], c[4] or 1
end

local frame = CreateFrame("Frame", "isiBlightfallTrackerFrame", UIParent, "BackdropTemplate")
frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetClampedToScreen(true)
frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
frame:SetBackdropColor(COLORS.background[1], COLORS.background[2], COLORS.background[3], 0.7)
frame:SetBackdropBorderColor(Color(COLORS.border))
frame:Hide()

-- State accent: a thin bar along the left edge.
local accent = frame:CreateTexture(nil, "ARTWORK")
accent:SetTexture(WHITE)
accent:SetPoint("TOPLEFT", 1, -1)
accent:SetPoint("BOTTOMLEFT", 1, 1)
accent:SetWidth(2)

-- "Now" highlight: a 1px cool frame over the border that pulses in alpha only.
local nowFrame = CreateFrame("Frame", nil, frame)
nowFrame:SetAllPoints()
nowFrame:Hide()
do
  local function Edge(p1, p2, horizontal)
    local t = nowFrame:CreateTexture(nil, "OVERLAY")
    t:SetTexture(WHITE)
    t:SetBlendMode("ADD")
    t:SetVertexColor(Color(COLORS.now))
    t:SetPoint(p1)
    t:SetPoint(p2)
    if horizontal then
      t:SetHeight(1)
    else
      t:SetWidth(1)
    end
  end
  Edge("TOPLEFT", "TOPRIGHT", true)
  Edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
  Edge("TOPLEFT", "BOTTOMLEFT", false)
  Edge("TOPRIGHT", "BOTTOMRIGHT", false)
end
local pulse = nowFrame:CreateAnimationGroup()
pulse:SetLooping("BOUNCE")
do
  local fade = pulse:CreateAnimation("Alpha")
  fade:SetFromAlpha(0.55)
  fade:SetToAlpha(1.0)
  fade:SetDuration(1.2)
end

-- Every font string with its font, so ApplyAppearance can switch outlines.
local texts = {}

-- Single-line text anchored to a row. justify "RIGHT" anchors to the right edge.
local function Text(template, size, flags, y, justify, inset, width)
  local text = frame:CreateFontString(nil, "OVERLAY", template)
  local path = text:GetFont()
  if path and size then
    pcall(text.SetFont, text, path, size, flags or "")
  end
  texts[#texts + 1] = { text = text, path = path, size = size, flags = flags or "" }
  text:SetShadowColor(0, 0, 0, 1)
  text:SetShadowOffset(1, -1)
  if justify == "RIGHT" then
    text:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, y)
  else
    text:SetPoint("TOPLEFT", frame, "TOPLEFT", inset or PAD, y)
  end
  text:SetJustifyH(justify or "LEFT")
  text:SetWordWrap(false)
  text:SetWidth(width or INNER)
  return text
end

-- Styles a font string created outside this file (the aura container's
-- duration texts) like the table values, once. It is NOT kept in the
-- readability list: after the hand-over the container denies addon code any
-- access while auras are secret (Mythic+, combat), so it gets the outline
-- for every transparency right away and is never touched again.
local function AdoptValueText(text)
  local path = text:GetFont()
  if path then
    pcall(text.SetFont, text, path, 9, "OUTLINE")
  end
  text:SetShadowColor(0, 0, 0, 1)
  text:SetShadowOffset(1, -1)
  text:SetTextColor(Color(COLORS.title))
  text:SetJustifyH("RIGHT")
  text:SetWordWrap(false)
end

-- Rows with a fixed label (locale key), re-labelled on a language switch and
-- re-coloured on a transparency change.
local labelledRows = {}

-- One table row: label left (muted), value right (bright).
local function TableRow(y, labelKey)
  local row = { labelKey = labelKey }
  row.label = Text("GameFontHighlightSmall", 9, nil, y, "LEFT", PAD, LABEL_WIDTH)
  row.label:SetTextColor(Color(COLORS.muted))
  row.label:SetText(labelKey and L[labelKey] or "")
  if labelKey then
    labelledRows[#labelledRows + 1] = row
  end
  row.value = Text("GameFontHighlightSmall", 9, nil, y, "RIGHT", nil, VALUE_WIDTH)
  row.value:SetTextColor(Color(COLORS.title))
  return row
end

-- Header: spell icon left, headline number right-aligned.
local ICON_SIZE = 22
local icon = frame:CreateTexture(nil, "ARTWORK")
icon:SetSize(ICON_SIZE, ICON_SIZE)
icon:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, ROW.number + 1)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
do
  local texture
  if C_Spell and C_Spell.GetSpellTexture then
    local ok, value = pcall(C_Spell.GetSpellTexture, SPELL.BLIGHTFALL)
    if ok and not ns.IsSecret(value) then
      texture = value
    end
  end
  icon:SetTexture(texture or 136133)
end
local estimateLine =
  Text("GameFontHighlightLarge", 21, "OUTLINE", ROW.number, "RIGHT", nil, INNER - ICON_SIZE - 5)

local signalLine = Text("GameFontNormal", 10, nil, ROW.signal)

local enemiesRow = TableRow(ROW.enemies, "ROW_ENEMIES")
local perTargetRow = TableRow(ROW.perTarget, "ROW_PER_TARGET")

local barTracks = {}

local function Bar(y, barY, labelKey, color)
  local row = TableRow(y, labelKey)
  local bar = CreateFrame("StatusBar", nil, frame)
  bar:SetStatusBarTexture(WHITE)
  bar:SetStatusBarColor(Color(color))
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  bar:SetHeight(3)
  bar:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, barY)
  bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, barY)
  local track = bar:CreateTexture(nil, "BACKGROUND")
  track:SetTexture(WHITE)
  track:SetAllPoints()
  track:SetVertexColor(Color(COLORS.barTrack))
  barTracks[#barTracks + 1] = track
  bar.valueText = row.value
  return bar
end

local dtBar = Bar(ROW.dt, ROW.dtBar, "BAR_DT", COLORS.barDT)
local vpBar = Bar(ROW.vp, ROW.vpBar, "BAR_VP", COLORS.barPlagues)
local dpBar = Bar(ROW.dp, ROW.dpBar, "BAR_DP", COLORS.barPlagues)

local timingRow = TableRow(ROW.timing)

-- Separator, then the "what really happened" rows.
local resultSeparator = frame:CreateTexture(nil, "ARTWORK")
resultSeparator:SetTexture(WHITE)
resultSeparator:SetVertexColor(Color(COLORS.border))
resultSeparator:SetHeight(1)
resultSeparator:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, ROW.separator)
resultSeparator:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, ROW.separator)

local eruptsRow = TableRow(ROW.erupts, "ROW_ERUPTS")
local realRow = TableRow(ROW.real, "ROW_REAL")
local predictedRow = TableRow(ROW.predicted, "ROW_PREDICTED")

-- Signal text (locale key) + colour per state; "now" states share the cool
-- highlight. Keys are resolved at render time, so a language switch applies
-- on the next update.
local SIGNAL_TEXT = {
  idle = { "SIGNAL_IDLE", COLORS.dim },
  ["no-plagues"] = { "SIGNAL_NO_PLAGUES", COLORS.warn },
  charging = { "SIGNAL_CHARGING", COLORS.barDT },
  ["now-dt-ending"] = { "SIGNAL_NOW_DT_ENDING", COLORS.now },
  ["now-soul-reaper"] = { "SIGNAL_NOW_SOUL_REAPER", COLORS.now },
  ["now-dt-ready"] = { "SIGNAL_NOW_DT_READY", COLORS.now },
  ["now-plagues-expiring"] = { "SIGNAL_NOW_PLAGUES_EXPIRING", COLORS.now },
}

-- Remaining time in whole seconds, rounded up like a countdown, so the table
-- matches the plague rows filled by the game's own aura display ("19 s").
local function Seconds(value)
  return string.format(L.SECONDS_FMT, math.ceil(value))
end

local function SetBar(bar, left, total)
  if left and left > 0 and total and total > 0 then
    bar:SetMinMaxValues(0, total)
    bar:SetValue(math.min(left, total))
    bar.valueText:SetText(Seconds(left))
  else
    bar:SetValue(0)
    bar.valueText:SetText("-")
  end
end

-- Last rendered state, reported by /ibt (diagnostics are not on screen).
local lastRendered
-- Live erupt display text and the status of the last read (logged on change).
local liveText, liveStatus
-- Statuses for which ReadEruptsLive returned display text.
local LIVE_HAS_TEXT = { plain = true, ["secret-passthrough"] = true, ["none-yet"] = true }

local function Render(result)
  lastRendered = result
  local signal = SIGNAL_TEXT[result.signal] or SIGNAL_TEXT.idle
  local isNow = type(result.signal) == "string" and result.signal:find("^now%-") ~= nil
  signalLine:SetText(L[signal[1]])
  signalLine:SetTextColor(Color(signal[2]))
  accent:SetVertexColor(Color(signal[2]))
  if isNow then
    if not nowFrame:IsShown() then
      nowFrame:Show()
      pulse:Play()
    end
  elseif nowFrame:IsShown() then
    pulse:Stop()
    nowFrame:Hide()
  end

  -- Headline: the expected Blightfall damage. With several enemies the
  -- all-target value leads (upper bound: which enemies carry Virulent Plague
  -- is secret), with one enemy the single-target value.
  if result.estimateSingle then
    local multi = result.enemies > 1
    local headline = multi and result.estimateAll or result.estimateSingle
    local hasValue = headline > 0
    estimateLine:SetText(hasValue and ("~" .. FormatAmount(headline)) or "-")
    -- Only bright once Blightfall is actually available (after DT).
    estimateLine:SetTextColor(Color(result.ready and COLORS.number or COLORS.numberInactive))
    enemiesRow.label:SetText(L.ROW_ENEMIES)
    enemiesRow.value:SetText(tostring(math.max(result.enemies, 1)))
    perTargetRow.value:SetText(hasValue and ("~" .. FormatAmount(result.estimateSingle)) or "-")
  else
    estimateLine:SetText("-")
    estimateLine:SetTextColor(Color(COLORS.numberInactive))
    enemiesRow.label:SetText(L.ESTIMATE_OFF)
    enemiesRow.value:SetText("")
    perTargetRow.value:SetText("-")
  end

  SetBar(dtBar, result.dtLeft, result.dtTotal)
  -- Plague rows: with a hostile target the real debuff time comes from
  -- Blizzard's aura container (PlagueAuras.lua) and the modelled values stay
  -- empty underneath; without one, or without the container, the model shows.
  local Auras = ns.PlagueAuras
  if Auras and Auras.ShowsTarget() then
    vpBar:SetValue(0)
    vpBar.valueText:SetText("")
    dpBar:SetValue(0)
    dpBar.valueText:SetText("")
  else
    local duration = result.plagueDuration or 0
    SetBar(vpBar, result.remVP, math.max(duration, result.remVP))
    SetBar(dpBar, result.remDP, math.max(duration, result.remDP))
  end

  -- One status row: while the Soul Reaper debuff runs (and adds 20 % to the
  -- estimate) show that, otherwise the Dark Transformation cooldown.
  if result.soulReaperLeft > 0 then
    timingRow.label:SetText(result.soulReaperBonus and L.ROW_SOUL_REAPER_BONUS or L.ROW_SOUL_REAPER)
    timingRow.value:SetText(Seconds(result.soulReaperLeft))
    timingRow.label:SetTextColor(Color(COLORS.now))
    timingRow.value:SetTextColor(Color(COLORS.now))
  elseif result.dtReadyIn then
    timingRow.label:SetText(L.ROW_DT_CD)
    timingRow.value:SetText(
      result.dtReadyIn > 0 and Seconds(result.dtReadyIn) or L.VALUE_READY
    )
    timingRow.label:SetTextColor(Color(COLORS.muted))
    timingRow.value:SetTextColor(Color(COLORS.title))
  else
    timingRow.label:SetText("")
    timingRow.value:SetText("")
  end

  -- Erupt total. liveText may be a secret string: decide on the (always plain)
  -- status, never test or compare the value itself.
  if LIVE_HAS_TEXT[liveStatus] then
    eruptsRow.value:SetText(liveText)
  elseif inCombat then
    -- Verified at the dummy (2026-10-01): the meter's spell IDs are secret in
    -- combat, so the erupt rows cannot be identified until combat ends.
    eruptsRow.value:SetText(L.VALUE_LOCKED)
  else
    eruptsRow.value:SetText("-")
  end

  -- Last combat: Blightfall's derived share per cast (an estimate: other
  -- erupt sources are modelled, not measured) vs the average prediction.
  if lastSplit then
    realRow.value:SetText("~" .. FormatAmount(lastSplit.actualPerCast))
    predictedRow.value:SetText("~" .. FormatAmount(lastSplit.predictedPerCast))
  else
    realRow.value:SetText("-")
    predictedRow.value:SetText("-")
  end
end

-- Diagnostics line for /ibt (mode, calibration, log size).
local function DiagnosticsText()
  local entries, dropped = Log.Count()
  local factors = Model.factors
  local estimating = lastRendered and lastRendered.estimateSingle ~= nil
  local logText = L.STATE_OFF
  if Log.IsEnabled() then
    logText = tostring(entries) .. (dropped > 0 and string.format(L.DROPPED_FMT, dropped) or "")
  end
  return string.format(
    L.DIAG_FMT,
    estimating and L.MODE_ESTIMATE or L.MODE_TIMING,
    factors.samples > 0 and string.format("x%.1f (%d)", factors.vp, factors.samples) or L.CALIB_NEW,
    logText,
    (ns.Settings.Get("combatOnly") and L.WINDOW_COMBAT_ONLY or L.WINDOW_ALWAYS)
      .. (ns.Settings.Get("readyOnly") and L.WINDOW_READY_ONLY_SUFFIX or "")
  )
end

-- Voice cue when the signal turns to "now". Plays once per switch into a
-- now-state; sound and channel are chosen in the options (see Sound.lua).
local function IsNowSignal(signal)
  return type(signal) == "string" and signal:find("^now%-") ~= nil
end

local function PlayGoSound(signal)
  local played, choice, channel = ns.Sound.Play(false)
  if choice then
    Log.Add("sound", { signal = signal, played = played, choice = choice, channel = channel })
  end
end

local elapsedSinceRender = 0
local LIVE_READ_INTERVAL = 1
local lastLiveRead = 0
local function OnUpdate(_, elapsed)
  elapsedSinceRender = elapsedSinceRender + elapsed
  if elapsedSinceRender < UI_INTERVAL then
    return
  end
  local now = GetTime()
  if inCombat then
    Model.Accumulate(elapsedSinceRender, now)
  end
  elapsedSinceRender = 0

  if inCombat and now - lastSample >= SAMPLE_INTERVAL then
    lastSample = now
    local tooltip = Model.SampleTooltips()
    local result = Model.Evaluate(now)
    Log.Add("sample", {
      combat = combatIndex,
      vpTotal = tooltip.vpTotal,
      dpTotal = tooltip.dpTotal,
      tooltip = tooltip.vpReason .. "/" .. tooltip.dpReason,
      remVP = ns.Round(result.remVP, 1),
      remDP = ns.Round(result.remDP, 1),
      est1 = result.estimateSingle and math.floor(result.estimateSingle) or nil,
      estAll = result.estimateAll and math.floor(result.estimateAll) or nil,
      enemies = result.enemies,
      plates = result.enemyDiag.plates,
      attackableAlive = result.enemyDiag.attackableAlive,
      secretReads = result.enemyDiag.secretReads,
      signal = result.signal,
    })
  end

  local result = Model.Evaluate(now)
  if inCombat and result.enemies > Model.calibration.maxEnemies then
    Model.calibration.maxEnemies = result.enemies
  end
  if result.signal ~= lastSignal then
    Log.Add("signal", { from = lastSignal, to = result.signal, combat = combatIndex })
    if inCombat and IsNowSignal(result.signal) and not IsNowSignal(lastSignal) then
      PlayGoSound(result.signal)
    end
    lastSignal = result.signal
  end
  if now - lastLiveRead >= LIVE_READ_INTERVAL then
    lastLiveRead = now
    local status
    liveText, status = ReadEruptsLive()
    if status ~= liveStatus then
      Log.Add("live_erupt", { status = status, from = liveStatus, inCombat = inCombat, combat = combatIndex })
      liveStatus = status
    end
  end
  Render(result)
end

local guardedUpdate = Guard("OnUpdate", OnUpdate)
frame:SetScript("OnUpdate", function(self, elapsed)
  guardedUpdate(self, elapsed)
  if ns.disabledSites.OnUpdate then
    -- Stop updating for good and say so instead of erroring every frame.
    self:SetScript("OnUpdate", nil)
    signalLine:SetText(L.SIGNAL_STOPPED)
    signalLine:SetTextColor(0.9, 0.4, 0.4)
  end
end)

-- Position: the window is anchored by its top-left corner, stored in UIParent
-- units ({ left = x, top = y }), so a size change keeps the left edge in place
-- and the window grows to the right and down.
local function TopLeft()
  local left, top = frame:GetLeft(), frame:GetTop()
  if type(left) ~= "number" or type(top) ~= "number" then
    return nil
  end
  local scale = frame:GetScale()
  return left * scale, top * scale
end

local function PlaceTopLeft(left, top)
  local scale = frame:GetScale()
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / scale, top / scale)
end

local function SavePosition()
  local left, top = TopLeft()
  if left and Log.DB() then
    Log.DB().position = { left = left, top = top }
  end
  return left, top
end

frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local left, top = SavePosition()
  if left then
    PlaceTopLeft(left, top)
  end
end)

-- Saved coordinates must be finite numbers (no NaN / +-inf from a damaged
-- file) within a generous screen range.
local function IsCoordinate(value)
  return type(value) == "number" and value == value and value > -10000 and value < 10000
end

local ANCHOR_POINTS = {
  TOPLEFT = true,
  TOP = true,
  TOPRIGHT = true,
  LEFT = true,
  CENTER = true,
  RIGHT = true,
  BOTTOMLEFT = true,
  BOTTOM = true,
  BOTTOMRIGHT = true,
}

-- A damaged saved position must not break the login: anything invalid or
-- rejected by the client falls back to the default position.
local function RestorePosition()
  local db = Log.DB()
  local pos = db and db.position
  if type(pos) ~= "table" then
    return
  end
  local ok
  if IsCoordinate(pos.left) and IsCoordinate(pos.top) then
    ok = pcall(PlaceTopLeft, pos.left, pos.top)
  elseif ANCHOR_POINTS[pos[1]] and ANCHOR_POINTS[pos[2]] and IsCoordinate(pos[3]) and IsCoordinate(pos[4]) then
    -- Up to 0.6.0: { point, relativePoint, x, y }; converted on the next save.
    ok = pcall(function()
      frame:ClearAllPoints()
      frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    end)
  end
  if not ok then
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    db.position = nil
    Log.Add("position_reset", { reason = "invalid saved position" })
  end
end

local function ResetPosition()
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
  if Log.DB() then
    Log.DB().position = nil
  end
end

-- Text outline and tones for the current background transparency.
local function ApplyReadability(transparency)
  local clear = transparency > CLEAR_THRESHOLD
  local tones = clear and TEXT_TONES.clear or TEXT_TONES.solid
  for i = 1, 3 do
    COLORS.muted[i] = tones.muted[i]
    COLORS.dim[i] = tones.dim[i]
  end
  COLORS.barTrack[4] = tones.barTrack
  for _, t in ipairs(texts) do
    if t.path and t.size then
      local flags = t.flags
      if clear and flags == "" then
        flags = "OUTLINE"
      end
      pcall(t.text.SetFont, t.text, t.path, t.size, flags)
    end
  end
  for _, row in ipairs(labelledRows) do
    row.label:SetTextColor(Color(COLORS.muted))
  end
  for _, track in ipairs(barTracks) do
    track:SetVertexColor(Color(COLORS.barTrack))
  end
end

-- Appearance from the options: size, background transparency, border and
-- lock. A locked window ignores the mouse entirely (no drag, click-through).
-- The size changes around the top-left corner (see TopLeft).
local function ApplyAppearance()
  local Settings = ns.Settings
  local scale = Settings.Get("scale")
  local left, top
  if frame:GetScale() ~= scale then
    left, top = TopLeft()
  end
  frame:SetScale(scale)
  if left then
    PlaceTopLeft(left, top)
    SavePosition()
  end
  local transparency = Settings.Get("bgTransparency")
  local bg = COLORS.background
  frame:SetBackdropColor(bg[1], bg[2], bg[3], 1 - transparency)
  ApplyReadability(transparency)
  local border = COLORS.border
  frame:SetBackdropBorderColor(border[1], border[2], border[3], Settings.Get("showBorder") and 1 or 0)
  frame:EnableMouse(not Settings.Get("locked"))
end

-- Option "combat only" (off by default): the window is then shown only while
-- in combat. Option "ready only" (off by default): shown only while Blightfall
-- is available (from Dark Transformation until Blightfall is cast). Both can
-- be combined. The frame is not secure, so showing and hiding it in combat is
-- allowed. A hidden frame gets no OnUpdate, so the cast handler calls this
-- whenever readiness may have changed.
local function UpdateVisibility()
  local Settings = ns.Settings
  local combatOk = inCombat or not Settings.Get("combatOnly")
  local readyOk = Model.state.ready or not Settings.Get("readyOnly")
  frame:SetShown(active and combatOk and readyOk)
end

-- Language from the options: fixed row labels now, everything else on the
-- next render.
local function ApplyLanguage()
  ns.SetLanguage(ns.Settings.Get("language"))
  for _, row in ipairs(labelledRows) do
    row.label:SetText(L[row.labelKey])
  end
  if lastRendered then
    Render(lastRendered)
  end
end

-- Used by the options page (Options.lua) and the aura container
-- (PlagueAuras.lua).
ns.UI = {
  frame = frame,
  PAD = PAD,
  VALUE_WIDTH = VALUE_WIDTH,
  WHITE = WHITE,
  barColor = COLORS.barPlagues,
  plagueRows = {
    { key = "vp", spellID = SPELL.VIRULENT_PLAGUE, y = ROW.vp, barY = ROW.vpBar },
    { key = "dp", spellID = SPELL.DREAD_PLAGUE, y = ROW.dp, barY = ROW.dpBar },
  },
  AdoptValueText = AdoptValueText,
  ApplyAppearance = ApplyAppearance,
  ApplyLanguage = ApplyLanguage,
  UpdateVisibility = UpdateVisibility,
  ResetPosition = ResetPosition,
}

local function UpdateActivation(reason)
  local shouldBeActive = IsUnholy()
  if shouldBeActive == active then
    return
  end
  active = shouldBeActive
  Log.Add("activation", { active = active, reason = reason })
  UpdateVisibility()
  if active then
    SelfTest("activation")
  end
end

-- Events (registered statically in the main chunk) ------------------------------

local events = CreateFrame("Frame")

local function SafeRegister(eventName)
  local ok = pcall(events.RegisterEvent, events, eventName)
  if not ok then
    Log.Add("error", { where = "RegisterEvent", event = eventName })
  end
end

SafeRegister("PLAYER_LOGIN")
SafeRegister("PLAYER_ENTERING_WORLD")
SafeRegister("PLAYER_SPECIALIZATION_CHANGED")
SafeRegister("PLAYER_REGEN_DISABLED")
SafeRegister("PLAYER_REGEN_ENABLED")
SafeRegister("ENCOUNTER_START")
SafeRegister("ENCOUNTER_END")
SafeRegister("CHALLENGE_MODE_START")
SafeRegister("CHALLENGE_MODE_COMPLETED")
SafeRegister("ADDON_RESTRICTION_STATE_CHANGED")
SafeRegister("PLAYER_TARGET_CHANGED")
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")

local function OnPlayerCast(spellID)
  if ns.IsSecret(spellID) then
    Log.Add("cast", { spellID = "SECRET", combat = combatIndex })
    return
  end
  local now = GetTime()
  local tracked = ns.TRACKED_SPELLS[spellID]

  -- Snapshot the estimate before the cast changes the model: for Blightfall
  -- this is the prediction that the damage-meter readout is compared against.
  local before
  if spellID == SPELL.BLIGHTFALL then
    Model.SampleTooltips()
    before = Model.Evaluate(now)
  end

  if inCombat then
    -- Before the model update: a strike erupts the plagues that tick now.
    Model.NoteEruptCast(spellID, now)
    if before then
      local headline = before.enemies > 1 and before.estimateAll or before.estimateSingle
      Model.NoteBlightfallCast(headline)
    end
  end
  local wasReady = Model.state.ready
  local effect = Model.OnPlayerCast(spellID, now)
  if Model.state.ready ~= wasReady then
    -- "Ready only" window: Dark Transformation shows it, Blightfall hides it.
    UpdateVisibility()
    -- Render on the next frame instead of showing the stale last state.
    elapsedSinceRender = UI_INTERVAL
  end
  if inCombat then
    Model.NoteCastForCalibration(spellID)
  end
  if inCombat or tracked then
    local entry = {
      spellID = spellID,
      name = SpellName(spellID),
      effect = effect,
      combat = combatIndex,
    }
    if before then
      entry.est1 = before.estimateSingle and math.floor(before.estimateSingle) or nil
      entry.estAll = before.estimateAll and math.floor(before.estimateAll) or nil
      entry.remVP = ns.Round(before.remVP, 1)
      entry.remDP = ns.Round(before.remDP, 1)
      entry.enemies = before.enemies
      entry.signal = before.signal
      entry.soulReaperLeft = ns.Round(before.soulReaperLeft, 1)
    end
    Log.Add("cast", entry)
  end
end

local function OnEvent(_, event, ...)
  if event == "PLAYER_LOGIN" then
    Log.InitDB()
    if Log.IsEnabled() then
      Log.StartSession()
    end
    Model.LoadFactors(Log.DB().factors)
    ApplyLanguage()
    RestorePosition()
    ApplyAppearance()
    if ns.PlagueAuras then
      Log.Add("plague_auras", { status = ns.PlagueAuras.Setup(ns.UI) })
    end
    if ns.Options then
      ns.Options.Register()
    end
    if C_Spell and C_Spell.RequestLoadSpellData then
      pcall(C_Spell.RequestLoadSpellData, SPELL.VIRULENT_PLAGUE)
      pcall(C_Spell.RequestLoadSpellData, SPELL.DREAD_PLAGUE)
    end
    UpdateActivation("login")
    return
  end
  if event == "PLAYER_TARGET_CHANGED" then
    if ns.PlagueAuras then
      ns.PlagueAuras.OnTargetChanged()
    end
    return
  end
  -- Boss state is tracked for every spec, so a spec change during an
  -- encounter cannot leave it stale; a loading screen always ends it.
  if event == "ENCOUNTER_START" or event == "ENCOUNTER_END" or event == "PLAYER_ENTERING_WORLD" then
    Model.SetBossEncounter(event == "ENCOUNTER_START")
  end
  if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" then
    UpdateActivation(event)
    if active then
      Log.Add("zone", InstanceContext())
    end
    return
  end
  if not active then
    return
  end

  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    local _, _, spellID = ...
    OnPlayerCast(spellID)
  elseif event == "PLAYER_REGEN_DISABLED" then
    inCombat = true
    UpdateVisibility()
    combatIndex = combatIndex + 1
    lastSample = 0
    Model.ResetCalibration()
    SelfTest("combat-start")
    -- The combat restriction is still "activating" at PLAYER_REGEN_DISABLED;
    -- a second probe shows what is secret once it is fully active.
    local probedCombat = combatIndex
    C_Timer.After(1.5, function()
      if inCombat and combatIndex == probedCombat then
        selfTestGuarded("combat+1.5s")
      end
    end)
  elseif event == "PLAYER_REGEN_ENABLED" then
    inCombat = false
    UpdateVisibility()
    if ns.PlagueAuras and ns.PlagueAuras.IsDeferred() then
      Log.Add("plague_auras", { status = ns.PlagueAuras.Setup(ns.UI) })
    end
    local calibration = Model.calibration
    Log.Add("combat_end", {
      combat = combatIndex,
      restrictions = RestrictionStates(),
      vpUptime = ns.Round(calibration.vpUptime, 1),
      dpUptime = ns.Round(calibration.dpUptime, 1),
      vpExpected = math.floor(calibration.vpExpected),
      dpExpected = math.floor(calibration.dpExpected),
      maxEnemies = calibration.maxEnemies,
      epidemicCasts = calibration.epidemicCasts,
      strikeEruptExpected = math.floor(calibration.strikeEruptExpected),
      strikeCasts = calibration.strikeCasts,
      blightfallPredicted = math.floor(calibration.blightfallPredicted),
      blightfallCasts = calibration.blightfallCasts,
    })
    local snapshot = {
      vpExpected = calibration.vpExpected,
      dpExpected = calibration.dpExpected,
      maxEnemies = calibration.maxEnemies,
      epidemicCasts = calibration.epidemicCasts,
      strikeEruptExpected = calibration.strikeEruptExpected,
      blightfallPredicted = calibration.blightfallPredicted,
      blightfallCasts = calibration.blightfallCasts,
    }
    Model.ResetCombatState()
    C_Timer.After(1.5, function()
      readDamageMeterGuarded(1, snapshot)
    end)
  elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
    local restrictionType, restrictionState = ...
    Log.Add("restriction", { type = ns.Plain(restrictionType), state = ns.Plain(restrictionState) })
  else
    local a, b, c = ...
    Log.Add("event", { name = event, a = ns.Plain(a), b = ns.Plain(b), c = ns.Plain(c) })
    if event == "CHALLENGE_MODE_START" or event == "ENCOUNTER_START" then
      SelfTest(event)
    end
  end
end

-- Per-event guard sites, so one failing event cannot silence the others.
local guardedByEvent = {}
events:SetScript("OnEvent", function(self, event, ...)
  local handler = guardedByEvent[event]
  if not handler then
    handler = Guard("OnEvent:" .. tostring(event), OnEvent)
    guardedByEvent[event] = handler
  end
  handler(self, event, ...)
end)

-- Optional slash command; nothing is required for normal use. -----------------

SLASH_ISIBLIGHTFALL1 = "/ibt"
SlashCmdList.ISIBLIGHTFALL = Guard("Slash", function(message)
  message = (message or ""):lower()
  if message == "reset" then
    ResetPosition()
  elseif message == "options" or message == "optionen" or message == "config" then
    if not (ns.Options and ns.Options.Open()) then
      print(addonName .. ": " .. L.OPTIONS_UNAVAILABLE)
    end
  elseif message == "sound" then
    local enabled = not ns.Settings.Get("soundEnabled")
    ns.Settings.Set("soundEnabled", enabled)
    print(addonName .. ": " .. (enabled and L.SOUND_ON or L.SOUND_OFF))
    if enabled then
      ns.Sound.Play(true)
    end
  elseif message == "log on" or message == "log an" then
    Log.SetEnabled(true)
    print(addonName .. ": " .. L.LOG_ON)
    SelfTest("log-enabled")
  elseif message == "log off" or message == "log aus" then
    Log.SetEnabled(false)
    print(addonName .. ": " .. L.LOG_OFF)
  elseif message == "combat on" or message == "combat an" then
    ns.Settings.Set("combatOnly", true)
    UpdateVisibility()
    print(addonName .. ": " .. L.COMBAT_ONLY_ON)
  elseif message == "combat off" or message == "combat aus" then
    ns.Settings.Set("combatOnly", false)
    UpdateVisibility()
    print(addonName .. ": " .. L.COMBAT_ONLY_OFF)
  elseif message == "ready on" or message == "bereit an" then
    ns.Settings.Set("readyOnly", true)
    UpdateVisibility()
    print(addonName .. ": " .. L.READY_ONLY_ON)
  elseif message == "ready off" or message == "bereit aus" then
    ns.Settings.Set("readyOnly", false)
    UpdateVisibility()
    print(addonName .. ": " .. L.READY_ONLY_OFF)
  elseif message == "test" then
    local tooltip = SelfTest("manual")
    print(addonName .. ": " .. string.format(L.SELFTEST_FMT, tooltip.vpReason, tooltip.dpReason))
    if not Log.IsEnabled() then
      print(addonName .. ": " .. L.SELFTEST_NOLOG)
    end
  else
    print(addonName .. ": " .. L.HELP)
    print(addonName .. ": " .. DiagnosticsText())
  end
end)
