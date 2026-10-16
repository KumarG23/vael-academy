# VS-1B — Road rescue and aftermath, playable draft v1

2026-10-16. Baseline **f0c43294 (VS-1A, 568 tests green)**.
Neal's locked decisions authorize this narrow story/integration pass. The scene
wording below is a draft for Neal's edit, not a declaration of final prose.
No wider opening, arrival ceremony, lore reveal, or house-choice rewrite.

## What changed and why

The chapter now uses [the revised intro](data/dialogue/road_bandit_intro.json)
and [a new aftermath](data/dialogue/road_bandit_outro.json). Together they are
**39 text panels / 537 words** (intro20/307, aftermath19/230). The map, original
four students, five enemies, objective, non-lethal handling, movement, formulas,
combat RNG and XP are retained. The rescue is staged in the VN; civilians and
escort are not new map units, escort AI or a hidden defend objective.

| Beat | Draft action | Emotional purpose / improvement |
|---|---|---|
| The handoff | Third morning: Hesta checks Kai onto academy supply wagons, leaves one rider, gives concrete illness/travel instructions, waits for them to be repeated, rides ahead. | His collection was personal. His transfer is deliberate. She does not abandon an unprotected boy or sit out a nearby battle. Her need to reach Vael first is legible; her private reason remains private. |
| The trigger | A mother with an injured leg cannot get her young boy behind the well. An axeman approaches. Kai calls out and crosses before his escort can catch him. | A person in immediate danger replaces a generic raid. Kai's action exposes him to danger; it is not a hero speech or a chosen-one announcement. |
| The flare | Green flicker at his brow, then gone. Asked whether he intended it, Kai answers simply: “No.” | Preserves the cave-born mark and involuntary manifestation. Nobody identifies the power or congratulates him for controlling it. |
| Perrin | He intercepts the approach with his blade and presses too far forward. He delights in the audacity, introduces himself, gets “Less talking” from Kai. | Warmth and overeagerness act together; the personality is useful and imperfect. No house rally or invisible cavalry troop. |
| Serra | Pulls them back into a workable line, protects the evacuation, gives Kai a practical instruction when he admits he cannot control the light. | Her criticism comes from the danger. She protects first, without a doctrine lecture or treating Kai as a menace. |
| Rina | Spots the chief directing the raiders before asking about the flare. | Gives the player a useful objective read. Her curiosity still arrives at an awkward moment; she is not only a pair of eyes staring at Kai. |
| The escort | Helps the mother and boy to shelter while Serra creates room. | Explains why the adult is absent from the four-unit tactical force. Hesta's safety arrangement does something worthwhile. |
| The aftermath | Raiders scatter; the boy is still clutching his mother's sleeve. Kai kneels, unties Essa's bundle, shares bread and keeps the heel. | Home becomes something he can carry and give, not something discarded for destiny. The child looks to his mother before taking it: both remain people with agency. |
| The other three | Perrin's cloak offer startles the boy; he slows down and leaves it within reach. Serra steadies a binding. Rina provides water, asks about pain before meaning. | Their first reactions become small actions of care. No vows, instant intimacy, or universal admiration of Kai. |
| Toward Vael | Serra offers to walk together when Kai is ready. He waits for the boy to finish eating. | A modest reason to look forward to the school, without fixing a best friend or revealing the heirs' titles. The offer makes room; it does not collect a new follower. |

## Lines to review together

- Hesta: “I must reach Vael today. Stay with the wagons. Your escort will
  see you through the gates.” Her urgency is clear; a later scene must give the private purpose
  an answer. No new clue about Morvane is added here.
- Serra: “You can't hold the road alone. Back a pace. Give me room. Keep the boy
  low — I'll help his mother.” This should sound like competent urgency, not
  performative coldness. Shorten if it feels over-instructed in a read-through.
- Kai, offering the bread: “Ma packed too much. She usually does.” A small way
  of speaking about home without explaining what he has lost. He keeps some;
  kindness need not mean refusing his own needs.
- Rina: “I was going to ask.” Kai: “I noticed.” The tension stays small and
  unfinished. We should not give her a polished apology for her entire flaw yet.
- Serra: “We're going to Vael too. Walk with us when you're ready.” An invitation
  to share a road is enough for this first meeting.

The writing deliberately leaves the mystery's vocabulary out. There is no
Morvane name, royal explanation, color-system lesson, locket, new warning letter,
secret symbol, or revelation that any heir knows Kai's origin. Hesta and Morvane
sensing the cave event is a **locked GM fact**, preserved by the existing cave
ending/Director response. Sensing the event does not mean knowing the boy's
identity, history, or the other character's thoughts.

One supporting chronology correction: Rina's existing house pitch now says
“turning it over ever since” rather than claiming several nights in the stacks
between this fight and the oath. No ceremony/interface or other pitch rewrite.

The existing `CHARACTER_BIBLE_KAI.md:13` explicitly mentions a younger sibling.
Per Neal's “unless explicitly present elsewhere” boundary, that statement is
preserved rather than silently deleting family canon. It has **no role or
assumption in this road/opening plan**. Tam and Essa remain its emotional center.
No sibling creation or resolution is a dependency for VS-1C.

## Painted-scene sockets — no generated assets

Existing DialogueScene portraits/backdrops do the work; no cutscene or animation
framework was added. `backdrop_fallback` is an optional per-line field. A missing
optional image uses `black`, `white` or `clear` (the real map beneath), without
trying to load a missing resource. Supplying an image at the configured path
activates it on the next playback; no code or JSON edit required. Other dialogue
keeps the existing default black fallback. `clear` also leaves a previous still.

| Missing asset / live JSON socket | Current fallback | Suggested commissioning prompt / composition target |
|---|---|---|
| `assets/art/vn/painted/road_handoff.png` — intro panel1 | Black, text and existing portraits | Wide painted narrative still matching the current VN backgrounds; morning academy supply wagons on a country road, gray-robed older Hesta checking the driver's passenger list, one rider waiting with Kai while another readies her horse. Practical purposeful departure; no ominous villain reveal, new insignia or battle. Keep lower third quiet for narration and side portrait areas clear. Kai is still in traveling/commoner clothes, marked over his anatomical left brow. |
| `assets/art/vn/painted/road_aftermath.png` — aftermath panel1 | Live pixel tactical map | Same small hamlet, well and ford as `prologue.tres`; smoke thinning, ordinary people recovering, scattered belongings, exhaustion rather than triumph. No corpses, named antagonist, unexplained magic or new architecture. Match camera geography to the existing map; quiet lower third. |
| `assets/art/vn/painted/road_bread.png` — aftermath panel4 | Black, quiet narrated emphasis | Intimate painted story still: Kai kneeling beside the well, breaking a modest crushed loaf from Essa's cloth bundle for a young boy close to his injured mother. Boy checks his mother's face; she is conscious and involved. Small human gesture, green mark faint, no spell effect. Warm bread/cloth against cool stone; room below for narration. No posed heroic tableau or theme text. |

Suggested delivery: 16:9, e.g.1920×1080, PNG, reviewed against the existing
painted VN register and approved Kai identity. These are **prompt drafts**, not
API submissions or approved new art. No art/audio generation, purchases or API
spend occurred. Also missing: Hesta/mother/boy portraits and commoner-outfit Kai
expressions; existing fallback cards/portraits remain. No survivor names, faces
or family portrait assets are invented as canon by these prompts. Narration is
text-only where new lines lack existing voice clips. The battle theme resumes
at the intro's final line; aftermath stops music; the unchanged oath restores
the campus track.

## Crownspark: controlled use waits for the Vision

`crownspark.tres.required_story_flag = "crownspark_unlocked"`. Only this resource
uses the new field. No opening script, mark flag, victory, house oath, calendar
week, school flag or default save migration sets it. The later authored Vision
must explicitly set this flag; **the Vision scene is still not built**.

The bound inventory entry remains, preserving saved item order/uses except when
an old equipped spell needs a usable carried weapon moved to the front. Before
the flag it is inert: excluded from Magic/Equip choices, blocked by `Unit.weapon`
for native attacks/counters/AI snapshots, and cannot consume durability through
an invalid direct equip. Old saves get the same lock; no automatic “old means
post-Vision” grandfathering. HP, XP, stats, other items and uses are untouched.
If an old save has ONLY the locked spell, Kai is unarmed until given a usable
weapon or the story flag; we do not invent a replacement sword or overwrite gear.
Innate backfill still preserves ownership but **does not confer control**.

Existing isolated illustrated/A-B sandboxes use private duplicate spell resources
with the gate cleared for their local demos. They never set the campaign unlock
or alter shared definitions. The production presentation regression fixture
explicitly models post-Vision permission. Production New Game/road/academy/arena
and loaded campaign saves use the real locked resource. Combat formulas, RNG,
spell stats, presentation coverage and other schools are unchanged.

## Flow and save contract

- Five existing Awakening scenes unchanged → road intro/handoff/rescue → original
  tutorial battle → victory-only bread aftermath → Victory result → existing
  selected house pitch/oath → Week1 campus.
- `road_intro_seen` is set only after real intro playback; `road_aftermath_seen`
  only after real victory-outro playback. Neither advances the week or unlocks
  a spell. `prologue_done` remains set on result dismissal.
- Mid-battle resume consumes the staged payload and skips the intro. It does
  not repeat Hesta's handoff or claim the aftermath has happened.
- A campaign save made at the completed road result now routes directly to the
  existing oath, using `road_aftermath_seen`; it cannot replay the raid/bread
  simply because result dismissal had not yet set `prologue_done`.
- No mid-dialogue save/resume or new autosave surface is introduced. Existing
  gameplay saves remain version1 and keep using the Campaign flags dictionary.
- Defeat retains its Title/game-over route and does not play success aftermath.
  The unchanged non-lethal road chapter lets wounded heirs rejoin the aftermath;
  nobody is described as unwounded. Optional visits remain available as before.

## Remaining decisions / VS-1C recommendation

1. **Arrival's first social reversal:** reveal Perrin/Serra/Rina's status at the
   gate, after Kai has met people rather than titles. Recommend an institutional
   moment that embarrasses or unsettles him, paired with a practical kindness.
   Keep overt commoner hostility specific to a person, not a chorus of sneers.
2. **The oath's real choice:** recommend hearing all three brief invitations
   before commitment, with a chance to reconsider. Each should offer a real
   benefit and a real source of friction. Don't make one house the humane option.
3. **Kai's first intention on campus:** recommend one small chosen destination or
   person to find, with space to explore. Avoid a compulsory activity tour or an
   early sanctum reveal. A later home-letter payoff should preserve mixed anger
   and affection; it need not be added to arrival itself.

**Recommended VS-1C: Arrival and informed oath**, co-write a brief gate/identity
reveal and adjust the existing pitch preview/confirmation only. Finish at the
same Week1 campus. No new map, roster, magic unlock, full school-day sequence or
Opening Rite rewrite. Hesta's private urgency can remain a tracked later payoff;
settle its answer privately before adding a new clue about it.


## Validation and acceptance

- **576/576 GUT tests, 3,967 assertions, 86 scripts, 148.688s**; eight added
  regression tests, strengthened existing Crownspark/preview tests. Focused
  story/gating/campaign/VN: **35/35, 226 assertions, 1.034s**.
- Graphical real New Game → unchanged Awakening sequence → revised road intro
  → native round-five victory → bread aftermath before result → real Tidemark
  pitch/oath → Week1 campus. Kai never has controlled Magic in this run. Other
  two house continuation mechanisms remain covered by the existing suite.
- Old equipped-spell snapshots, no-sword snapshots, explicit later unlock,
  flag round trips, mid-battle intro suppression, completed-result continuation,
  defeat/no-success-outro, optional still fallback and pilot isolation checked.
- [Captures, scripts and logs](assets/art_review/vs1b_road/README.md). No real
  player save IO in smoke; test save IO is isolated. Reading accelerated; Neal's
  emotional pacing/prose review remains open. Existing13 deprecations/two
  ObjectDB/one resource exit reports remain. No new runtime errors in final runs.
- Scope complete: road scripts/integration, safe controlled-spell gate and save
  compatibility, painted sockets/missing targets, plan/handoff/audit updates.
  No arrival restructuring, combat-formula change, generated art or spend.
