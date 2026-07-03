class_name TurnManager
extends RefCounted
## Tracks whose phase it is and the round number. Pure state (§2 rule 2); the
## battle scene drives it and reacts. Player and enemy each take one phase per
## round; a full round is player phase + enemy phase.

enum Team { PLAYER = 0, ENEMY = 1 }

var round_number: int = 1
var active_team: Team = Team.PLAYER


func is_player_phase() -> bool:
	return active_team == Team.PLAYER


func is_enemy_phase() -> bool:
	return active_team == Team.ENEMY


## Hand the phase to the other team. Advancing from the enemy back to the player
## starts a new round.
func advance() -> void:
	if active_team == Team.PLAYER:
		active_team = Team.ENEMY
	else:
		active_team = Team.PLAYER
		round_number += 1


func phase_name() -> String:
	return "Player Phase" if is_player_phase() else "Enemy Phase"
