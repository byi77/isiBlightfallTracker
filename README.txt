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
40 yards and deals 100 % of their REMAINING damage at once (200 % until
the hotfix of 2026-10-07).

It does not store damage. You "charge" it by extending your plagues:
Death Coil and Epidemic (and their Forbidden Knowledge versions Necrotic
Coil and Graveyard) add 1 s, Putrefy with Blightburst and Vampiric Strike
with Infliction of Sorrow add 3 s. Without extensions the value
drops with every plague tick. Blightfall stays on the button until you use
it, even after Dark Transformation has ended.

When to press it (current guides and simulations): shortly before the
first of these runs out:
  - Dark Transformation (also extended by 1 s per Death Coil / Epidemic,
    Necrotic Coil / Graveyard),
  - the Soul Reaper debuff (+20 % to Blightfall's damage; up to 3 enemies
    or a boss encounter, Reaping talented),
  - a damage trinket effect.


2. The window
-------------
  [icon]                     ~1.27M   expected Blightfall damage (big number)
  NOW: Transformation ends            signal
  Enemies                         12
  Per target                   ~115k
  Dark Transformation            3 s  + bar  time left
  Virulent Plague              15 s  + bar  real time left on your target
  Dread Plague                 15 s  + bar  (modelled without an enemy target)
  Next Transformation           29 s  or "Soul Reaper +20%  4 s" while
                                      the Soul Reaper debuff runs
  --------------------------------
  Erupts                      ~4.25M  plague erupt damage of the last fight
  Actual (estimated)           ~410k  last fight: Blightfall per press
  Predicted                    ~390k  last fight: average prediction at press

The number is grey until Blightfall is available and white once you can
press it. In a "NOW" state the frame pulses and a short voice cue
("Go! Go!") plays once.

Drag the window with the left mouse button. Size, background
transparency, border, lock, sound, channel and language are set in the
options page (see section 5). A size change keeps the left edge of the
window in place; the window grows to the right and down. Above 50 %
background transparency all text gets an outline so it stays readable
over the game world.


3. Which numbers you can trust, and which are estimates
--------------------------------------------------------
RELIABLE (taken directly from the game or from your own casts):
  - Blightfall ready / not ready        your own Dark Transformation cast
  - Dark Transformation bar             15 s from your cast, +1 s per Death
                                        Coil or Epidemic while it runs
  - Soul Reaper time                    8 s from your Soul Reaper cast
  - The "NOW" signal timing             rules above, from your own casts
  - Enemies                             enemies in combat with a VISIBLE
                                        nameplate (turn on enemy nameplates).
                                        LIMITED on training dummies: the game
                                        counts only one dummy nameplate, so a
                                        multi-target dummy test shows 1 enemy
                                        and a too low all-target value. Judge
                                        multi-target in dungeon pulls.
  - Erupts (after combat)               Blizzard damage meter, exact
  - Virulent Plague / Dread Plague      real time left of YOUR plagues on
    (with an enemy target)              your target, shown by the game's
                                        own aura display

APPROXIMATE:
  - Next Transformation                 assumes the base 45 s cooldown;
                                        cooldown reductions are not tracked

ESTIMATED (shown with "~"):
  - The big number and "Per target"
  - Virulent Plague / Dread Plague without an enemy target (modelled
    from your casts)
  - Actual (estimated) and Predicted


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

"Actual (estimated)" is an estimate too: Blightfall has no damage meter line of
its own. Its damage is counted together with the erupts of Scourge
Strike, Vampiric Strike and Putrefy. The addon subtracts a calculated
share for those. That works reasonably on a single target; in large
pulls other erupt sources hit many targets and the value becomes
unreliable.

"Enemies" is an upper bound for the multi-target value: which enemies
actually carry Virulent Plague is hidden in combat.


5. Options and commands (optional - nothing needs to be typed)
---------------------------------------------------------------
Options page: Esc > Options > AddOns > isiBlightfallTracker (or /ibt options)
  General         language: automatic (game language), English, Deutsch
  Voice cue       on/off, sound, sound channel, "Play sound" test button
    Sound:        the voice "Go! Go!" (default), built-in game sounds
                  (raid warning, ready check, alarm clock, boss whisper),
                  or any sound of an installed shared-media sound pack
    Channel:      Master (default), Effects, Dialog, Ambience, Music -
                  the cue follows that channel's volume slider
  Window          show only in combat, show only when Blightfall is
                  ready (from Dark Transformation until you cast it),
                  lock, border, size, background transparency,
                  reset position
  Log             record a local log (default: off)

Commands:
  /ibt                 mode, calibration, log and window setting
  /ibt options         open the options page
  /ibt combat on|off   show the window only in combat (default: off)
  /ibt ready on|off    show the window only while Blightfall is ready
                       (default: off; German alias: /ibt bereit an|aus)
  /ibt log on|off      record the log (default: off)
  /ibt sound           voice cue on/off (plays it once when switched on)
  /ibt test            run a self-test (written to the log if it is on)
  /ibt reset           reset the window position
  German aliases: "an" / "aus" instead of "on" / "off".


6. Self-test and log
--------------------
The log is OFF by default. Switch it on with /ibt log on if you want to
check the estimate or report a problem. When on, the addon checks what the
game allows right now (at login, at every combat start, keystone start and
boss pull) and writes a log:
casts, estimates, signals and the damage meter result after each fight.
Values the game hides are never stored. The log stays on your computer in
  WTF\Account\<account>\SavedVariables\isiBlightfallTracker.lua
(last 10 sessions). It is written on /reload or logout.


7. Languages
------------
By default the texts follow the game client: German client - German,
every other client - English. The options page lets you pick English or
German yourself; the window and the chat messages switch at once, the
options page itself after the next /reload. The damage estimate reads
German and English plague tooltips (this depends on the game client, not
on the chosen language); on other client languages the window shows
"estimate off" and only the timing signal works.


8. Safety
---------
Built for the 12.x addon restrictions: no combat log, no protected
actions, all hidden values are only passed to the display or skipped.
Every handler runs behind an error guard: a failing part is logged and
switched off instead of showing Lua errors.
The real plague time uses the game's own aura display. It is set up out
of combat only (after a /reload in combat: when combat ends); the addon
configures it once and never touches it again, because the game locks it
while auras are hidden (combat, Mythic+). If it cannot be set up, the
plague rows show the modelled time.


-----------------------------------------------------------------------
Deutsch - Kurzfassung
-----------------------------------------------------------------------
Zeigt den erwarteten Schaden von Seuchensturz, sagt mit Signal und
Ansage "Go! Go!", wann du zünden sollst, und protokolliert alles lokal.

Zündsignal: kurz vor Ende der Dunklen Verwandlung, kurz vor Ende des
Seelenernter-Debuffs (mit Talent "Reaping"; bei bis zu 3 Gegnern oder in
jedem Bosskampf, auch mit Adds), oder bevor die Seuchen auslaufen.

Verlässlich: Bereitschaft, DT-Balken (15 s + 1 s je Todesmantel/Epidemie),
Seelenernter-Zeit, Zündsignal, Gegnerzahl (sichtbare Namensplaketten),
Ausbrüche nach dem Kampf. Ungefähr: Nächste Verwandlung.
Virulente Seuche / Schreckensseuche: echte Restzeit auf deinem Ziel (ohne
feindliches Ziel aus deinen Zaubern gerechnet).
Geschätzt (mit "~"): große Zahl, Pro Ziel, Ist (geschätzt), Vorhersage.

Warum: Seit Patch 12.0 verbirgt Blizzard Kampfdaten vor Addons (Gegner-
Auren, eigene Werte, Damage Meter, Kampflog). Das Addon rechnet deshalb
aus deinen eigenen Zaubern, dem Live-Tooltip deiner Seuchen und einem
selbst gelernten Korrekturfaktor. Seuchensturz hat im Damage Meter keine
eigene Zeile, daher ist auch "Ist" nur gerechnet - im Einzelziel brauchbar,
in großen Packs nicht.

Einstellungen: Esc > Optionen > AddOns > isiBlightfallTracker (oder
/ibt optionen): Sprache (automatisch, English, Deutsch), Ansage an/aus, Sound (Sprache, Spielsounds oder Sounds aus
einem Shared-Media-Soundpaket), Soundkanal (Standard Master), Testsound;
Fenster nur im Kampf, nur wenn Seuchensturz bereit (ab Dunkler
Verwandlung bis zum Zünden), sperren, Rahmen, Größe, Hintergrund-
Transparenz, Position zurücksetzen; Log (Standard aus). Beim Ändern der
Größe bleibt der linke Rand stehen. Ab 50 % Transparenz bekommt die
Schrift eine Kontur.
Befehle: /ibt combat an|aus, /ibt bereit an|aus, /ibt log an|aus,
/ibt sound, /ibt test, /ibt reset.

Seuchensturz verursacht seit dem Hotfix vom 2026-10-07 100 % des
restlichen Seuchenschadens (vorher 200 %); die Schätzung ist angepasst.
