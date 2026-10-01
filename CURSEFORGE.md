# isiBlightfallTracker

**Know what your Blightfall will hit for - and when to press it.**

A small, self-contained helper for **Unholy Death Knights** (Retail 12.1, Midnight). It shows the expected damage of **Blightfall** (German: *Seuchensturz*), tells you the right moment to press it with a visual signal and a short voice cue, and learns from your own fights.

Works in the open world, dungeons, **Mythic+** and raids. No setup, no typing: it switches itself on for Unholy and stays hidden otherwise.

<!-- Screenshot: upload media/screenshot.png under "Images" in the CurseForge project and insert it here. -->

---

## Features

- **Expected Blightfall damage** as a big number, for one target and for all enemies in combat
- **"NOW" signal + voice cue "Go! Go!"** when it is time to press (once per window)
- **Dark Transformation bar** that follows Eternal Agony extensions (+1 s per Death Coil / Epidemic)
- **Plague timer**, Soul Reaper window (with the +20 % bonus shown) and Dark Transformation cooldown
- **After every fight:** plague erupt damage from the Blizzard damage meter and an estimated "real vs. predicted" comparison
- **Self-calibrating:** learns a correction factor from your single-target fights
- **Self-test and local log** of what the game allows - useful for tuning, never sent anywhere
- **Built for the 12.x addon rules:** no combat log, no protected actions, error guard on every handler - no Lua error spam in your key
- English and German

## How Blightfall works (in short)

Blightfall consumes your plagues within 40 yards and deals **200 % of their remaining damage** at once. It does not store damage - you *charge* it by extending your plagues (Death Coil, Epidemic, Putrefy with Blightburst, Vampiric Strike with Infliction of Sorrow). Guides and simulations press it shortly before **Dark Transformation**, the **Soul Reaper** debuff (single target) or a trinket effect runs out. That is exactly what the signal follows.

---

## Which numbers can you trust?

| Shown value | Type | Source |
|---|---|---|
| Blightfall ready / not ready | **Reliable** | your own Dark Transformation cast |
| Dark Transformation bar | **Reliable** | 15 s from your cast, +1 s per Death Coil / Epidemic |
| Soul Reaper time | **Reliable** | 8 s from your Soul Reaper cast |
| "NOW" signal | **Reliable** | timing rules from your own casts |
| Enemies | **Reliable** | enemies in combat with a *visible* nameplate |
| Erupts (after combat) | **Reliable** | Blizzard damage meter |
| DT cooldown | Approximate | base 45 s, reductions not tracked |
| **Big number / Per target** | *Estimated* (`~`) | live plague tooltip × learned factor × modelled remaining time |
| Plagues bar | *Estimated* | rebuilt from your casts |
| Real (est.) / Predicted | *Estimated* | damage meter minus calculated share of other erupts |

### Why are some numbers only estimates?

Since patch 12.0 Blizzard hides most combat data from addons (**"secret values"**). In combat - and always inside Mythic+ and raid encounters - an addon may **not** read the auras on enemies (remaining time and tick damage of your plagues), your own stats, or the damage meter values, and the combat log is gone for addons.

So the addon rebuilds the picture from what it is allowed to see: **your own casts**, the **live tooltip of your plagues** (the game still computes it with your current stats and talents) and a **correction factor** it learns after single-target fights, when the damage meter is readable again.

**Real (est.)** is calculated as well: Blightfall has no damage meter line of its own - its damage is counted together with the erupts of Scourge Strike, Vampiric Strike and Putrefy. The addon subtracts a calculated share for those. On a single target that works reasonably; in big pulls other erupt sources hit many targets and the value becomes unreliable.

**Enemies** is an upper bound for the all-target value - which enemies really carry Virulent Plague is hidden in combat. Turn on enemy nameplates (default key **V**) so they can be counted.

The **timing signal does not depend on any of this** - it only uses your own casts.

---

## Commands (optional)

| Command | Effect |
|---|---|
| `/ibt` | log size, mode, calibration |
| `/ibt sound` | voice cue on/off |
| `/ibt test` | write a self-test to the log |
| `/ibt reset` | reset window position |

Drag the window with the left mouse button.

## Notes

- The damage estimate reads German and English plague tooltips. On other client languages the window shows *estimate off*; the timing signal still works.
- The log stays on your computer (`WTF\Account\<account>\SavedVariables\isiBlightfallTracker.lua`, last 10 sessions).

---

## Deutsch

Zeigt den **erwarteten Schaden von Seuchensturz**, gibt mit Signal und Ansage "Go! Go!" den richtigen Zündzeitpunkt vor und lernt aus deinen Kämpfen. Läuft in Open World, Dungeons, **M+** und Raids.

**Verlässlich:** Bereitschaft, DT-Balken (15 s + 1 s je Todesmantel/Epidemie), Seelenernter-Zeit, Zündsignal, Gegnerzahl (sichtbare Namensplaketten), Ausbrüche nach dem Kampf. **Ungefähr:** DT-CD. **Geschätzt** (mit `~`): große Zahl, Pro Ziel, Seuchen-Balken, Ist (gesch.), Vorhersage.

**Warum geschätzt?** Seit Patch 12.0 verbirgt Blizzard Kampfdaten vor Addons: Auren auf Gegnern, deine Werte, den Damage Meter im Kampf und das Kampflog. Das Addon rechnet deshalb mit deinen eigenen Zaubern, dem Live-Tooltip deiner Seuchen und einem selbst gelernten Korrekturfaktor. Seuchensturz hat im Damage Meter keine eigene Zeile - "Ist" ist darum ebenfalls gerechnet: im Einzelziel brauchbar, in großen Packs nicht. Das **Zündsignal** hängt davon nicht ab.
