# Changelog

## Unreleased - Version 0.6.0

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
