# Emberwing native-input action transcript

Reproduction companion for issue #19. Start with `emberwing-rite-start.json` in an isolated save slot, load it through Title, then Begin battle. Coordinates are zero-based map cells; all actions below were sent through keyboard movement/action menus. Enemy turns and normal dialogue advance run between rounds. This is a curated action list, not a raw runtime/model log.

| Round | Unit | From → destination | Action | Target |
| --- | --- | --- | --- | --- |
| 1 | kael | (3, 12) → (9, 12) | Wait | — |
| 1 | liora | (2, 11) → (5, 9) | Wait | — |
| 1 | kai | (2, 12) → (8, 12) | Wait | — |
| 1 | perrin | (1, 12) → (7, 11) | Wait | — |
| 1 | brenna | (2, 13) → (5, 11) | Wait | — |
| 1 | dain | (1, 13) → (2, 9) | Wait | — |
| 1 | wren | (3, 13) → (4, 9) | Wait | — |
| 2 | kai | (8, 12) → (11, 13) | Attack | (10, 13) |
| 2 | perrin | (7, 11) → (4, 8) | Attack | (4, 7) |
| 2 | brenna | (5, 11) → (9, 12) | Attack | (10, 12) |
| 2 | wren | (4, 9) → (4, 9) | Heal | (4, 8) |
| 2 | dain | (2, 9) → (5, 8) | Attack | (6, 8) |
| 3 | perrin | (4, 8) → (5, 10) | Attack | (5, 9) |
| 3 | brenna | (9, 12) → (10, 12) | Attack | (11, 12) |
| 3 | dain | (5, 8) → (5, 8) | Attack | (5, 9) |
| 4 | perrin | (5, 10) → (5, 10) | Attack | (5, 11) |
| 4 | dain | (5, 8) → (6, 11) | Wait | — |
| 5 | perrin | (5, 10) → (5, 9) | Attack | (6, 9) |
| 6 | perrin | (5, 9) → (10, 9) | Wait | — |

Observed: Kai fell during the enemy phase of round 2. Play continued; Perrin won alone in round 6 and the result returned to Week 2. MASTER_PLAN §3 requires lord loss to defeat the player. See issue #19 for the asynchronous lifetime cause.
