# isiBlightfallTracker

**Know what your Blightfall will hit for - and when to press it.**

A small, self-contained helper for **Unholy Death Knights** (Retail 12.1, Midnight). It shows the expected damage of **Blightfall** (German: *Seuchensturz*), tells you the right moment to press it with a visual signal and a voice cue, shows the real time left on your plagues, and learns from your own fights.

Works in the open world, dungeons, **Mythic+** and raids. No setup, no typing: it switches itself on for Unholy and stays hidden otherwise.

<!-- Animation: upload media/isiBlightfallTracker.gif under "Images" in the CurseForge project and insert it here. -->

---

## What's new in 0.7.1

- **Clearer timing documentation:** Soul Reaper expiry and Dark Transformation expiry are alternative triggers for one "NOW" signal. The first reason stays latched and the voice cue plays once per Blightfall window.
- A new Dark Transformation starts a new window; casting Blightfall consumes the current one. Runtime behaviour is unchanged from 0.7.0.

## What's new in 0.7.0

- **Blightfall nerf (hotfix 2026-10-07):** Blightfall now deals 100 % of the remaining plague damage (was 200 %) - the estimate is updated accordingly
- **New option "Show only when Blightfall is ready"** (also `/ibt ready on|off`): the window appears with Dark Transformation and hides when you cast Blightfall - big and visible when you need it, out of the way the rest of the time. Can be combined with "Show only in combat".
- **Boss fights:** the "NOW" signal shortly before your Soul Reaper debuff ends now also fires when adds are up and you use Epidemic - just like the simulation rotation (up to 3 enemies, or any boss fight). Outside boss fights nothing changes.

## What's new in 0.6.0

- **Options page** in *Esc > Options > AddOns > isiBlightfallTracker*
- **Your sound, your channel:** voice "Go! Go!" (now about 11 dB louder), built-in game sounds or your shared-media sounds - on Master (default), Effects, Dialog, Ambience or Music
- **Window appearance:** size, background transparency, border, lock - text stays readable even with a see-through background
- **Real plague time:** Virulent Plague and Dread Plague each show the real time left on your target - also in combat and Mythic+
- **Language:** automatic, English or Deutsch
- **Fixed:** Necrotic Coil and Graveyard (Forbidden Knowledge) now extend plagues and Dark Transformation like Death Coil and Epidemic

---

## Features

- **Expected Blightfall damage** as a big number, for one target and for all enemies in combat
- **"NOW" signal + voice cue** when it is time to press (once per window)
- **Real time left of Virulent Plague and Dread Plague** on your target, with bars
- **Dark Transformation bar** that follows Eternal Agony extensions (+1 s per Death Coil / Epidemic, also Necrotic Coil / Graveyard)
- **Soul Reaper window** (with the +20 % bonus shown) and the next Dark Transformation
- **After every fight:** plague erupt damage from the Blizzard damage meter and an estimated "actual vs. predicted" comparison
- **Self-calibrating:** learns a correction factor from your single-target fights
- **Optional local log** (off by default) with a self-test of what the game allows - never sent anywhere
- **Built for the 12.x addon rules:** no combat log, no protected actions, error guard on every handler - no Lua error spam in your key
- English and German

## How Blightfall works (in short)

Blightfall consumes your plagues within 40 yards and deals **100 % of their remaining damage** at once (200 % until the hotfix of 2026-10-07). It does not store damage - you *charge* it by extending your plagues (Death Coil, Epidemic, Putrefy with Blightburst, Vampiric Strike with Infliction of Sorrow). Guides and simulations press it shortly before **Dark Transformation**, the **Soul Reaper** debuff (up to 3 enemies, or any boss fight) or a trinket effect runs out. That is exactly what the signal follows.

---

## ⚠ Testing on training dummies: multi-target is limited

**Single-target tests on a training dummy work fine.** Multi-target tests on a group of dummies are **limited**: the game does not show all dummies as counted enemies (only a single nameplate is counted, even when you hit several). The addon therefore sees **one enemy**:

- **Enemies** stays at 1 and the **all-target value** is too low,
- the Soul Reaper timing rule may still fire although you are hitting several targets,
- **calibration** only learns from single-target fights anyway.

The addon notices Epidemic / Graveyard casts and treats that window as multi-target, so the timing is still sensible. For a real multi-target picture, judge it in **dungeon pulls**, where enemy nameplates are counted correctly.

---

## Which numbers can you trust?

| Shown value | Type | Source |
|---|---|---|
| Blightfall ready / not ready | **Reliable** | your own Dark Transformation cast |
| Dark Transformation bar | **Reliable** | 15 s from your cast, +1 s per Death Coil / Epidemic (also Necrotic Coil / Graveyard) |
| Virulent Plague / Dread Plague | **Reliable** with an enemy target | real time left of your plagues on your target, via the game's own aura display; modelled from your casts without an enemy target |
| Soul Reaper time | **Reliable** | 8 s from your Soul Reaper cast |
| "NOW" signal | **Reliable** | timing rules from your own casts |
| Enemies | **Reliable** in dungeons | enemies in combat with a *visible* nameplate (limited on training dummies, see above) |
| Erupts (after combat) | **Reliable** | Blizzard damage meter |
| Next Transformation | Approximate | base 45 s cooldown, reductions not tracked |
| **Big number / Per target** | *Estimated* (`~`) | live plague tooltip × learned factor × modelled remaining time |
| Actual (estimated) / Predicted | *Estimated* | damage meter minus calculated share of other erupts |

### Why are some numbers only estimates?

Since patch 12.0 Blizzard hides most combat data from addons (**"secret values"**). In combat - and always inside Mythic+ and raid encounters - an addon may **not** read the auras on enemies (remaining time and tick damage of your plagues), your own stats, or the damage meter values, and the combat log is gone for addons.

The **plague rows** use the game's own aura display, which may *show* the real time but never hands the number to an addon. For the damage estimate the addon therefore rebuilds the picture from what it is allowed to see: **your own casts**, the **live tooltip of your plagues** (the game still computes it with your current stats and talents) and a **correction factor** it learns after single-target fights, when the damage meter is readable again.

**Actual (estimated)** is calculated as well: Blightfall has no damage meter line of its own - its damage is counted together with the erupts of Scourge Strike, Vampiric Strike and Putrefy. The addon subtracts a calculated share for those. On a single target that works reasonably; in big pulls other erupt sources hit many targets and the value becomes unreliable.

**Enemies** is an upper bound for the all-target value - which enemies really carry Virulent Plague is hidden in combat. Turn on enemy nameplates (default key **V**) so they can be counted.

The **timing signal does not depend on any of this** - it only uses your own casts.

---

## Options

Open **Esc > Options > AddOns > isiBlightfallTracker** (or type `/ibt options`).

| Section | Settings |
|---|---|
| General | language: automatic (game language), English, Deutsch |
| Voice cue | on/off · sound (voice "Go! Go!", raid warning, ready check, alarm clock, boss whisper, shared-media sounds) · channel (Master, Effects, Dialog, Ambience, Music) · test button |
| Window | show only in combat · show only when Blightfall is ready (from Dark Transformation until you cast it) · lock · border · size (50-200 %) · background transparency (0-100 %) · reset position |
| Log | record a local log (default: off) |

The cue follows the volume slider of the chosen channel in the game's sound settings. A size change keeps the window's left edge in place. Above 50 % background transparency all text gets an outline, so it stays readable over the game world.

## Commands (optional)

| Command | Effect |
|---|---|
| `/ibt` | mode, calibration, log and window setting |
| `/ibt options` | open the options page |
| `/ibt combat on` / `off` | show the window only in combat (default: off) |
| `/ibt ready on` / `off` | show the window only while Blightfall is ready (default: off) |
| `/ibt log on` / `off` | record a local log (default: off) |
| `/ibt sound` | voice cue on/off |
| `/ibt test` | run a self-test |
| `/ibt reset` | reset window position |

Drag the window with the left mouse button.

## Notes

- The damage estimate reads German and English plague tooltips. On other client languages the window shows *estimate off*; the timing signal and the plague rows still work.
- The log is off by default. When switched on it stays on your computer (`WTF\Account\<account>\SavedVariables\isiBlightfallTracker.lua`, last 10 sessions).

---

## Deutsch

Zeigt den **erwarteten Schaden von Seuchensturz**, gibt mit Signal und Ansage den richtigen Zündzeitpunkt vor, zeigt die **echte Restzeit deiner Seuchen** auf dem Ziel und lernt aus deinen Kämpfen. Läuft in Open World, Dungeons, **M+** und Raids.

**⚠ Test an Trainingspuppen:** Einzelziel funktioniert. **Multitarget an mehreren Puppen ist eingeschränkt**, weil das Spiel nicht alle Puppen als Gegner anzeigt (es wird nur eine Namensplakette gezählt). Gegnerzahl und Alle-Ziele-Wert sind dort zu niedrig. Für Multitarget bitte im **Dungeon** beurteilen, dort werden die Gegner korrekt gezählt.

**Zündsignal:** kurz vor Ende der Dunklen Verwandlung, kurz vor Ende des Seelenernter-Debuffs (mit Talent "Reaping"; bei bis zu 3 Gegnern **oder in jedem Bosskampf**, auch mit Adds), oder bevor die Seuchen auslaufen.

**Verlässlich:** Bereitschaft, Balken der Dunklen Verwandlung (15 s + 1 s je Todesmantel/Epidemie, auch Nekrotischer Mantel/Friedhof), Restzeit von Virulenter Seuche und Schreckensseuche auf deinem Ziel, Seelenernter-Zeit, Zündsignal, Gegnerzahl im Dungeon (sichtbare Namensplaketten), Ausbrüche nach dem Kampf. **Ungefähr:** Nächste Verwandlung. **Geschätzt** (mit `~`): große Zahl, Pro Ziel, Ist (geschätzt), Vorhersage.

**Warum geschätzt?** Seit Patch 12.0 verbirgt Blizzard Kampfdaten vor Addons: Auren auf Gegnern, deine Werte, den Damage Meter im Kampf und das Kampflog. Die Seuchen-Zeilen nutzen die spieleigene Aura-Anzeige, die die echte Zeit anzeigen, aber nicht an Addons weitergeben darf. Für die Schätzung rechnet das Addon deshalb mit deinen eigenen Zaubern, dem Live-Tooltip deiner Seuchen und einem selbst gelernten Korrekturfaktor. Seuchensturz hat im Damage Meter keine eigene Zeile - "Ist" ist darum ebenfalls gerechnet: im Einzelziel brauchbar, in großen Packs nicht. Das **Zündsignal** hängt davon nicht ab.

**Einstellungen:** *Esc > Optionen > AddOns > isiBlightfallTracker* (oder `/ibt optionen`): Sprache (automatisch, English, Deutsch), Ansage an/aus, Sound (Sprache, Spielsounds oder Shared-Media-Sounds), Soundkanal (Standard Master), Testsound; Fenster nur im Kampf, nur wenn Seuchensturz bereit (ab Dunkler Verwandlung bis zum Zünden), sperren, Rahmen, Größe, Hintergrund-Transparenz, Position zurücksetzen; Log (Standard aus).

**Seuchensturz** verursacht seit dem Hotfix vom 2026-10-07 **100 %** des restlichen Seuchenschadens (vorher 200 %); die Schätzung ist angepasst.

**Befehle:** `/ibt combat an|aus`, `/ibt bereit an|aus`, `/ibt log an|aus`, `/ibt sound`, `/ibt test`, `/ibt reset`.
