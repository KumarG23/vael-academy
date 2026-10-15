class_name ActiveDefenseTrial
extends RefCounted
## CP-9 isolated, provisional rules. No production combat math or RNG access.
var settings: Dictionary
var elapsed := 0.0
var action := ""
var input_time := -1.0
var closed := false
var assisted := false


func _init(config: Dictionary) -> void:
	settings = config.duplicate(true)


func attempt(choice: String) -> bool:
	if closed or action != "" or choice not in ["dodge", "block"]:
		return false
	action = choice
	input_time = elapsed
	return true


func advance(delta: float, auto_block: bool) -> void:
	if closed:
		return
	elapsed += maxf(0.0, delta)
	if auto_block and action == "" and elapsed >= float(settings["cue"]):
		# Crossing the cue, not overshooting by a slow frame, triggers assist.
		action = "block"
		input_time = float(settings["cue"])
		assisted = true


func resolve(base: StrikeResult, block_fraction: float) -> Dictionary:
	closed = true
	var outcome := copy_strike(base)
	var result := "no_input" if action == "" else "failed"
	if not base.connected:
		result = "native_miss"
	elif action != "":
		var window := float(settings[action + "_window"])
		if absf(input_time - float(settings["cue"])) <= window + 0.000001 and input_time <= float(settings["windup"]) + 0.000001:
			result = action
			outcome.damage = 0 if action == "dodge" else ceili(base.damage * block_fraction)
			outcome.connected = action != "dodge"
			outcome.was_crit = false
			outcome.defender_hp_after = maxi(0, base.defender_hp_before - outcome.damage)
	return {"strike": outcome, "result": result, "action": action, "offset": input_time - float(settings["cue"]), "assisted": assisted}


static func copy_strike(base: StrikeResult) -> StrikeResult:
	var copy := StrikeResult.new()
	for field: String in ["attacker_name", "defender_name", "is_counter", "displayed_hit", "displayed_crit", "connected", "was_crit", "damage", "defender_hp_before", "defender_hp_after"]:
		copy.set(field, base.get(field))
	return copy
