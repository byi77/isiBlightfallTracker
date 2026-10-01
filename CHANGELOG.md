# Changelog

## Version 0.5.0

### Added
- `/ibt combat on|off`: show the window only in combat (default: off, always visible).
- `/ibt log on|off`: the local session log is now opt-in. German aliases `an` / `aus` work as well.
- `/ibt` now also reports the log and window setting.

### Changed
- The log is off by default. Settings (window position, voice cue, combat-only, calibration) are saved independently of the log.

## Version 0.4.3 - first public release

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
