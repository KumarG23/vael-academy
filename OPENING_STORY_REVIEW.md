# Opening story review — VS-1A

VS-1B follow-up: road rescue/aftermath and controlled Crownspark gating are
now implemented as a playable draft; current notes: `VS1B_STORY_NOTES.md`.
The baseline assessment below is retained; arrival proposals still await review.

2026-10-16. Implementation baseline: **480e783a (CP-9, 560 tests green)**.
This is a creative assessment and proposal document, not new canon or approved
replacement dialogue. The user-authorized scope is one opening-flow WO. Existing
co-write prose is connected unchanged; substantial new scenes await Neal's edit.

## Judgment

We have the makings of a distinctive opening, but the baseline player experience
is not yet that opening. New Game jumps straight to a largely silent tactical
map. The best writing—the parents, the kept sword, Hesta at the door—was invisible
there. Connecting it is necessary; it does not by itself earn attachment to Kai,
make the road rescue legible, or make the house choice emotionally informed.

The strongest hook is **a loved boy discovering that his parents have hidden part
of his life just as an institution comes to take him away**. The magical cave is
an effective disturbance. It is not, by itself, our differentiator. The family's
imperfect love and the Academy's mixture of coercion and possibility are.

The opening should leave the player wanting two things at once: to get back to
Essa and Tam, and to find a place with these new people. If the family is only a
sad introduction that disappears once the school opens, we have promised the
wrong game. Keep the loss alive through ordinary contact and player attention,
not repeated speeches about belonging.

## Sources and precedence

Read against the actual JSON, scenes and scripts, not just status claims:
`HANDOFF.md`, `MASTER_PLAN.md` §2/§3/§8/§10, `AUDITS.md`, `STORY_CRAFT.md`,
`COWRITE_PLAN.md`, the complete `COWRITE_SESSION_2026-07-10.md`,
`WORLD_BIBLE.md`, `ACADEMY_BIBLE.md`, `CAMPAIGN_STRUCTURE.md`,
`VILLAIN_BIBLE.md`, Kai/heirs/all three house character bibles, and Nilu's bible.
`PLAN_REWRITE_AUDIT.md` supplies the preservation rationale. July 10 locked
rulings and bible canon-update blocks supersede older contradictory paragraphs.
Some scene prose in the session is still labeled DRAFT v1; "authored" here means
existing written co-write material, not a claim of final line-by-line approval.

Locked: the theme; no sword in the cave; Tam gives it after the foundling reveal;
green left-brow mark after the awakening; Tam/Essa; Hesta collects Kai personally;
commoners have no surnames; involuntary opening magic; usable Crownspark at the
semester-one Vision. Morvane/Claim/split inheritance remain GM knowledge. Keep
pixel exploration and tactical maps, existing painted VN art, and the approved
illustrated battle direction. This WO does not expand battle-art coverage.

## What a player actually encounters

| Beat / actual source | Baseline availability and emotional purpose | Know / feel / wonder | Character versus exposition; assessment |
|---|---|---|---|
| Title → Classic/Casual (`title_screen.gd`) | Normal New Game immediately enters `battle/prologue.tscn`. Placeholder title calls the game Emberline Tactics. | Know almost nothing about Kai; expect a tactics tutorial. | No emotional premise before deployment. |
| Forest (`prologue_forest_intro.json`, 9 panels) | Previously Dev Jump only. Comfortable forager, errands, self-aware delay, familiar cave. | Know he has a home and restless curiosity; feel easy amusement; wonder why today will differ. | Specific mushrooms and Ma's deadline are good character. Narrator then explains his curiosity twice. Kai has no other person to bounce against. |
| Cave → sanctum → blast (`prologue_cave_awakening.json`, 18 lines + flag event) | Dev Jump only; last playable preview scene at baseline. Begins unmarked; warm recognition; white flash; distant searching presence. | Know something answered him and hurt him; feel wonder turning to alarm; ask what recognized him and who noticed. | "This is such a bad idea" is human. "Not because he was clever" overexplains the mechanism and devalues the curiosity we just established. Numerous narrated movements can feel like reading stage directions. |
| Oakstead waking (`prologue_oakstead_wake.json`, 10 panels) | Written with existing cottage backdrop, disconnected at baseline. Familiar bed, frightened Essa, watchful Tam, new mark, riders. | Know he was gone a day and something is changing at home; feel vulnerable; ask why his parents exchange that look. | Tam watching the road gives him a competing priority without a lecture. Essa's concern is credible, but we have not met her before this crisis. |
| Family reveal (`prologue_parent_reveal.json`, 23 panels) | Written and disconnected; existing lantern-kitchen backdrop. Foundling secret, anger, Tam leaves and returns with the sword, hands held. | Know the raising was real but the history was concealed; feel hurt and tenderness together; ask who left him and why the blade answers. | Our best scene. Tam's sixteen winters are care made material. "I'm still angry … Don't let go anyway" allows an unresolved relationship. The narrator's "least important thing" explains a conclusion the hands already express. |
| Hesta / goodbye (`prologue_director_arrives.json`, 23 panels) | Written and disconnected; kitchen and first-light backdrops exist. Mandatory admission, forty-soldier threat, "Bring the sword," bread, buckle, look back. | Know leaving is compulsory; feel anger, unease, affection; ask how Hesta knows, what Vael wants, whether Kai can return. | Strong entrance and physical goodbye. Threat may make Hesta seem villainous despite the bible; she needs evidence of costly restraint eventually. "The last night" can imply death or permanent loss beyond what canon promises. |
| Road raid (`prologue.tres`, `battle_view.gd`) | Normal baseline first scene. Four controllable allies, five enemies, burning house, visits, defeat-chief objective, non-lethal retreats. **No intro/outro/boss dialogue paths assigned.** | Know rules and positions; feel tactical engagement, but the protected person and Kai's motivation are absent on-screen. | Kai starts stationary beside strangers; player can proceed methodically. The documented reckless rescue is not enacted. Mechanical tutorial scaffolding exists; do not confuse it with a complete narrated tutorial. |
| Road intro file (`road_bandit_intro.json`, 9 panels) | Written draft, **not referenced by the chapter**. Kai sees a child, ignores Envoy, heirs respond. | Intended: admiration, friction, relief; ask about the mark. | Has useful comic interruption. "Emberwing, on me!" identifies a house before the intended arrival reveal; "lances" and a rallied house imply troops the map does not field. Envoy/Hesta escort continuity is unresolved. Not connected in VS-1A. |
| Optional hamlet visits (`visit_hamlet_cottage/house.json`) | Two authored map interactions; cottage grants vulnerary. | Know people were frightened; feel useful; learn camp/terrain advice. | Wounds/carry-home line humanizes the reward. Farmer's quiet-wardstones line sounds like the deprecated plot. Advising archers is odd with the actual opening party. These are drafts, not the rescue's emotional payoff. |
| Victory → oath (`_on_result_dismissed`, `house_choice_scene.gd`) | Result dismissal sets `prologue_done`; immediate three-card oath menu. | Know house labels and weapon identities; feel relief, then pressure to choose; ask why no arrival or introductions happened. | No named civilian thanks, aftermath, journey conclusion, or Academy reaction. The narrative jumps across the scene that should turn strangers into famous heirs. |
| Selected pitch (`house_pitch_*.json`, 6 panels each) | Only the selected card's pitch plays; finishing it **automatically binds** that house. No preview-all / reconsider step. Existing prose drafts, not July 10's completed pitch co-write. | Intended: feel wanted for different reasons. Actual: player chooses before hearing the argument. | Perrin warm but sales-like; Serra forceful and already caring; Rina admits her flaw remarkably fluently. Each diagnoses Kai too completely for a first encounter. Claims about observed rescue/mark have no enacted baseline callback. |
| First campus (`castle_scene.gd`) | House locks; roster/theme changes; walkable campus, Week 1 Opening Rite. War Room routes the proper rival chapter for every house. | Know Vael is a substantial place; feel curiosity, possibly abandonment without a welcome; ask where to go and who cares that he arrived. | Space and activities offer real promise. No authored first-arrival scene bridges the family's loss to this freedom. Early warmth is discoverable, not dramatically established. |
| Beyond arrival (existing systems, not this WO) | Classes, fishing, training, supports, calendar, mission preparation and three-house rivals function. Supports and many campus lines remain drafts; content parity lags mechanical parity. | Potential to build attachments through repeated encounters. | A large set of activities cannot substitute for a reason to seek out a particular person tomorrow. |

After VS-1A, normal New Game plays forest → cave → wake → family → Hesta/goodbye
→ unchanged road battle → unchanged oath/pitch → campus. The formerly standalone
VN now previews all five scenes, returns to Title, and cannot write Campaign.
This restores the established order, not the missing road/arrival drama.

## Honest creative assessment

**Hook and Kai.** The forest's errands and dry bargaining with himself are good.
Kai has an appetite (go farther), a flaw (discount the consequences), and a voice
before anyone explains his magic. But the current sequence proves curiosity far
more than kindness. It tells us his instinct is to get between people; the
normal battle then gives no dramatic context in which to notice it. Give him an
ordinary, inconvenient act of care before giving him cosmic importance. Do not
turn him into a humor dispenser: his jokes should avoid embarrassment, buy time,
or conceal fear, and occasionally land badly. Let him be wrong about a person.

**Family and loss.** The reveal is emotionally specific enough to keep. The
misread of Tam leaving, then the bundle returning, is our strongest reversal.
Essa accepting responsibility avoids making love an excuse. But the player has
never experienced the normal family that is being lost. We ask for grief before
we supply a memory. A small shared chore, an affectionate irritation, or an
unfinished argument would do more than an extra origin paragraph. Keep Kai angry
after the handclasp. A later letter can contain both missing home and refusing
to say everything is fine. VS-1B clarification: the older bible explicitly mentions a younger sibling,
so that statement is preserved outside this opening work. The opening plan
assumes only Tam and Essa; a sibling is not a writing dependency.

**Mystery.** The playable VN wisely does not name First Crown, Morvane, royal
blood, the Claim, or the Academy sanctum. Preserve that restraint. Recognition,
the new mark, the blade's warmth, and Hesta's knowledge are enough. Repeated
crown-shaped imagery plus narrator certainty already make "secret royalty" easy
to predict. Let the question be less "is he special?" and more "why do adults
think they can decide what he is?" Do not add a villain cutaway or explain the
color system. Leave the cause of Hesta's sword knowledge unresolved *to players*,
but settle its literal answer privately before adding further clues about it
(STORY_CRAFT's answer-first rule). The record explicitly leaves two alternatives.

**Hesta.** She is memorable immediately. The personal appearance, neutral trims,
gold thread, measured threat and specific command are a coherent person, not a
lore kiosk. Yet "forty soldiers" followed by no visible protective act risks
teaching players she is simply the enemy. Do not soften her into a kindly
headmistress. Propose one practical intervention that costs her convenience or
political cover, while she still refuses Kai an explanation. The tension should
be that she offers a real protection at a price he did not consent to, not that
the script insists we like her. Her commoner history is a later recontextualizer,
not an entrance biography.

**Heirs.** Their bibles contain excellent competing instincts; the current
normal opening barely dramatizes any of them. Perrin's enthusiasm should cause
a small social mistake; Serra's caution should save someone; Rina's observation
should solve a problem while missing a person's need. Give each an independent
objective before asking what they think about Kai. Avoid three admirers orbiting
the protagonist. Let Kai appreciate Serra and resent her in the same scene.
Rina's pitch promises a mature ethical self-awareness that should take time to
earn. Perrin calling the other houses cages/dissections undersells equal routes.
Serra's hearth metaphor, meanwhile, overlaps the global theme too conveniently.

**Pacing and tone.** All five scripts total **83 text panels / ~1,440 words**;
only nine panels have voice clips, all in the first two scenes. Reading rate,
typewriter and advance pauses matter: this is roughly 10–16 minutes before
ordinary gameplay, not a guaranteed five-minute hook. Measure with Neal. The
sequence has five escalating revelations with little normal life between them.
Its best breathing spaces are the silence before the sword, the belt adjustment,
and the single look back. Keep those. Trim repeated explanation, not tenderness.
"It is, from Tam, a speech" earns its place through character; narrating that the
sword is less important than love is less necessary. Spoken characters stay
text-only under the established narration frame.

**Academy and originality.** Three noble houses, secret royal foundling, awakening
relic, compulsory elite school, dead prince and student war rites are familiar
pieces. A fourth and superior bloodline can accidentally vindicate the hierarchy
we mean to question. Do not resolve snobbery by proving Kai is the noblest boy.
Our distinctive material is a family that chose him before he mattered, the
only student allowed to choose a house in a society that inherits it, Hesta's
law that "protects" by taking, and the later counterfeit belonging of the Claim.
The school should invite attachment through shared inconvenience, habits and
repeated places, not a tour of features. The contrast matters: warm inhabited
windows above sealed architecture, a roll call that makes "of Oakstead" sound
like a missing surname, a grand hall where someone quietly makes room for him.
These are proposals, not inserted canon.

## Continuity and payoff ledger

| Issue | Evidence and disposition |
|---|---|
| Sword history | July 10 R1 overrides older carried-since-childhood paragraphs in Kai/WORLD/CAMPAIGN. Connected JSON correctly keeps it home until Tam's reveal. No bible rewrite here. |
| Rescue → heir friendship | No chapter intro/outro and no authored mid-battle heir chats. Pitches refer to a rescue and mark flare the actual battle does not stage. Priority next co-write. |
| Escort convenience | Hesta personally collects him; disconnected road draft says Envoy; a senior battlemage plus riders could trivialize five bandits. Decide her location and constraints before wiring that file. Do not replace a name and pretend this solves it. |
| Heir anonymity / party | Road draft announces Emberwing and implies accompanying forces. Decide what Kai learns when, and make staging match the actual four-unit party. |
| Hesta's sword knowledge | Session leaves knowledge-source alternatives open. Her line is established and can play unanswered; new follow-up clues require a private answer. |
| Awakening knowledge | Baseline VN emits `set_flag` with no receiving handler; fixed in VS-1A for campaign playback only. Touch sets `kai_awakened`, full goodbye sets `opening_complete`; neither means road victory. |
| Save continuation | Real battle id `prologue` was absent from `RESUME_SCENES` (only legacy `hamlet_cottage` alias). Fixed; no new save schema. Older pre-oath saves do not acquire a retroactive VN obligation. |
| Calendar | AW-76 already gates victory advancement on house lock. Preserved/tested: Week 1 through arrival; Opening Rite victory advances normally. Road currently still records a battlefield grade—existing behavior, retained for a later design ruling. |
| Crownspark | **Existing runtime contradicts R2:** `kai.tres` includes Crownspark; `Unit.can_use_weapon` allows innate magic without a story gate, and `_ensure_innate_weapons` restores it to older inventories. VS-1A leaves progression unchanged as requested and adds no grant from `kai_awakened`. A later reviewed migration must address the starting kit, innate backfill, existing saves and dev pilots together; simply removing one resource reference is insufficient. The Vision/unlock beat is not built. |
| Locket / missing people | Locked clue exists in planning, not the road chapter or visits. No new clue silently added. Preserve the GM answer: raiders can be the missing, keepsake belongs to its bearer. |
| Arrival / choice | No authored reveal of heir status, welcome, or house-choice framing. Card-first, one-pitch-then-bind interface remains unchanged. Needs co-write and a separate focused implementation. |
| Sibling and old names | Kai bible still has a younger sibling, old Kumar heading, stale default-house framing; other older paragraphs contradict locked sword/mark/director updates. Record precedence; Neal resolves content rather than an agent silently repairing canon. |
| Opening Rite route voice | All three variants still share Emberwing intro/outro (including Kael speaking for a Tidemark/Thornrook player); graphical continuation confirms the old audit finding. Mechanical route parity is not authored parity. Retained outside VS-1A; needs route-aware co-writing. |
| Parent relationship | Bread/buckle promises home beyond departure. No opening-specific return contact payoff is authored. Recommend a small early letter, not family death or a surprise attack. |

## Assets and presentation inventory

Already present and reused: `portrait_kai_nomark`, marked Kai and expressions,
all three heir portraits; painted forest path, cave mouth/dark, light column,
cottage morning, lantern kitchen, first-light gate; existing `vn/sanctum.png`;
nine hearth narrator WAVs; black/white backdrop handling, typewriter, dialogue
input, existing music/audio systems and deferred scene changes. No new images,
API requests, music, or purchases. AW-79's alternate sealed-door/sanctum direction
remains pending; the established sanctum fallback is used, not newly selected art.

**Missing / unfinished:** Essa, Tam and Hesta portraits (their JSON has no portrait
id, so the existing initial-letter fallback renders); later narration recordings;
a commoner-outfit portrait set (even `kai_nomark` currently shows the academy
uniform before he attends; later expression portraits do too);
opening music/ambient cues (no `music` fields in these five scripts, and the VN
starts in silence); dramatic road intro/aftermath; first-arrival writing and
staging. No authored close-up of the sword on the kitchen table. These do not
block reading existing scenes; they limit their dramatic delivery. Long narrated
paragraphs exceeded the renderer's three-line cap: VS-1A fits their full text
without changing their words. There is no new cinematic transition system.

## Alternative hook treatments — all proposals

1. **Preferred: home-first, linear recognition.** Keep the approved chronology.
   Open with a short ordinary family interaction around Kai's forage chore;
   forest curiosity becomes a departure from a place we already like. Retain the
   cave, awakening, reveal and collection, with less explanatory narration. The
   first mystery is an interruption of a believable day. Cheapest creative change,
   strongest relationship foundation, no new reveal order to explain. Risk: too
   much domestic setup; target 60–90 seconds, give Kai a small want and a cost.
2. **Door-first cold open.** Three knocks; Hesta: "Bring the sword." Cut to that
   morning in the woods, then earn our way back. Immediate human threat and
   specific question. Risk: the sword's reveal becomes an answer to a teaser
   rather than Tam's intimate choice; flashback bookkeeping adds friction. Use
   only if timed playtests find the linear first five minutes too slight.
3. **Road rescue cold open, family in retrospective fragments.** Start with a
   concrete endangered person and an impulsive rescue, then revisit home during
   travel. Quick agency and ensemble spark. Highest restructuring cost and risks
   reducing the parents to tragic backstory. Not recommended for this slice: it
   undercuts the intact family sequence and resembles the familiar tactics opener
   we are trying to give a more personal identity.

## Proposed first 30–45 minutes

Timing targets for a revised co-written opening, not measured current runtime.
Do not ship a long rail of optional lore to meet a minute count. A quick reader
and tactics veteran may arrive sooner; a new player may take longer.

| Target | Dramatic action / player participation | Know / feel / wonder | Opportunity and payoff |
|---|---|---|---|
| 0–2 min | Tiny home/chore exchange, then Kai slips beyond his sensible route. | This is his place; he is useful and irritating and loved. Want to follow him. | Essa notices an unfinished task; Tam has a practical remedy. Humor from habit, not a joke about being a chosen one. Co-write before building. |
| 2–6 min | Familiar woods → impossible door → warm stone → blast. Existing VN shape, tightened prose. | He chose curiosity; something answered. Wonder before dread. | Repeat an ordinary shape or warmth later at Vael. Let the image establish recognition before narrator explains it. No royal vocabulary. |
| 6–10 min | Wake, parents' disagreement about telling him, Tam's bundle, Kai takes their hands. | He belongs here and has been lied to; anger survives love. | Protect the long silence. The sword can wait while he chooses human contact. No instant forgiveness. |
| 10–13 min | Hesta arrives; Kai chooses how to face a departure he cannot refuse. First-light bread/buckle goodbye. | Law can compel attendance, not trust. How does she know? | A modest expressive choice could show what he cannot say yet, with no fake option to cancel canon. Do not implement until co-written. |
| 13–15 min | Road: companions collide over a specific endangered civilian and a flawed rescue plan. | Meet three motives before titles. Feel alarm and a little unexpected delight. | Perrin commits too loudly; Serra creates the safe route; Rina notices something useful while being socially unhelpful. Kai needs them. Escort solution must be approved. |
| 15–28 min | Existing road tutorial battle; short contextual instruction and optional heir exchanges only when useful. | These people help differently; my choices protect someone. | Give the existing cottage/cover/approach a human purpose. Preserve current rules; don't invent escort AI or a second combat mechanic to stage this. No compulsory three-chat tour. |
| 28–31 min | Brief rescue aftermath and a quiet travel beat. | Relief and cost, not only victory. Want to speak to one heir again. | Locket clue may be noticed as a personal object, without naming its meaning. A possible bread-sharing callback connects home to a new acquaintance. Both require co-write. |
| 31–36 min | Academy gate / roll call; famous names revealed; practical kindness against institutional awkwardness. | This place is overwhelming; one person makes it survivable. Why can I choose when they cannot? | Kai misreads a helpful action; heirs disagree about what he needs. Show gold-trimmed grandeur through pixel space. No speech touring every system. |
| 36–40 min | Hear three distinct invitations, with opportunity to reconsider; make the oath. | Choose people and values after experiencing them. Feel commitment, not a build-menu selection. | Each house offers something Kai wants and something that could hurt him. Avoid designating Emberwing the only humane answer. |
| 40–45 min | One small arrival interaction; release into campus with a personal next intention. | I can explore and I have someone to find. What is behind that sealed space? | A shared table, a practical favor, a place to put the bread wrapping. One gentle architectural echo, not the Tremor/Vision ahead of schedule. The Opening Rite can wait until the player has breathed. |

Environmental proposals: a worn threshold below the Academy's grand façade;
one repaired chair among ceremonial furniture; a space left for a student's
missing correspondence; a founding carving whose familiar shape goes unremarked.
Choose one or two with literal answers in the clue ledger, not a trail of glowing
quest objects. Ordinary environmental detail need not all be plot foreshadowing.

## Three decisions for the next room session

1. **Whose ordinary day opens the game?** Recommend home-first with one compact
   family interaction and an imperfect Kai; keep approved linear chronology.
   Choose the one domestic detail that can recur later; the opening remains
   centered on Tam and Essa (VS-1B lock).
2. **Who is on the road, and why must these four act?** Recommend Hesta's personal
   collection remains true, but decide explicitly whether she travels separately
   after a documented handoff or is occupied protecting others out of this fight.
   Prefer an established escort handoff if it fits her motives; don't make her
   conveniently powerless. Co-write Kai's rescue and each heir's different stake.
3. **When does Vael become a place Kai might want?** Recommend an arrival beat
   before the oath, titles revealed there, and hearing/reconsidering all three
   invitations before binding. Give one small kindness on every route. Settle
   the social framing first; the existing house/roster mechanics can carry it.

## Next focused work order

**VS-1B — The road rescue and its aftermath, co-written first.** Settle escort
continuity, endangered person, first impressions and the optional locket seed;
edit the existing nine-line road draft plus one short aftermath. Then wire only
those approved scenes into the unchanged tutorial chapter and verify its return
to the existing oath. No new map, combat system, roster production, school-year
expansion or broad dialogue rewrite. First-arrival/oath presentation follows as
its own reviewed WO. Finish VS-1A at this review boundary.
