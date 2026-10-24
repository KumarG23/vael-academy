# GH-127 — active fishing cast through window resize

## Plan and owning document

- `MASTER_PLAN.md` §§1–2, §6 WO-6.4, §10 M9 / modernization status.
- `ACADEMY_BIBLE.md` §3, “The grounds & waterside” and “Fishing”: fishing remains the existing self-contained waterside activity and a counterweight to combat.
- No conflict with authored story, mechanic, reward, or scope direction was found. No canon decision was made.

## Automated source evidence

- Accepted base: `8b442f13b34d86924cdb0fe374b49d7a7872649a`.
- Regression-first production `FishingGame` in real `SubViewport`s: on the unchanged source, the new suite failed its geometry case (18 bound assertions) after shrinking; the other three test cases passed. This confirms the stale viewport geometry in the source, not a native reproduction.
- After repair, production resize + original fishing tests pass **19/19, 155 assertions / 2 scripts**. They cover 1280×720, 800×450, 640×360, shrink/restore in WAITING and BITE, line/bobber/marker/hint bounds, active-font hint width and outline margins, marker sway pinning, exact text and click-through behavior, timers/phase/local RNG/Campaign snapshots, same-seed result with and without resize, early miss, the unchanged strict `> 0.55s` expiry boundary, one catch, no post-finish mutation, dispatched Space confirm, and normal castle cleanup/control recovery.
- Affected fishing/castle/Journal/close/keyboard/Campaign/save boundary: **141/141 tests, 4,800 assertions / 13 scripts**, exit 0. The focused process reports 35 inherited GUT wait-frame deprecations and the existing exit-time two ObjectDB / one resource diagnostics.
- Team helpers: **113 discovered, 111 passed, two existing opt-in lifecycle skips**.
- Final Godot 4.7.2 editor import on the changed production source exited 0 with no script-load errors. It used the common `vael-godot-heavy.lock` and disposable `XDG_DATA_HOME`.
- Final full GUT: **1,032/1,032 tests, 22,685 assertions / 126 scripts**, exit 0 (482.922 s). The run reported 99 inherited wait-frame deprecations and expected dummy-renderer image readback diagnostics in existing battle animation tests; no test failed.
- Final latest fishing/Journal pass, including manual/autosave/settings byte snapshots: **43/43 tests, 267 assertions / 3 scripts**, exit 0. The final affected fishing/castle/Journal/close/keyboard/Campaign/save boundary passes **142/142, 4,816 assertions / 13 scripts**, exit 0; it reports 35 inherited GUT wait-frame deprecations and existing exit-time two ObjectDB / one resource diagnostics. Team helpers: **113 discovered, 111 passed, two existing opt-in lifecycle skips**.

## Native evidence boundary

No GUI run or capture was made for this issue. Issue #114 remains the sole authorized desktop controller; the issue’s release-and-lead-naming queue has not reached #127. The PR remains draft pending that gate.

Existing evidence is reusable only for the unchanged behavior it observed: [GH-68 runtime QA](../issue-68-fish-log/README.md) records a naturally earned fishing result, Fish Log, normal Journal save, and fresh Title/load continuation at source `651e3336120928a35938c69df2f8c947b1b9bbec`, with default 1152×648 and compact 800×480 inspection. It does not test live resize during a cast, 640×360, or this issue’s changed source, so it is not evidence for GH-127’s visual acceptance.

When the authorized native gate is reached, record exact source SHA, original Forward+ renderer, isolated earned checkpoint provenance/hash, actual ordinary Title/load-to-waterside route, natural cast and real inputs, inspected captures and SHA-256 hashes, resize direction/sizes, observed result and continuation, whole-state and save/settings byte comparisons, and the boundary between observed gameplay and seeded automated fixtures. Do not call a seeded result natural gameplay or claim Neal visual approval.
