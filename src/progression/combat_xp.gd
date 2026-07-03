class_name CombatXP
extends RefCounted
## Experience awards (§3): ~10 for a hit, ~30+ for a kill, scaled by the level
## difference and clamped to 1–100 per action. Pure and table-testable.

const HIT_BASE := 10
const KILL_BASE := 30
const LEVEL_CAP := 20
const XP_PER_LEVEL := 100


## XP the acting unit earns this exchange. `killed` implies the target reached 0 HP;
## `connected` means at least one strike landed. Higher-level targets pay more.
static func award(attacker_level: int, defender_level: int, connected: bool, killed: bool) -> int:
	if not connected and not killed:
		return 0
	var diff := defender_level - attacker_level
	var xp := (KILL_BASE + diff * 3) if killed else (HIT_BASE + diff)
	return clampi(xp, 1, 100)


## XP a healer earns for restoring `amount` HP (§4: healers gain XP from healing).
static func award_heal(amount: int) -> int:
	if amount <= 0:
		return 0
	return clampi(HIT_BASE + amount, 1, 100)
