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
## The *_wind/*_strike pairs are chained two-part choreography: the strike
## segment's first frame IS the wind-up's last, and the seam between them is
## the exact impact moment (all hit effects fire there at once).
const KIT_EXTRA_ANIMS := ["crit", "attack_wind", "attack_strike",
	"crit_wind", "crit_strike"]
## Generic enemy unit ids share one design's kit (mirrors the walk-frame
## promotion mapping).
const KIT_ALIASES := {
	"tm_soldier_a": "tm_soldier", "tm_soldier_b": "tm_soldier",
	"tm_guard": "tm_soldier", "tm_scout": "tm_soldier",
	"tm_armor": "tm_knight", "tm_adept": "tm_mage",
	"tide_a": "tm_soldier", "tide_b": "tm_soldier",
	"bandit_a": "bandit", "bandit_b": "bandit", "bandit_c": "bandit",
	"bandit_d": "bandit", "bandit_boss": "bandit",
	"serra_prologue": "serra",  # same character, prologue instance
}
## Battlers aim for ~45% of screen height (GBA proportion) regardless of
## the kit's native resolution (32px map-scale kits vs 64px+ battle kits).
const TARGET_BATTLER_PX := 385.0
const FPS := 10.0
## Strike animations play hot — GBA attacks resolve in about a second.
const STRIKE_FPS := 14.0

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
## The DEFENDER's terrain tile (set by the executor per exchange) — picks the
## battle-scene background, FE style: fight on a forest tile, get the forest.
var stage_terrain: int = Terrain.Type.PLAINS

const BG_DIR := "res://assets/art/pixellab/battle_bgs"
const BG_FOR_TERRAIN := {
	Terrain.Type.PLAINS: "bg_plains", Terrain.Type.FLOWERS: "bg_plains",
	Terrain.Type.PATH: "bg_plains", Terrain.Type.FOREST: "bg_forest",
	Terrain.Type.MOUNTAIN: "bg_mountain", Terrain.Type.WATER: "bg_river",
	Terrain.Type.FORT: "bg_fort", Terrain.Type.WALL: "bg_fort",
	Terrain.Type.FLOOR: "bg_hall", Terrain.Type.CARPET: "bg_hall",
	Terrain.Type.PILLAR: "bg_hall", Terrain.Type.SPRING: "bg_plains",
	Terrain.Type.SITE: "bg_village",
}
## Screen-space y of the scene ground line battlers stand on.
const GROUND_FRAC := 0.72

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
## Projectile style per side for this exchange: "" melee, "arrow" bow, "magic"
## tome. Ranged attackers don't run in — they loose/cast from where they stand.
var _left_proj := ""
var _right_proj := ""
## Attacker XP readout, filled after the blow lands (playtest 3).
var _xp_panel: Control
var _xp_shown := 0.0
var _xp_gain := 0
var _xp_leveled := false

# chrome rebuilt per exchange
var _chrome: Control
var _wash: ColorRect
var _platform: Control


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
		frames.set_animation_speed(anim, STRIKE_FPS if anim in ["attack", "crit"] else FPS)
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
	_wash = ColorRect.new()
	_wash.color = Color(0.93, 0.92, 0.86, 0.42)
	_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_wash)
	# diorama platform: tiled terrain top + shaded lip (FE pedestal) — only
	# shown for the washed-map fallback; scene backgrounds carry their own ground
	_platform = Control.new()
	_platform.set_anchors_preset(Control.PRESET_CENTER)
	_platform.draw.connect(_draw_platform.bind(_platform))
	_platform.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_root.add_child(_platform)
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
	# attacker XP bar (filled after the blow)
	_xp_panel = Control.new()
	_xp_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_xp_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_panel.draw.connect(_draw_xp_panel)
	_xp_panel.visible = false
	_root.add_child(_xp_panel)


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
## Common staging for both attack and heal cut-ins: pick the scene backdrop by
## `stage_terrain`, load both battlers, scale and plant their feet on the ground
## line. Returns whether a painted scene background was used (vs the washed map).
func _stage_battlers(left_id: String, right_id: String, map_shot: Texture2D, gap := 190.0) -> bool:
	var bg_name: String = BG_FOR_TERRAIN.get(stage_terrain, "bg_plains")
	var bg_path := "%s/%s.png" % [BG_DIR, bg_name]
	var scene_bg := ResourceLoader.exists(bg_path)
	_backdrop.texture = load(bg_path) if scene_bg else map_shot
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_wash.visible = not scene_bg
	_platform.visible = not scene_bg
	_left_sprite.sprite_frames = load_kit(left_id)
	_right_sprite.sprite_frames = load_kit(right_id)
	# NOTE: Control.position set at runtime is ABSOLUTE (from the parent's
	# top-left) — unlike the _ready-time values, which float with the center
	# anchor because the parent had no size yet. Everything here is absolute.
	for i2 in range(2):
		var spr: AnimatedSprite2D = [_left_sprite, _right_sprite][i2]
		var holder: Control = [_left_holder, _right_holder][i2]
		_apply_strike_timing(spr.sprite_frames)
		var frame_h := _kit_frame_height(spr.sprite_frames)
		# scale by the STANDING FIGURE's height, not the frame — kit frames are
		# cropped to the union of all anims, so a tall crit (Wren's light pillar)
		# inflates the canvas and would shrink the idle figure. Every battler now
		# reads at the same on-screen size.
		var b := _idle_bounds(spr.sprite_frames)
		var content_h: float = maxf(b.y - b.x, 8.0)
		var sc := clampf(TARGET_BATTLER_PX / content_h, 1.0, 9.0)
		spr.scale = Vector2.ONE * sc
		var x := _root.size.x * 0.5 + (-gap if i2 == 0 else gap)
		# plant the figure's FEET (content bottom) on the scene's ground line
		var feet_off: float = b.y - frame_h * 0.5   # feet offset from frame center
		holder.position = Vector2(x, _ground_line(scene_bg) - feet_off * sc)
	return scene_bg


## Where battler feet sit, in screen y. Scene backgrounds have their floor line
## at a per-terrain fraction (indoor floors sit lower than field horizons — the
## castle "floating" fix); the washed-map platform plants them near center.
func _ground_line(scene_bg: bool) -> float:
	if not scene_bg:
		return _root.size.y * 0.5 + 58.0
	var frac := GROUND_FRAC
	match BG_FOR_TERRAIN.get(stage_terrain, "bg_plains"):
		"bg_hall": frac = 0.82
		"bg_fort": frac = 0.80
	return _root.size.y * frac


## Projectile/advance style for a unit: bows loose an arrow, tomes hurl a bolt,
## everything else closes to melee. Ranged styles suppress the run-in.
func _proj_style(u: Unit) -> String:
	var w := u.weapon()
	if w == null:
		return ""
	if w.weapon_type == WeaponDef.WeaponType.TOME:
		return "magic"
	if w.weapon_type == WeaponDef.WeaponType.BOW:
		return "arrow"
	return ""


## The idle figure's vertical content bounds within the frame: Vector2(top,
## bottom_exclusive) of non-transparent rows. Used to size + plant battlers.
func _idle_bounds(frames: SpriteFrames) -> Vector2:
	if not frames.has_animation("idle"):
		return Vector2(0, 32)
	var img := frames.get_frame_texture("idle", 0).get_image()
	var top := -1
	var bottom := 0
	for y in range(img.get_height()):
		var solid := false
		for x in range(0, img.get_width(), 2):
			if img.get_pixel(x, y).a > 0.1:
				solid = true
				break
		if solid:
			if top < 0:
				top = y
			bottom = y
	if top < 0:
		return Vector2(0, float(img.get_height()))
	return Vector2(top, bottom + 1)


## before the popup opens (becomes the washed backdrop, FE field-battle style).
func play_exchange(attacker: Unit, defender: Unit, strikes: Array,
		exchange: Dictionary = {}, map_shot: Texture2D = null, dist: int = 1,
		xp_from: int = 0, xp_gain: int = 0) -> void:
	_left_proj = _proj_style(attacker)
	_right_proj = _proj_style(defender)
	_xp_gain = xp_gain
	_xp_leveled = false
	_xp_shown = float(xp_from % 100)
	_xp_panel.visible = false
	# a range-2 clash stands the fighters farther apart (Neal: show the distance)
	var gap := 300.0 if dist >= 2 else 190.0
	var scene_bg := _stage_battlers(attacker.unit_id(), defender.unit_id(), map_shot, gap)
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

	# XP earned: fill the attacker's bar right here in the popup (Neal's ask)
	if _xp_gain > 0:
		_xp_panel.visible = true
		_xp_panel.queue_redraw()
		await get_tree().create_timer(0.25).timeout
		var target := _xp_shown + float(_xp_gain)
		var fill := create_tween()
		fill.tween_property(self, "_xp_shown", target, 0.55).set_trans(Tween.TRANS_SINE)
		await fill.finished
		if target >= 100.0:
			_xp_leveled = true
			_screen_flash(0.5)
			_xp_panel.queue_redraw()
			await get_tree().create_timer(0.5).timeout

	await get_tree().create_timer(0.4).timeout
	var out := create_tween()
	out.tween_property(_root, "modulate:a", 0.0, 0.16)
	await out.finished
	_root.visible = false
	_xp_panel.visible = false
	for s in [_left_sprite, _right_sprite]:
		s.modulate.a = 1.0
		(s.material as ShaderMaterial).set_shader_parameter("flash", 0.0)


## Heal cut-in (playtest 3: staves deserve a scene too, FE-style). Healer on the
## left raises the staff; a green light crosses to the ally on the right, who is
## bathed in it as their HP bar refills. `hp_before` is the ally's HP prior to
## the heal being applied (the bar fills from there to their current HP).
func play_heal(healer: Unit, ally: Unit, hp_before: int, map_shot: Texture2D = null) -> void:
	_left_proj = ""
	_right_proj = ""
	var scene_bg := _stage_battlers(healer.unit_id(), ally.unit_id(), map_shot)
	_build_heal_chrome(healer, ally, hp_before)
	_left_sprite.play("idle")
	_right_sprite.play("idle")
	_root.visible = true
	_root.modulate.a = 0.0
	var tin := create_tween()
	tin.tween_property(_root, "modulate:a", 1.0, 0.18)
	await tin.finished
	# the healer raises the staff — a lift and a soft glint
	_flash_sprite(_left_sprite, 0.55, 0.45)
	var home_y := _left_holder.position.y
	var lift := create_tween()
	lift.tween_property(_left_holder, "position:y", home_y - 26.0, 0.24).set_trans(Tween.TRANS_SINE)
	lift.tween_property(_left_holder, "position:y", home_y, 0.24).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.42).timeout
	# green light blooms over the ally
	await _heal_glow(_right_holder.position)
	_ally_heal_flash(_right_sprite)
	_shake(0.12)
	if _right_hp != null:
		var fill := create_tween()
		fill.tween_property(_right_hp, "shown_hp", float(ally.current_hp), 0.5).set_trans(Tween.TRANS_SINE)
	var bob := create_tween()
	var ay := _right_holder.position.y
	bob.tween_property(_right_holder, "position:y", ay - 16.0, 0.18).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_right_holder, "position:y", ay, 0.2).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.75).timeout
	var out := create_tween()
	out.tween_property(_root, "modulate:a", 0.0, 0.16)
	await out.finished
	_root.visible = false
	for s in [_left_sprite, _right_sprite]:
		s.modulate = Color(1, 1, 1, 1)
		(s.material as ShaderMaterial).set_shader_parameter("flash", 0.0)


func _build_heal_chrome(healer: Unit, ally: Unit, hp_before: int) -> void:
	for c in _chrome.get_children():
		c.queue_free()
	_left_hp = null
	_right_hp = null
	var vp := _root.size
	var lc := _team_colors(healer)
	var rc := _team_colors(ally)
	_framed_panel(_chrome, Rect2(26, 22, 240, 40), lc[0], TRIM)
	_panel_label(_chrome, Vector2(26, 28), healer.unit_def.display_name, 20, Color(0.98, 0.96, 0.9), 240)
	_framed_panel(_chrome, Rect2(vp.x - 266, 22, 240, 40), rc[0], TRIM)
	_panel_label(_chrome, Vector2(vp.x - 266, 28), ally.unit_def.display_name, 20, Color(0.98, 0.96, 0.9), 240)
	# staff plate under the healer
	var wname := healer.weapon().display_name if healer.weapon() != null else "Staff"
	_framed_panel(_chrome, Rect2(26, vp.y - 72, 240, 40), Color(0.11, 0.30, 0.16, 0.96), TRIM)
	_panel_label(_chrome, Vector2(26, vp.y - 66), wname, 18, Color(0.72, 1.0, 0.78), 240)
	# the ally's HP trough (fills during the cast)
	var bar := BattlePopupHPBar.new()
	bar.max_hp = ally.max_hp()
	bar.shown_hp = float(hp_before)
	bar.position = Vector2(vp.x - 266, vp.y - 68)
	bar.size = Vector2(220, 48)
	_chrome.add_child(bar)
	_right_hp = bar


## Expanding green rings + rising motes over a point — the staff's blessing.
## Rides the same aged-burst pipeline as strike VFX (see _draw_fx / _process).
func _heal_glow(pos: Vector2) -> void:
	_bursts.append({"pos": pos, "age": 0.0, "life": 0.6, "big": false, "kind": "heal"})
	_fx.queue_redraw()
	await get_tree().create_timer(0.55).timeout


func _ally_heal_flash(spr: AnimatedSprite2D) -> void:
	spr.modulate = Color(0.5, 1.0, 0.62)
	var tw := create_tween()
	tw.tween_property(spr, "modulate", Color(1, 1, 1, 1), 0.6).set_trans(Tween.TRANS_SINE)


## Real playback time of an animation with per-frame durations applied.
func _swing_time(frames: SpriteFrames, anim: String) -> float:
	var fps := frames.get_animation_speed(anim)
	var total := 0.0
	for i in range(frames.get_frame_count(anim)):
		total += frames.get_frame_duration(anim, i) / fps
	return total


func _kit_frame_height(frames: SpriteFrames) -> float:
	var tex := frames.get_frame_texture("idle", 0) if frames.has_animation("idle") else null
	return float(tex.get_height()) if tex != null else 32.0


## Empty margin (px) between the idle stance's feet and the frame bottom.
## Kit frames are cropped to the union of ALL animations, so a standing pose
## usually has dead space under it — without this the battler floats.
func _kit_ground_gap(frames: SpriteFrames) -> float:
	if not frames.has_animation("idle"):
		return 0.0
	var img := frames.get_frame_texture("idle", 0).get_image()
	for y in range(img.get_height() - 1, -1, -1):
		for x in range(0, img.get_width(), 2):
			if img.get_pixel(x, y).a > 0.1:
				return float(img.get_height() - 1 - y)
	return 0.0


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
			if f < 0.3:
				dur = 1.2    # a breath of tension, not slow motion
			elif f < 0.6:
				dur = 0.75   # accelerating...
			else:
				dur = 0.45   # ...into the strike: near-instant
			frames.set_frame(anim, i, frames.get_frame_texture(anim, i), dur)
	# chained pairs: the wind-up accelerates into the seam; the strike segment
	# IS the impact and plays hot from its first frame
	for anim in ["attack_wind", "crit_wind"]:
		if not frames.has_animation(anim):
			continue
		var n2 := frames.get_frame_count(anim)
		for i in range(n2):
			var f2 := float(i) / maxf(n2 - 1, 1.0)
			frames.set_frame(anim, i, frames.get_frame_texture(anim, i),
				1.15 if f2 < 0.5 else 0.7)
	for anim in ["attack_strike", "crit_strike"]:
		if not frames.has_animation(anim):
			continue
		for i in range(frames.get_frame_count(anim)):
			frames.set_frame(anim, i, frames.get_frame_texture(anim, i), 0.7)


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
	var proj := _left_proj if striker_left else _right_proj  # "" melee, else ranged
	var home := actor_holder.position
	# melee closes in; ranged (bow/tome) looses from where it stands (Neal: mages
	# shouldn't run forward — they're not melee)
	var contact := home if proj != "" else Vector2(target_holder.position.x - dir * 120.0, home.y)
	var base := "crit" if strike.was_crit and actor.sprite_frames.has_animation("crit") else "attack"
	# chained two-part choreography when the kit has it: the seam between
	# wind-up and strike segments is the exact impact frame
	var paired: bool = actor.sprite_frames.has_animation(base + "_wind") \
		and actor.sprite_frames.has_animation(base + "_strike")
	var anim := (base + "_wind") if paired else base
	var swing := _swing_time(actor.sprite_frames, anim)

	# crits stage themselves: a beat of stillness, then a BLUR dash
	if strike.was_crit:
		_flash_sprite(actor, 0.5, 0.35)
		await get_tree().create_timer(0.3).timeout
	var run := create_tween()
	run.tween_property(actor_holder, "position", contact, 0.10 if strike.was_crit else 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if proj == "":
		_ghost_trail(actor, actor_holder, 4 if strike.was_crit else 2)
	await run.finished
	actor.play(anim)
	if strike.was_crit and not paired and proj == "":
		# over-the-top: the crit rides an aerial arc onto the target
		var arc := create_tween()
		arc.tween_property(actor_holder, "position:y", contact.y - 110.0, 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		arc.tween_property(actor_holder, "position:y", contact.y, 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_ghost_trail(actor, actor_holder, 5)
	if paired:
		# the wind-up runs to its final frame; impact fires AT the seam
		await actor.animation_finished
		actor.play(base + "_strike")
	else:
		# single-segment kits: impact lands late in the swing
		await get_tree().create_timer(maxf(swing * 0.78, 0.18)).timeout

	var impact_pos := Vector2(target_holder.position.x - dir * 40.0,
		target_holder.position.y - 40.0)
	# ranged: the arrow/bolt crosses the gap and lands the hit on arrival
	if proj != "":
		_projectile(actor_holder.position + Vector2(dir * 70.0, -46.0), impact_pos, dir, proj)
		await get_tree().create_timer(0.16).timeout
	if strike.connected:
		var lethal: bool = strike.defender_hp_after <= 0
		target.play("ko" if lethal and target.sprite_frames.has_animation("ko") else "hit")
		_burst(impact_pos, strike.was_crit)
		_slash_arc(impact_pos, dir, strike.was_crit)
		_screen_flash(0.9 if strike.was_crit else 0.4)
		# hit-stop: the whole scene bites for a beat (GBA crunch)
		actor.pause()
		target.pause()
		await get_tree().create_timer(0.14 if strike.was_crit else 0.09).timeout
		actor.play()
		target.play()
		_flash_sprite(target, 1.0, 0.32)
		_knockback(target_holder, dir)
		_shake(0.6 if strike.was_crit else 0.32)
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

	# Projectile travel and the impact delay can outlast a short animation.
	# A finished one-shot will not emit animation_finished again.
	if actor.is_playing():
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
	tw.tween_property(holder, "position:x", home.x + dir * 42.0, 0.05)
	tw.tween_property(holder, "position:x", home.x, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _shake(strength: float) -> void:
	var tw := create_tween()
	for i in range(6):
		var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 30.0 * strength
		tw.tween_property(_root, "position", off, 0.03)
	tw.tween_property(_root, "position", Vector2.ZERO, 0.05)


func _screen_flash(strength := 0.85) -> void:
	_crit_flash.color = Color(1, 1, 1, strength)
	var tw := create_tween()
	tw.tween_property(_crit_flash, "color:a", 0.0, 0.22 + strength * 0.1)


func _burst(pos: Vector2, big: bool) -> void:
	_bursts.append({"pos": pos, "age": 0.0, "life": 0.30 if big else 0.22, "big": big,
		"kind": "burst"})
	_fx.queue_redraw()


## A flying arrow or magic bolt crossing from a ranged attacker to the target.
func _projectile(from: Vector2, to: Vector2, dir: float, style: String) -> void:
	_bursts.append({"pos": from, "to": to, "age": 0.0, "life": 0.18, "big": false,
		"kind": "proj", "style": style, "dir": dir})
	_fx.queue_redraw()


## The sweeping blade-arc light that follows a strike (the Lyn slash read).
func _slash_arc(pos: Vector2, dir: float, big: bool) -> void:
	_bursts.append({"pos": pos, "age": 0.0, "life": 0.26 if big else 0.2, "big": big,
		"kind": "slash", "dir": dir})
	_fx.queue_redraw()


func _process(delta: float) -> void:
	if _xp_panel != null and _xp_panel.visible:
		_xp_panel.queue_redraw()
	if _bursts.is_empty():
		return
	for b in _bursts:
		b["age"] += delta
	_bursts = _bursts.filter(func(b): return b["age"] < b["life"])
	_fx.queue_redraw()


## The attacker's XP bar (bottom-left, above the weapon plate), filling after a
## connected/killing blow with a "+N" and a level-up flash on wrap.
func _draw_xp_panel() -> void:
	var vp := _root.size
	var x := 26.0
	var y := vp.y - 182.0
	_xp_panel.draw_rect(Rect2(x, y, 340, 28), Color(0.08, 0.09, 0.13, 0.95), true)
	_xp_panel.draw_rect(Rect2(x, y, 340, 28), TRIM, false, 2.0)
	var font := ThemeDB.fallback_font
	_xp_panel.draw_string(font, Vector2(x + 10, y + 20), "XP", HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
		Color(0.95, 0.9, 0.55))
	var bx := x + 46
	var shown := _xp_shown if _xp_shown < 100.0 else _xp_shown - 100.0
	_xp_panel.draw_rect(Rect2(bx, y + 8, 236, 13), Color(0.15, 0.13, 0.05), true)
	_xp_panel.draw_rect(Rect2(bx, y + 8, 236 * clampf(shown / 100.0, 0.0, 1.0), 13),
		Color(0.95, 0.82, 0.35), true)
	if _xp_leveled:
		_xp_panel.draw_string(font, Vector2(x + 292, y + 20), "LEVEL UP!",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 1.0, 0.6))
	elif _xp_gain > 0:
		_xp_panel.draw_string(font, Vector2(x + 292, y + 20), "+%d" % _xp_gain,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 1.0, 0.6))


func _draw_fx() -> void:
	for b in _bursts:
		var t: float = b["age"] / b["life"]
		var pos: Vector2 = b["pos"]
		var alpha := (1.0 - t)
		if b.get("kind", "burst") == "proj":
			var to: Vector2 = b["to"]
			var cur := pos.lerp(to, t)
			if b["style"] == "magic":
				_fx.draw_circle(cur, 11.0, Color(0.55, 0.35, 0.95, 0.9))
				_fx.draw_circle(cur, 6.0, Color(0.85, 0.75, 1.0, 1.0))
				_fx.draw_circle(cur - (to - pos).normalized() * 16.0, 6.0, Color(0.55, 0.35, 0.95, 0.4))
			else:  # arrow: a streak with a head
				var d: float = b["dir"]
				var tail := cur - Vector2(d * 34.0, 0)
				_fx.draw_line(tail, cur, Color(0.95, 0.92, 0.8, 0.95), 3.0)
				_fx.draw_line(cur, cur - Vector2(d * 9.0, 5.0), Color(0.8, 0.78, 0.7, 0.95), 3.0)
				_fx.draw_line(cur, cur - Vector2(d * 9.0, -5.0), Color(0.8, 0.78, 0.7, 0.95), 3.0)
			continue
		if b.get("kind", "burst") == "heal":
			# expanding green blessing rings + motes drifting up off the ally
			for k in range(3):
				var rr := 22.0 + t * 96.0 + k * 20.0
				_fx.draw_arc(pos, rr, 0.0, TAU, 40, Color(0.42, 1.0, 0.56, alpha * 0.7), 4.0)
			for m in range(8):
				var mp := pos + Vector2.from_angle(TAU * m / 8.0) * (t * 64.0) \
					- Vector2(0, t * 46.0)
				_fx.draw_circle(mp, 5.0 * (1.0 - t), Color(0.72, 1.0, 0.74, alpha))
			continue
		if b.get("kind", "burst") == "slash":
			# a crescent of 3 sweeping arcs slicing through the impact point,
			# rotating with age — reads as the blade's afterglow
			var dir: float = b["dir"]
			var base_ang := (-0.6 if dir > 0 else PI + 0.6) + t * 1.6 * dir
			for j in range(3):
				var rr := (52.0 + j * 16.0) * (1.5 if b["big"] else 1.0)
				_fx.draw_arc(pos, rr, base_ang - 0.9, base_ang + 0.9, 18,
					Color(1, 1, 0.9, alpha * (1.0 - j * 0.25)),
					(6.0 - j * 1.5) * (1.4 if b["big"] else 1.0))
			continue
		var r := (34.0 + t * 46.0) * (1.6 if b["big"] else 1.0)
		# radiating slash spokes + a thin expanding ring
		for i in range(8):
			var ang := TAU * i / 8.0 + (0.4 if b["big"] else 0.0)
			var inner := pos + Vector2.from_angle(ang) * r * 0.35
			var outer := pos + Vector2.from_angle(ang) * r
			_fx.draw_line(inner, outer, Color(1, 1, 0.92, alpha), 4.0 if b["big"] else 3.0)
		_fx.draw_arc(pos, r * 0.75, 0, TAU, 24, Color(1, 1, 0.85, alpha * 0.8), 2.5)
