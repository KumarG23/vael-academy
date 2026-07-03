class_name ObjectiveResolver
extends RefCounted
## Pure win/loss evaluation (§6, §3 permadeath). No node deps — the battle scene
## feeds it scalars derived from the board and reacts to the Outcome.
##
## Precedence: defeat is checked before victory. Lord death is game over regardless
## of the objective (§3).

enum Outcome { ONGOING, VICTORY, DEFEAT }


## `has_lord` false means the chapter defines no lord — then defeat is only "all
## player units lost" (the lord-death rule simply doesn't apply).
static func evaluate(
	objective: ChapterDef.Objective,
	seize_cell: Vector2i,
	has_lord: bool,
	lord_alive: bool,
	lord_cell: Vector2i,
	player_alive_count: int,
	enemy_alive_count: int,
) -> Outcome:
	# Defeat first (§3: lord death = game over regardless).
	if has_lord and not lord_alive:
		return Outcome.DEFEAT
	if player_alive_count <= 0:
		return Outcome.DEFEAT

	match objective:
		ChapterDef.Objective.ROUT:
			if enemy_alive_count <= 0:
				return Outcome.VICTORY
		ChapterDef.Objective.SEIZE:
			if has_lord and lord_alive and lord_cell == seize_cell:
				return Outcome.VICTORY

	return Outcome.ONGOING
