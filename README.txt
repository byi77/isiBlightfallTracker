isiBlightfallTracker
====================

Unholy Death Knight helper for Blightfall (German client: "Seuchensturz").
Shows the expected Blightfall damage, tells you when to press it, and keeps
a local log so the estimate can be checked against what really happened.

World of Warcraft Retail 12.1 (Midnight). Works in the open world, dungeons,
Mythic+ keystones and raids.


1. What Blightfall does
-----------------------
Dark Transformation puts Blightfall on its button. Blightfall consumes your
plagues (Virulent Plague on every enemy, Dread Plague on one enemy) within
40 yards and deals 200 % of their REMAINING damage at once.

It does not store damage. You "charge" it by extending your plagues:
Death Coil and Epidemic add 1 s, Putrefy with Blightburst and Vampiric
Strike with Infliction of Sorrow add 3 s. Without extensions the value
drops with every plague tick. Blightfall stays on the button until you use
it, even after Dark Transformation has ended.

When to press it (current guides and simulations): shortly before the
first of these runs out:
  - Dark Transformation (also extended by 1 s per Death Coil / Epidemic),
  - the Soul Reaper debuff (+20 % to Blightfall's damage; single target),
  - a damage trinket effect.


2. The window
-------------
  [icon]                ~1.27M   expected Blightfall damage (big number)
  NOW - DT ending                signal
  Enemies                    12
  Per target              ~115k
  DT                       2.7s  + bar  Dark Transformation time left
  Plagues                  5.7s  + bar  plague time left (modelled)
  DT-CD                     29s  or "SR (+20%)  3.1s" while Soul Reaper runs
  ---------------------------
  Erupts                 ~4.25M  plague erupt damage of the last fight
  Real (est.)             ~410k  last fight: Blightfall per press (estimated)
  Predicted               ~390k  last fight: average prediction at press

The number is grey until Blightfall is available and white once you can
press it. In a "NOW" state the frame pulses and a short voice cue
("Go! Go!") plays once.

Drag the window with the left mouse button.


3. Which numbers you can trust, and which are estimates
--------------------------------------------------------
RELIABLE (taken directly from the game or from your own casts):
  - Blightfall ready / not ready        your own Dark Transformation cast
  - Dark Transformation bar             15 s from your cast, +1 s per Death
                                        Coil or Epidemic while it runs
  - Soul Reaper time (SR / SE)          8 s from your Soul Reaper cast
  - The "NOW" signal timing             rules above, from your own casts
  - Enemies                             enemies in combat with a VISIBLE
                                        nameplate (turn on enemy nameplates)
  - Erupts (after combat)               Blizzard damage meter, exact

APPROXIMATE:
  - DT-CD                               assumes the base 45 s cooldown;
                                        cooldown reductions are not tracked

ESTIMATED (shown with "~"):
  - The big number and "Per target"
  - The Plagues bar
  - Real (est.) and Predicted


4. Why some numbers can only be estimated
-----------------------------------------
Since patch 12.0 Blizzard hides most combat data from addons ("secret
values"). In combat, and always inside Mythic+ and raid encounters, an
addon may not read:
  - the auras on enemies (so not the remaining time or tick damage of
    your plagues),
  - your own stats (attack power, versatility, mastery),
  - the damage meter values and spell IDs,
and the combat log is no longer available to addons at all.

So the addon cannot simply read "how much is left on your plagues". It
rebuilds that from what it may see:
  - your own casts (Outbreak, Scourge Strike, Vampiric Strike, Death Coil,
    Epidemic, Putrefy, Soul Reaper, Dark Transformation, Blightfall),
  - the live tooltip of your plagues, which the game still computes with
    your current stats and talents,
  - a correction factor the addon learns after single-target fights by
    comparing its expectation with the damage meter (which is readable
    again after combat).

"Real (est.)" is an estimate too: Blightfall has no damage meter line of
its own. Its damage is counted together with the erupts of Scourge
Strike, Vampiric Strike and Putrefy. The addon subtracts a calculated
share for those. That works reasonably on a single target; in large
pulls other erupt sources hit many targets and the value becomes
unreliable.

"Enemies" is an upper bound for the multi-target value: which enemies
actually carry Virulent Plague is hidden in combat.


5. Commands (optional - nothing needs to be typed)
---------------------------------------------------
  /ibt          log size, mode and calibration
  /ibt sound    voice cue on/off (plays it once when switched on)
  /ibt test     write a self-test to the log
  /ibt reset    reset the window position


6. Self-test and log
--------------------
The addon checks on its own what the game allows right now (at login, at
every combat start, keystone start and boss pull) and writes a log:
casts, estimates, signals and the damage meter result after each fight.
Values the game hides are never stored. The log stays on your computer in
  WTF\Account\<account>\SavedVariables\isiBlightfallTracker.lua
(last 10 sessions). It is written on /reload or logout.


7. Languages
------------
German client: German texts. Every other client: English texts. The
damage estimate reads German and English plague tooltips; on other
client languages the window shows "estimate off" and only the timing
signal works.


8. Safety
---------
Built for the 12.x addon restrictions: no combat log, no protected
actions, all hidden values are only passed to the display or skipped.
Every handler runs behind an error guard: a failing part is logged and
switched off instead of showing Lua errors.


-----------------------------------------------------------------------
Deutsch - Kurzfassung
-----------------------------------------------------------------------
Zeigt den erwarteten Schaden von Seuchensturz, sagt mit Signal und
Ansage "Go! Go!", wann du zünden sollst, und protokolliert alles lokal.

Verlässlich: Bereitschaft, DT-Balken (15 s + 1 s je Todesmantel/Epidemie),
Seelenernter-Zeit, Zündsignal, Gegnerzahl (sichtbare Namensplaketten),
Ausbrüche nach dem Kampf. Ungefähr: DT-CD.
Geschätzt (mit "~"): große Zahl, Pro Ziel, Seuchen-Balken, Ist (gesch.),
Vorhersage.

Warum: Seit Patch 12.0 verbirgt Blizzard Kampfdaten vor Addons (Gegner-
Auren, eigene Werte, Damage Meter, Kampflog). Das Addon rechnet deshalb
aus deinen eigenen Zaubern, dem Live-Tooltip deiner Seuchen und einem
selbst gelernten Korrekturfaktor. Seuchensturz hat im Damage Meter keine
eigene Zeile, daher ist auch "Ist" nur gerechnet - im Einzelziel brauchbar,
in großen Packs nicht.
