## isiBlightfallTracker 0.7.3

- All four DK helpers now live here: Soul Reaper and Putrefy crosses, horse-sound
  muting, and the movable missing-ghoul reminder.
- Existing isiLive settings and the ghoul position are imported once when isiLive
  is loaded. Configure them under Death Knight helpers; the tracker runs standalone.
- GoGo plays at most once per DT phase. DT expiry takes priority; Soul Reaper counts
  only when the final three-second windows overlap. Early plague warnings cannot
  consume the cue, and extending DT or reapplying plagues cannot repeat it.
