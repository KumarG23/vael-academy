# CAMPAIGN_STRUCTURE.md — The Spine

Companion to `MASTER_PLAN.md`, `WORLD_BIBLE.md`, `ACADEMY_BIBLE.md`. This is a **draft skeleton to react to**, not locked canon — the shape of the campaign so the bibles have something to hang on. Names and beats past the prologue are all open. What's already *built and tested* is noted inline so nothing here implies throwing away working code.

---

## Prologue — The Road to Vael (the bandit raid)

**Kai's first battle, and the player's tutorial.** Four travelers, strangers to each other, are on the same road to the Academy when bandits hit — a raid on innocent travelers or a roadside village. The four:

- **Kai** — just collected by the Academy rep (`ACADEMY_BIBLE.md` §5), on the road for the first time in his life.
- **Perrin, Serra, Corin** — the three Great House heirs, each traveling in to start the year. None of them announces who they are; to Kai (and the player) they're just three capable young nobles caught in the same mess.

**Why it works:**
- The player meets all three house leaders as *people* before ever choosing a house — which is exactly what an informed house choice needs. No one's a menu option; they're someone you fought beside once.
- It's the perfect stage for Kai's defining trait. The three heirs are cautious and tactical; Kai just *throws himself in* to protect whoever's being hurt, without weighing the odds. That reckless-but-right first impression is how all three of them — and the player — learn who he is, through action, not a bio. (It also seeds every later "you're going to get yourself killed doing that" support beat.)
- Kai's mark and his strange, involuntary magic flicker under the stress of real danger — the heirs notice, nobody understands it, the mystery is planted in minute one.
- Mechanically it's a clean tutorial: small map, a few enemies, one or two allies, teaches movement/attack/terrain before the roster grows.

**Conversation hooks:** Kai can talk to each heir mid- or post-battle. Short, personality-forward exchanges — the player's first read on Perrin (bold, warm, thrilled by a scrappy stranger), Serra (disciplined, sizing everyone up), Corin (watchful, already curious about that mark). None of them know he's the commoner the whole Academy is about to be gossiping about; he doesn't know they're the three most famous students at Vael. The dramatic irony pays off the moment they all arrive.

*Open: who exactly the bandits are hurting, and whether the raid is random or an early, deniable symptom of the kingdom's unrest (`WORLD_BIBLE.md` §4). Leaning toward "looks random, isn't."*

---

## Act structure (rough)

1. **Prologue** — the road, the raid, meet the three heirs. → arrive at Vael.
2. **Arrival & house choice** — the mark gets noticed, the Academy reacts to a commoner in its halls, each house makes its case (now with faces the player already knows), Kai chooses. This is the full house-choice feature — the fork that changes roster, tactics, conversations, and playthrough.
3. **Opening inter-house battle** — the year's first Mock Battle rite (`ACADEMY_BIBLE.md` §4). *This is the currently-built Chapter 1 / Mock Battle content (WO-4.1, done, 245 tests green) — reframed as the opening rite, not rebuilt.*
4. **The school year** — the living-castle core (`ACADEMY_BIBLE.md` §3): exploration, conversations, fishing/cooking/study, smaller missions off the War Room board, holidays and parties, exams. The kingdom mystery escalates quietly underneath the warmth.
5. **Closing inter-house battle** — the year's climax; everything the player and their house have grown into.
6. **Beyond year one** — where the wardstone mystery stops being quiet. Deliberately unbuilt; the slice proves the loop first, then the plan extends.

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
