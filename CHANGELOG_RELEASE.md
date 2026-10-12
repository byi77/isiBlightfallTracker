## isiBlightfallTracker 0.7.7

- All four DK helpers now live here: Soul Reaper and Putrefy crosses, horse-sound
  muting, and the movable missing-ghoul reminder. Existing isiLive settings and the
  ghoul position are imported once when isiLive is loaded.
- "Go! Go!" plays once per Dark Transformation phase, in its final three seconds
  (or with an overlapping Soul Reaper signal). Plague warnings show "NOW" silently.
  A DT phase that ended out of combat no longer cues at the next pull.
- "Actual (estimated)" subtracts Putrefy's erupts (Blightburst), counted once per press.
  Putrefy re-applies plagues Blightfall consumed.
- Calibration keeps running while the window is hidden; /reload in combat, chain pulls
  and damaged saved files are handled.
