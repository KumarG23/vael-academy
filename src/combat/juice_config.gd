class_name JuiceConfig
extends Resource
## Every knob for the combat presentation layer (WO-2.5), in one tunable resource
## so feel can be tweaked without code edits (§6 acceptance). The battle scene loads
## data/config/juice.tres; these defaults are the fallback.
##
## Philosophy (Darkest Dungeon): spectacle from static art + code, no frame animation.

@export_group("Lunge / recoil")
@export var lunge_distance: float = 36.0   # px the attacker drives toward the target
@export var lunge_time: float = 0.09
@export var recoil_time: float = 0.12
@export var target_recoil: float = 14.0    # px the target is knocked back on a hit

@export_group("Hit-stop (freeze on connect)")
@export var hitstop_hit: float = 0.06      # 60ms
@export var hitstop_crit: float = 0.12     # 120ms
@export var hitstop_kill: float = 0.14

@export_group("Screen shake (scaled by damage)")
@export var shake_per_damage: float = 1.2  # px of shake per point of damage
@export var shake_max: float = 24.0        # cap on the base (pre-crit) shake
@export var shake_crit_mult: float = 2.0
@export var shake_decay: float = 90.0      # px/sec falloff

@export_group("Damage number")
@export var number_rise: float = 60.0
@export var number_time: float = 0.7
@export var number_pop_scale: float = 1.7

@export_group("Miss whiff")
@export var whiff_distance: float = 54.0
@export var whiff_time: float = 0.13

@export_group("Death dissolve")
@export var dissolve_time: float = 0.4

@export_group("Clash splash (crit / kill cut-in)")
@export var splash_in: float = 0.07
@export var splash_hold: float = 0.24
@export var splash_out: float = 0.18
@export var splash_on_crit: bool = true
@export var splash_on_kill: bool = true


## Screen-shake magnitude for a strike. Base scales with damage (capped); a crit
## multiplies past the cap so it reads bigger.
func shake_magnitude(damage: int, is_crit: bool) -> float:
	var base := minf(float(damage) * shake_per_damage, shake_max)
	return base * (shake_crit_mult if is_crit else 1.0)


## Freeze duration on connect. A kill freezes longest, then a crit, then a plain hit.
func hitstop_duration(is_crit: bool, is_kill: bool) -> float:
	if is_kill:
		return hitstop_kill
	return hitstop_crit if is_crit else hitstop_hit


## Whether a full-screen clash splash fires for this strike.
func wants_splash(is_crit: bool, is_kill: bool) -> bool:
	return (is_crit and splash_on_crit) or (is_kill and splash_on_kill)
