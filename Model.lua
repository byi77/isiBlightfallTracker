local _, ns = ...

-- Estimation model. Inside combat the plague auras on enemies, the player's
-- stats and the damage meter are secret in 12.x, so nothing here reads them.
-- Inputs are (a) the player's own casts (UNIT_SPELLCAST_SUCCEEDED is plain for
-- "player") and (b) the plague spell descriptions, whose numbers are computed
-- live from the player's current stats and talents and are not annotated as
-- secret. Every input is checked for secrecy before use; if the description
-- turns secret or unreadable the estimate is switched off (fail closed).

local Model = {}
ns.Model = Model

local SPELL = {
  VIRULENT_PLAGUE = 191587,
  DREAD_PLAGUE = 1240996,
  BLIGHTFALL = 1271967,
  DARK_TRANSFORMATION = 1233448,
  OUTBREAK = 77575,
}
ns.SPELL = SPELL

-- Casts that extend both plagues (seconds). Several abilities exist under more
-- than one spell ID; all known variants are listed, the cast log shows which
-- one the client actually reports.
local EXTENSION_BY_SPELL = {
  [47541] = 1, -- Death Coil
  [445513] = 1, -- Death Coil (variant)
  [207317] = 1, -- Epidemic
  [1237172] = 1, -- Epidemic (variant)
  -- Forbidden Knowledge replaces Death Coil with Necrotic Coil and Epidemic
  -- with Graveyard; both run the same impact effects (SimC necrotic_coil_t /
  -- graveyard_t -> unholy_rp_impact_effects).
  [1242174] = 1, -- Necrotic Coil
  [383269] = 1, -- Graveyard
  [1247378] = 3, -- Putrefy (Blightburst)
  [1277016] = 3, -- Putrefy single target (Blightburst)
  [390220] = 3, -- Putrefy area (Blightburst)
  [433895] = 3, -- Vampiric Strike (Infliction of Sorrow)
  [434422] = 3, -- Vampiric Strike (variant)
}

-- Scourge Strike and Vampiric Strike apply Virulent Plague to their target when
-- it is not ticking (SimC scourge_strike_base_t::impact). Dread Plague is only
-- applied by Outbreak (or jumps on the host's death, which is not a cast).
local VIRULENT_PLAGUE_APPLIERS = {
  [55090] = true, -- Scourge Strike
  [433895] = true, -- Vampiric Strike
  [434422] = true, -- Vampiric Strike (variant)
}

-- Eternal Agony (390268, part of Dark Transformation): every Death Coil and
-- Epidemic cast while DT is active extends it by 1 s (SimC applies it per
-- cast in unholy_rp_execute_effects, not per hit).
local DT_EXTENDERS = {
  [47541] = true, -- Death Coil
  [445513] = true, -- Death Coil (variant)
  [207317] = true, -- Epidemic
  [1237172] = true, -- Epidemic (variant)
  [1242174] = true, -- Necrotic Coil (Forbidden Knowledge)
  [383269] = true, -- Graveyard (Forbidden Knowledge)
}
local ETERNAL_AGONY_SECONDS = 1

-- Epidemic only makes sense with several plagued enemies. Its casts are plain
-- and therefore a reliable multi-target marker even when the nameplate count
-- misses enemies (training dummies, hidden nameplates).
local EPIDEMIC_SPELLS = { [207317] = true, [1237172] = true, [383269] = true } -- 383269: Graveyard

local SOUL_REAPER_SPELLS = { [343294] = true, [448229] = true }
local SOUL_REAPER_DEBUFF_SECONDS = 8
local DARK_TRANSFORMATION_COOLDOWN = 45
local DARK_TRANSFORMATION_DURATION = 15
-- SimC applies the Soul Reaper rule only with at most 3 enemies (or a boss)
-- and only with the Reaping talent (377514) and Soul Reaper talented.
local SOUL_REAPER_RULE_MAX_ENEMIES = 3
local REAPING_TALENT = 377514
-- Soul Reaper debuff 1241521 effect #3: +20 % on Virulent/Dread Plague (Erupt).
local SOUL_REAPER_ERUPT_BONUS = 0.20

-- Returns true/false, or nil when the client offers no way to tell.
-- C_SpellBook.IsSpellKnown (12.x). The global IsPlayerSpell only exists in
-- Blizzard's deprecation fallbacks (CVar loadDeprecationFallbacks) and is the
-- last resort; without either the talent stays unknown (nil).
local function SpellKnownFunction()
  local spellBook = rawget(_G, "C_SpellBook")
  if type(spellBook) == "table" and type(spellBook.IsSpellKnown) == "function" then
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    return function(spellID)
      return spellBook.IsSpellKnown(spellID, bank)
    end
  end
  local legacy = rawget(_G, "IsPlayerSpell")
  if type(legacy) == "function" then
    return legacy
  end
  return nil
end

function Model.HasReapingTalent()
  local check = SpellKnownFunction()
  if not check then
    return nil
  end
  local ok, known = pcall(check, REAPING_TALENT)
  if not ok or ns.IsSecret(known) then
    return nil
  end
  return known == true
end
local SIGNAL_LEAD_SECONDS = 3 -- about two global cooldowns

ns.TRACKED_SPELLS = {}
for id in pairs(EXTENSION_BY_SPELL) do
  ns.TRACKED_SPELLS[id] = true
end
for id in pairs(SOUL_REAPER_SPELLS) do
  ns.TRACKED_SPELLS[id] = true
end
for id in pairs(VIRULENT_PLAGUE_APPLIERS) do
  ns.TRACKED_SPELLS[id] = true
end
for _, id in pairs(SPELL) do
  ns.TRACKED_SPELLS[id] = true
end

local state = {
  ready = false,
  vpExpires = nil,
  dpExpires = nil,
  duration = nil,
  vpTotal = nil,
  dpTotal = nil,
  tooltipStatus = "unknown",
  soulReaperEnds = nil,
  darkTransformationAt = nil,
  bossEncounter = false, -- between ENCOUNTER_START and ENCOUNTER_END
}
Model.state = state

-- Boss encounters (dungeon and raid bosses, set from ENCOUNTER_START /
-- ENCOUNTER_END) keep the Soul Reaper timing rule with adds, as in SimC.
function Model.SetBossEncounter(active)
  state.bossEncounter = active == true
end

-- Tooltip parsing -----------------------------------------------------------

local BIG_SUFFIXES = {
  { "^%s*[Mm]rd", 1e9 },
  { "^%s*[Bb]illion", 1e9 },
  { "^%s*[Mm]io", 1e6 },
  { "^%s*[Mm]illion", 1e6 },
}

local function TokenToNumber(token, following)
  for _, suffix in ipairs(BIG_SUFFIXES) do
    if following:find(suffix[1]) then
      local decimal = tonumber((token:gsub(",", ".")))
      return decimal and decimal * suffix[2] or nil
    end
  end
  return tonumber((token:gsub("[%.,]", "")))
end

-- Returns totalDamage, durationSeconds or nil plus a reason.
function Model.ParsePlagueDescription(text)
  if ns.IsSecret(text) then
    return nil, nil, "secret"
  end
  if type(text) ~= "string" or text == "" then
    return nil, nil, "empty"
  end

  local duration
  local durationStart
  for startPos, token, unit in text:gmatch("()(%d+[%.,]?%d*)%s*(%a+)") do
    local lowered = unit:lower()
    if lowered:find("^sek") or lowered:find("^sec") then
      duration = tonumber((token:gsub(",", ".")))
      durationStart = startPos
      break
    end
  end

  local best
  for startPos, token, endPos in text:gmatch("()(%d[%d%.,]*)()") do
    if startPos ~= durationStart then
      local value = TokenToNumber(token, text:sub(endPos, endPos + 12))
      if value and (not best or value > best) then
        best = value
      end
    end
  end

  if not duration or duration <= 0 then
    return nil, nil, "no-duration"
  end
  if not best or best <= 0 then
    return nil, nil, "no-damage"
  end
  return best, duration, "ok"
end

local function ReadDescription(spellID)
  if not (C_Spell and C_Spell.GetSpellDescription) then
    return nil
  end
  local ok, text = pcall(C_Spell.GetSpellDescription, spellID)
  if not ok then
    return nil
  end
  return text
end

-- Refreshes the live per-plague totals. Returns a log-ready table.
function Model.SampleTooltips()
  local vpText = ReadDescription(SPELL.VIRULENT_PLAGUE)
  local dpText = ReadDescription(SPELL.DREAD_PLAGUE)
  local vpTotal, vpDuration, vpReason = Model.ParsePlagueDescription(vpText)
  local dpTotal, dpDuration, dpReason = Model.ParsePlagueDescription(dpText)

  if vpReason == "ok" and dpReason == "ok" then
    state.vpTotal = vpTotal
    state.dpTotal = dpTotal
    state.duration = vpDuration
    state.tooltipStatus = "ok"
  else
    state.vpTotal = nil
    state.dpTotal = nil
    state.tooltipStatus = vpReason ~= "ok" and vpReason or dpReason
  end

  return {
    vpTotal = vpTotal,
    dpTotal = dpTotal,
    vpDuration = vpDuration,
    dpDuration = dpDuration,
    vpReason = vpReason,
    dpReason = dpReason,
    -- Raw text only when readable, so a parsing problem can be fixed offline.
    vpText = (vpReason ~= "secret") and ns.Plain(vpText) or "SECRET",
    dpText = (dpReason ~= "secret") and ns.Plain(dpText) or "SECRET",
  }
end

-- Cast handling ---------------------------------------------------------------

local function Remaining(expires, now)
  if not expires then
    return 0
  end
  local left = expires - now
  return left > 0 and left or 0
end

-- Returns a short tag describing what the cast changed (for the log).
function Model.OnPlayerCast(spellID, now)
  if spellID == SPELL.OUTBREAK then
    local duration = state.duration or 24
    state.vpExpires = now + duration
    state.dpExpires = now + duration
    return "plagues-applied"
  end
  if spellID == SPELL.DARK_TRANSFORMATION then
    state.ready = true
    state.darkTransformationAt = now
    state.dtEndsAt = now + DARK_TRANSFORMATION_DURATION
    state.epidemicInWindow = false
    state.nowReason = nil
    return "blightfall-ready"
  end
  if spellID == SPELL.BLIGHTFALL then
    state.ready = false
    state.nowReason = nil
    state.vpExpires = nil
    state.dpExpires = nil
    return "blightfall-consumed"
  end
  if SOUL_REAPER_SPELLS[spellID] then
    state.soulReaperEnds = now + SOUL_REAPER_DEBUFF_SECONDS
    return "soul-reaper-window"
  end
  -- Same order as the game: extensions only touch ticking plagues, then the
  -- strike applies a fresh Virulent Plague if none is ticking.
  local tags = {}
  if EPIDEMIC_SPELLS[spellID] and state.ready then
    -- Epidemic is only worth casting with several plagued enemies: treat the
    -- current Blightfall window as multi-target even if nameplates miss them.
    state.epidemicInWindow = true
  end
  if DT_EXTENDERS[spellID] and state.dtEndsAt and state.dtEndsAt > now then
    state.dtEndsAt = state.dtEndsAt + ETERNAL_AGONY_SECONDS
    table.insert(tags, "dt+" .. ETERNAL_AGONY_SECONDS)
  end
  local extension = EXTENSION_BY_SPELL[spellID]
  if extension then
    if Remaining(state.vpExpires, now) > 0 then
      state.vpExpires = state.vpExpires + extension
    end
    if Remaining(state.dpExpires, now) > 0 then
      state.dpExpires = state.dpExpires + extension
    end
    table.insert(tags, "extended+" .. extension)
  end
  if VIRULENT_PLAGUE_APPLIERS[spellID] and Remaining(state.vpExpires, now) <= 0 then
    state.vpExpires = now + (state.duration or 24)
    table.insert(tags, "vp-applied")
  end
  return #tags > 0 and table.concat(tags, ",") or nil
end

-- Talents change only out of combat; refreshed on activation, spec change and
-- combat start. Returns the value for the log.
function Model.RefreshTalents()
  state.hasReaping = Model.HasReapingTalent()
  return state.hasReaping
end

function Model.ResetCombatState()
  state.vpExpires = nil
  state.dpExpires = nil
  state.soulReaperEnds = nil
end

-- Calibration: integrates the tooltip damage rate over the time each plague
-- is modelled as ticking. After combat this is compared offline with the
-- damage meter's real plague tick damage (191587 / 1240996).
local calibration = {}
Model.calibration = calibration

function Model.ResetCalibration()
  calibration.vpUptime = 0
  calibration.dpUptime = 0
  calibration.vpExpected = 0
  calibration.dpExpected = 0
  calibration.maxEnemies = 0
  calibration.epidemicCasts = 0
  -- Post-combat Blightfall split (see Model.NoteEruptCast).
  calibration.strikeEruptExpected = 0
  calibration.strikeCasts = 0
  calibration.blightfallPredicted = 0
  calibration.blightfallCasts = 0
end

-- Blightfall shares its damage-meter rows (Virulent/Dread Plague Erupt) with
-- the erupts of Scourge Strike and Vampiric Strike. To split the post-combat
-- total, each strike's erupt is modelled from the live tooltip tick:
--   Scourge Strike: 35 % + Scourging rank 2 (65 %) = 100 % of one tick
--   Vampiric Strike: same, x (1 + 75 % Infliction of Sorrow)
-- (SimC scourge_strike_base_t; values from the 12.1.0 spell data.)
local STRIKE_ERUPT_MULT = { [55090] = 1.0, [433895] = 1.75, [434422] = 1.75 }
local TICKS_PER_DURATION = 8

function Model.NoteEruptCast(spellID, now)
  local mult = STRIKE_ERUPT_MULT[spellID]
  if not mult or state.tooltipStatus ~= "ok" then
    return
  end
  local erupt = 0
  if Remaining(state.vpExpires, now) > 0 then
    erupt = erupt + state.vpTotal * Model.factors.vp / TICKS_PER_DURATION
  end
  if Remaining(state.dpExpires, now) > 0 then
    erupt = erupt + state.dpTotal * Model.factors.vp / TICKS_PER_DURATION
  end
  calibration.strikeEruptExpected = calibration.strikeEruptExpected + erupt * mult
  calibration.strikeCasts = calibration.strikeCasts + 1
end

-- prediction: the headline estimate shown when Blightfall was pressed.
function Model.NoteBlightfallCast(prediction)
  calibration.blightfallCasts = calibration.blightfallCasts + 1
  calibration.blightfallPredicted = calibration.blightfallPredicted + (prediction or 0)
end

function Model.NoteCastForCalibration(spellID)
  if EPIDEMIC_SPELLS[spellID] then
    calibration.epidemicCasts = calibration.epidemicCasts + 1
  end
end

-- Learned ratio "real plague tick damage / tooltip expectation". The tooltip
-- misses target-side and proc multipliers; the damage meter (readable after
-- combat) supplies the truth. Persisted in SavedVariables.
local MIN_EXPECTED_FOR_LEARNING = 20000
local LEARN_RATE = 0.3

local factors = { vp = 1, dp = 1, samples = 0 }
Model.factors = factors

-- Bumped whenever the learning rules change, which drops factors that were
-- learned under the old rules (v1 learned from a multi-dummy fight that the
-- nameplate count saw as single-target).
local FACTORS_VERSION = 2
Model.FACTORS_VERSION = FACTORS_VERSION

-- Learned factors are clamped to 0.5 .. 10 (see Model.Learn); anything else in
-- the saved file (NaN, inf, wrong type) is damage and ignored.
local function IsFactor(value)
  return type(value) == "number" and value >= 0.5 and value <= 10
end

function Model.LoadFactors(saved)
  if type(saved) == "table" and saved.version == FACTORS_VERSION and IsFactor(saved.vp) and IsFactor(saved.dp) then
    local samples = saved.samples
    if type(samples) ~= "number" or samples ~= samples or samples < 0 or samples > 1e6 then
      samples = 0
    end
    factors.vp, factors.dp, factors.samples = saved.vp, saved.dp, math.floor(samples)
  end
end

-- snapshot: calibration copy taken at combat end. Returns a log table or nil.
function Model.Learn(snapshot, actualVP, actualDP)
  if snapshot.maxEnemies > 1 or (snapshot.epidemicCasts or 0) > 0 then
    return { skipped = "multi-target", maxEnemies = snapshot.maxEnemies, epidemicCasts = snapshot.epidemicCasts }
  end
  if not actualVP or not actualDP then
    return { skipped = "no-damage-meter-rows" }
  end
  if snapshot.vpExpected < MIN_EXPECTED_FOR_LEARNING or snapshot.dpExpected < MIN_EXPECTED_FOR_LEARNING then
    return { skipped = "too-little-uptime" }
  end
  local rawVP = math.min(math.max(actualVP / snapshot.vpExpected, 0.5), 10)
  local rawDP = math.min(math.max(actualDP / snapshot.dpExpected, 0.5), 10)
  if factors.samples == 0 then
    factors.vp, factors.dp = rawVP, rawDP
  else
    factors.vp = factors.vp + LEARN_RATE * (rawVP - factors.vp)
    factors.dp = factors.dp + LEARN_RATE * (rawDP - factors.dp)
  end
  factors.samples = factors.samples + 1
  return { rawVP = rawVP, rawDP = rawDP, vp = factors.vp, dp = factors.dp, samples = factors.samples }
end
Model.ResetCalibration()

function Model.Accumulate(elapsed, now)
  if not state.duration or state.duration <= 0 then
    return
  end
  if Remaining(state.vpExpires, now) > 0 then
    calibration.vpUptime = calibration.vpUptime + elapsed
    if state.vpTotal then
      calibration.vpExpected = calibration.vpExpected + state.vpTotal / state.duration * elapsed
    end
  end
  if Remaining(state.dpExpires, now) > 0 then
    calibration.dpUptime = calibration.dpUptime + elapsed
    if state.dpTotal then
      calibration.dpExpected = calibration.dpExpected + state.dpTotal / state.duration * elapsed
    end
  end
end

-- Counts attackable, living enemies in combat that have a nameplate. This is
-- an upper bound for the number of Virulent Plague targets: which enemies
-- actually carry the plague is secret.
-- Second return value: diagnostics (plates found / attackable+alive / secret
-- reads) so the log shows why the count is what it is.
function Model.CountEngagedEnemies()
  local count, plates, attackableAlive, secretReads = 0, 0, 0, 0
  for index = 1, 40 do
    local unit = "nameplate" .. index
    local ok, exists, attackable, dead, inCombat = pcall(function()
      return UnitExists(unit), UnitCanAttack("player", unit), UnitIsDead(unit), UnitAffectingCombat(unit)
    end)
    if ok then
      if
        ns.IsSecret(exists)
        or ns.IsSecret(attackable)
        or ns.IsSecret(dead)
        or ns.IsSecret(inCombat)
      then
        secretReads = secretReads + 1
      elseif exists then
        plates = plates + 1
        if attackable and not dead then
          attackableAlive = attackableAlive + 1
          if inCombat then
            count = count + 1
          end
        end
      end
    end
  end
  return count, { plates = plates, attackableAlive = attackableAlive, secretReads = secretReads }
end

local ENEMY_SCAN_INTERVAL = 0.5
local enemyCache = {}

-- Snapshot of everything the display and the log need.
function Model.Evaluate(now)
  local remVP = Remaining(state.vpExpires, now)
  local remDP = Remaining(state.dpExpires, now)
  local result = {
    ready = state.ready,
    remVP = remVP,
    remDP = remDP,
    tooltipStatus = state.tooltipStatus,
  }
  -- Scanning 40 nameplates every render is wasteful; refresh twice a second.
  if not enemyCache.at or now - enemyCache.at >= ENEMY_SCAN_INTERVAL or now < enemyCache.at then
    enemyCache.count, enemyCache.diag = Model.CountEngagedEnemies()
    enemyCache.at = now
  end
  result.enemies, result.enemyDiag = enemyCache.count, enemyCache.diag

  if state.tooltipStatus == "ok" and state.duration and state.duration > 0 then
    -- Extensions push the remaining time past the base duration; those are
    -- real extra ticks, so the remaining time is not capped.
    -- Dread Plague uses the Virulent Plague factor: both are shadow DoTs with
    -- the same multipliers, and the learned DP factor is inflated because the
    -- model misses Dread Plague jumping to a new host (uptime underestimated).
    -- factors.dp is still learned and logged for offline analysis.
    local dpPart = state.dpTotal * factors.vp * remDP / state.duration
    local vpPart = state.vpTotal * factors.vp * remVP / state.duration
    result.estimateSingle = 2 * (dpPart + vpPart)
    local targets = math.max(result.enemies, remVP > 0 and 1 or 0)
    result.estimateAll = 2 * (dpPart + vpPart * targets)

    -- Soul Reaper debuff (1241521, from Reaping): +20 % damage taken from
    -- both plague erupts, which is what Blightfall deals. It sits on the
    -- Soul Reaper target only, so it raises the single-target share once.
    local soulReaperActive = Remaining(state.soulReaperEnds, now) > 0
    if soulReaperActive and state.hasReaping ~= false then
      local bonus = result.estimateSingle * SOUL_REAPER_ERUPT_BONUS
      result.estimateSingle = result.estimateSingle + bonus
      result.estimateAll = result.estimateAll + bonus
      result.soulReaperBonus = true
    end
  end

  local soulReaperLeft = Remaining(state.soulReaperEnds, now)
  local dtReadyIn = state.darkTransformationAt
      and (state.darkTransformationAt + DARK_TRANSFORMATION_COOLDOWN - now)
    or nil
  result.soulReaperLeft = soulReaperLeft
  result.dtReadyIn = dtReadyIn

  local dtLeft = state.dtEndsAt and (state.dtEndsAt - now) or nil
  result.dtLeft = dtLeft
  -- Full window length including Eternal Agony extensions (for a progress bar).
  result.dtTotal = state.dtEndsAt and state.darkTransformationAt and (state.dtEndsAt - state.darkTransformationAt)
    or nil
  result.plagueDuration = state.duration

  -- Once a "now" rule fires the signal latches until Blightfall is cast, so
  -- the cue cannot flicker back to "charging" (and is announced once).
  if not state.ready then
    result.signal = "idle"
  elseif remVP <= 0 and remDP <= 0 then
    result.signal = "no-plagues"
  elseif state.nowReason then
    result.signal = state.nowReason
  else
    local reason
    if dtLeft and dtLeft <= SIGNAL_LEAD_SECONDS then
      -- Covers the end of the DT window and every moment after it.
      reason = "now-dt-ending"
    elseif
      soulReaperLeft > 0
      and soulReaperLeft <= SIGNAL_LEAD_SECONDS
      -- SimC: (active_enemies <= 3 | raid_event.pull.has_boss). Epidemic in
      -- the window stands for "more than 3" (nameplate counts can miss
      -- enemies); a boss encounter keeps the rule with any number of adds.
      and (state.bossEncounter or (result.enemies <= SOUL_REAPER_RULE_MAX_ENEMIES and not state.epidemicInWindow))
      and state.hasReaping ~= false
    then
      reason = "now-soul-reaper"
    elseif dtReadyIn and dtReadyIn <= SIGNAL_LEAD_SECONDS then
      reason = "now-dt-ready"
    elseif math.max(remVP, remDP) <= SIGNAL_LEAD_SECONDS then
      reason = "now-plagues-expiring"
    end
    if reason then
      state.nowReason = reason
      result.signal = reason
    else
      result.signal = "charging"
    end
  end
  return result
end
