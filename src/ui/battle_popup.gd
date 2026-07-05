class_name BattlePopup
extends CanvasLayer
## WO-4.9: FE/Dark Deity-style combat cut-in. Slides in over the map when a
## combat resolves, plays the attacker's attack animation against the
## defender's hit/KO reaction per strike, with name plates + HP bars.
## Convention-based like every art hook: available only when BOTH units have
## kit frames under `assets/art/pixellab/<id>/{idle,attack,hit,ko}_east/`;
## otherwise combat presents on the map exactly as before.

const KIT_DIR := "res://assets/art/pixellab/%s/%s_east"
const KIT_ANIMS := ["idle", "attack", "hit", "ko"]
## Optional extras loaded when present; never required by has_kit. "crit" is
## the class-flavored critical choreography (falls back to "attack").
const KIT_EXTRA_ANIMS := ["crit"]
## Generic enemy unit ids share one design's kit (mirrors the walk-frame
## promotion mapping).
const KIT_ALIASES := {
	"tm_soldier_a": "tm_soldier", "tm_soldier_b": "tm_soldier",
	"tm_guard": "tm_soldier", "tm_scout": "tm_soldier",
	"tm_armor": "tm_knight", "tm_adept": "tm_mage",
	"tide_a": "tm_soldier", "tide_b": "tm_soldier",
	"bandit_a": "bandit", "bandit_b": "bandit", "bandit_c": "bandit",
	"bandit_d": "bandit", "bandit_boss": "bandit",
}
const SPRITE_SCALE := 6.0
const FPS := 10.0

## Stage dressing per the chapter's base terrain (set by the battle view):
## sky gradient + a ground band tiled from the matching terrain atlas.
var stage_base: int = Terrain.Type.PLAINS

var _root: Control
var _left_sprite: AnimatedSprite2D
var _right_sprite: AnimatedSprite2D
var _left_holder: Control
var _right_holder: Control
var _left_hp: ProgressBar
var _right_hp: ProgressBar
var _left_name: Label
var _right_name: Label
var _damage_label: Label


## Whether `unit_id` has a full combat kit on disk (aliases resolved).
static func has_kit(unit_id: String) -> bool:
	if unit_id == "":
		return false
	var kit: String = KIT_ALIASES.get(unit_id, unit_id)
	for anim in KIT_ANIMS:
		if not ResourceLoader.exists(KIT_DIR % [kit, anim] + "/%s_f1.png" % anim):
			return false
	return true


## Build SpriteFrames from a unit's kit (variable frame counts, WO-4.7 style).
static func load_kit(unit_id: String) -> SpriteFrames:
	var kit: String = KIT_ALIASES.get(unit_id, unit_id)
	var frames := SpriteFrames.new()
	for anim in KIT_ANIMS + KIT_EXTRA_ANIMS:
		var dir := KIT_DIR % [kit, anim]
		var paths: Array[String] = []
		var i := 1
		while ResourceLoader.exists("%s/%s_f%d.png" % [dir, anim, i]):
			paths.append("%s/%s_f%d.png" % [dir, anim, i])
			i += 1
		if paths.is_empty():
			continue
		frames.add_animation(anim)
		frames.set_animation_speed(anim, FPS)
		frames.set_animation_loop(anim, anim == "idle")
		for p in paths:
			frames.add_frame(anim, load(p))
	return frames


func _ready() -> void:
	layer = 55  # above battle UI, below transitions
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	# darken the map
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.07, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	# stage: sky gradient band + tiled terrain ground (falls back to flats)
	var indoor := stage_base == Terrain.Type.FLOOR
	var sky := TextureRect.new()
	var grad := Gradient.new()
	if indoor:
		grad.set_color(0, Color(0.16, 0.13, 0.19))
		grad.set_color(1, Color(0.34, 0.28, 0.36))
	else:
		grad.set_color(0, Color(0.22, 0.30, 0.52))
		grad.set_color(1, Color(0.66, 0.60, 0.48))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(0, 1)
	sky.texture = gtex
	sky.set_anchors_preset(Control.PRESET_CENTER)
	sky.custom_minimum_size = Vector2(760, 320)
	sky.position = Vector2(-380, -160)
	_root.add_child(sky)
	var ground_tex := _ground_tile_texture(indoor)
	if ground_tex != null:
		var ground := TextureRect.new()
		ground.texture = ground_tex
		ground.stretch_mode = TextureRect.STRETCH_TILE
		ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ground.set_anchors_preset(Control.PRESET_CENTER)
		ground.custom_minimum_size = Vector2(760, 96)
		ground.position = Vector2(-380, 64)
		_root.add_child(ground)
	else:
		var flat := ColorRect.new()
		flat.color = Color(0.20, 0.26, 0.16) if not indoor else Color(0.42, 0.38, 0.30)
		flat.set_anchors_preset(Control.PRESET_CENTER)
		flat.custom_minimum_size = Vector2(760, 96)
		flat.position = Vector2(-380, 64)
		_root.add_child(flat)
	# combat sprites
	_left_sprite = _make_sprite(Vector2(-190, 40), false)
	_right_sprite = _make_sprite(Vector2(190, 40), true)
	_left_holder = _left_sprite.get_parent()
	_right_holder = _right_sprite.get_parent()
	# chrome
	_left_name = _make_name(Vector2(-360, -140))
	_right_name = _make_name(Vector2(120, -140))
	_left_hp = _make_hp(Vector2(-360, -108))
	_right_hp = _make_hp(Vector2(120, -108))
	_damage_label = Label.new()
	_damage_label.add_theme_font_size_override("font_size", 34)
	_damage_label.set_anchors_preset(Control.PRESET_CENTER)
	_damage_label.position = Vector2(-40, -60)
	_root.add_child(_damage_label)


## A tileable 32px ground texture cut from the base terrain's atlas (the
## all-base wang tile). Null when the atlases aren't installed.
func _ground_tile_texture(indoor: bool) -> Texture2D:
	var set_name := "floor_wall" if indoor else "grass_forest"
	var atlas_path := "res://assets/art/pixellab/tilesets/%s_atlas.png" % set_name
	var maps := TerrainTiles.load_wang_maps("res://assets/art/pixellab/tilesets/wang_maps.json")
	if not ResourceLoader.exists(atlas_path) or not maps.has(set_name):
		return null
	var pos: Vector2i = maps[set_name][0]
	var img: Image = (load(atlas_path) as Texture2D).get_image()
	var tile := img.get_region(Rect2i(pos.x * 32, pos.y * 32, 32, 32))
	return ImageTexture.create_from_image(tile)


func _make_sprite(pos: Vector2, flip: bool) -> AnimatedSprite2D:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_CENTER)
	holder.position = pos
	_root.add_child(holder)
	var s := AnimatedSprite2D.new()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * SPRITE_SCALE
	s.flip_h = flip
	holder.add_child(s)
	return s


func _make_name(pos: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 20)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.position = pos
	l.custom_minimum_size = Vector2(240, 26)
	_root.add_child(l)
	return l


func _make_hp(pos: Vector2) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.position = pos
	p.custom_minimum_size = Vector2(240, 14)
	_root.add_child(p)
	return p


## Play a full combat exchange. `strikes` is CombatResult.strikes; attacker is
## always shown on the left facing right.
func play_exchange(attacker: Unit, defender: Unit, strikes: Array) -> void:
	_left_sprite.sprite_frames = load_kit(attacker.unit_id())
	_right_sprite.sprite_frames = load_kit(defender.unit_id())
	_left_name.text = attacker.unit_def.display_name
	_right_name.text = defender.unit_def.display_name
	for pair in [[_left_hp, attacker], [_right_hp, defender]]:
		var bar: ProgressBar = pair[0]
		var u: Unit = pair[1]
		bar.max_value = u.max_hp()
		bar.value = u.current_hp
	_damage_label.text = ""
	_left_sprite.play("idle")
	_right_sprite.play("idle")
	_root.visible = true
	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.18)
	await tw.finished

	for strike in strikes:
		await _play_strike(strike)
		await get_tree().create_timer(0.22).timeout

	await get_tree().create_timer(0.35).timeout
	var out := create_tween()
	out.tween_property(_root, "modulate:a", 0.0, 0.15)
	await out.finished
	_root.visible = false
	_left_sprite.modulate.a = 1.0
	_right_sprite.modulate.a = 1.0


## One strike, GBA-style: the actor lunges in, the blow lands MID-swing
## (reaction, knockback, flash, shake, damage pop), then the actor recovers
## back to its mark. Crits use the class "crit" choreography when the kit
## has one, with a heavier shake.
func _play_strike(strike) -> void:
	var striker_left: bool = not strike.is_counter
	var actor := _left_sprite if striker_left else _right_sprite
	var actor_holder := _left_holder if striker_left else _right_holder
	var target := _right_sprite if striker_left else _left_sprite
	var target_holder := _right_holder if striker_left else _left_holder
	var target_bar := _right_hp if striker_left else _left_hp
	var dir := 1.0 if striker_left else -1.0
	var home := actor_holder.position
	var anim := "crit" if strike.was_crit and actor.sprite_frames.has_animation("crit") else "attack"
	var swing := actor.sprite_frames.get_frame_count(anim) / FPS

	# lunge toward the opponent while the swing starts
	var lunge := create_tween()
	lunge.tween_property(actor_holder, "position:x", home.x + dir * 95.0, 0.12) \
		.set_ease(Tween.EASE_OUT)
	actor.play(anim)
	await get_tree().create_timer(maxf(swing * 0.55, 0.15)).timeout  # impact moment

	if strike.connected:
		var lethal: bool = strike.defender_hp_after <= 0
		target.play("ko" if lethal and target.sprite_frames.has_animation("ko") else "hit")
		target_bar.value = strike.defender_hp_after
		_flash(target, Color(1.0, 0.35, 0.35))
		_knockback(target_holder, dir)
		_shake(0.35 if strike.was_crit else 0.16)
		_pop_damage(("CRIT %d" % strike.damage) if strike.was_crit else str(strike.damage),
			Color(1.0, 0.85, 0.2) if strike.was_crit else Color(1.0, 0.5, 0.45),
			strike.was_crit)
		if lethal:
			var fade := create_tween()
			fade.tween_property(target, "modulate:a", 0.0, 0.7).set_delay(0.35)
	else:
		# whiff: the target sways out of the blow
		_knockback(target_holder, dir * 0.5)
		_pop_damage("Miss", Color(0.85, 0.85, 0.9), false)

	await actor.animation_finished
	actor.play("idle")
	var back := create_tween()
	back.tween_property(actor_holder, "position", home, 0.14).set_ease(Tween.EASE_IN)
	await back.finished
	if strike.connected and strike.defender_hp_after > 0 and target.animation != "idle":
		target.play("idle")


func _flash(sprite: AnimatedSprite2D, color: Color) -> void:
	var alpha := sprite.modulate.a
	sprite.modulate = Color(color.r, color.g, color.b, alpha)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1, 1, 1, alpha), 0.28)


func _knockback(holder: Control, dir: float) -> void:
	var home := holder.position
	var tw := create_tween()
	tw.tween_property(holder, "position:x", home.x + dir * 18.0, 0.06)
	tw.tween_property(holder, "position:x", home.x, 0.16)


func _shake(strength: float) -> void:
	var tw := create_tween()
	for i in range(5):
		var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 14.0 * strength * 3.0
		tw.tween_property(_root, "position", off, 0.035)
	tw.tween_property(_root, "position", Vector2.ZERO, 0.05)


func _pop_damage(text: String, color: Color, big: bool) -> void:
	_damage_label.text = text
	_damage_label.modulate = color
	_damage_label.pivot_offset = _damage_label.size / 2.0
	_damage_label.scale = Vector2.ONE * (1.9 if big else 1.5)
	var tw := create_tween()
	tw.tween_property(_damage_label, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
