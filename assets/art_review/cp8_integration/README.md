# CP-8 — illustrated battles in the real game loop

Based on green **b8d927eb (CP-7)**. One WO: integrate the approved presentation
in one existing encounter and synchronize battle sounds. Pixel world and maps,
illustrated battles; no illustrated walking, new character art or roster rollout.

[Watch the integration with sound](integration.mp4) — actual **1152×648, 60fps,
31.95s**, including forecast, boss quote, sword/counter/follow-up, magic,
contact-before-collapse, return to map, level-up, Serra yield/outro and Victory.
Stills and capture/test logs are alongside this file. Native GPU rendering;
headless tests alone are not visual approval.

## Play

Normal game: Title → Dev Jump → **Mock Battle (3 houses)** → preparations/start.
The Emberwing Mock Battle now opts into illustrated Kai-versus-enemy-Serra
exchanges. Normal map, deployment, stats, dialogue and objective are unchanged.
The campaign ChapterRegistry and mid-battle resume already use this same scene.

For an immediate local rehearsal:

```sh
godot --path . -s assets/art_review/cp8_integration/preview.gd
```

This loads the real Mock Battle, moves Kai/Serra to adjacent open tiles, fixes
seed 1 and skips the long opening dialogue. Select Kai with Enter, confirm his
tile, choose Attack/Magic and weapon, target Serra and confirm. Ordinary sword
and counter leave both alive; progress/uses persist. Boss dialogue is enabled.
There are no CP-6 canned review buttons or overrides of combat/progression.
No save is written. Normal production starting positions are unchanged.
Tracked preview PID/log: `/tmp/vael-cp8-live.{pid,log}`; verify process identity
before stopping it. The previous tracked A/B preview is closed, editor preserved.

## Integration boundary

- BattleCombatExecutor resolves **once** with the live RNG, then chooses the
  illustrated player if this encounter opts in and both current kits qualify.
- The existing CP-6/7 player applies actual map HP at each native strike contact.
  Complete counter/follow-up order is retained. No second HP replay at return.
- The executor then removes defeated units, spends one weapon use per side that
  swung, awards XP/real level-up rolls and checks objectives as before. Boss
  quote precedes combat; yield/outro and results follow the established flow.
- Scope gate: unpromoted team-0 Kai / team-1 Serra; configured Kai
  Verdant Blade/iron sword/Crownspark and Serra iron/signature lance. Reversed
  initiation works while keeping Kai staged left. Other characters, teams,
  promoted designs, axes and unapproved spells retain their existing player
  (on-map normally, existing pixel popup if enabled). Other scenes stay opt-out.
- Pixel map actor/filtering is untouched; linear art stays inside the combat
  stage. Production chrome uses the chapter title, without A/B experiment text.
  Existing visible FX creator/license footer and bundled provenance remain.

## Verification and capture fixture

**Full suite: 557/557 tests, 3,679 assertions, 84 scripts, 135.057s.**
New production integration checks: **4/4, 75 assertions, 20.25s**. They exercise
real cursor/menu callbacks, contact HP/order, native seed parity, enemy
initiation, magic, exact weapon uses/XP, level-up RNG, actual boss quote/yield/
outro input, non-lethal defeat, victory/campaign capture and supported-kit gates.
CP-6 parity/miss tests and CP-7 delayed-collapse checks remain green. Inherited
13 deprecations / two ObjectDB + one resource exit reports remain; no new
runtime errors in the final capture or test runs.

The movie uses the **real production scene/executor/input** with explicit local
fixture changes: bring Kai/Serra together; select native seed 1; restore local
HP/action availability between exchanges; select the existing innate spell;
remove other foes without events and wound Serra to 1 HP for a short final-rival
test; set Kai XP95 to show an actual level-up. No fabricated StrikeResults,
formula changes or campaign saves. Final Kai: level2, XP28, sword38 uses; Serra
recorded defeated non-lethally. Ordinary sword XP11/sword39 uses; magic XP22/
Crownspark998 uses. These are fixture observations, not chapter balance edits.

Reproduce:

```sh
godot --path . --fixed-fps 60 --write-movie /tmp/vael-cp8-integration.avi -s assets/art_review/cp8_integration/capture.gd
ffmpeg -y -i /tmp/vael-cp8-integration.avi -c:v libx264 -crf 20 -pix_fmt yuv420p -c:a aac -b:a 160k -movflags +faststart assets/art_review/cp8_integration/integration.mp4
```

## Sound, music and next decisions

Five deterministic locally synthesized cue layers: blade whoosh, magic gather,
launch, connected magic impact and delayed armor/defeat. Existing contact
hit/crit/miss, level-up, victory and music retained. AudioManager owns the
voice pool, caching and volume/mute. [Source/generator and music direction](../../source/combat_audio/README.md).
Zero new third-party imports, external API calls or spend. [Existing FX licenses](../../source/hybrid_combat_fx/README.md)
remain unchanged. No new music generated; Gemini/Lyria is Neal's intended
music resource, with reviewed offline exports planned.

Visual inspection: silhouettes/weapon orientation stay coherent, hit/HP precede
collapse, map→stage→map and post-combat overlays render at game resolution.
The current poses still support a thrust, not a broad slash or fully drawn fall;
Serra's kneeling illustration omits the lance. The bright chapter title could
use stronger contrast in a later UI polish pass. New synthesized cues need
Neal's listening review; the sound-on movie is supplied for that review.

Next recommendation: review this real flow, then a **separate optional active
defense experiment**, initially one incoming melee strike for Kai. Clear
telegraphs and sound, timing/assist options, tactics first. Define dodge/block
damage and forecast/counter semantics with Neal before touching combat rules.
Current evasion is an authored presentation of resolver misses, not timed input.
