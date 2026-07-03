extends Node
## Global signal hub for cross-system communication (§2 coding rule 3).
##
## Registered as the `EventBus` autoload. Systems emit and connect to signals
## here instead of reaching across the scene tree to find each other. Keep this
## to genuinely cross-system events; do not turn it into a dumping ground.

## Emitted when a unit's HP reaches zero and it is removed from play.
signal unit_died(unit: Node)

## Emitted when the player wins the current battle (objective met).
signal battle_won

## Emitted when a support pair advances a rank (C/B/A).
signal support_rank_up(pair_id: String, new_rank: String)
