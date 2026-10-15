class_name PixelCombatComparison
extends BattlePopup
## CP-6 A: existing PixelLab player/kits, isolated comparison-only staging.
## No edits to the original animation frames or production BattlePopup behavior.
signal beat(name: String)
signal contact(strike: StrikeResult)
var presentation_data: Dictionary
var active_strike: StrikeResult
var _dodging := false
var _dodge_home := Vector2.ZERO
var _dodge_target: Control
var _first_strike := true


func _ready() -> void:
	super._ready()
	presentation_data = JSON.parse_string(FileAccess.get_file_as_string(IllustratedCombatPresentation.DATA))
	var badge := Label.new()
	badge.text = "A  /  PIXELLAB BATTLE FRAMES"
	badge.position = Vector2(340, 25)
	badge.size.x = 470
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 18)
	badge.add_theme_color_override("font_color", TRIM)
	_root.add_child(badge)


func _stage_battlers(left_id: String, right_id: String, map_shot: Texture2D, _gap: float = 190.0) -> bool:
	_first_strike = true
	var factor := _root.size.y / 720.0
	var background := super._stage_battlers(left_id, right_id, map_shot, 190.0 * factor)
	for index in range(2):
		var sprite: AnimatedSprite2D = [_left_sprite, _right_sprite][index]
		var holder: Control = [_left_holder, _right_holder][index]
		var id: String = left_id if index == 0 else right_id
		var record: Dictionary = presentation_data["characters"][id]
		# Serra's lance extends above her head. Use the actual standing BODY
		# height, not the weapon's bounds, to match B's visible figure height.
		var size := float(record["height"]) * factor / float(record["pixel_body_height"])
		sprite.scale = Vector2.ONE * size
		var bounds := _idle_bounds(sprite.sprite_frames)
		holder.position.y = _ground_line(background) - (bounds.y - _kit_frame_height(sprite.sprite_frames) * 0.5) * size
	beat.emit("establish")
	return background


func _play_strike(strike) -> void:
	if _first_strike:
		_first_strike = false
		beat.emit("ready")
		await get_tree().create_timer(0.28).timeout
	active_strike = strike
	_dodging = not strike.connected
	if _dodging:
		_dodge_target = _left_holder if strike.is_counter else _right_holder
		_dodge_home = _dodge_target.position
		var direction := -1.0 if strike.is_counter else 1.0
		# Parent computes the attack's original destination synchronously before
		# this tween moves the defender, so the authored attack visibly misses.
		var dodge := create_tween()
		dodge.tween_property(_dodge_target, "position:x", _dodge_home.x + direction * 90.0, 0.075)
		beat.emit("dodge")
	beat.emit("critical_hold" if strike.was_crit else "windup")
	await super._play_strike(strike)
	if _dodging:
		var back := create_tween()
		back.tween_property(_dodge_target, "position", _dodge_home, 0.18).set_trans(Tween.TRANS_SINE)
		await back.finished
	_dodging = false
	beat.emit("recovery")


func _burst(at: Vector2, big: bool) -> void:
	super._burst(at, big)
	contact.emit(active_strike)
	beat.emit("contact")


func _knockback(holder: Control, direction: float) -> void:
	if _dodging:
		contact.emit(active_strike)
		beat.emit("contact")
		return
	super._knockback(holder, direction)
