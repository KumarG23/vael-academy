# CP-9 — optional dodge/block trial

Based on green **f6736cc0 (CP-8)**. Neal approved the real illustrated battle
flow as the baseline, then authorized this small optional active-defense test.
This is a local experiment; production Mock Battle remains CP-8 combat.

[Motion with sound](defense-practice.mp4): native **1152×648 / 60fps / 22.32s**.
Five actual input/outcome cases: dodge, block, early failure, no input, assist.
Stills and logs are alongside the video. HP remains 26 through judging, then
changes at contact: dodge26, block20, failed/unused15, assisted block20.

## Play

Title → Dev Jump → **Dodge / block practice**, or:

```sh
godot res://scenes/proto/active_defense_pilot.tscn
```

- **Space** / Again starts one incoming Serra thrust; resets local HP each trial.
- **Q** / Dodge avoids damage with a tighter window (green meter zone).
- **E** / Block halves damage, rounded up, with a wider window (gold zone).
- Press as the moving white marker reaches the bright line. A tick marks the cue.
- **Wide practice windows** starts enabled; turn it off for the tighter profile.
- **Auto-block assist** blocks at the cue if no manual attempt was made. A manual
  attempt remains the player's choice and can fail; assist does not overwrite it.
- **Esc** returns to Title, including mid-attack. No saves are written.

One attempt per strike: early, late, held/repeated key or alternate-button spam
cannot replace the first accepted attempt. Keys before the active windup are
ignored. Verdict includes early/late milliseconds and actual damage. The header
shows native incoming damage and both possible defenses before the strike.

## Provisional rules and timing

Base damage is the real CombatResolver's first Serra→Kai strike with independent
seed0 and existing stats/terrain/lance: **11** damage. A successful dodge takes
0, block takes ceil(11×0.5)=6, failed/unused defense takes 11. No bonus counter or
extra RNG. These are trial rules for Neal's review, not a production balance lock.

| Profile | Windup / input deadline | Cue | Dodge half-window | Block half-window |
|---|---:|---:|---:|---:|
| Normal | 0.90s | 0.68s | ±90ms | ±180ms |
| Wide practice | 1.35s | 1.00s | ±180ms | ±280ms |

Block is deliberately easier and less protective; otherwise the full-avoid dodge
would be both easier and stronger. Timing is in `data/proto/active_defense.json`.
Assist triggers at the cue crossing even at low frame rates. The deadline closes
before the existing 0.12s thrust, so the whole-pose sidestep clears the blade
before contact. This judges the **anticipation cue**, not last-millisecond weapon
contact. Later tuning may move the window into authored approach motion.

## Reuse and boundary

`ActiveDefenseTrial` evaluates input and returns an adjusted copy of the native
strike; the original resolver result remains unchanged. The practice juice
finalizes the pending strike before commitment, then the inherited impact
callback applies it **once at contact** to the real local map Unit and HP bar.
Block uses the approved guard/hit illustration, small recoil and metal flash;
dodge uses the existing whole-pose evade. No anatomy deformation/new art.

Only the first incoming strike is replayed. The native exchange's precomputed
counters/follow-ups are discarded, never used after defense changes HP. No XP,
durability, campaign, progression or save writes. Source units are spawned fresh
without campaign overlays. The live combat RNG is untouched. The practice is not
reachable from production combat; only its dedicated Dev Jump/scene uses it.

The only shared presentation change is a default-preserving juice factory in
IllustratedCombatPresentation. CP-8 and prior pilots retain their default player;
the production executor, combat math/formulas, forecasts, saves and campaign
content are unchanged. Future integration needs an explicit forecast contract
and sequential strike resolution after active defense, plus a decision about
which characters/attacks are eligible. No roster rollout is authorized here.

Three new **original synthesized** sounds (cue/block/dodge); generator and source
record: `assets/source/active_defense_audio/`. No third-party imports, new art,
external generation/API calls or spend. Existing HD FX credits remain visible
and [licenses remain bundled](../../source/hybrid_combat_fx/README.md).

## Validation / reproduction

Focused tests: **3/3, 129 assertions**. Covers exact timing boundaries, failures,
one-attempt/spam protection, odd/minimum damage, native misses, assist at 30/60/
144fps and a long frame, actual Q/E input, physical clearance at contact, final
HP/results, unchanged original strike/RNG/XP/inventory/Campaign, and recovery.
Full suite: **560/560 tests, 3,808 assertions, 85 scripts, 148.221s**. Results:
`gut-full-log.txt` (all existing CP-8 integration checks retained). Thirteen
inherited deprecations/two ObjectDB/one resource exit reports remain. A CP-8
async test dialogue-driver lifetime race was exposed and fixed with an instance
validity guard. Final runs have no new runtime errors.
`entry_check.gd` invokes the real Title route and Esc at impact, verifies return,
time scale and unchanged Campaign. Waiting for deferred cleanup/hit-stop timers
returns exit reports to the inherited two ObjectDB / one resource baseline.

```sh
godot --path . --fixed-fps 60 --write-movie /tmp/vael-cp9-defense.avi -s assets/art_review/cp9_defense/capture.gd
ffmpeg -y -i /tmp/vael-cp9-defense.avi -c:v libx264 -crf 20 -pix_fmt yuv420p -c:a aac -b:a 160k -movflags +faststart assets/art_review/cp9_defense/defense-practice.mp4
godot --headless -s assets/art_review/cp9_defense/entry_check.gd
```

Visual inspection confirms intact anatomy/weapon silhouettes, actual pre-contact
clearance on dodge, a smaller block reaction, readable damage/timing and return
to crisp pixel units. The guard pose is reused, not a dedicated drawn parry, and
the meter currently asks the player to read a UI cue. Whether this feels good
enough for the full tactics game remains Neal's playtest decision. Stop at the
trial for review; no campaign rollout. Live PID/log `/tmp/vael-cp9-live.{pid,log}`.
