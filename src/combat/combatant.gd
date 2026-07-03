class_name Combatant
extends RefCounted
## A snapshot of one participant in a combat exchange: stats, equipped weapon, and
## the terrain modifiers of the tile it stands on. Decoupled from Unit nodes (§2
## rule 2) so CombatResolver is pure and headless-testable. Build one from a Unit
## at attack time (WO-1.2).

var display_name: String = ""
var max_hp: int = 20
var current_hp: int = 20
var strength: int = 5
var magic: int = 0
var skill: int = 5
var speed: int = 5
var luck: int = 3
var defense: int = 5
var resistance: int = 0
var weapon: WeaponDef
var terrain_def: int = 0
var terrain_avoid: int = 0
var support_hit: int = 0
var support_avoid: int = 0
var support_damage: int = 0
var support_crit: int = 0


static func make(
	display_name: String,
	stats: Dictionary,
	weapon: WeaponDef,
	terrain_def: int = 0,
	terrain_avoid: int = 0,
	support_bonus: Dictionary = {},
) -> Combatant:
	var c := Combatant.new()
	c.display_name = display_name
	c.max_hp = stats.get("hp", 20)
	c.current_hp = stats.get("current_hp", c.max_hp)
	c.strength = stats.get("str", 5)
	c.magic = stats.get("mag", 0)
	c.skill = stats.get("skl", 5)
	c.speed = stats.get("spd", 5)
	c.luck = stats.get("lck", 3)
	c.defense = stats.get("def", 5)
	c.resistance = stats.get("res", 0)
	c.weapon = weapon
	c.terrain_def = terrain_def
	c.terrain_avoid = terrain_avoid
	c.apply_support_bonus(support_bonus)
	return c


func apply_support_bonus(bonus: Dictionary) -> void:
	support_hit = int(bonus.get("hit", 0))
	support_avoid = int(bonus.get("avoid", 0))
	support_damage = int(bonus.get("damage", 0))
	support_crit = int(bonus.get("crit", 0))


func attack_speed() -> int:
	var weight := weapon.weight if weapon != null else 0
	return CombatMath.attack_speed(speed, strength, weight)


func is_alive() -> bool:
	return current_hp > 0


## Can this combatant strike a target at `distance` (weapon exists, can attack, in range)?
func can_strike_at(distance: int) -> bool:
	return weapon != null and weapon.can_attack() and weapon.in_range(distance)


## Defense stat an attacker with `magical` weapon reads against this combatant.
func defense_against(magical: bool) -> int:
	return resistance if magical else defense
