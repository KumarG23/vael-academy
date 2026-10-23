# Bounded native-input actions

Source `55711c99`, original Forward+ renderer, 1280×720 desktop, disposable saves. Native input uses ordinary OS keyboard/pointer events. Read-only inspection observes state/coordinates and supplies tactical suggestions; it does not execute game actions or modify state.

1. Fresh Title → Load the byte-identical native round-5 field UI checkpoint from #54. No save fields changed. Two rivals remain, Corvin (3 HP) and Nilu (1 HP); Kael, Brenna, Dain and Kai survive. This resumes #54's declared boundary run, not a new semester or full battle playthrough.
2. Brenna (12,10) → (16,9), Wait. Dain (10,12) → (12,9), Wait. Turn menu → End Turn; normal enemy combat makes Brenna/Dain yield and reaches round 6.
3. Kael (19,11) → (17,7), Attack Corvin at (17,8), accept the existing weapon/forecast. Corvin yields. End Turn; Nilu's normal attack/counter sequence ends in Victory, Kai/Kael surviving. No HP, damage, result, roster, calendar or progression injection.
4. Record the read-only completed-result snapshot: C/53, fresh empty grade samples and pending receipt; gold absent. Return dismisses Victory and enters the castle normally.
5. Advance Callan's standing → remark → 80-gold reward → merchant lines with Return. Inspect that receipt/gold remain pending/zero until completion. Next Return completes the card: 80 gold, delivered receipt and merchant unlock; the existing Victory Feast starts alone. Advance the feast normally; its seen flag commits on completion.
6. J → Grades: inspect C/53 locked history, neutral next-term Battlefield and purse 80g. Right → System → Down twice → Enter writes physical Save Slot 3 (`slot_2.json`). Close Journal and close the window normally.
7. Launch a fresh process → Title Load. The sparse menu contains Slot 0 (battle), Slot 2 (delivered campus), Back. An initial physical-third-row navigation selected Back; return to Load and select the displayed Slot 2 row. Inspect the campus without card/feast replay, then Journal → Grades: C/53 and 80g unchanged. System → Save Slot 3 again; compare the entire saved campaign dictionary with the first campus save and read-only fresh-load observation. They match exactly.
8. Close Journal and the second game window normally. No graphical input/capture process remains. Publish explicit desktop release 6363795304.

Pending save/reload before presentation, interruption/re-entry, duplicate callbacks, first-boundary rest/S/full-inventory, legacy no-backpay and malformed-load cases are covered by the focused/headless regressions. The graphical sequence above demonstrates one actual C reward from resumed normal combat, the final card/feast order and completed-save replay protection; it does not claim every automated case was also played graphically.
