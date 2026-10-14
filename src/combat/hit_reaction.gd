class_name HitReaction
extends RefCounted
## CP-1: how a TARGET answers a strike at the impact beat — pure classification
## (no nodes), so the presentation layer stays dumb and this stays testable.
## JuiceController turns the kind into a timed tween on the target (or, when the
## target has high-res combat art, on a temporary target rig in its
## `parry_hit` pose). Tuning numbers live in JuiceConfig.
##
##   DODGE     — a miss: the target sidesteps across the line of attack
##   FLINCH    — an ordinary hit: a short shove + squash
##   STAGGER   — a crit, or a hit that takes a big bite of max HP: a heavier
##               shove + wobble
##   KNOCKBACK — a killing blow: thrown back hard before the death dissolve

enum Kind { NONE, DODGE, FLINCH, STAGGER, KNOCKBACK }


## `stagger_frac` = share of the target's max HP one hit must take to stagger
## without a crit (JuiceConfig.stagger_hp_frac).
static func classify(strike: StrikeResult, is_kill: bool, target_max_hp: int, stagger_frac := 0.35) -> int:
	if strike == null:
		return Kind.NONE
	if not strike.connected:
		return Kind.DODGE
	if is_kill:
		return Kind.KNOCKBACK
	if strike.was_crit:
		return Kind.STAGGER
	if target_max_hp > 0 and float(strike.damage) / float(target_max_hp) >= stagger_frac:
		return Kind.STAGGER
	return Kind.FLINCH


static func kind_name(kind: int) -> String:
	match kind:
		Kind.DODGE: return "dodge"
		Kind.FLINCH: return "flinch"
		Kind.STAGGER: return "stagger"
		Kind.KNOCKBACK: return "knockback"
		_: return "none"
