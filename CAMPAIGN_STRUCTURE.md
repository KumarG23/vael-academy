# CAMPAIGN_STRUCTURE.md — The Spine

> **THEME (locked 2026-07-09):** *Belonging isn't given by blood — it's built by what you protect.*


Companion to `MASTER_PLAN.md`, `WORLD_BIBLE.md`, `ACADEMY_BIBLE.md`. This is a **draft skeleton to react to**, not locked canon — the shape of the campaign so the bibles have something to hang on. Names and beats past the prologue are all open. What's already *built and tested* is noted inline so nothing here implies throwing away working code.

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
3. **Opening inter-house battle** — the year's first Mock Battle rite (`ACADEMY_BIBLE.md` §4). *This is the currently-built Chapter 1 / Mock Battle content (WO-4.1, done, 245 tests green) — reframed as the opening rite, not rebuilt.*
4. **The school year** — the living-castle core (`ACADEMY_BIBLE.md` §3): exploration, conversations, fishing/cooking/study, smaller missions off the War Room board, holidays and parties, exams. The kingdom mystery escalates quietly underneath the warmth.
5. **Closing inter-house battle** — the year's climax; everything the player and their house have grown into.
6. **Beyond year one** — where the First Crown mystery stops being quiet and the **dead prince** steps out of the shadows (`WORLD_BIBLE.md` §3b, `VILLAIN_BIBLE.md`). Deliberately unbuilt; the slice proves the loop first, then the plan extends.

---

## What house choice actually forks

The whole point of un-parking house choice (`MASTER_PLAN.md` §11 → now a real feature) is replayability. Each house should give a distinct playthrough:
- **Different roster** — five unique students + a unique teacher per house.
- **Different conversations & supports** — Kai's bonds are entirely different depending on where he lands.
- **Different tactics & playstyle** — Emberwing swords/cavalry/offense, Tidemark lances/armor/faith, Thornrook bows/reason/technique (`WORLD_BIBLE.md` §2).
- **Different buff, uniform, color** — the `HouseDef` theming that already exists, per house.
- **Different rival dynamics** — whichever house Kai *doesn't* pick are the ones across the field at the inter-house battles.

*Scope honesty (not a design change): this means Tidemark and Thornrook eventually need Emberwing's level of build-out — full playable rosters and kits, not just fiction. That's a real milestone for a Fable session, flagged here so it's on the record. The story side (this pass) is house-agnostic groundwork that's worth writing now regardless of build order.*

---

## Open / Placeholder List
- Everything past the closing battle (intentionally blank)
- Whether the prologue is one battle or a short prologue chapter with travel scenes around it
- Number of "school year" missions between the two inter-house battles
- How the mystery's escalation is paced against the calendar (a beat per term? per holiday?)


## ⚖ CANON UPDATE — co-write session 2026-07-10 (record: COWRITE_SESSION_2026-07-10.md)

- **Pacing (locked):** story beats decouple from week numbers; the calendar
  grows without doc rewrites. Semester 1 = the slow FE3H build (school life,
  friendships, clues piling: the locket, the margin note, missing-persons
  gossip, one small mission) plus **the Tremor** (a 5-second mark-flare at the
  sealed stacks — a shiver, early). **The VISION is the semester-1 finale**
  (and grants usable Crownspark). **The Agent** lands mid-semester 2; **the
  Closing Rite** ends the year; the epilogue carries Alaric's half-truth and
  the only spoken "prince".
- **W5 The Agent (locked shape):** a mid-battle forced choice — chase the
  fleeing agent or save the endangered; the Patron learns of Kai either way
  (signal already sent); the branch decides cost + which clue you take. The
  agent is later recognized as one of the missing.
- **W6 Closing Rite (locked shape):** opens house-vs-house (2–3 rounds), the
  rite is sabotaged, and **bonded rivals join the player's command** while
  unbonded ones become protect-targets — the year's friendships literally
  become the army. The employer glimpse moves to the epilogue.
- **The Returned:** freed claimed choose — join the army (roster growth
  across the campaign) or go home (visitable town NPCs, families, lit
  windows as the war's progress bar).
- **Prologue scenes 1–5 are authored** (co-write): data/dialogue/prologue_
  {forest_intro, cave_awakening, oakstead_wake, parent_reveal, director_arrives}.json,
  played by scenes/flow/prologue_vn.tscn (scenes 1–2 fully wired: backdrops +
  the hearth narrator's voice).

