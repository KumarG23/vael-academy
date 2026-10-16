# VS-1A — real opening flow evidence

2026-10-16, based on green 480e783a (CP-9). No new art or audio generated.
Existing authored text, portraits, painted VN backdrops and pixel maps reused.

## Verification

- Full GUT: **568/568 tests, 3,883 assertions, 85 scripts, 149.195s**.
  [Log](gut-full-log.txt). Eight new regression tests plus the existing New Game
  test updated to expect Awakening. Covers order, touch/completion timing,
  calendar, dev isolation, missing content, legacy routing, pre-oath save/load,
  actual road snapshot resumption, all house rosters/rival routing, progression
  retention and clearing stale staged scene transitions on New Game.
- Focused VN/campaign/title: **29/29 tests, 149 assertions, 1.29s**.
  [Log](gut-focused-log.txt).
- Graphical GPU smoke: [runner](smoke.gd), [final log](smoke-log.txt).
  Reproduce with `godot --path . -s res://assets/art_review/vs1a_opening/smoke.gd`.
  Starts from actual Title New Game inputs; Enter drives all 83 VN panels;
  four original allies versus original five bandits, unchanged map/stats/kits,
  seed 1 for reproducibility. AIBrain chooses legal player movements/targets;
  real cursor/menu/forecast inputs execute them through the production combat
  resolver, enemy phases, weapon uses/XP and result. Chief defeated in round 5.
  Result dismissal → real Emberwing pitch/oath → movable Week 1 campus.
  The road campaign checkpoint is then restored in memory for the other two
  real pitches/oaths/campus arrivals. All three War Room mission routes reach
  their correct Opening Rite preparations after finishing the actual intro;
  Escape opens the real preparation menu. No save slots written or deleted.
  Reading is accelerated; this is automated playable-flow verification, not a
  natural-duration human playtest or proof of emotional pacing. War Room opens
  via its existing handler; no new mission content is implemented.
- Native 1152×648 screenshots below, visually inspected for narrative text,
  scene order, fallback portraits, campus and the three rival preparations.
  Long narration now fits in full. No footage was needed for this routing WO.
- Existing exit reports remain: two ObjectDB instances / one resource. Full
  suite also has 13 inherited wait_frames deprecations; no new runtime errors
  in the final runs. First smoke harness attempt used the tactical movement
  action on campus; corrected to campus's existing ui_right, then reran the
  complete path successfully. No production movement code changed.

## Captures

| Beat | Screenshot |
|---|---|
| Title | [01](01-title.png) |
| Forest, unmarked Kai | [02](02-forest.png) |
| Full four-line cave narration | [03](03-long-narration.png) |
| Waking / Essa | [04](04-waking.png) |
| Tam's kept sword | [05](05-tam-sword.png) |
| Kai remains angry | [06](06-family.png) |
| Hesta's command | [07](07-hesta.png) |
| Goodbye | [08](08-goodbye.png) |
| Original road deployment | [09](09-road-start.png) |
| Real attack forecast | [10](10-road-forecast.png) |
| Native road victory | [11](11-road-victory.png) |
| Existing oath cards | [12](12-oath.png) |
| Selected pitch | [13](13-house-pitch.png) |
| First campus arrival | [14](14-campus-arrival.png) |
| Tidemark / Thornrook arrival | [Tidemark](arrival-tidemark.png), [Thornrook](arrival-thornrook.png) |
| Opening Rite preparations | [Emberwing](rite-prep-emberwing.png), [Tidemark](rite-prep-tidemark.png), [Thornrook](rite-prep-thornrook.png) |

## Limits visible in these captures

Parents/Hesta use existing initial-letter fallback cards, not finished portraits.
The current Kai portrait set wears a school uniform before he attends, including
kai_nomark; gray portrait rectangles and ornate nameplate overlap are inherited.
No commoner outfit art was generated. Only the first two scenes have existing
narrator recordings; no opening music is authored. The old sanctum backdrop
remains pending AW-79's art selection. Road rescue introduction and aftermath,
heir-status reveal, and Academy arrival are still missing story scenes. The
existing oath offers one pitch after card selection and binds immediately; not
an improved preview-all choice flow. Opening Rite introductions still speak in Emberwing/Kael voice on other routes.
Opening Crownspark still contradicts the
locked slow-reveal timing; no progression migration was attempted in VS-1A.

Full creative assessment, alternatives and proposed 30–45-minute outline:
[OPENING_STORY_REVIEW.md](../../../OPENING_STORY_REVIEW.md).
