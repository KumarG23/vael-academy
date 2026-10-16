# VS-1B — approved package reconciliation and review

2026-10-16. Package revision based on **ede37ffb**, the already green VS-1B
implementation (576 tests). The supplied package describes the older VS-1A
baseline; its missing-outro/early-spell observations were already repaired.
The original integration and save-safe controlled-magic gate are preserved.
The complete unchanged supplied manuscripts, including **unimplemented VS-1C
drafts**, are archived in `docs/story_packages/vs1b/`.

## What the player now experiences

| Runtime slot | Scene / emotional work | Painting |
|---|---|---|
| `PrologueVN` first script | **Morning at home**, exact supplied kitchen banter. Kai is funny, useful, reckless and loved before becoming a mystery. Essa's ordinary “come home” request prepares the goodbye. | One morning relight of the existing night kitchen, used for the entire scene. |
| Next five scripts | Existing forest → cave → waking → parent reveal → Hesta/goodbye. **All text, events, voices, backdrops and ordering retained**; presentation IDs use commoner Kai and actual parent/Director portraits. | Existing reviewed environments reused. |
| `PrologueVN` final script | **Waystation**, after one day. Hesta hands a sealed travel order to the road warden, rides ahead with a stated practical purpose and a withheld private reason. Days-later smoke ends the transition. | Waystation handoff, then hamlet approach. |
| Original chapter intro | **Rescue**. Kai runs at the threat to a specific girl. Serra shields; Perrin arrives on horseback with useful audacity and an imperfect entrance; Rina identifies the escape lane. Warden evacuates families **before map control**. | Well/cart environment, Kai rush, four strangers. |
| Original tactical battle | Same four allies, five axe bandits, map, objective, non-lethal handling, XP, uses, RNG and formulas. | Pixel map/current combat presentation retained. |
| Victory-only chapter outro | **Recovery → bread → names**. Child and mother remain together. Essa's travel-worn bread becomes a piece of home Kai can give. Serra asks him to plan; Perrin and Rina find a first shared joke. No instant vows or royal titles. | Recovering square; dedicated bread painting held through the exchange; return to square for group conversation. |
| Existing result/house/campus | Aftermath finishes before result, then existing selected pitch/oath and Week1 campus. | Existing UI/art. No gate/registry/all-pitch redesign. |

The four new/package scripts keep **every supplied line verbatim**. Presentation
changes: road speaker labels say Lancer/Rider/Traveler until names are exchanged;
actual portraits replace letter cards; travel Kai never wears an academy uniform;
bread painting returns to aftermath at Serra's first critique; baseline silence /
battle-music cues retained. Portraits reset between scripts so Essa cannot remain
as a silent figure in the forest. Bread alone opts into small framed portrait
insets: native review showed full-size duplicate figures competing with the
painted gesture. The standard layout returns for the group exchange and resets
for every new script. No new cinematic engine or mechanic.

## Independent creative assessment

The kitchen is the biggest improvement. “The goat won” gives Tam an entire
relationship in three words. Kai's useful habit of saying yes becomes the same
flaw that makes him run toward danger. The bread now pays off **both** the warm
morning and the difficult goodbye, without having someone explain the theme.
The child initially refusing food protects the scene from becoming a reward
ceremony for Kai's kindness. The three strangers solve different parts of the
same immediate problem; this earns curiosity more effectively than house slogans.

The risks are still real. Hesta's “I rarely give one before it is useful” can
sound like a writer announcing withheld information. Her scene is twenty panels,
so “short” depends on delivery; review whether the sword exchange needs all its
beats before adding any further mystery. The rescue is twenty-eight panels
before the player gets tactical control: its action should be read briskly and
must not grow into a tactical lecture. The aftermath's “Only if you're someone
she loves” is poignant but polished; judge whether it sounds like this frightened
boy, rather than preserving it just because it quotes well. These remain review
notes, not silent edits to approved prose.

The existing oath still cuts straight from shared road to faction selection,
reveals status without the drafted arrival scene, and plays only one selected
pitch. That remains a visible **VS-1C gap**, not a newly invented bridge. Existing
Thornrook pitch still references the road mark; no new explanation is introduced.
New story lines remain text-only where VO/music were not already authored.

## Art review and provenance

See `assets/source/vs1b_story_art/README.md` for reuse decisions, all generation
versions/rejections, prompt/reference hashes, selected sources and costs policy.
Eight painted story stills; commoner Kai before/after mark and expression variants;
Tam, Essa, Hesta, child and warden portrait candidates. The new supporting faces
are **visual-review candidates**, not finalized appearance canon.

The bread is painted into the scene behind dialogue portrait insets. Its offer is high
in the center, away from side portraits and the text box; no flattened text or
new pan/animation system. Native screenshots and normal-speed text playback are
in `assets/art_review/vs1b_package/`. Review these crops, not just the masters.
The multi-heir and aftermath iterations rejected duplicated people; the selected
aftermath deliberately depicts ordinary recovery work while the named students'
actions happen off frame. All previous green captures are preserved separately.

## State, saves and controlled magic

`opening_complete` now follows the waystation. The cave alone sets
`kai_awakened`; no new scene event advances calendar, grants items, or unlocks a
spell. Preview plays all seven without Campaign writes. Existing completed
opening saves continue to the road; package updates do not rewind older players.
Pre-opening saves begin at home, mid-battle resumes suppress intro, completed-road
result saves continue to oath, and defeat never plays success aftermath.

**Crownspark is preserved as a separately tested progression concern.** The
existing `crownspark_unlocked` gate, eligible-carried-weapon repair for old saves,
inert bound inventory entry/backfill, native snapshot/counter protection and
private demo-resource isolation are unchanged. No grandfathering, further
migration or new unlock is introduced. The later Vision is still unbuilt and
must grant controlled use explicitly. Cave mark and involuntary road light remain.

Neal expanded the scope during review to restore PixelLab MCP and add pixel
battlefield fire. The credential-aware client/stdio registration now work, and
one real pro-mode VFX Creator export animates the existing burning cottage.
It cost8 generations, with12 frames/10fps, nine opaque palette colors and clean
binary alpha. Cosmetic-only map rendering preserves the full battle payload;
no new magic or gameplay system. `VS1B_VFX_PILOT.md` records sources and checks.

## Next co-write / VS-1C

1. **Status reveal:** use the supplied gate/registry draft as a starting point;
   keep the joke about shouting more politely, but avoid a chorus of anonymous
   commoner sneers. Let practical behavior carry the social hierarchy.
2. **Informed oath:** hear all three brief invitations and reconsider before
   binding. Preserve real warmth and friction in each route. Edit the supplied
   pitches together; none is production-authorized by this pass.
3. **First campus intention:** choose one person or place Kai wants to find,
   with room to explore. Hesta's private urgency needs a later payoff, not an
   explanatory speech at the gate.

Recommend **VS-1C: gate, names and informed oath**, ending at the existing Week1
campus. No full school day, roster expansion, Vision, new map or combat system.


## Final verification

- Full Godot/GUT **585/585**, 4,336 assertions, 88 scripts, 152.958s.
- Focused opening/road/fire/gating/campaign **44/44**, 595 assertions, 3.368s.
- Six Python credential/stdio tests; live authenticated tools/list and actual
  VFX creation/retrieval/export verified. No credential committed.
- Native NewGame/seven scripts → original seed1/round5 road victory → bread
  before result → all three original pitches/oaths → Week1 campus. Completed-
  road save/load uses an isolated directory; no player slots touched.
- Full100-panel native story playback3m24.9s; real pixel road/fire/threats8.03s,
  including unchanged full battle payload. Selected native screenshots inspected.
- Inherited13 GUT deprecations and two ObjectDB/one resource exit reports remain;
  no new runtime failure in final captures or tests.
- 45 Gemini requests (44 delivered/one connection failure), 12 final portrait
  candidates/eight paintings; rejected styles/versions retained, exact reference
  snapshots preserved. PixelLab one effect/8 generations. Gemini dollar billing
  is not returned by the configured helper.
