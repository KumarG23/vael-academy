# GH-96 — Journal Roster compact-window acceptance

## Scope and plan basis

This is an existing-flow presentation repair. The Roster remains a read-only
reference to current students, stats, equipment, and skills. It adds keyboard
detail paging for windows where all fields cannot fit at once and keeps the
selected student visible in the list.

- [MASTER_PLAN §1 — Vision](https://github.com/KumarG23/vael-academy/blob/main/MASTER_PLAN.md#1-vision): Vael Academy is the walkable school's center between battles.
- [MASTER_PLAN §2 — Tech Stack & Conventions](https://github.com/KumarG23/vael-academy/blob/main/MASTER_PLAN.md#2-tech-stack--conventions): preserve the existing Godot UI/input/data conventions.
- [MASTER_PLAN §6 — WO-9.4 UI theme pass / WO-9.7 Journal](https://github.com/KumarG23/vael-academy/blob/main/MASTER_PLAN.md#6-milestones--work-orders): existing Journal presentation and reference-tool scope.
- [MASTER_PLAN §10 — partial M9 status](https://github.com/KumarG23/vael-academy/blob/main/MASTER_PLAN.md#10-status-fable-updates-this--never-delete-rows): records which Journal and UI slices are delivered and which remain partial.
- [ACADEMY_BIBLE §3 — The Castle, the Heart of the Game](https://github.com/KumarG23/vael-academy/blob/main/ACADEMY_BIBLE.md#3-the-castle--the-heart-of-the-game): the Quartermaster is the existing home for roster, inventory, and promotion reference tools.

No contradiction with the owning documents was found. No story, roster data,
stat, skill, item, save, or canon change is included; there is no Neal visual
approval claim.

## Native runtime

- Godot `4.7.2.stable.official.ed1daf0bf`, original Vulkan Forward+ renderer on
  llvmpipe, native X11 window/input on the existing 1280×720 Xvfb desktop.
- Disposable `XDG_DATA_HOME`; native X11 keyboard events sent with `xdotool`.
- Started from Title → Load using the existing native Week-2 Emberwing return
  checkpoint, copied byte for byte from
  `docs/qa/issue-5-school-loop/emberwing-return-save.json` to the disposable
  profile's ordinary Slot 1. Source and copied file both had SHA-256
  `681e0c32af7483a6b48abdfe2c0c612ee65cf5450352d62ca5a8a431275b1fe4` before
  and after the run. No fixture edits or game-state injection.
- Inspected at 1280×720, resized live to 800×450 and 640×360, then restored
  live to 1280×720. First and final roster members were reached with Up/Down;
  PageUp/PageDown browsed the selected member's details at compact sizes.
- J closed the Journal back to campus. A fresh Right input moved the player
  and camera during ordinary exploration. The game exited and no game, input,
  or capture job remains; the shared desktop was released in the #96 issue.
- No manual save, autosave, or settings files were changed by QA; the native
  source checkpoint remained byte-identical. Automated byte-preservation
  assertions are recorded in the regression suite.

## Inspected captures

The initial captures show the existing first member, both compact sizes, all
eight stats, carried equipment and skills, final-member browsing,
close/continuation, and the live resize back to default. The three footer
review captures record the revised hint at default and both compact sizes.
Capture checksums are recorded in [SHA256SUMS](SHA256SUMS).

| Capture | What it records |
| --- | --- |
| [1280×720 Roster](images/04-default-roster.png) | Default layout, first member and all current fields on one page. |
| [800×450 Roster](images/05-compact-800.png) | Compact tab wrap, visible selected row, stats and detail-page prompt. |
| [800×450 carried gear and skills](images/06-compact-800-details.png) | PageDown reaches carried equipment and skill state. |
| [640×360 first member](images/09-640-first-member.png) | First member remains visible at the smallest supported size. |
| [640×360 final member, first page](images/14-640-final-member-first.png) | Up wraps to the final student and keeps the selected row visible. |
| [640×360 final member, remaining stats](images/15-640-final-member-next.png) | PageDown reaches the remaining stats. |
| [640×360 final member, carried equipment](images/16-640-final-member-next2.png) | Complete carried items remain readable. |
| [640×360 final member, skills](images/17-640-final-member-skills.png) | Skills and empty state remain readable. |
| [640×360 closed Journal](images/19-640-closed.png) | J returns to exploration without reopening an overlay. |
| [Restored 1280×720](images/21-restored-1280.png) | Live resize returns to default exploration. |
| [Continued exploration](images/24-continuation-movement.png) | Fresh movement input works after close; camera follows. |
| [Reviewed footer at 1280×720](images/25-footer-default.png) | Measured, centered Roster hint clears both lower frame ornaments. |
| [Reviewed footer at 800×450](images/26-footer-800.png) | The complete hint stays inside the safe frame area at compact width. |
| [Reviewed footer at 640×360](images/27-footer-640.png) | The complete hint clears the lower filigree at the smallest size. |

The small final-member pages do not contain its portrait after page 1; the
existing cached portrait is kept proportional on the first page. If a portrait
resource is missing, the existing name/class fallback remains in use.

The lead's P3 review noted that the original Roster footer crossed the lower-left
filigree at default size. The footer now uses actual active-font dimensions and
is horizontally centered inside a conservative inset derived from the ornate
panel. Its measured glyph bounds clear the lower frame at all three tested
sizes, and the last detail line is checked against those bounds in the
production-layout regression. The new captures were taken from the existing
Week-2 checkpoint with native input and the original Forward+ renderer. The
source and disposable Slot 0 checkpoint hashes matched before and after; the
game exited and the shared display was released afterward.

## Limits

This is bounded Journal acceptance from the existing Week-2 checkpoint, not a
full school-year playthrough or visual/taste sign-off. Other Journal tabs were
not used to assert their visual quality; their existing automated assertions
are included in the affected checks.
