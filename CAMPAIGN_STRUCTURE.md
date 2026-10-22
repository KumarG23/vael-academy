# CAMPAIGN_STRUCTURE.md — The Spine

> **THEME (locked 2026-07-09):** *Belonging isn't given by blood — it's built by what you protect.*


Companion to `MASTER_PLAN.md`, `WORLD_BIBLE.md`, `ACADEMY_BIBLE.md`. This is a **draft skeleton for Neal’s edit**, with explicit approved structural/canon updates below taking precedence over earlier proposals. Unwritten scenes and exact calendar mapping remain open; the approved first-year sequence is not an open structural question. What's already *built and tested* is noted inline so nothing here implies throwing away working code.

---

## Prologue — Awakening, then the Road *(NEW CANON, spine v2 — 2026-07)*

The prologue now opens **before** Vael, with Kai's awakening, and only *then* moves to the road. The awakening scenes 1–5 are **VN / dialogue-cutscene** beats (don't build forest/cave gameplay to ship them); the road raid (scene 6–7) is the practical tutorial battle and **is the already-built prologue chapter** — no rebuild.

1. **Forest boy.** Kai out in the forest he loves — restless, curious, at ease. Establish that exploring is *who he is*, not a quest marker.
2. **The normal cave, the hidden door.** A plain cave the town knows; he's just never explored it. Inside, the relic at his hip warms and the sealed door **opens for him** — recognition, not a puzzle (`CHARACTER_BIBLE_KAI.md` — The Incident).
3. **The ancient chamber.** A First Crown sanctum; a stone floating in runed light. He touches it out of curiosity. Magic explodes — his ancient royal magic wakes. Don't over-explain the stone.
4. **Waking in the village.** He comes to in Oakstead, marked (the silver-white lines), the world already different. The **Academy director's** representative is there / arrives fast: by ancient law he's going to Vael (`ACADEMY_BIBLE.md` §5). Not an invitation.
5. **The parent reveal.** His parents tell him they found him as an infant in that forest, with a sword beside him — and give him the blade. Emotionally central: it hurts because they *hid it*, not because their love isn't real. This is the hook.
6. **The road, and the raid** *(the built tutorial battle)* — below.

## Prologue battle — The Road to Vael (the bandit raid)

**Kai's first battle, and the player's tutorial.** Four travelers, strangers to each other, are on the same road to the Academy when bandits hit a town near Vael on the road in. The four:

- **Kai** — just collected by the Academy rep (`ACADEMY_BIBLE.md` §5), on the road for the first time in his life.
- **Perrin, Serra, Rina** — the three Great House heirs, each traveling in to start the year. None of them announces who they are; to Kai (and the player) they're just three capable young nobles caught in the same mess.

**Why it works:**
- The player meets all three house leaders as *people* before ever choosing a house — which is exactly what an informed house choice needs. No one's a menu option; they're someone you fought beside once.
- It's the perfect stage for Kai's defining trait. The three heirs are cautious and tactical; Kai just *throws himself in* to protect whoever's being hurt, without weighing the odds. That reckless-but-right first impression is how all three of them — and the player — learn who he is, through action, not a bio. (It also seeds every later "you're going to get yourself killed doing that" support beat.)
- Kai's mark and his strange, involuntary magic flicker under the stress of real danger — the heirs notice, nobody understands it, the mystery is planted in minute one.
- Mechanically it's a clean tutorial: small map, a few enemies, one or two allies, teaches movement/attack/terrain before the roster grows.

**Conversation hooks:** Kai can talk to each heir mid- or post-battle. Short, personality-forward exchanges — the player's first read on Perrin (bold, warm, thrilled by a scrappy stranger), Serra (disciplined, sizing everyone up), Rina (watchful, already curious about that mark). None of them know he's the commoner the whole Academy is about to be gossiping about; he doesn't know they're the three most famous students at Vael. The dramatic irony pays off the moment they all arrive.

*Open: who exactly the bandits are hurting, and whether the raid is random or an early, deniable symptom of the kingdom's unrest. **Leaning "looks random, isn't":** the raid can be the dead prince's agents — the first, deniable ripple of his search for the source (and now for the boy it answered). Keep that a subtle seed, not an exposition dump (`WORLD_BIBLE.md` §3b, `VILLAIN_BIBLE.md`).*

---

## Act structure (rough)

1. **Prologue** — the awakening (forest → cave → sanctum → wake → parent reveal, VN), then the road, the raid, meet the three heirs. → arrive at Vael.
2. **Arrival & house choice** — the mark gets noticed, the Academy reacts to a commoner in its halls, each house makes its case (now with faces the player already knows), Kai chooses. This is the full house-choice feature — the fork that changes roster, tactics, conversations, and playthrough.
3. **Semester 1** — opening Clash of Three Banners → slow school/relationship/mystery build including the Tremor → closing Clash and Vision at the semester-1 finale. The Vision grants usable Crownspark; exact scene ordering within that finale remains for Neal’s edit.
4. **Between semesters** — cozy unnamed winter/holiday break: relationships, meals/traditions and personal scenes. Name and actual scenes remain unwritten.
5. **Semester 2** — opening Clash → school and escalating mystery, with the Agent around the semester’s middle → final year-end closing Clash. Every ordinary Clash is three independent houses, friendly/nonlethal with normal tactical defeat. The final Clash has approximately 2–3 friendly rounds before a distinct hostile sabotage emergency: bonded rival students join command, unbonded rivals remain AI protect-targets.
6. **Epilogue → next-act direction** — preserve Alaric’s half-truth and the epilogue’s royal reveal; Morvane stays an off-screen threat through the school year, not a personally attacking school boss. Kai and companions choose to pursue Morvane, motivated by the finale and a concrete lead. Exact lead, destination, timing and next-act content remain UNWRITTEN/TBD.

Across school weeks: school/classes, activities, relationship development and discoveries → end-of-week tactical mission → consequences/reactions back at school. Each week advances a relationship, mystery or story element; not every week needs a major revelation. Named structural slots and open authoring work are in the [draft handoff](docs/FIRST_YEAR_AUTHORING_HANDOFF.md). These are approved structural directions from [#30 decision 6348790766](https://github.com/KumarG23/vael-academy/issues/30#issuecomment-6348790766), not new missions or adopted dialogue. #29 delivered six routed sample contests; #39 graphical acceptance remains pending. No full-year progression, break or sabotage is implemented by this document.

---

## What house choice actually forks

The whole point of un-parking house choice (`MASTER_PLAN.md` §11 → now a real feature) is replayability. Each house should give a distinct playthrough:
- **Different roster** — five unique students + a unique teacher per house.
- **Different conversations & supports** — Kai's bonds are entirely different depending on where he lands.
- **Different tactics & playstyle** — Emberwing swords/cavalry/offense, Tidemark lances/armor/faith, Thornrook bows/reason/technique (`WORLD_BIBLE.md` §2).
- **Different buff, uniform, color** — the `HouseDef` theming that already exists, per house.
- **Different rival dynamics** — whichever house Kai does not pick both compete against his chosen house, and against one another, at every Clash of Three Banners. They are two independent opposing factions, not a single allied rival side. Friendly and nonlethal in fiction; ordinary tactical defeat still applies. This is the approved direction in #22; the six routed chapters' implementation and pending qualification are tracked in #29.

*Scope honesty (not a design change): this means Tidemark and Thornrook eventually need Emberwing's level of build-out — full playable rosters and kits, not just fiction. That's a real milestone for a Fable session, flagged here so it's on the record. The story side (this pass) is house-agnostic groundwork that's worth writing now regardless of build order.*

---

## Approved event direction and remaining authoring

Neal approved the recurring, semester-opening and semester-closing **Clash of Three Banners**, three mutually competing houses, and friendly nonlethal competition with normal tactical defeat in [#22 comment 6340423944](https://github.com/KumarG23/vael-academy/issues/22#issuecomment-6340423944) (Discord decision 1562800434702196807). The name was approved in [#22 comment 6340542559](https://github.com/KumarG23/vael-academy/issues/22#issuecomment-6340542559) (Discord decision 1562802189938982935). Approved campus anticipation/reaction is direction only; new dialogue remains Neal co-write material.

Neal’s [#30 decision 6348790766](https://github.com/KumarG23/vael-academy/issues/30#issuecomment-6348790766) (Discord 1562902264115494963, following 1562899716633534615) confirms two semesters, a cozy break between them, the weekly school → mission → reactions rhythm, the existing milestone order, and a distinct final sabotage after approximately 2–3 friendly rounds. The 2026-07-10 co-write remains the story basis; Claim/belonging/bonds and the off-screen threat/epilogue reveal remain intact. Morvane personally attacking students is not approved. The six-week sample is **development scaffolding**, not a definitive year or implicit semester map; fixed week numbers do not own the structural beats.

## Open / Placeholder List

See [#30](https://github.com/KumarG23/vael-academy/issues/30) and the [draft calendar authoring handoff](docs/FIRST_YEAR_AUTHORING_HANDOFF.md) for remaining decisions: exact lengths/dates and event/beat placement, weekly relationship/mystery/mission/reaction content, break name/scenes, sabotage details, concrete pursuit lead/destination/timing, and treatment of legacy saved positions. Do not ask again whether there are two semesters, whether the six weeks are scaffolding, or whether sabotage is a separate interruption. No new authored content is finalized here.


## ⚖ CANON UPDATE — co-write session 2026-07-10 (record: COWRITE_SESSION_2026-07-10.md)

- **Pacing (locked):** story beats decouple from week numbers; the calendar
  grows without doc rewrites. Semester 1 = the slow FE3H build (school life,
  friendships, clues piling: the locket, the margin note, missing-persons
  gossip, one small mission) plus **the Tremor** (a 5-second mark-flare at the
  sealed stacks — a shiver, early). **The VISION is the semester-1 finale**
  (and grants usable Crownspark). **The Agent** lands mid-semester 2; **the
  Closing Rite** ends the year; the epilogue carries Alaric's half-truth and
  the only spoken "prince".
**Historical W5/W6 labels below are beat identifiers from the co-write, not binding calendar indices.** The approved two-semester order above governs the later authored map.

- **W5 The Agent (locked shape):** a mid-battle forced choice — chase the
  fleeing agent or save the endangered; the Patron learns of Kai either way
  (signal already sent); the branch decides cost + which clue you take. The
  agent is later recognized as one of the missing.
- **W6 Closing Rite (locked shape):** opens house-vs-house (2–3 rounds), the
  rite is sabotaged, and **bonded rivals join the player's command** while
  unbonded ones become AI protect-targets — the year's friendships literally
  become the army. The employer glimpse moves to the epilogue.
- **The Returned:** freed claimed choose — join the army (roster growth
  across the campaign) or go home (visitable town NPCs, families, lit
  windows as the war's progress bar).
- **Prologue scenes 1–5 are authored** (co-write): data/dialogue/prologue_
  {forest_intro, cave_awakening, oakstead_wake, parent_reveal, director_arrives}.json,
  played by scenes/flow/prologue_vn.tscn (scenes 1–2 fully wired: backdrops +
  the hearth narrator's voice).



## VS-1B locked road direction — Neal, 2026-10-16

Hesta personally collects Kai, then intentionally transfers him to an
academy-associated escort/travel arrangement and rides ahead on urgent business.
She is already away when the raid occurs. Kai's immediate protection of an
endangered family introduces Perrin's warmth/overeagerness, Serra's protective
organization and Rina's useful observation. Afterward he shares Essa's packed
bread with a recovering survivor. The opening remains centered on Tam and Essa;
no sibling assumption drives this sequence. The cave gives the mark and
involuntary flares, never controlled Crownspark; the later Vision remains its
unlock. Hesta and Morvane sense a major ancient-magic event, not automatically
Kai's identity or origin. Exact new road prose is a playable draft for Neal's
edit (`VS1B_STORY_NOTES.md`); arrival/oath restructuring is not part of VS-1B.


### VS-1B approved package integration — Neal, 2026-10-16

The supplied story package now frames the existing five Awakening scenes with
an ordinary Tam/Essa/Kai kitchen morning and a separate first-waystation Hesta
departure. The girl at the well escapes with the road warden before tactical
control. Perrin, Serra and Rina intervene independently; no prior Kai acquaintance
or shared heir travel party is assumed. They exchange first names after the raid.
Essa's dry travel bread is shared with the girl beside her mother. The four
package scenes preserve the supplied first-pass prose. Paintings/portraits are
review candidates; gate/registry/house-pitch drafts remain VS-1C proposals in
`docs/story_packages/vs1b/`. The current selected-pitch/oath mechanism is unchanged.
No new revelation or controlled spell unlock is added. See `VS1B_STORY_NOTES.md`.
