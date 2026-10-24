# GH-118 — promoted class in BattleView hover

Repairs the incorrect tactical class readout reported in [#118](https://github.com/KumarG23/vael-academy/issues/118). Basis: MASTER_PLAN §§1–2 (inspectable tactical information and separation of presentation from logic), §6 WO-4.4 / WO-9.5 and partial §10 M9; ACADEMY_BIBLE §4 (school battles). `BattleView` now uses `Unit.current_class()` for its existing hover class/level row, matching the Stats sheet. Missing current-class data retains the prior empty-name fallback. No story, canon, promotion rule, stat math, input, RNG, save schema, persistence or renderer change was made. No contradiction was found.

## Regression coverage

The production `BattleView` test starts a fresh supplementary Mock Battle. Brenna is Knight at base, then is promoted to Bastion through the existing `Unit.promote()` API; the actual string consumed by `_draw_hover_info()` is checked against the Stats subtitle. A second supplementary fixture serializes the promoted battle through `make_save_payload()` and restores it through `apply_save_payload()`. It checks that the restored hover and Stats remain Bastion. These are test fixtures, not claims of naturally earned progression or edits to cached UnitDef/ClassDef resources.

All nine authored promoted classes at level 20 are measured with the active font at 1280×720, 800×450, 640×360 and restore. Focused assertions cover the complete current class/level row and hover bounds. The regression also compares complete battle and Campaign payloads, including RNG/support/progression, and exact isolated autosave/settings sentinel bytes across hover and inspection. The related boundaries preserve stationary HP/occupancy refresh (#72), camera-space pointer mapping (#9), resize/layout (#112), promotion and snapshot resume.

## Native runtime evidence — 2026-10-24

Godot 4.7.2, Vulkan 1.4.318 **Forward+**, llvmpipe LLVM 20.1.2, on the existing X11 desktop hosted by Xvfb. This was a real Godot window running the production `BattleView`; pointer and keyboard input were delivered to that window with `xdotool`. No project renderer setting changed. The isolated XDG profile was disposable. No campaign/save was loaded; Campaign remained inactive. A temporary, uncommitted fixture runner used only the shipped battle scene, promotion API and existing battle snapshot resume path. It marked Brenna unavailable for actions so the ordinary confirm key opened Stats directly; this only made inspection available in the supplementary battle and injected no combat result.

- Base fixture: Brenna hover and Stats both show **Knight** ([hover](base-hover-default.png), [Stats](base-stats-default.png)).
- Supplementary promoted fixture: real pointer hover and ordinary Enter inspection show **Bastion** ([hover](images/promoted-hover-default-full.png), [Stats](images/promoted-stats-live.png)). Escape closes Stats; keyboard movement then continues normally ([continuation](images/promoted-continued-live.png)).
- The same promoted BattleView was shrunk live from 1280×720 to 800×450 and 640×360, then restored to 1280×720. Hover remains visible and says **Bastion Lv 1** at each captured size ([800×450](images/promoted-hover-800x450.png), [640×360](images/promoted-hover-640x360.png), [restored](images/promoted-hover-restored-full.png)).
- Resume fixture: a supplementary promoted payload passed through `BattleView.next_resume` and the production `apply_save_payload()` path. Hover and ordinary Stats both show **Bastion** ([hover](resumed-hover-default.png), [Stats](resumed-stats-default.png)).

Before/after snapshots in the resumed fixture have identical canonical SHA-256 hashes for the complete battle payload (`c1c4c1bb92b2546f726c8b544ffd4f77bb9876b028503012be6e8b2be488b423`) and Campaign (`1059fe298d7da5c3d06f90102a5cfcdfc4f556107f319e439d3b85ff2a686a35`) across Stats dismissal and live 800×450 → 640×360 → 1280×720 resize/restore. The active class and hover string remained Bastion / `Bastion   Lv 1`; Campaign remained inactive. These full-state hashes include the payload’s battle RNG/state and Campaign progression/support. The isolated runtime profile had no slot, autosave or settings files before/after the GUI pass. Exact sentinel file-byte equality is asserted separately in the focused regression.

Captures are the inspected production window/client; the 800×450 and 640×360 images are cropped to the X11 client bounds from full desktop captures. [Source and artifact SHA-256 manifest plus structured comparisons](results.json). No raw engine logs, private paths or credentials are included. No full-school replay or Neal visual/taste approval is claimed.

## Source attribution and checks

Native captures were produced from source commit `f9489c72edb30053ce78339f251c42f1e82f4087`. File-level hashes and image hashes are in `results.json`. The focused and full headless results are recorded in the linked PR; the final exact-head Verify after this QA documentation update is the outstanding automated gate. The full local baseline and affected boundaries passed on the same implementation source before this QA-only evidence update.
