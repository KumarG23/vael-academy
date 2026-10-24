# GH-114 — existing Journal Items compact layout

## Scope and source references

This is a presentation/input reachability repair for the existing Quartermaster
Items tab. It follows `MASTER_PLAN.md` §§1–2 and §6 WO-9.4/9.7, with M9 still
partial, and `ACADEMY_BIBLE.md` §3 (Quartermaster: roster, inventory, trading,
promotion items). The existing inventory rules and persistence channel are
documented in `HANDOFF.md` AW-52/AW-53/AW-55. No canon contradiction was found.

## Automated production-viewport evidence

`tests/test_journal_items_compact.gd` instantiates the production Academy
Journal in a real `SubViewport`, dispatches configured/default keyboard events,
and measures the same layout returned to the renderer with `UITheme.font()`.
The measurements cover 1280×720, 800×450 and 640×360, both resize directions,
all three existing trade stages, first/final students and recipients, complete
shipped pack labels/equipped markers/uses, full five-item packs, empty pack and
roster states, and inventory-origin feedback.

The regression-first run on accepted main `300f146a` passed 2/6 tests; the four
failing cases were compact label/instruction widths, the final student's body
bounds, and compact refusal-toast bounds. On the implementation source the
focused file passes **8/8 tests, 356 assertions**. The unchanged shipped input
flow and ordinary successful transfer/save round-trip pass. Godot 4.7.2
implementation-head import exited 0 with no script parse/load errors. It
regenerated untracked `.uid`/`.import` sidecars for existing files that lacked
them; those generated sidecars were removed from this worktree. Team helpers
pass **113 discovered, 111 passed, two existing opt-in skips**.

The full GUT attempt was stopped after a concurrent headless import appeared
outside the shared lock. That partial run is discarded, not a failure or
acceptance receipt. The required full suite and affected-sibling integration
checks remain pending a serialized run; exact-head Verify remains pending.

## Original-renderer GUI evidence

**Pending. No game, GUI input or capture job has been run.** Issue #112/Sol-dev
currently owns the shared desktop. GH-114 must wait for #112 to explicitly end
and release every GUI job, followed by the engineering lead naming the next GUI
controller. Do not infer visual acceptance from the SubViewport measurements.

After that gate, use the bounded ordinary Title/load flow and isolated earned
checkpoint required in [issue #114](https://github.com/KumarG23/vael-academy/issues/114).
Record checkpoint provenance, source/capture hashes, whole-state and file
hashes, intentional transfer/settings writes separately, and exact native vs
fixture evidence. Never alter the earned original. Five-item/full/bound/tome
fixtures are supplementary test fixtures, not earned campaign state.

## Capture manifest

No captures exist yet. Keep screenshots, input logs and state/hash receipts in
this directory once the authorized original-Forward+ run is complete. Record
the source SHA beside each capture and identify any fixture state explicitly.
