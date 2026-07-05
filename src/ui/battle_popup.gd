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
## Generic enemy unit ids share one design's kit (mirrors the walk-frame
## promotion mapping).
const KIT_ALIASES := {
	"tm_soldier_a": "tm_soldier", "tm_soldier_b": "tm_soldier",
	"tm_guard": "tm_soldier", "tm_scout": "tm_soldier",
	"tm_armor": "tm_knight", "tm_adept": "tm_mage",
	"tide_a": "tm_soldier", "tide_b": "tm_soldier",
}
const SPRITE_SCALE := 5.0
const FPS := 10.0

var _root: Control
var _left_sprite: AnimatedSprite2D
var _right_sprite: AnimatedSprite2D
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
	for anim in KIT_ANIMS:
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
	# stage band
	var stage := ColorRect.new()
	stage.color = Color(0.12, 0.13, 0.11)
	stage.set_anchors_preset(Control.PRESET_CENTER)
	stage.custom_minimum_size = Vector2(760, 320)
	stage.position = Vector2(-380, -160)
	_root.add_child(stage)
	var ground := ColorRect.new()
	ground.color = Color(0.20, 0.26, 0.16)
	ground.set_anchors_preset(Control.PRESET_CENTER)
	ground.custom_minimum_size = Vector2(760, 90)
	ground.position = Vector2(-380, 70)
	_root.add_child(ground)
	# combat sprites
	_left_sprite = _make_sprite(Vector2(-190, 40), false)
	_right_sprite = _make_sprite(Vector2(190, 40), true)
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
		var striker_left: bool = not strike.is_counter
		var actor := _left_sprite if striker_left else _right_sprite
		var target := _right_sprite if striker_left else _left_sprite
		var target_bar := _right_hp if striker_left else _left_hp
		actor.play("attack")
		await actor.animation_finished
		if strike.connected:
			var lethal: bool = strike.defender_hp_after <= 0
			target.play("ko" if lethal and target.sprite_frames.has_animation("ko") else "hit")
			target_bar.value = strike.defender_hp_after
			_damage_label.text = ("CRIT %d" % strike.damage) if strike.was_crit else str(strike.damage)
			_damage_label.modulate = Color(1.0, 0.85, 0.2) if strike.was_crit else Color(1.0, 0.5, 0.45)
			if not lethal:
				await target.animation_finished
				target.play("idle")
		else:
			_damage_label.text = "Miss"
			_damage_label.modulate = Color(0.85, 0.85, 0.9)
		actor.play("idle")
		await get_tree().create_timer(0.25).timeout

	await get_tree().create_timer(0.35).timeout
	var out := create_tween()
	out.tween_property(_root, "modulate:a", 0.0, 0.15)
	await out.finished
	_root.visible = false
