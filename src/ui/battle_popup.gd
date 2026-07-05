class_name BattlePopup
extends CanvasLayer
## WO-4.9 v3: full GBA-FE style battle screen (rebuilt to Neal's reference
## GIFs in sample/). The map itself becomes the washed backdrop with a
## terrain diorama platform; chrome is team-colored framed banners, weapon
## plates, HIT/DMG/CRT blocks and segmented HP bars that DRAIN (no floating
## damage numbers); strikes run in, land mid-swing with a starburst, shake
## and white flash; crits flash the whole screen; deaths dissolve to white.
## Convention-based: available only when BOTH units have kit frames under
## `assets/art/pixellab/<id>/{idle,attack,hit,ko}_east/`.

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
## Battlers aim for ~45% of screen height (GBA proportion) regardless of
## the kit's native resolution (32px map-scale kits vs 64px+ battle kits).
const TARGET_BATTLER_PX := 300.0
const FPS := 10.0

const PLAYER_COLOR := Color(0.16, 0.25, 0.55)
const PLAYER_EDGE := Color(0.45, 0.62, 0.95)
const ENEMY_COLOR := Color(0.52, 0.13, 0.13)
const ENEMY_EDGE := Color(0.95, 0.45, 0.40)
const TRIM := Color(0.86, 0.78, 0.55)

const FLASH_SHADER := "
shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a * COLOR.a);
}"

## Stage dressing per the chapter's base terrain (set by the battle view).
var stage_base: int = Terrain.Type.PLAINS

var _root: Control
var _backdrop: TextureRect
var _left_sprite: AnimatedSprite2D
var _right_sprite: AnimatedSprite2D
var _left_holder: Control
var _right_holder: Control
var _left_hp: BattlePopupHPBar
var _right_hp: BattlePopupHPBar
var _crit_flash: ColorRect
var _fx: Control
var _miss_label: Label
var _bursts: Array = []  # active starbursts: {pos, age, life, big}

# chrome rebuilt per exchange
var _chrome: Control


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
	# washed map backdrop (set per exchange) + warm wash + vignette dim
	_backdrop = TextureRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_root.add_child(_backdrop)
	var wash := ColorRect.new()
	wash.color = Color(0.93, 0.92, 0.86, 0.42)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(wash)
	# diorama platform: tiled terrain top + shaded lip (FE pedestal)
	var plat := Control.new()
	plat.set_anchors_preset(Control.PRESET_CENTER)
	plat.draw.connect(_draw_platform.bind(plat))
	plat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_root.add_child(plat)
	# combat sprites
	_left_sprite = _make_sprite(Vector2(-190, 46), false)
	_right_sprite = _make_sprite(Vector2(190, 46), true)
	_left_holder = _left_sprite.get_parent()
	_right_holder = _right_sprite.get_parent()
	# effects: starburst layer, MISS label, full-screen crit flash
	_fx = Control.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.draw.connect(_draw_fx)
	_root.add_child(_fx)
	_miss_label = Label.new()
	_miss_label.text = "MISS"
	_miss_label.add_theme_font_size_override("font_size", 26)
	_miss_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90))
	_miss_label.add_theme_color_override("font_outline_color", Color(0.15, 0.15, 0.2))
	_miss_label.add_theme_constant_override("outline_size", 6)
	_miss_label.set_anchors_preset(Control.PRESET_CENTER)
	_miss_label.visible = false
	_root.add_child(_miss_label)
	_crit_flash = ColorRect.new()
	_crit_flash.color = Color(1, 1, 1, 0)
	_crit_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_crit_flash)
	# chrome container (rebuilt per exchange: teams differ)
	_chrome = Control.new()
	_chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_chrome)


## FE diorama pedestal: the base terrain's tile drawn straight from its
## atlas region across the platform (TerrainTiles' proven path), scaled 2x
## chunky, with a shaded lip. Falls back to flat colors without atlases.
func _draw_platform(plat: Control) -> void:
	var indoor := stage_base == Terrain.Type.FLOOR
	var top := Rect2(-370, 8, 740, 104)
	var lip := Rect2(-370, 112, 740, 16)
	var set_name := "floor_carpet" if indoor else "grass_forest"
	var atlas_path := "res://assets/art/pixellab/tilesets/%s_atlas.png" % set_name
	var maps := TerrainTiles.load_wang_maps("res://assets/art/pixellab/tilesets/wang_maps.json")
	if ResourceLoader.exists(atlas_path) and maps.has(set_name):
		var pos: Vector2i = maps[set_name][0]
		var src := Rect2(pos.x * 32, pos.y * 32, 32, 32)
		var tex: Texture2D = load(atlas_path)
		var cell := 64.0  # 2x chunky tiles
		var x := top.position.x
		while x < top.end.x:
			var w := minf(cell, top.end.x - x)
			var y := top.position.y
			while y < top.end.y:
				var h := minf(cell, top.end.y - y)
				plat.draw_texture_rect_region(tex, Rect2(x, y, w, h),
					Rect2(src.position, Vector2(src.size.x * w / cell, src.size.y * h / cell)))
				y += cell
			x += cell
	else:
		plat.draw_rect(top, Color(0.30, 0.42, 0.22) if not indoor else Color(0.72, 0.66, 0.52), true)
	plat.draw_rect(lip, Color(0.12, 0.16, 0.09, 0.9) if not indoor else Color(0.25, 0.20, 0.14, 0.9), true)
	# soft edge line so the pedestal pops off the washed map
	plat.draw_rect(top, Color(0.10, 0.12, 0.08, 0.55), false, 2.0)


func _make_sprite(pos: Vector2, flip: bool) -> AnimatedSprite2D:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_CENTER)
	holder.position = pos
	_root.add_child(holder)
	var s := AnimatedSprite2D.new()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.flip_h = flip
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FLASH_SHADER
	mat.shader = sh
	s.material = mat
	holder.add_child(s)
	return s


# --- chrome -------------------------------------------------------------------

func _team_colors(unit: Unit) -> Array:
	return [PLAYER_COLOR, PLAYER_EDGE] if unit.team == 0 else [ENEMY_COLOR, ENEMY_EDGE]


func _framed_panel(parent: Control, rect: Rect2, fill: Color, edge: Color) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 4
	p.add_theme_stylebox_override("panel", sb)
	p.position = rect.position
	p.size = rect.size
	parent.add_child(p)
	return p


func _panel_label(parent: Control, pos: Vector2, text: String, size: int,
		color := Color(0.96, 0.94, 0.88), width := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.12, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.position = pos
	if width > 0.0:
		l.custom_minimum_size = Vector2(width, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


## Build the GBA chrome for this exchange: name banners top, weapon plate +
## HIT/DMG/CRT block + segmented HP bar per side at the bottom.
func _build_chrome(attacker: Unit, defender: Unit, exchange: Dictionary) -> void:
	for c in _chrome.get_children():
		c.queue_free()
	var vp := _root.size
	var sides := [
		{"unit": attacker, "stats": exchange.get("attacker", {}), "active": true, "x": 0.0},
		{"unit": defender, "stats": exchange.get("defender", {}),
			"active": bool(exchange.get("defender_can_counter", false)), "x": vp.x - 340.0},
	]
	for i in range(2):
		var s: Dictionary = sides[i]
		var unit: Unit = s["unit"]
		var colors := _team_colors(unit)
		var left_side: bool = i == 0
		# name banner (top corner)
		var bx := 26.0 if left_side else vp.x - 266.0
		_framed_panel(_chrome, Rect2(bx, 22, 240, 40), colors[0], TRIM)
		_panel_label(_chrome, Vector2(bx, 28), unit.unit_def.display_name, 20,
			Color(0.98, 0.96, 0.9), 240)
		# bottom block
		var px := 26.0 if left_side else vp.x - 366.0
		var py := vp.y - 148.0
		# weapon plate
		var wname := unit.weapon().display_name if unit.weapon() != null else "—"
		_framed_panel(_chrome, Rect2(px, py, 340, 34), Color(0.16, 0.14, 0.11, 0.97), TRIM)
		_panel_label(_chrome, Vector2(px, py + 4), wname, 17, Color(0.95, 0.9, 0.78), 340)
		# stat block + HP panel
		_framed_panel(_chrome, Rect2(px, py + 38, 340, 86), colors[0], TRIM)
		var stats: Dictionary = s["stats"]
		var rows := ([["HIT", "%d" % int(stats.get("hit", 0))],
			["DMG", "%d" % int(stats.get("damage", 0))],
			["CRT", "%d" % int(stats.get("crit", 0))]] if s["active"]
			else [["", ""], ["", "—"], ["", ""]])
		for r in range(3):
			_panel_label(_chrome, Vector2(px + 12, py + 40 + r * 25), rows[r][0], 14,
				Color(0.95, 0.9, 0.75))
			_panel_label(_chrome, Vector2(px + 56, py + 40 + r * 25), rows[r][1], 14)
		# segmented HP bar
		var bar := BattlePopupHPBar.new()
		bar.max_hp = unit.max_hp()
		bar.shown_hp = float(unit.current_hp)
		bar.position = Vector2(px + 108, py + 52)
		bar.size = Vector2(220, 58)
		_chrome.add_child(bar)
		if left_side:
			_left_hp = bar
		else:
			_right_hp = bar


# --- the exchange ---------------------------------------------------------------

## Play a full combat exchange. `strikes` is CombatResult.strikes; attacker is
## always shown on the left facing right. `exchange` is CombatForecast.exchange
## (drives the chrome numbers); `map_shot` is the battle viewport captured just
## before the popup opens (becomes the washed backdrop, FE field-battle style).
func play_exchange(attacker: Unit, defender: Unit, strikes: Array,
		exchange: Dictionary = {}, map_shot: Texture2D = null) -> void:
	_backdrop.texture = map_shot
	_left_sprite.sprite_frames = load_kit(attacker.unit_id())
	_right_sprite.sprite_frames = load_kit(defender.unit_id())
	for spr in [_left_sprite, _right_sprite]:
		_apply_strike_timing(spr.sprite_frames)
		var h := _kit_frame_height(spr.sprite_frames)
		spr.scale = Vector2.ONE * clampf(TARGET_BATTLER_PX / h, 3.0, 7.0)
	_build_chrome(attacker, defender, exchange)
	_left_sprite.play("idle")
	_right_sprite.play("idle")
	_root.visible = true
	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.18)
	await tw.finished

	for strike in strikes:
		await _play_strike(strike)
		await get_tree().create_timer(0.28).timeout

	await get_tree().create_timer(0.4).timeout
	var out := create_tween()
	out.tween_property(_root, "modulate:a", 0.0, 0.16)
	await out.finished
	_root.visible = false
	for s in [_left_sprite, _right_sprite]:
		s.modulate.a = 1.0
		(s.material as ShaderMaterial).set_shader_parameter("flash", 0.0)


func _kit_frame_height(frames: SpriteFrames) -> float:
	var tex := frames.get_frame_texture("idle", 0) if frames.has_animation("idle") else null
	return float(tex.get_height()) if tex != null else 32.0


## The GBA feel is in the TIMING, not just the frames: attack/crit anims hold
## their wind-up (anticipation), snap through the strike window, and ease the
## follow-through. Applied per-frame via relative durations.
func _apply_strike_timing(frames: SpriteFrames) -> void:
	for anim in ["attack", "crit"]:
		if not frames.has_animation(anim):
			continue
		var n := frames.get_frame_count(anim)
		for i in range(n):
			var f := float(i) / maxf(n - 1, 1.0)
			var dur := 1.0
			if f < 0.35:
				dur = 1.7    # coiled wind-up: hold it
			elif f < 0.65:
				dur = 0.45   # the strike itself: near-instant
			frames.set_frame(anim, i, frames.get_frame_texture(anim, i), dur)


## Afterimage ghosts trailing a dashing battler (Lyn's blur-dash read).
func _ghost_trail(actor: AnimatedSprite2D, holder: Control, count: int) -> void:
	for i in range(count):
		var tex := actor.sprite_frames.get_frame_texture(actor.animation, actor.frame)
		var ghost := Sprite2D.new()
		ghost.texture = tex
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ghost.scale = actor.scale
		ghost.flip_h = actor.flip_h
		ghost.position = holder.position
		ghost.modulate = Color(0.7, 0.85, 1.0, 0.45)
		_root.add_child(ghost)
		var tw := create_tween()
		tw.tween_property(ghost, "modulate:a", 0.0, 0.28)
		tw.tween_callback(ghost.queue_free)
		await get_tree().create_timer(0.05).timeout


## One strike, GBA style: run in, land the blow mid-swing (starburst, flash,
## knockback, shake, HP drain), run back. Crits use the class "crit" anim,
## flash the whole screen, and shake harder. Deaths dissolve to white.
func _play_strike(strike) -> void:
	var striker_left: bool = not strike.is_counter
	var actor := _left_sprite if striker_left else _right_sprite
	var actor_holder := _left_holder if striker_left else _right_holder
	var target := _right_sprite if striker_left else _left_sprite
	var target_holder := _right_holder if striker_left else _left_holder
	var target_bar := _right_hp if striker_left else _left_hp
	var dir := 1.0 if striker_left else -1.0
	var home := actor_holder.position
	var contact := Vector2(target_holder.position.x - dir * 120.0, home.y)
	var anim := "crit" if strike.was_crit and actor.sprite_frames.has_animation("crit") else "attack"
	var swing := actor.sprite_frames.get_frame_count(anim) / FPS

	# crits stage themselves: a beat of stillness, then a BLUR dash
	if strike.was_crit:
		_flash_sprite(actor, 0.5, 0.35)
		await get_tree().create_timer(0.3).timeout
	var run := create_tween()
	run.tween_property(actor_holder, "position", contact, 0.13 if strike.was_crit else 0.20) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_ghost_trail(actor, actor_holder, 4 if strike.was_crit else 2)
	await run.finished
	actor.play(anim)
	# impact lands where the strike window begins (the timing curve holds the
	# wind-up, so real time to impact stays roughly proportional)
	await get_tree().create_timer(maxf(swing * 0.62, 0.18)).timeout

	var impact_pos: Vector2 = _root.size * 0.5 + Vector2(target_holder.position.x - dir * 40.0,
		target_holder.position.y - 40.0)
	if strike.connected:
		var lethal: bool = strike.defender_hp_after <= 0
		target.play("ko" if lethal and target.sprite_frames.has_animation("ko") else "hit")
		_burst(impact_pos, strike.was_crit)
		_flash_sprite(target, 0.85, 0.3)
		_knockback(target_holder, dir)
		_shake(0.5 if strike.was_crit else 0.2)
		if strike.was_crit:
			_screen_flash()
		if target_bar != null:
			var drain := create_tween()
			drain.tween_property(target_bar, "shown_hp", float(strike.defender_hp_after), 0.4) \
				.set_trans(Tween.TRANS_SINE)
		if lethal:
			# white-silhouette dissolve, FE death style
			var mat := target.material as ShaderMaterial
			var die := create_tween()
			die.tween_method(func(v): mat.set_shader_parameter("flash", v), 0.0, 1.0, 0.35) \
				.set_delay(0.3)
			die.tween_property(target, "modulate:a", 0.0, 0.6)
	else:
		# dodge: quick slide away + MISS
		_knockback(target_holder, dir * 1.6)
		_miss_label.position = Vector2(target_holder.position.x - 34.0,
			target_holder.position.y - 120.0)
		_miss_label.visible = true
		_miss_label.scale = Vector2.ONE * 1.6
		_miss_label.pivot_offset = _miss_label.size / 2.0
		var mt := create_tween()
		mt.tween_property(_miss_label, "scale", Vector2.ONE, 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		mt.tween_interval(0.4)
		mt.tween_callback(func(): _miss_label.visible = false)

	await actor.animation_finished
	actor.play("idle")
	var back := create_tween()
	back.tween_property(actor_holder, "position", home, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await back.finished
	if strike.connected and strike.defender_hp_after > 0 and target.animation != "idle":
		target.play("idle")


# --- effects --------------------------------------------------------------------

func _flash_sprite(sprite: AnimatedSprite2D, strength: float, time: float) -> void:
	var mat := sprite.material as ShaderMaterial
	mat.set_shader_parameter("flash", strength)
	var tw := create_tween()
	tw.tween_method(func(v): mat.set_shader_parameter("flash", v), strength, 0.0, time)


func _knockback(holder: Control, dir: float) -> void:
	var home := holder.position
	var tw := create_tween()
	tw.tween_property(holder, "position:x", home.x + dir * 22.0, 0.07)
	tw.tween_property(holder, "position:x", home.x, 0.18)


func _shake(strength: float) -> void:
	var tw := create_tween()
	for i in range(6):
		var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 30.0 * strength
		tw.tween_property(_root, "position", off, 0.03)
	tw.tween_property(_root, "position", Vector2.ZERO, 0.05)


func _screen_flash() -> void:
	_crit_flash.color = Color(1, 1, 1, 0.85)
	var tw := create_tween()
	tw.tween_property(_crit_flash, "color:a", 0.0, 0.28)


func _burst(pos: Vector2, big: bool) -> void:
	_bursts.append({"pos": pos, "age": 0.0, "life": 0.30 if big else 0.22, "big": big})
	_fx.queue_redraw()


func _process(delta: float) -> void:
	if _bursts.is_empty():
		return
	for b in _bursts:
		b["age"] += delta
	_bursts = _bursts.filter(func(b): return b["age"] < b["life"])
	_fx.queue_redraw()


func _draw_fx() -> void:
	for b in _bursts:
		var t: float = b["age"] / b["life"]
		var pos: Vector2 = b["pos"]
		var r := (34.0 + t * 46.0) * (1.6 if b["big"] else 1.0)
		var alpha := (1.0 - t)
		# radiating slash spokes + a thin expanding ring
		for i in range(8):
			var ang := TAU * i / 8.0 + (0.4 if b["big"] else 0.0)
			var inner := pos + Vector2.from_angle(ang) * r * 0.35
			var outer := pos + Vector2.from_angle(ang) * r
			_fx.draw_line(inner, outer, Color(1, 1, 0.92, alpha), 4.0 if b["big"] else 3.0)
		_fx.draw_arc(pos, r * 0.75, 0, TAU, 24, Color(1, 1, 0.85, alpha * 0.8), 2.5)
