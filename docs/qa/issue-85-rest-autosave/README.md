# GH-85 — settled academy-rest checkpoint

## Scope and source basis

MASTER_PLAN §§1–2, §6 WO-9.6, partial §10 M9; ACADEMY_BIBLE §3; GRADING_SYSTEM §§1, 4–6 and accepted #54/#56 completion receipts. Parent: #84. Starting accepted main: `cd2af67c960fda359549e1bba0f4a62216a81c02`.

Only a successful non-battle Castle rest requests a checkpoint. One deferred completion writes `autosave.json` after the existing report-card/set-piece queue and callbacks settle. An unfinished, unplayable, detached or departing presentation does not replace the last checkpoint. The pending request gates world input until completion; no frame polling, retry loop or battle/activity autosave is introduced. Success/failure is nonblocking, and a later eligible rest retries after failure. New Game preserves recovery.

The autosave has the existing version-1 campaign envelope and shares SaveSystem's temporary-write/replace implementation. It has no manual-slot ID. All three numbered manual files remain independent. The shared writer now checks the store result and verifies the closed temporary file bytes before replacement: the real short-write regression showed that the prior get_error-only check can miss write failures. Title appends an explicitly named Autosave after occupied manual entries and retains their physical IDs. Restore uses the existing Campaign validation and deferred campaign routing; an invalid, missing, empty or battle checkpoint cannot fall back to a manual slot. The failed selection stays available for retry, another slot or Back.

No new canon contradiction was found. Existing six-entry calendar/semester arithmetic remains development scaffolding, with authored calendar/migration decisions under #30. Historical report cards remain opaque/no-backpay; no reward or receipt policy changes.

## Automated evidence

Clean Godot 4.7.2 import passed with no script-load errors. Final affected checks pass **220/220 tests, 7,041 assertions / 21 scripts**, exit 0 (48.592 s); storage-only checks pass **13/13, 202 assertions**. Helpers: **104 discovered, 102 pass, two existing opt-in skips**. Tests use disposable player data; the common Git-directory heavy lock serializes Godot work. Full GUT passes **943/943, 16,864 assertions / 115 scripts**, exit 0 (442.965 s), with 32 inherited deprecations, no script-load or exit-time resource errors. Expected headless popup renderer diagnostics remain. Final-head CI is still pending. The affected run has 25 inherited deprecations and the existing two ObjectDB/one resource exit diagnostics.

New coverage exercises production rest and completion callbacks, normal rest interaction, repeated input, full settled Campaign equality (including training RNG, supports, visits, grades, receipts and inventory), report-card/festival serialization, interruption, deferred departure, actual temporary-open/short-write/rename failure paths and later retry, all manual bytes, sparse Title mapping, occupied-invalid/missing recovery, legacy defaults/no-backpay, New Game preservation and a separate-process Title confirmation/normal campus continuation. Before IO hardening, the new real short-write regression fails in the affected run (**219/220, 7,039/7,041 assertions**). The Linux short-write fixture ignores SIGXFSZ and applies a 1 KiB child-process file-size limit: both buffered and larger writes must fail without replacing the prior file, then a small write must succeed. Existing assertions are retained.

## Required original-renderer evidence — pending

No game/native input/capture was launched for GH-85. #83 remains sole GUI controller until explicit release and lead naming of #85. This is a preparation receipt, not graphical acceptance or Neal visual approval.

After release, use disposable save files and the original project renderer:

1. Copy the existing native [Week-2 checkpoint](../issue-5-school-loop/emberwing-return-save.json), SHA-256 `681e0c32af7483a6b48abdfe2c0c612ee65cf5450352d62ca5a8a431275b1fe4`, into an isolated manual slot. Declare any fixture deltas separately. Record all three manual hashes before play.
2. Load through Title, walk to the existing house-hall rest point and rest normally. Capture Week 3 and truthful autosave feedback. Confirm the checkpoint equals the complete live Campaign and every manual hash is unchanged.
3. Quit normally, launch a fresh process and choose Autosave through Title. Capture its chapter/week/mode context, restored Week 3 and ordinary play continuation. Compare complete payloads and RNG state, not only visible week/gold.
4. Rest from Week 3. Observe the existing report-card ceremony followed by the Founding Festival. Confirm checkpoint bytes remain unchanged throughout both presentations; only their completed callbacks permit replacement. Record existing rank/gold/item/merchant/festival/cooking/conduct/receipt values, reload and verify no replay or duplicated reward.
5. In isolated data only, occupy Autosave with invalid JSON. Exercise rejection, retry after replacing the file, other-slot selection and cancel; capture default and compact layouts. Preserve source/neighbor bytes and live Campaign/roster/RNG/staging/room state on rejection.
6. End every game/input/capture job and explicitly release the desktop. Record tested SHA, renderer, native checkpoint/fixture differences, inputs, inspected captures, hashes and limits here.

Final accepted-main fetch remains `cd2af67c`; no accepted sibling delta is available at publication. Accepted #83 feedback and #76 Journal changes must be integrated normally before readiness. Exact-head Verify and engineering-lead review remain required; no self-merge, full-year replay or creative approval claim.
