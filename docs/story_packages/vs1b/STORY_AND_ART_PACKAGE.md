# Vael Academy — Opening Story & Art Package (co-write draft v1)

**Date:** 2026-10-16  
**Baseline:** `KumarG23/vael-academy` after VS-1A (`f0c43294`), not a production commit.  
**Status:** complete first-pass co-write drafts for the user's review. Nothing in this package was committed to the repository or generated through Gemini/PixelLab.

## Agreed constraints

- Home scene stays centered on **Tam, Essa and Kai**. An obsolete sibling reference in the bible should be flagged as superseded *for this opening*; don't invent a sibling or silently rewrite the rest of the story.
- **One painted kitchen still** serves the entire home scene. Preserve the approved banter and its “come home” callback.
- Add a **short on-road Hesta handoff scene**. She rides ahead on unspecified urgent Academy business; the deeper reasons and Morvane's attention remain unrevealed. The escort's role is to evacuate civilians once raiders appear, not to join tactical combat.
- Perrin, Serra and Rina are **strangers to Kai** at first contact. They arrive independently rather than as a shared traveling party and join the rescue according to their own values; do not invent whether the heirs already know one another. They exchange first names only after the battle; their titles are revealed at Vael.
- The **child near the well escapes before player tactical control**. No invented protect-NPC win condition. The actual map has a well, cart/crates, burning house, four allied spawns and five axe-wielding raiders.
- Kai's brow mark appears at the **cave awakening**; a subtle involuntary flicker can occur under danger on the road. **No player-controllable Crownspark before the semester-one Vision**, pending a separately scoped save-safe progression fix.
- The bread scene is an **illustrated tableau** behind regular dialogue portraits, not a new fully animated cinematic. Essa's bread is a little dry after several travel days. Kai's line: *“My mother would be furious if I didn’t offer. She’d somehow hear about it all the way from Oakstead.”*
- Painted stills are chosen for **storytelling quality, coherence, and visual impact**, not minimum count or lowest cost. Use existing character references and visually review in-engine.
- The Academy gate and house-pitch drafts are **VS-1C preview proposals**, not permission to immediately change house-choice mechanics or locked canon.

## Scene order and placement

1. **NEW `prologue_home_morning.json`** → before the existing forest script (same campaign-opening VN playlist).
2. Existing forest → cave → wake → family reveal → Hesta's door/goodbye (unchanged during first implementation).
3. **NEW `prologue_road_waystation.json`** → after Hesta goodbye, before scene switches to existing road battle.
4. **REPLACE draft `road_bandit_intro.json`** → production prologue chapter's `intro_dialogue`, with new first-meeting action.
5. **CREATE/REPLACE `road_bandit_outro.json`** → production prologue chapter's `outro_dialogue`. The map references this file; it was missing from the connected GitHub main on inspection.
6. **VS-1C LATER**: painted Vael arrival → preview all three house pitches → confirm oath → campus. Do not accidentally force a selected pitch before a player can hear the others.

Scripts use the existing dialogue JSON format: `speaker`, `text`, optional `portrait`, `side`, `expression`, `backdrop`. Any additional pause, pan, crossfade or foreground-illustration system needs an explicit small engine work order and tests. Assets referenced below are **not yet generated**; create and approve them before linking in production. The JSON drafts are valid JSON, not claims of being import-tested inside Godot.

## Full dialogue drafts

The script content below is generated from the included JSON files. Stage narration represents the existing voiced/letterboxed storyteller format, not extra hidden stage directions.
### Scene A — Before the Forest
*Art: one warm Oakstead cottage kitchen still; slow morning rhythms; no crown mark on Kai.*

*Oakstead. An ordinary morning, as far as anyone knows.*

**Essa:** You are not “just stepping out,” Kai. Last time you were “just stepping out,” you came back after dark with wet boots and somebody else’s goat.

**Kai:** The goat was having a difficult day.

**Tam:** The goat won.

**Kai:** Cruelly.

**Essa:** You laugh now. You still need willow bark, chanterelles if you find them, and if Old Mara asks, you are not climbing her roof again.

**Kai:** She asked me to last time.

**Essa:** She asks everyone to do things she should not ask.

**Tam:** She only asks the ones she thinks will say yes.

**Kai:** So I’m beloved. Good to know.

**Essa:** You’re useful. Don’t dress it up.

**Kai:** I’ll be home before the light goes.

**Essa:** That is what you said yesterday.

**Kai:** And look how confidently I’m saying it today.

**Tam:** Basket.

*Tam nudges the basket toward him. It is already packed for the things Kai always forgets.*

**Tam:** If you go beyond the ridge, at least pretend you thought better of it first.

**Kai:** I always pretend.

**Essa:** Kai.

**Kai:** Ma.

**Essa:** Home before dark.

**Kai:** One of these days, you’ll learn to ask me for something easy.

**Essa:** I did. I asked you to come home.

### Scene B — The Director Rides Ahead
*Art: one waystation/Hesta handoff still and a smoke-on-horizon transition still.*

*At the first waystation on the Vael road, the Director is already saddling a fresh horse.*

**Kai:** You said four days. That was one.

**Hesta:** You still have three to go.

**Kai:** And you?

**Hesta:** There are matters at the Academy that cannot wait three days.

**Kai:** Does one of them involve me?

**Hesta:** Yes.

**Kai:** You could try being less reassuring.

**Hesta:** I am not trying to reassure you. I am trying to have the gates ready before you arrive.

*She passes a sealed travel order to the road warden waiting beside the supply wagon.*

**Hesta:** He travels with your party. The main road, the usual stops. No shortcuts.

**Road Warden:** Understood, Director.

**Kai:** You know what that sword is. I saw your face.

**Hesta:** You saw a woman in a hurry.

**Kai:** That is not an answer.

**Hesta:** You will find I rarely give one before it is useful.

*Before he can ask again, the Director turns her horse toward the northern road.*

**Road Warden:** Come along, then. People on foot arrive later than people with opinions and fresh horses.

**Kai:** I am beginning to suspect the Academy is full of both.

*Days later, a day's travel from Vael, smoke rises beyond the roofs of a roadside hamlet.*

### Scene C — The Road Rescue
*Art: well/cart tableau, Kai moving, four-stranger standoff; no borrowed familiarity.*

*The road narrows beside a hamlet well. A cart lies on its side. Beyond it, a house burns.*

**Road Warden:** Raiders. Keep behind the wagon. I need to get these people off the road.

*A child is trapped against the well by the overturned cart. A brigand with an axe closes the distance.*

**Kai:** There’s a child by the well.

**Road Warden:** I see her. Wait until I can—

*Kai is already running. The brigand turns toward him instead.*

**Kai:** Hey! Over here!

*Beside the well, a young woman in blue steps between the child and the axe. She raises a lance.*

**Serra:** Down, behind me. Do not run until I say.

**Kai:** I can get the cart out of her way!

**Serra:** And leave yourself exposed to the next man. Hold the well side!

*A rider in crimson pulls up hard at the edge of the square. He sees the axe, the child, and the strangers trying to help.*

**Perrin:** You there! Axe in hand! Try somebody who can fight back!

*His horse rears against a loose market awning. The rider catches the reins a heartbeat too late.*

**Perrin:** Ah. Bad entrance. Sorry!

**Serra:** Then make a better second one. Keep that lane clear!

*From the steps above the square, another traveler points toward a gap between two cottages.*

**Rina:** The cart is not the only problem. Two more are coming around the crates. Take the child through the fence lane instead.

**Kai:** You’ve been watching them?

**Rina:** Since before you shouted at one. Go.

*Kai braces the cart long enough for the child to slip through. For an instant, a fine green light crosses the mark above his left brow. It vanishes before he notices.*

*The woman on the steps notices. She says nothing.*

**Road Warden:** I have her! The families are clear of the western lane!

**Serra:** Good. Then we keep the raiders from following.

**Perrin:** Well. I was heading to Vael, but I can spare a few minutes for this.

**Kai:** Whoever you are, thank you. Now—please—help me finish it.

**Rina:** The chief is holding back by the far road. Take away his men, and he has nowhere to send them.

*Four strangers turn toward the raiders. The child is safe. The road is not.*

### Scene D — After the Smoke
*Art: aftermath square and memorable bread-giving illustration; give the quiet time.*

*The last raider retreats. For a moment, nobody celebrates. The hamlet is still standing; some of it is still burning.*

**Serra:** Count the injured. The well is clear—keep a path open for water.

**Road Warden:** The families made it out. That child is with her mother now.

*Perrin helps a shopkeeper drag a beam off the doorway. Rina checks the lanes for anyone left behind.*

*At the edge of the square, the child sits against her mother’s shoulder, quiet and shaking.*

**Kai:** Are you hungry?

**Child:** I don’t think so.

**Kai:** Fair. I’m not sure I am, either.

*He opens the cloth bundle Essa pressed into his hands. The last of the bread is a little dry, but the smell still takes him home.*

**Kai:** Here.

**Child:** But that’s yours.

**Kai:** My mother would be furious if I didn’t offer. She’d somehow hear about it all the way from Oakstead.

**Child:** Is she really that scary?

**Kai:** Only if you’re someone she loves.

*The child takes the bread. Kai waits until her hands stop trembling before he stands.*

**Serra:** You ran at an armed man without a plan.

**Kai:** I noticed.

**Serra:** Next time, give me half a breath to make one.

**Kai:** Half a breath. I can try.

**Serra:** Try harder than you sound.

*Perrin returns, sleeves dusty, wearing a grin he has not entirely earned.*

**Perrin:** For the record, I meant to arrive with more dignity than that.

**Rina:** And yet we all survived the disappointment.

**Perrin:** That’s a very generous account of events.

**Kai:** You can argue while we walk. I’m Kai.

**Perrin:** Perrin. And I promise the horse is usually better behaved.

**Serra:** Serra.

**Rina:** Rina. We should leave before the smoke settles over the road.

*They have a road in common for the moment. None of them knows what that will mean.*

### Scene E — The Gate (VS-1C preview only)
*Art: academy gate, roll call, oath hall; titles revealed here, not on the road.*

*Vael Academy rises beyond the gate: towers, courtyards, three banners, and more windows than Kai can count.*

**Kai:** That’s a school?

**Perrin:** Some of it. You haven’t seen the part that looks like it’s trying to swallow the sky.

**Kai:** Please tell me that’s a joke.

**Rina:** It’s an exaggeration. Not a particularly large one.

**Serra:** The registry is straight ahead. We should sign in before the courtyard fills.

*At the register, an official reads the next three names from a gilded ledger.*

**Registrar:** Perrin of Emberwing. Serra of Tidemark. Rina of Thornrook.

**Kai:** Wait. Those are the names of the—

**Perrin:** The people who got their boots dirty with you? Those ones.

**Kai:** You could have mentioned it.

**Perrin:** Would it have helped?

**Kai:** I would’ve shouted a little more politely.

**Serra:** No, you wouldn’t.

**Kai:** No. Probably not.

**Registrar:** And ... Kai. Of Oakstead?

*Behind them a few students exchange glances. A word—“commoner”—travels just far enough to be heard.*

**Kai:** That’s me.

**Serra:** Then write it down. He is standing in front of you.

*The registrar lowers the pen. A second line appears beneath Kai’s name: “House designation: pending.”*

**Rina:** Pending. That is unusual.

**Kai:** It’s been an unusual week.

**Perrin:** Come on. There’s somewhere quieter to hear the invitation.

*Inside the oath hall, three doors wait beneath three different banners. For the first time since leaving Oakstead, Kai is asked where he wishes to go.*

### Emberwing invitation — Perrin (VS-1C preview)
*Promise: warmth and shared daring. Risk: privilege and rashness.*

**Perrin:** I’m not going to pretend Emberwing is quiet. It isn’t. It’s a room full of people who’d rather do something than stand back and discuss doing it.

**Kai:** I have met exactly one of those people.

**Perrin:** And he made a spectacular mess of a market awning. Yes, yes.

**Perrin:** But you saw what happened when the cart fell. I charged. You charged. Neither of us checked whether the other needed us.

**Perrin:** Emberwing can teach us when to move together. We might even learn when not to charge at all. I make no promises about how fast.

**Kai:** That sounds like a terrible sales pitch.

**Perrin:** It’s an honest one. Come meet the rest of us, and then decide whether we’re your sort of terrible.

### Tidemark invitation — Serra (VS-1C preview)
*Promise: safety and duty. Risk: rigid rule-following.*

**Serra:** I’m going to tell you something unpleasant. On the road, you were right to help. You were also one step from getting someone else hurt.

**Kai:** I noticed you were there to tell me.

**Serra:** I was there because someone needed a shield and a clear way out. Those are not the same thing as a glorious charge.

**Serra:** Tidemark teaches you to stand when running would be easier, and to think before a choice becomes someone else’s injury.

**Kai:** Sounds like rules. A lot of rules.

**Serra:** Yes. Sometimes they save lives. Sometimes they need challenging. I am still learning the difference.

**Serra:** If you come to Tidemark, I will expect you to challenge me when I’m wrong. And I will expect you to listen when I’m right.

### Thornrook invitation — Rina (VS-1C preview)
*Promise: questions and understanding. Risk: detachment.*

**Rina:** On the road, everyone was looking at the raiders. I looked at the route the villagers could still use.

**Kai:** It worked.

**Rina:** Only once the rest of you acted on it. Observations are not rescue missions by themselves.

**Rina:** Thornrook is for people who keep asking the question after everyone else thinks the matter is settled.

**Kai:** And the questions about this?

*He gestures briefly at the mark above his left brow.*

**Rina:** I have some. More than I should ask a person I met yesterday.

**Kai:** That’s a start.

**Rina:** Come to Thornrook. We can look for answers. And you can tell me when the looking gets in the way of seeing you.

## Painted-story art direction — quality first

**Visual target:** existing Vael Academy painterly anime/storybook register, consistent with the approved illustrated Kai/Serra character artwork and warm painted VN backgrounds. High fidelity at 16:9, preferably 2048×1152 masters or better and downsampled/cropped in Godot. Avoid generic game art, oversaturated bloom, photorealism, invented costume details, inaccurate character ages/faces, readable image-generated text, extra fingers, and duplicated protagonists caused by foreground portrait overlays.

**Art pipeline:** Use existing source Kai, Serra, Perrin, Rina and parent/Director references where available. Generate missing Tam/Essa/Hesta transparent portrait candidates and pre-academy unmarked Kai portrait/outfit for review; current captures show initial-letter fallbacks and academy-uniform Kai before admission. Lock a character sheet before producing multiple narrative stills. Keep Kai's mark above his **anatomical left brow** after the cave, never before. Preserve the original blue/gray/gold house identities.

**VN composition:** Keep the central 35–65% width for scene action. Allow dark/quiet margins behind portrait overlays in approximately the outer quarters, and keep the bottom ~24% readable for a translucent text panel. In the bread illustration, Kai and the child should be part of the *background painting* while the portrait system remains active. Check for duplicate-Kai visual confusion and adjust staging rather than flattening the VN into full-screen text.

**Detailed Gemini concept prompts** — use these as starting briefs with image references, then iterate based on in-engine crops, not blind first-pass acceptance:

### VAEL-ART-01: Oakstead kitchen — one still only
"A lived-in rural kitchen in the Kingdom of Aldreth on an ordinary early morning, tender painterly fantasy-anime storybook illustration. Warm low hearthlight and clear misty dawn light, old wooden beams, herbs and bark drying on hooks, well-used rough table with a small cloth-covered loaf and a woven forage basket, patched chair, copper pot, worn door to the woods. The room suggests a loving household without wealth or staged sentimentality. No people, no fantasy magic, no crown symbols. Calm central activity area for visual-novel characters and subtle free areas left/right for portraits; no text, no UI. 16:9 cinematic painterly background." 

### VAEL-ART-02: Road waystation, Hesta departure
"A modest King's Road courier waystation at morning, painted medieval fantasy-anime storybook illustration with cinematic natural light. A weathered stone-and-timber shelter, supply wagon, waiting horse, cloth-covered provisions, worn travel road disappearing toward a northern ridge. The scene conveys purposeful early departure and an ordinary overland journey, not a grand royal escort. Optional accurate Hesta reference: stern elderly gray-robed woman with all three house trims and one gold thread, mounting a swift horse; keep characters medium-sized so portraits can still overlay. No magic spectacle, no readable text, 16:9." 

### VAEL-ART-03: Approaching hamlet / first smoke
"A bend in a traveled medieval fantasy road approaching a small inhabited hamlet near Vael, view from slight elevation behind scattered trees and grass. Stone well visible in village square, tiled cottage roofs, carts and fencing, one thin dark plume of smoke curling behind a rooftop. Late-afternoon gold light becoming uneasy; anticipation, not disaster-porn; no close-up characters. Rich illustrated background, 16:9, clean negative space for visual novel portraits." 

### VAEL-ART-04: Roadside raid well and cart, environment
"Storybook fantasy-anime 16:9 action background depicting a rustic hamlet square amid a sudden brigand raid: a round stone well, tipped wooden cart and fallen axle, damaged stalls, one burning cottage near the far road, safe western lane between stone fence and cottages, tense dust and limited smoke. No archers: the opposing raiders are axe-wielding brigands. No text, gore, unrealistic flames or unnecessary crowd chaos; stage environment so character portraits and captions stay legible." 

### VAEL-ART-05: Kai rushes to the child
"Cinematic painted story still, immediately after a roadside raid begins. A 16-year-old brown-skinned dark-haired rural boy, simple travel clothes with an old sheathed green-tinged relic sword and a delicate green crown-shaped mark over his *anatomical left brow*, rushes to divert an axe-carrying brigand from a frightened child trapped beside an overturned cart and stone well. This is his first selfless, unplanned leap; fear and resolve mixed, not superhero swagger. Accurate Kai reference art required. Clean readable silhouettes, dynamic yet anatomically natural poses, rich natural light and smoke, no gore, 16:9." 

### VAEL-ART-06: Four strangers take a stand
"Painterly anime fantasy wide tableau of four sixteen-to-eighteen-year-old travelers converging independently to protect civilians in a hamlet square: Kai with green forehead mark near the well, disciplined blue/silver lance-bearing Serra shielding the evacuation route, warm crimson/gold mounted Perrin arriving and reining in his restless horse, analytical green/bronze mage Rina surveying the flank from slightly elevated steps. Each is visibly busy with a *different task*, not posing as an established friend group. The child and civilians escape behind them. Use exact accepted face/costume references for each, natural perspective, clear silhouettes, no text, 16:9."

### VAEL-ART-07: The aftermath square
"The same fantasy hamlet square after a brief raid. Fire and smoke receding, bucket line and small repairs beginning, overturned cart and scorched cottage present but no gore or triumphal celebration. Villagers gather quietly; crimson-clad youth helping lift a fallen beam, blue-clad defender organizing water, green-clad scholar checking a path. Warm late sunlight on the relief and exhaustion. Painterly grounded fantasy anime look; 16:9, safe portrait/caption areas." 

### VAEL-ART-08: Kai offering Essa's bread — hero emotional still
"Intimate painterly visual-novel story illustration, 16:9. In a quiet corner of a damaged medieval roadside hamlet after the fighting, Kai, a 16-year-old brown-skinned boy with short practical dark hair, plain travel clothes and faint crown-green mark over his anatomical left brow, kneels near a young survivor resting beside her mother and offers the last piece of bread from a rumpled cloth bundle. The bread is slightly travel-worn, not freshly baked; the adult is comforting the child. Warm sunlight catches dust motes; gentle, humane, restrained emotion, no tears-for-the-camera, no grand heroic pose. The central gesture of the offered bread must be unmistakable. Both figures are in the midground within the center 35–65% of frame, leaving soft unobtrusive portrait zones at left and right and bottom readable for dialogue UI. Use accepted Kai reference; no text, logos or extra fingers." 

### VAEL-ART-09: Academy gate — VS-1C later
"An overwhelming but inviting painted fantasy academy exterior as seen by a boy arriving for the first time: Vael's immense stone gate, layered towers, tree-lined courtyard, three rich house banners of crimson/gold, blue/silver, green/bronze, old walls repaired and inhabited over centuries; students arriving in small groups. Scale dwarfs a single rural traveler but suggests warm windows and human life inside. Painterly anime storybook style, impressive architecture, legible foreground, 16:9." 

### VAEL-ART-10: Registry and oath hall — VS-1C later
"Grand yet intimate interior entry hall of Vael Academy, polished stone beneath age-worn banners, oak registrar's desk and book, three doorways under the great house colors; intricate old architecture with quietly imperfect human details—ink-stained papers, scratched benches, subtle warm light. A traveler would feel both welcome and judged. No legible text or symbols accidentally implying fourth house membership. Two distinct compositions may be preferable: a narrow registry desk and a wider oath hall. Painterly fantasy-anime 16:9." 

### VAEL-ART-11: Hesta's kitchen entrance — additional polish, not blocked by VS-1B
"Existing Oakstead lantern-lit kitchen at night seen from within, door ajar, Hesta in restrained gray with three house trims and one gold thread illuminated by lamplight, her presence controlled and intimidating rather than evil. Tam and Essa in modest rural clothing framed near the door, Kai partly visible but not the focus. This supplements the existing kitchen backdrop if the final in-engine cut benefits from a character-specific story still; do not replace the approved kitchen-morning single still." 

**QC gate per image:** compare against source characters, check exact brow/side, costume continuity and proportions, lighting continuity across cuts, visual reads at game resolution, faces/hands, absence of incorrect lore symbols or legible gibberish, and whether portraits obscure important painted faces/actions. Reject or edit until it meets the story beat; don't stop at the first plausible output.

## VFX Creator experiment (separate from narrative scene approval)

Official PixelLab MCP documents `create_vfx` and `get_vfx` with sprite references, lite/pro artists, revisions using `effect_id`, and optional `game_pack` export of whole/front/behind sprite sheets plus manifest. Verify the currently attached PixelLab MCP schema before use and query cost quote rather than assuming a fixed price.

High-value **isolated map-sprite pilots**:
1. `vael_kai_uncontrolled_mark_flicker` — a subtle one-shot emerald-green Crown-shaped shimmer over the anatomical left brow during an involuntary stress beat; no controllable spell projectile.
2. `vael_road_slow_embers` — small drifting orange embers and dull smoke over the burning cottage; don't obscure tiles/threat ranges.
3. `vael_old_seal_responds` — gentle intermittent pixels around a rune seal, reserved for a later chapter; should not look like a finished player spell.

Suggested experimental prompt for create_vfx: “Subtle involuntary ancient green Crown-light flicker around an existing 2D pixel boy's brow, single restrained pulse then fading motes, stays precisely aligned to his face and never resembles a controlled spell cast, transparent effect, 8–12 frame aesthetic, preserve the sprite's silhouette and eye visibility.” Reuse the known PixelLab Kai sprite reference ID from project manifests. Request `game_pack=true` for separable layers and Godot timing/anchor validation. Keep VFX tests isolated from the approved high-resolution illustrated combat pipeline.

## Stage / QA / story gates

- No painted backdrops, portrait assets, or sound were actually generated by this package. Missing `res://` paths must be generated/approved before wiring into the playable build (or deliberately use safe review fallbacks).
- New Game ordering must be home → established forest/cave/wake/parent/Hesta scenes → short Hesta waystation → real prologue chapter intro → tactical play → outro → existing house choice. Do not overwrite existing established dialogue in the middle five scenes in this work order.
- On the road the child escapes before battle begins. The actual four-unit battle remains Kai, Perrin, Serra, Rina versus five axe bandits, boss on far road. Do not script a bowman or a reserve army that's not on the map.
- The traveler silhouettes and gestures in paintings are *not* substitutes for the 2D map sprites. Preserve combat resolution, non-lethal battle objective, XP, weapon uses, progression, save/resume, house rosters.
- Check `intro_dialogue`/`outro_dialogue` paths and run native graphical smoke for all three houses. Test save/load right before and after the prologue.
- **VS-1B:** implement home/travel/road/aftermath and resulting approved art, submit taste-review captures. **VS-1C:** implement Academy gate, roll call, all three house pitches presented before committing to a choice, and house-neutral arrival. The VS-1C drafts in this pack should be edited jointly before production.
- **Crownspark gate:** separate progression WO with migration safe against older saves; mark at cave and involuntary cues do not imply player-usable Crownspark. Preserve the existing Vision story unlock and never silently remove powers from an active player save without a migration strategy.
