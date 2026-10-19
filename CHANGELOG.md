# Changelog

## 2026-10-19 - Version 0.7.9

### Added
- The tracker only switches on with the Blightfall talent. On an Unholy build without
  Blightfall (for example a solo build) it stays off: no window, no voice cue.
  Talent and loadout changes are picked up at once, so it comes back by itself when
  Blightfall is talented again. Player request.
- The talent is found in the active loadout by spell ID or by its localized name. If the
  loadout cannot be read, the tracker stays on (fail open), and a Blightfall cast always
  switches it on until the next talent or spec change.
- `/ibt` says when the tracker is off because Blightfall is not talented.
- The self-test and activation log entries record the Blightfall talent check.

The Death Knight helpers (Soul Reaper/Putrefy crosses, ghoul reminder, horse sounds)
are not affected by the talent and keep following their own options.

## 2026-10-14 - Version 0.7.8

- Declare WoW Retail 12.1.5 (TOC interface `120105`) as the supported client patch.

## 2026-10-12 - Version 0.7.7

0.7.3 was never published; its changes ship with this version.

### Added
- DK helper options migrated from isiLive: Soul Reaper and Putrefy button crosses,
  Riders of the Apocalypse horse-sound muting, and the movable missing-ghoul reminder.
- One-time import of the four existing isiLive choices and the ghoul position when
  isiLive is loaded. Existing tracker values take priority; isiLive is not needed
  after import. All four options are off on a fresh installation.
- The self-test log records whether the client reports the Blightburst talent (diagnostic only).

### Changed
- The voice cue is reserved for the end of Dark Transformation (and an eligible Soul Reaper
  signal in the same final three seconds). "Plagues expiring" and "DT ready soon" still show
  "NOW" in the window but are silent.
- "Actual (estimated)" also subtracts Putrefy's erupts: with Blightburst, Putrefy erupts 35 % of the next 3 seconds of each ticking plague into the same damage meter rows as Blightfall (SimulationCraft `trigger_blightburst`, Blightburst 1254552). The value was too high before.
- Dread Plague uses the duration from its own tooltip for the timer, the estimate and the calibration (both plagues are 24 s, 18 s with Ebon Fever, so the numbers do not change today).

### Fixed
- The voice cue plays at most once per Dark Transformation phase, including plague
  reapplication and extensions after the cue. Only a new DT cast resets the latch.
- Early plague warnings cannot consume the DT-end cue. Soul Reaper shares the same
  cue only when both expiry windows overlap within three seconds; DT expiry wins
  over an earlier plague warning and still cues when both plagues have expired.
- A Dark Transformation phase that ended out of combat no longer plays the cue at the next pull.
- Putrefy counts once per press: its single-target (1277016) and area (390220) parts no longer
  extend or apply the plagues or add an erupt a second and third time. They are still logged.
- Putrefy with Blightburst re-applies plagues that are not ticking. Guides follow Blightfall with Putrefy (Blightfall resets its cooldown); until now the plague rows stayed empty and the estimate stayed at 0 until the next Outbreak.
- With "Show only in combat" or "Show only when Blightfall is ready", the calibration, enemy count and log kept running only while the window was visible, so the learned correction factor could be based on part of the fight. They now run whether the window is shown or not.
- After a /reload in combat the addon knows it is in combat: the combat-only window shows right away, and that partial fight is not used for calibration. This also works when the specialization is only known after login.
- On a chain pull, the post-combat damage-meter readout could land in the next fight and learn from the wrong numbers. A readout for an older fight is now dropped.
- A damaged saved file (wrong type for the whole table or the log sessions) no longer stops the addon at login.
- Commands with extra spaces (`/ibt log on ` from chat history or a macro) work instead of showing the help.
- Large numbers just below a unit read "1.00M" / "1k" instead of "1000k" / "1000".
- German ghoul reminder text is upper case like the English one.

### Release
- The CurseForge token is sent as a header instead of in the upload URL.
- A release is refused when `CHANGELOG_RELEASE.md` does not name the tagged version.

### Tests
- Regression tests for every fix above, the DK helper migration, all 29 migrated DK helper
  scenarios and the DT/Soul Reaper cue checks.

## 2026-10-11 - Version 0.7.2

### Fixed
- Soul Reaper expiry only triggers the "NOW" signal and voice cue when Dark Transformation also has at most 3 seconds remaining, including Eternal Agony extensions. Casting Soul Reaper shortly after Dark Transformation no longer triggers an early cue.

## 2026-10-10 - Version 0.7.1

### Documentation
- Clarify that Soul Reaper expiry and Dark Transformation expiry are alternative triggers for the same "NOW" signal. The first signal stays latched; the voice cue plays once per Blightfall window.
- Explain that a new Dark Transformation starts a new window, while casting Blightfall consumes the current one. Runtime behaviour is unchanged.

## 2026-10-07 - Version 0.7.0

### Added
- Option "Show only when Blightfall is ready" (also `/ibt ready on|off`, German `/ibt bereit an|aus`; default: off): the window appears with Dark Transformation and hides again when you cast Blightfall. Can be combined with "Show only in combat".

### Changed
- Blightfall estimate follows the hotfix of 2026-10-07: Blightfall now deals 100 % of the remaining plague damage (was 200 %), so all estimates are halved.
- Boss fights: the "NOW" signal before the end of the Soul Reaper debuff now also fires with adds and Epidemic in the window, as in the simulation rotation (up to 3 enemies or a boss in the pull). Boss fights are recognised from the game's encounter start and end; a loading screen ends them. After a /reload in the middle of a boss fight the rule works as outside boss fights until the next encounter.

## 2026-10-03 - Version 0.6.0

### Added
- Options page in *Esc > Options > AddOns > isiBlightfallTracker* (also `/ibt options`).
- Voice cue sound of your choice: the voice "Go! Go!", built-in game sounds (raid warning, ready check, alarm clock, boss whisper) or any sound from an installed shared-media sound pack.
- Sound channel of your choice: Master (default), Effects, Dialog, Ambience, Music. "Play sound" test button.
- Window appearance: size (50-200 %), background transparency (0-100 %), border on/off, lock (no drag, click-through).
- Real plague time: Virulent Plague and Dread Plague each get their own row with the real time left on your target, also in combat and Mythic+. The game's own aura display (Blizzard_AuraContainer) fills the rows; the addon never reads those hidden values. Without an enemy target the rows show the modelled time as before. Set up out of combat only, configured once and never touched again (the game locks it while auras are secret); any setup failure falls back to the modelled time.
- Language option: automatic (game language), English or Deutsch. The window and chat messages switch at once, the options page after the next /reload.

### Changed
- The "Go! Go!" voice cue is about 11 dB louder (re-mastered from -21.6 to -10.5 LUFS).
- Invalid saved settings fall back to their defaults.
- On-screen texts are written out in full, no abbreviations ("Actual (estimated)", "Dark Transformation", "Next Transformation", "Soul Reaper +20%", "NOW: Transformation ends"). The window is wider for that (170 instead of 130 px).
- All times are shown in whole seconds ("19 s", rounded up like a countdown), the same format as the plague rows filled by the game's own aura display.
- Readability: all texts have a drop shadow; above 50 % background transparency they also get an outline and the grey labels brighten.
- A size change keeps the window's left edge in place (the window grows to the right and down). The position is now saved as the top-left corner; older saved positions keep working.

### Fixed
- Plague and Dark Transformation timers ran short while Forbidden Knowledge was active: Necrotic Coil (replaces Death Coil) and Graveyard (replaces Epidemic) now extend both plagues and Dark Transformation by 1 s, like Death Coil and Epidemic. Graveyard also counts as multi-target, like Epidemic.
- Reaping talent check uses `C_SpellBook.IsSpellKnown`. The old global `IsPlayerSpell` only exists in the game's deprecation fallbacks; without them the Soul Reaper rule could not see the talent.
- A damaged saved file (invalid window position, broken calibration values) no longer stops the addon at login; the values fall back to their defaults.

## 2026-10-01 - Version 0.5.0

### Added
- `/ibt combat on|off`: show the window only in combat (default: off, always visible).
- `/ibt log on|off`: the local session log is now opt-in. German aliases `an` / `aus` work as well.
- `/ibt` now also reports the log and window setting.

### Changed
- The log is off by default. Settings (window position, voice cue, combat-only, calibration) are saved independently of the log.

## 2026-10-01 - Version 0.4.3 - first public release

Unholy Death Knight helper for Blightfall (Retail 12.1, Midnight).

### Features
- Expected Blightfall damage as a large number (single target and all engaged enemies).
- "NOW" signal with a short voice cue ("Go! Go!") once per Blightfall window:
  - shortly before Dark Transformation ends (Eternal Agony extensions included),
  - shortly before the Soul Reaper debuff ends (single target, Reaping talented, no Epidemic in the window),
  - shortly before Dark Transformation is ready again or the plagues run out.
- Dark Transformation and plague bars, Soul Reaper window with the +20 % bonus, Dark Transformation cooldown.
- After every fight: plague erupt damage from the Blizzard damage meter and an estimated per-press comparison of real vs. predicted Blightfall damage.
- Self-calibrating estimate (learns from single-target fights).
- Self-test and local session log.
- Compact two-column window (labels left, values right), English and German.

### Robustness
- Built for the 12.x addon restrictions: hidden ("secret") values are never compared, added or stored; they are only passed to the display or skipped.
- Error guard on every handler: a failing part is logged and switched off instead of raising Lua errors.
- Verified in Mythic+ keystones and boss encounters.
