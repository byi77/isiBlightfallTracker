---@diagnostic disable: undefined-global, lowercase-global, duplicate-set-field, assign-type-mismatch, redefined-local
-- Test script: runs outside WoW with standard Lua and stubs WoW globals.
local ns = {}
local function load(path) assert(loadfile(path))("isiBlightfallTracker", ns) end
GetTime = function() return 0 end
UnitExists = function(u) return u == "nameplate1" or u == "nameplate2" or u == "nameplate3" end
UnitCanAttack = function() return true end
UnitIsDead = function() return false end
UnitAffectingCombat = function() return true end
C_Spell = { GetSpellDescription = function(id)
  if id == 191587 then return "im Verlauf von 18 Sek. 12.610 Schattenschaden verursacht." end
  return "im Verlauf von 18 Sek. 48.168 Schattenschaden verursacht. Explodiert, 11.435 Schattenschaden, 1 Wirt."
end }
load(arg[1] .. "/Log.lua"); load(arg[1] .. "/Model.lua")
local M = ns.Model
local function check(cond, msg) if not cond then print("FAIL " .. msg); os.exit(1) end print("PASS " .. msg) end
M.SampleTooltips()
M.OnPlayerCast(77575, 0)          -- Outbreak at t=0 -> 18 s
M.OnPlayerCast(1233448, 1)        -- Dark Transformation -> ready
local r = M.Evaluate(1)
check(r.ready and r.signal == "charging", "ready and charging after DT")
check(math.abs(r.remVP - 17) < 1e-9, "VP remaining 17s")
-- Hotfix 2026-10-07: Blightfall deals 100 % of the remaining plague damage (was 200 %).
check(M.BLIGHTFALL_REMAINING_SHARE == 1.0, "Blightfall share is 100 % of the remaining plague damage")
local expected1 = (48168 + 12610) * 17 / 18
check(math.abs(r.estimateSingle - expected1) < 1e-6, "single-target estimate = (DP+VP)*rem/dur")
check(r.enemies == 3 and math.abs(r.estimateAll - (48168 + 12610 * 3) * 17 / 18) < 1e-6, "all-target estimate uses 3 enemies")
M.OnPlayerCast(47541, 2)          -- Death Coil +1
check(math.abs(M.Evaluate(2).remVP - 17) < 1e-9, "Death Coil extends by 1s")
M.OnPlayerCast(343294, 5)         -- Soul Reaper window 8s -> ends 13
check(M.Evaluate(8).signal == "charging", "no signal while Soul Reaper has 5s left")
check(M.Evaluate(10.5).signal == "charging", "Soul Reaper ending stays silent with more than 3s of DT left")
M.OnPlayerCast(1271967, 11)       -- Blightfall consumes
local after = M.Evaluate(11)
check(not after.ready and after.remVP == 0 and after.signal == "idle", "Blightfall consumes plagues and readiness")
-- Log case from 2026-10-01: Blightfall at 31.8 consumed, Scourge Strike at 35.36 re-applied VP.
M.OnPlayerCast(55090, 20)
local r2 = M.Evaluate(20)
check(math.abs(r2.remVP - 18) < 1e-9 and r2.remDP == 0, "Scourge Strike re-applies VP only")
M.OnPlayerCast(433895, 21)        -- Vampiric Strike while VP ticks: +3, no reset
check(math.abs(M.Evaluate(21).remVP - 20) < 1e-9, "Vampiric Strike extends a ticking VP by 3s")
M.ResetCombatState(); M.ResetCalibration()
M.OnPlayerCast(77575, 30)
M.Accumulate(9, 39)
check(math.abs(M.calibration.vpExpected - 12610 / 18 * 9) < 1e-6 and M.calibration.dpUptime == 9, "calibration integrates tooltip rate over uptime")
-- Learning with the real numbers from session 3 (2026-10-01, single dummy).
local learned = M.Learn({ vpExpected = 121134, dpExpected = 203680, maxEnemies = 1 }, 355247, 690052)
check(math.abs(learned.vp - 355247 / 121134) < 1e-9 and math.abs(learned.dp - 690052 / 203680) < 1e-9, "first sample sets factors (VP x2.93, DP x3.39)")
check(M.Learn({ vpExpected = 1e6, dpExpected = 1e6, maxEnemies = 4 }, 1, 1).skipped == "multi-target", "multi-target fights are not learned")
local stateBefore = M.factors.vp
M.Learn({ vpExpected = 100000, dpExpected = 100000, maxEnemies = 1 }, 200000, 200000)
check(math.abs(M.factors.vp - (stateBefore + 0.3 * (2 - stateBefore))) < 1e-9, "later samples blend with rate 0.3")
M.ResetCombatState()
M.OnPlayerCast(77575, 100); M.OnPlayerCast(47541, 100); M.OnPlayerCast(47541, 100) -- 18 + 2 = 20s
local r3 = M.Evaluate(100)
check(math.abs(r3.estimateSingle - (48168 + 12610) * M.factors.vp * 20 / 18) < 1e-6, "estimate applies the VP factor to both plagues, remaining time uncapped")
-- 0.1.3: Epidemic casts mark a fight as multi-target even if nameplates show one enemy.
M.ResetCalibration()
M.NoteCastForCalibration(207317)
local skip = M.Learn({ vpExpected = 232621, dpExpected = 291965, maxEnemies = 1, epidemicCasts = M.calibration.epidemicCasts }, 1567754, 1374123)
check(skip.skipped == "multi-target", "fight with Epidemic is not learned (session 5 numbers)")
M.factors.vp, M.factors.dp, M.factors.samples = 1, 1, 0
M.LoadFactors({ vp = 6.74, dp = 4.71, samples = 1 })
check(M.factors.vp == 1 and M.factors.samples == 0, "unversioned (v1) factors are dropped")
M.LoadFactors({ version = M.FACTORS_VERSION, vp = 2.9, dp = 3.4, samples = 1 })
check(M.factors.vp == 2.9 and M.factors.dp == 3.4, "current-version factors load")
local _, diag = M.CountEngagedEnemies()
check(diag.plates == 3 and diag.attackableAlive == 3, "enemy diagnostics count plates")
-- 0.1.6: replay of the 2026-10-01 key pattern (DT, Soul Reaper 1s later).
local function Replay(enemyCount)
  UnitExists = function(u) return tonumber(u:match("%d+")) <= enemyCount end
  M.ResetCombatState()
  M.OnPlayerCast(77575, 500)               -- plagues
  M.OnPlayerCast(1233448, 500)             -- DT at 500 -> window ends 515
  M.OnPlayerCast(343294, 501)              -- Soul Reaper -> ends 509
  for t = 501, 508 do M.OnPlayerCast(47541, t) end -- Death Coils keep plagues up
end
Replay(8)
check(M.Evaluate(506.5).signal == "charging", "8 enemies: Soul Reaper rule stays silent (SimC: <=3 enemies)")
check(M.Evaluate(519.9).signal == "charging", "8 enemies: 8 Death Coils extend DT to 523, still charging at 519.9")
check(M.Evaluate(520.1).signal == "now-dt-ending", "8 enemies: now 2.9s before the extended DT ends")
check(M.Evaluate(525).signal == "now-dt-ending", "signal stays latched after DT ended (523) until Blightfall")
M.OnPlayerCast(1271967, 531)
check(M.Evaluate(531).signal == "idle", "Blightfall clears the latch")
Replay(2)
check(M.Evaluate(503).signal == "charging", "DT then Soul Reaper: no early signal after 2s")
check(M.Evaluate(504).signal == "charging", "DT then Soul Reaper: no early signal after 3s")
check(M.Evaluate(506.1).signal == "charging", "2 enemies: Soul Reaper expiry cannot bypass extended DT")
check(M.Evaluate(507).signal == "charging", "early Soul Reaper expiry does not latch a signal")
check(M.Evaluate(519.9).signal == "charging", "single target waits for the extended DT end window")
check(M.Evaluate(520).signal == "now-dt-ending", "expired Soul Reaper: DT signals at exactly 3s left")
-- Eternal Agony only extends a running DT.
M.ResetCombatState()
M.OnPlayerCast(1233448, 600)               -- DT ends 615
M.OnPlayerCast(207317, 601)                -- Epidemic +1 -> 616
check(math.abs(M.Evaluate(601).dtLeft - 15) < 1e-9, "Epidemic during DT extends it by 1s")
M.OnPlayerCast(47541, 617)                 -- after DT ended: no effect
check(M.Evaluate(617).dtLeft < 0, "Death Coil after DT ended does not revive it")
-- 0.6.0: Forbidden Knowledge replacements (Necrotic Coil 1242174, Graveyard
-- 383269) extend plagues and DT like Death Coil / Epidemic.
M.ResetCombatState()
M.OnPlayerCast(77575, 700)                 -- plagues 18 s -> 718
M.OnPlayerCast(1233448, 700)               -- DT ends 715
M.OnPlayerCast(1242174, 701)               -- Necrotic Coil +1
M.OnPlayerCast(383269, 702)                -- Graveyard +1
local fk = M.Evaluate(702)
check(math.abs(fk.remVP - 18) < 1e-9 and math.abs(fk.remDP - 18) < 1e-9, "Necrotic Coil and Graveyard extend both plagues by 1s each")
check(math.abs(fk.dtLeft - 15) < 1e-9, "Necrotic Coil and Graveyard extend DT (Eternal Agony)")
M.OnPlayerCast(1271967, 703)               -- clear the window
-- 0.2.1: replay of the 2026-10-01 14:15 dummy session (DT 37.0, SR 38.4, Epidemic in the window).
local function Window(withEpidemic, reaping)
  IsPlayerSpell = function(id) return id == 377514 and reaping end
  M.RefreshTalents()
  UnitExists = function() return false end   -- dummies: no counted nameplates
  M.ResetCombatState()
  M.OnPlayerCast(1271967, 30)                -- clear any latch from earlier tests
  M.OnPlayerCast(77575, 36)
  M.OnPlayerCast(1233448, 37)
  M.OnPlayerCast(343294, 38.4)               -- Soul Reaper ends 46.4
  if withEpidemic then M.OnPlayerCast(207317, 40) end
end
Window(true, true)
check(M.Evaluate(43.5).signal == "charging", "Epidemic in the DT window disables the Soul Reaper rule")
Window(false, false)
check(M.Evaluate(43.5).signal == "charging", "without Reaping the Soul Reaper rule stays off")
Window(false, true)
check(M.Evaluate(43.5).signal == "charging", "single target + Reaping still waits for DT to end")
-- SimC: (active_enemies <= 3 | boss in the pull). A boss encounter keeps the
-- Soul Reaper rule with adds (Epidemic in the window, many nameplates).
M.SetBossEncounter(true)
Window(true, true)
check(M.Evaluate(43.5).signal == "charging", "boss encounter cannot bypass the DT end guard")
Window(true, false)
check(M.Evaluate(43.5).signal == "charging", "boss encounter without Reaping: no Soul Reaper rule")
M.SetBossEncounter(false)
Window(true, true)
check(M.Evaluate(43.5).signal == "charging", "after the encounter: Epidemic disables the rule again")
-- Both expiry windows must overlap; all previous talent/enemy guards remain.
local function Overlap(enemyCount, withEpidemic, reaping, boss)
  M.SetBossEncounter(boss)
  IsPlayerSpell = function(id) return id == 377514 and reaping end
  M.RefreshTalents()
  UnitExists = function(u) return tonumber(u:match("%d+")) <= enemyCount end
  M.ResetCombatState()
  M.OnPlayerCast(77575, 550)
  M.OnPlayerCast(1233448, 550) -- DT ends 565
  M.OnPlayerCast(448229, 558) -- alternate Soul Reaper spell ends 566
  if withEpidemic then M.OnPlayerCast(207317, 559) end -- DT ends 566
end
Overlap(2, false, true, false)
check(M.Evaluate(561.999).signal == "charging", "just outside DT's 3s window: no Soul Reaper signal")
check(M.Evaluate(562).signal == "now-dt-ending", "DT can signal before Soul Reaper enters its own 3s window")
Overlap(2, false, true, false)
check(M.Evaluate(563).signal == "now-soul-reaper", "both windows overlap: Soul Reaper signal is allowed")
check(M.Evaluate(567).signal == "now-soul-reaper", "overlapping Soul Reaper signal stays latched")
M.OnPlayerCast(1271967, 568)
check(M.Evaluate(568).signal == "idle", "Blightfall clears the overlapping Soul Reaper signal")
Overlap(8, true, true, true)
check(M.Evaluate(562.999).signal == "charging", "boss + Epidemic: extension delays Soul Reaper signal")
check(M.Evaluate(563).signal == "now-soul-reaper", "boss + adds: both windows overlap at exactly 3s")
Overlap(8, true, true, false)
check(M.Evaluate(563).signal == "now-dt-ending", "outside bosses: adds/Epidemic keep the Soul Reaper guard")
Overlap(2, false, false, false)
check(M.Evaluate(563).signal == "now-dt-ending", "without Reaping: only the DT reason is allowed")
Overlap(2, false, true, false)
M.OnPlayerCast(47541, 560) -- DT ends 566
M.OnPlayerCast(47541, 561) -- DT ends 567
check(M.Evaluate(563).signal == "charging", "Death Coil extensions postpone an overlapping Soul Reaper signal")
check(M.Evaluate(564).signal == "now-soul-reaper", "Soul Reaper may signal when extended DT reaches 3s")
IsPlayerSpell = nil
check(M.HasReapingTalent() == nil, "missing talent API reports unknown")
-- 12.x: C_SpellBook.IsSpellKnown (player bank) wins over the deprecated global.
local bankSeen
C_SpellBook = { IsSpellKnown = function(id, bank) bankSeen = bank; return id == 377514 end }
IsPlayerSpell = function() return false end
check(M.HasReapingTalent() == true and bankSeen == 0, "C_SpellBook.IsSpellKnown used with the player spell bank")
C_SpellBook = nil
IsPlayerSpell = nil
-- 0.2.2: log sample 14:15 t=34 (tooltip VP 19543, DP 46149, rem 14.1s, factors 2.49/6.39).
M.factors.vp, M.factors.dp, M.factors.samples = 2.49, 6.39, 2
UnitExists = function() return false end
C_Spell.GetSpellDescription = function(id)
  if id == 191587 then return "im Verlauf von 18 Sek. 19.543 Schattenschaden verursacht." end
  return "im Verlauf von 18 Sek. 46.149 Schattenschaden verursacht. 1 Wirt."
end
M.SampleTooltips(); M.ResetCombatState()
M.OnPlayerCast(77575, 700)
local r4 = M.Evaluate(703.9) -- 14.1 s left
check(math.abs(r4.estimateSingle - (19543 + 46149) * 2.49 * 14.1 / 18) < 1e-6, "pull-start estimate drops from 269k to ~128k (100 % share)")
print(("   (value: %d)"):format(math.floor(r4.estimateSingle)))
-- 0.2.3: Soul Reaper debuff adds 20 % to the single-target share while active (Reaping known).
IsPlayerSpell = function(id) return id == 377514 end; M.RefreshTalents()
UnitExists = function(u) return tonumber(u:match("%d+")) <= 3 end
M.factors.vp = 1
M.ResetCombatState(); M.OnPlayerCast(77575, 800); M.OnPlayerCast(343294, 800) -- SR until 808
local withSR = M.Evaluate(804)
local base = (46149 + 19543) * 14 / 18
check(math.abs(withSR.estimateSingle - base * 1.2) < 1e-6 and withSR.soulReaperBonus, "single target +20% while Soul Reaper debuff is up")
local baseAll = (46149 + 19543 * 3) * 14 / 18
check(math.abs(withSR.estimateAll - (baseAll + base * 0.2)) < 1e-6, "all-target adds the bonus once (SR target only)")
local after = M.Evaluate(809)
check(not after.soulReaperBonus and math.abs(after.estimateSingle - (46149 + 19543) * 9 / 18) < 1e-6, "bonus disappears when the debuff ends")
IsPlayerSpell = function() return false end; M.RefreshTalents()
M.ResetCombatState(); M.OnPlayerCast(77575, 900); M.OnPlayerCast(343294, 900)
check(not M.Evaluate(904).soulReaperBonus, "no bonus without Reaping")
-- 0.4.1: strike erupt model for the post-combat Blightfall split.
M.factors.vp = 1
C_Spell.GetSpellDescription = function(id)
  if id == 191587 then return "im Verlauf von 18 Sek. 16.000 Schattenschaden verursacht." end
  return "im Verlauf von 18 Sek. 40.000 Schattenschaden verursacht. 1 Wirt."
end
M.SampleTooltips(); M.ResetCombatState(); M.ResetCalibration()
M.NoteEruptCast(55090, 1000)                      -- no plagues yet: nothing to erupt
check(M.calibration.strikeEruptExpected == 0, "strike without plagues erupts nothing")
M.OnPlayerCast(77575, 1000)
M.NoteEruptCast(55090, 1001)                      -- (16000 + 40000) / 8 = 7000
check(math.abs(M.calibration.strikeEruptExpected - 7000) < 1e-6, "Scourge Strike erupts one tick of both plagues")
M.NoteEruptCast(433895, 1002)                     -- x1.75 = 12250
check(math.abs(M.calibration.strikeEruptExpected - 19250) < 1e-6 and M.calibration.strikeCasts == 3, "Vampiric Strike erupts 175 % (3 strikes counted, 1 without plagues)")
M.NoteBlightfallCast(500000); M.NoteBlightfallCast(300000)
check(M.calibration.blightfallCasts == 2 and M.calibration.blightfallPredicted == 800000, "Blightfall predictions are summed per combat")

-- Dread Plague with its own (different) duration: applied, estimated and
-- integrated with that duration, not Virulent Plague's.
C_Spell = { GetSpellDescription = function(id)
  if id == 191587 then return "im Verlauf von 18 Sek. 18.000 Schattenschaden verursacht." end
  return "im Verlauf von 24 Sek. 48.000 Schattenschaden verursacht. 1 Wirt."
end }
M.ResetCombatState()
M.SampleTooltips()
M.OnPlayerCast(77575, 100)
local rd = M.Evaluate(100)
check(math.abs(rd.remVP - 18) < 1e-9 and math.abs(rd.remDP - 24) < 1e-9, "Outbreak applies each plague with its own duration")
check(math.abs(rd.estimateSingle - (48000 * 24 / 24 + 18000 * 18 / 18) * M.factors.vp) < 1e-6, "DP share uses the DP duration")
check(rd.dpDuration == 24 and rd.plagueDuration == 18, "both durations reported for the bars")
M.ResetCalibration()
M.Accumulate(1, 100)
check(math.abs(M.calibration.dpExpected - 2000) < 1e-6 and math.abs(M.calibration.vpExpected - 1000) < 1e-6, "calibration integrates each plague at its own rate")

-- Putrefy with Blightburst (SimC trigger_blightburst): applies the plagues
-- Blightfall consumed, extends ticking ones by 3 s, and its erupt (35 % of
-- the next 3 s) shares the erupt rows with Blightfall.
M.ResetCombatState()
M.OnPlayerCast(77575, 200)        -- Outbreak: VP 18 s, DP 24 s
M.OnPlayerCast(1233448, 200)      -- Dark Transformation
M.OnPlayerCast(1271967, 201)      -- Blightfall consumes both
local rb = M.Evaluate(201)
check(rb.remVP == 0 and rb.remDP == 0, "Blightfall consumed the plagues")
M.ResetCalibration()
M.NoteEruptCast(1247378, 202)
check(M.calibration.strikeEruptExpected == 0, "Putrefy without plagues erupts nothing")
M.OnPlayerCast(1247378, 202)      -- Putrefy re-applies
local rp = M.Evaluate(202)
check(math.abs(rp.remVP - 18) < 1e-9 and math.abs(rp.remDP - 24) < 1e-9, "Putrefy applies both plagues, no extra 3 s on a fresh plague")
M.NoteEruptCast(1247378, 203)
local putrefyErupt = (18000 * 0.35 * 3 / 18 + 48000 * 0.35 * 3 / 24) * M.factors.vp
check(math.abs(M.calibration.strikeEruptExpected - putrefyErupt) < 1e-6, "Putrefy erupt = 35 % of the next 3 s of each plague")
M.OnPlayerCast(1247378, 203)
check(math.abs(M.Evaluate(203).remVP - 20) < 1e-9, "Putrefy extends a ticking plague by 3 s")
