class_name Unit
extends Node2D
## A unit on the battle map. Presentation node: draws a placeholder token
## (team-ring disc + class letter + HP bar, §8 programmer art), animates movement,
## and gives simple hit/miss/crit feedback (placeholder for WO-2.5 juice). Game
## rules live in the pure combat/pathfinding classes; this node holds board state
## and renders.

const MOVE_SPEED_PX := 640.0  # pixels/sec along the path
const PLAYER_COLOR := Color(0.30, 0.55, 0.95)
const ENEMY_COLOR := Color(0.90, 0.32, 0.30)

signal move_finished

@export var unit_def: UnitDef

var cell: Vector2i
var team: int = 0
var current_hp: int = 1
var has_acted: bool = false
var level: int = 1
var xp: int = 0
var inventory := Inventory.new()
## Sentinels start asleep and wake when a player enters their threat range (§5).
## Aggressors and bosses are always "awake".
var ai_awake := true
## Set on promotion (WO-2.4) so the shared UnitDef resource stays immutable.
var _class_override: ClassDef = null
var _move_bonus := 0

# Permanent stat gains from level-ups, added on top of the UnitDef base. Keeps the
# shared UnitDef resource immutable while stats grow per-instance.
var _stat_bonus := {"hp": 0, "str": 0, "mag": 0, "skl": 0, "spd": 0, "lck": 0, "def": 0, "res": 0}

# AW-27: transient aura bonuses projected onto this unit by nearby allies' aura
# skills. Recomputed from live positions by battle_view._recompute_auras before
# any Combatant is built; never saved. Stat auras fold into stat(); combat auras
# ride the support-bonus channel via aura_combat_bonus().
var _aura_stat := {}
var _aura_combat := {"hit": 0, "avoid": 0, "damage": 0, "crit": 0}

# UnitDef field name for each stat key.
const _STAT_FIELD := {
	"hp": "max_hp", "str": "strength", "mag": "magic", "skl": "skill",
	"spd": "speed", "lck": "luck", "def": "defense", "res": "resistance",
}

var _grid: Grid
var _moving := false
var _flash := 0.0
## WO-4.7: whether dedicated north/south walk frame sets were found.
var _has_walk_n := false
var _has_walk_s := false
## WO-4.8: outfit/context variant. Frames load from
## `assets/sprites/units/<id>/<variant>/` when that set exists, falling back
## to the legacy root frames (the battle kit). Battles use the default;
## hub/castle scenes set school/casual/party per context.
var sprite_variant := "battle"
## Painted standee (AW-6 hook): drawn instead of the placeholder token when
## `assets/standees/standee_<id>.png` exists. Pure presentation.
var _standee: Texture2D = null
## Animated pixel sprite (AW-7): built from `assets/sprites/units/<id>/walk_f*.png`
## when present — supersedes both the token and the standee. Pure presentation.
var _anim: AnimatedSprite2D = null

## AW-33: hover idle — the unit perks up (breathing bob) and shows a signature
## gleam in its own colour while the cursor rests on it. Pure presentation.
var _hovered := false
var _hover_phase := 0.0
var _idle_tween: Tween
var _anim_base_pos := Vector2.ZERO
var _anim_base_scale := Vector2.ONE


func setup(def: UnitDef, grid: Grid, start_cell: Vector2i) -> void:
	unit_def = def
	team = def.team if def != null else 0
	level = def.level if def != null else 1
	xp = 0
	current_hp = def.max_hp if def != null else 1
	if def != null:
		var weapons: Array = [def.weapon]
		weapons.append_array(def.extra_weapons)
		inventory = Inventory.from_starting(weapons, def.starting_items)
		ai_awake = def.ai_behavior != AIBrain.Behavior.SENTINEL
	_grid = grid
	cell = start_cell
	position = _grid.cell_center(cell)
	_standee = null
	if def != null and def.id != "":
		var standee_path := "res://assets/standees/standee_%s.png" % sprite_id()
		if ResourceLoader.exists(standee_path):
			_standee = load(standee_path)
			texture_filter = TEXTURE_FILTER_LINEAR  # painted art, not pixel art
	_setup_sprite_frames(sprite_id() if def != null else "")
	queue_redraw()


## WO-4.7: scan conventional walk frame sets for a unit sprite dir.
## Returns {"walk": [paths...], "walk_n": [...], "walk_s": [...]} — east set
## under "walk" (any frame count, walk_f1..fN), north/south optional
## (walk_n_f*/walk_s_f*). Empty arrays for missing sets.
static func scan_walk_frames(dir: String) -> Dictionary:
	var sets := {"walk": "walk_f", "walk_n": "walk_n_f", "walk_s": "walk_s_f"}
	var out := {}
	for anim in sets:
		var paths: Array[String] = []
		var i := 1
		while ResourceLoader.exists("%s/%s%d.png" % [dir, sets[anim], i]):
			paths.append("%s/%s%d.png" % [dir, sets[anim], i])
			i += 1
		out[anim] = paths
	return out


## WO-4.7: the two "passing" poses of an N-frame walk cycle (1-based indices)
## for the idle bob. N=4 keeps the original f2/f4 behavior.
static func idle_frame_indices(n: int) -> Array[int]:
	if n <= 1:
		return [1, 1]
	return [int(ceil(n / 2.0)), n]


## WO-4.8: resolve the frame directory for a unit id + variant. A variant
## subdir wins when it holds frames; the unit root is the battle-kit default.
static func resolve_sprite_dir(id: String, variant: String) -> String:
	var root := "res://assets/sprites/units/%s" % id
	if variant != "" and variant != "battle":
		var vdir := "%s/%s" % [root, variant]
		if ResourceLoader.exists(vdir + "/walk_f1.png"):
			return vdir
	return root


## WO-4.8: switch outfit/context variant and rebuild the sprite frames.
func set_sprite_variant(variant: String) -> void:
	if variant == sprite_variant:
		return
	sprite_variant = variant
	_setup_sprite_frames(sprite_id() if unit_def != null else "")


## AW-7/WO-4.7: build an AnimatedSprite2D from conventional walk frames.
## walk = east cycle (flip_h for west); walk_n / walk_s when frame sets exist;
## idle = the passing poses of the east cycle (subtle bob).
func _setup_sprite_frames(id: String) -> void:
	if _anim != null:
		_anim.queue_free()
		_anim = null
	_has_walk_n = false
	_has_walk_s = false
	if id == "":
		return
	var dir := resolve_sprite_dir(id, sprite_variant)
	var sets := scan_walk_frames(dir)
	var east: Array = sets["walk"]
	if east.is_empty():
		return
	var frames := SpriteFrames.new()
	for anim in ["walk", "walk_n", "walk_s"]:
		var paths: Array = sets[anim]
		if paths.is_empty():
			continue
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 8.0)
		for p in paths:
			frames.add_frame(anim, load(p))
	_has_walk_n = not (sets["walk_n"] as Array).is_empty()
	_has_walk_s = not (sets["walk_s"] as Array).is_empty()
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 2.0)
	# AW-37: an optional clear-faced idle override (a weaponless standing pose)
	# so staff-carriers don't hold a staff across their face while standing/
	# selected. Present as <dir>/idle_f1.png; otherwise the walk passing-poses.
	var idle_override := "%s/idle_f1.png" % dir
	if ResourceLoader.exists(idle_override):
		frames.add_frame("idle", load(idle_override))
	else:
		for idx in idle_frame_indices(east.size()):
			frames.add_frame("idle", load(east[idx - 1]))
	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = frames
	_anim.texture_filter = TEXTURE_FILTER_NEAREST  # crisp pixels at any zoom
	_anim.scale = Vector2.ONE * (float(_grid.cell_size) / 32.0)
	_anim.position = Vector2(0, -_grid.cell_size * 0.06)
	add_child(_anim)
	_anim.play("idle")


## The scale the on-map sprite renders at: map sprites are authored at 32px and
## scaled up to the cell. Overlays (the combat rig) match this so they don't
## shrink or balloon relative to the unit.
func map_sprite_scale() -> float:
	return (float(_grid.cell_size) / 32.0) if _grid != null else 1.0


## Local offset of the on-map sprite from the unit's cell-center origin, so an
## overlay can sit exactly where the sprite sits.
func map_sprite_offset() -> Vector2:
	return Vector2(0, -_grid.cell_size * 0.06) if _grid != null else Vector2.ZERO


## Which way the on-map sprite currently faces (art faces east/right by default;
## flip_h true = facing west/left). Used so an attack/heal on a straight-up or
## straight-down tile keeps the unit's facing instead of snapping it around.
func facing_right() -> bool:
	return _anim == null or not _anim.flip_h


## Turn the on-map sprite to face left/right (e.g. toward the tile it's acting
## on), so the unit keeps that facing after an attack/heal.
func set_facing(face_right: bool) -> void:
	if _anim != null:
		_anim.flip_h = not face_right


# --- AW-33: hover idle -------------------------------------------------------------

## The cursor rested on (or left) this unit: start/stop a looping "perk up" — a
## gentle breathing bob of the sprite plus a signature gleam above the head.
func set_hovered(on: bool) -> void:
	if on == _hovered:
		return
	_hovered = on
	if on:
		_hover_phase = 0.0
		_start_idle_bob()
	else:
		_stop_idle_bob()
	queue_redraw()


func _start_idle_bob() -> void:
	if _anim == null or _moving:
		return
	_anim_base_pos = _anim.position
	_anim_base_scale = _anim.scale
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = create_tween().set_loops()
	# rise a touch and swell, then settle — a slow breath (~1.1s round trip).
	_idle_tween.tween_property(_anim, "position:y", _anim_base_pos.y - 2.5, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.parallel().tween_property(_anim, "scale", _anim_base_scale * 1.04, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(_anim, "position:y", _anim_base_pos.y, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.parallel().tween_property(_anim, "scale", _anim_base_scale, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_idle_bob() -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null
	if _anim != null and _anim_base_scale != Vector2.ZERO:
		_anim.position = _anim_base_pos
		_anim.scale = _anim_base_scale


## Signature accent colour for this unit — its hover glow + combat-FX hue. Named
## heroes get their own colour (Kai's relic green, Perrin's gold, …); mages read
## from their anima element; everyone else falls back to a warm gold.
const SIGNATURE_COLORS := {
	"kai": Color(0.42, 1.0, 0.55),      # relic green
	"perrin": Color(1.0, 0.85, 0.30),   # gold
	"kael": Color(0.62, 0.85, 1.0),     # keen steel-blue
	"dain": Color(1.0, 0.55, 0.22),     # molten
	"brenna": Color(0.72, 0.80, 1.0),   # bastion blue
	"wren": Color(1.0, 0.80, 0.42),     # amber light
	"serra": Color(0.40, 0.70, 1.0),    # tide
	"corin": Color(0.55, 1.0, 0.55),    # stag green
	"sable": Color(0.70, 1.0, 0.60),    # beast green
}
func signature_color() -> Color:
	var id := unit_def.id if unit_def != null else ""
	if SIGNATURE_COLORS.has(id):
		return SIGNATURE_COLORS[id]
	var w := weapon()
	if w != null:
		match w.school:
			"ember": return Color(1.0, 0.55, 0.20)
			"gale": return Color(0.55, 1.0, 0.55)
			"tide": return Color(0.40, 0.70, 1.0)
		if w.is_staff():
			return Color(0.55, 1.0, 0.75)
		if w.weapon_type == WeaponDef.WeaponType.BOW:
			return Color(0.60, 1.0, 0.60)
	return Color(0.96, 0.85, 0.42)  # gold


## Effective value of a stat key (UnitDef base + level-up bonus).
func stat(key: String) -> int:
	var base: int = unit_def.get(_STAT_FIELD[key]) if unit_def != null else 0
	var skill_mod := 0
	for sk in active_skills():
		if not sk.is_aura():  # auras buff allies, not their owner
			skill_mod += int(sk.stat_bonuses.get(key, 0))
	return base + int(_stat_bonus.get(key, 0)) + int(_aura_stat.get(key, 0)) + skill_mod


func max_hp() -> int:
	return stat("hp")


func is_alive() -> bool:
	return current_hp > 0


func is_moving() -> bool:
	return _moving


## The equipped weapon (first weapon in the inventory).
func weapon() -> WeaponDef:
	return inventory.equipped_weapon()


## Spend one use of the equipped weapon after an attack. Returns the item that
## broke (removed from inventory), or null.
func spend_weapon_use() -> InventoryItem:
	return inventory.use_equipped_weapon()


## Replace the equipped weapon (equip / test helper). Resets its uses.
func equip_weapon(w: WeaponDef) -> void:
	var it := inventory.equipped_weapon_item()
	if it != null:
		it.def = w
		it.uses = w.max_uses
	else:
		inventory.add(InventoryItem.from_weapon(w))


## The unit's current class (promoted override if set, else the UnitDef's class).
func current_class() -> ClassDef:
	if _class_override != null:
		return _class_override
	return unit_def.char_class if unit_def != null else null


func movement_type() -> ClassDef.MovementType:
	var c := current_class()
	return c.movement_type if c != null else ClassDef.MovementType.FOOT


func token_letter() -> String:
	var c := current_class()
	return c.token_letter if c != null else "?"


func is_lord() -> bool:
	return unit_def != null and unit_def.is_lord


func unit_id() -> String:
	return unit_def.id if unit_def != null else ""


## AW-48: the id all sprite art resolves through — `UnitDef.sprite_id` lets a
## code-built unit (arena waves) borrow another unit's frames; "" = its own id.
func sprite_id() -> String:
	if unit_def != null and unit_def.sprite_id != "":
		return unit_def.sprite_id
	return unit_id()


func ai_behavior() -> AIBrain.Behavior:
	return unit_def.ai_behavior if unit_def != null else AIBrain.Behavior.AGGRESSOR


func move_points() -> int:
	return (unit_def.movement if unit_def != null else 5) + _move_bonus


## This unit's promotion target: the per-character unique class when the def
## carries one (approved ladder), else the class's own path.
func promotion_target() -> ClassDef:
	if unit_def != null and unit_def.promotion_class != null:
		return unit_def.promotion_class
	var c := current_class()
	return c.promoted_class if c != null else null


func can_promote() -> bool:
	return promotion_target() != null and level >= Promotion.MIN_LEVEL


## Promote to the current class's promoted class: apply flat stat bonuses, gain any
## movement bonus, and reset level to 1 (cap stays 20). Returns a result dict
## { "class_name": String, "bonuses": {stat->int}, "mov": int } or {} if ineligible.
func promote() -> Dictionary:
	if not can_promote():
		return {}
	var target := promotion_target()
	var bonuses := target.promotion_stat_bonuses()
	for key in bonuses:
		_stat_bonus[key] = int(_stat_bonus.get(key, 0)) + int(bonuses[key])
	current_hp += int(bonuses.get("hp", 0))  # HP bonus also raises current HP
	_move_bonus += target.promo_mov
	_class_override = target
	level = 1
	xp = 0
	queue_redraw()
	return {"class_name": target.display_name, "bonuses": bonuses, "mov": target.promo_mov}


## WO-8.1: the skills this unit currently knows — DERIVED from class + level
## (no acquisition bookkeeping, nothing new in saves). A promoted unit keeps
## its base class's skills up to the promotion floor (level 10): any legally
## promoted unit had at least reached it.
func active_skills() -> Array[SkillDef]:
	var out: Array[SkillDef] = []
	var base: ClassDef = unit_def.char_class if unit_def != null else null
	if base != null:
		var base_cap := Promotion.MIN_LEVEL if _class_override != null else level
		for sk in base.skills:
			if sk != null and sk.unlock_level <= base_cap:
				out.append(sk)
	if _class_override != null:
		for sk in _class_override.skills:
			if sk != null and sk.unlock_level <= level:
				out.append(sk)
	# AW-27: signature skills carried by the character persist across promotion.
	if unit_def != null:
		for sk in unit_def.personal_skills:
			if sk != null and sk.unlock_level <= level:
				out.append(sk)
	return out


## Summed combat modifiers from active skills (folded into the Combatant
## alongside supports/camaraderie — same forecast/resolver path). Auras are
## excluded here — they buff nearby allies, not their owner (see set_aura).
func skill_combat_bonus() -> Dictionary:
	var total := {"hit": 0, "avoid": 0, "damage": 0, "crit": 0}
	for sk in active_skills():
		if sk.is_aura():
			continue
		var b := sk.combat_bonus()
		for key in total:
			total[key] += int(b[key])
	return total


# --- auras (AW-27) ------------------------------------------------------------

## Active aura skills this unit projects onto nearby allies.
func aura_skills() -> Array[SkillDef]:
	var out: Array[SkillDef] = []
	for sk in active_skills():
		if sk.is_aura():
			out.append(sk)
	return out


## Wipe any aura bonuses currently on this unit (called before each recompute).
func clear_auras() -> void:
	_aura_stat = {}
	_aura_combat = {"hit": 0, "avoid": 0, "damage": 0, "crit": 0}


## Fold one aura skill's bonuses onto this unit (it stands in an ally's aura).
func add_aura(sk: SkillDef) -> void:
	for key in sk.stat_bonuses:
		_aura_stat[key] = int(_aura_stat.get(key, 0)) + int(sk.stat_bonuses[key])
	var b := sk.combat_bonus()
	for key in _aura_combat:
		_aura_combat[key] += int(b[key])


## Combat modifiers this unit currently receives from allies' auras — folded into
## the Combatant next to supports/camaraderie/skills.
func aura_combat_bonus() -> Dictionary:
	return _aura_combat.duplicate()


## WO-8.2: whether this unit may wield `w`. Only Kai is gated — his schools
## open through story beats (broader than any house lane, §4/M8); everyone
## else is already locked to their lane by their kit.
func can_use_weapon(w: WeaponDef) -> bool:
	if w == null or w.school == "":
		return true
	# AW-53: innate magic (Crownspark) is its bearer's OWN — no story gate; but
	# only for the unit whose character sheet actually lists it.
	if w.innate:
		return _kit_lists_weapon(w.id)
	if unit_def == null or unit_def.id != "kai":
		return true
	return bool(Campaign.flags.get("school_" + w.school, false))


## Whether this unit's authored kit (def weapon + extras) includes weapon `id`.
func _kit_lists_weapon(id: String) -> bool:
	if unit_def == null:
		return false
	if unit_def.weapon != null and unit_def.weapon.id == id:
		return true
	for w in unit_def.extra_weapons:
		if w != null and w.id == id:
			return true
	return false


func can_attack() -> bool:
	var w := weapon()
	return w != null and w.can_attack()


## Build a pure Combatant snapshot from this unit's live state + its tile's terrain.
func to_combatant(terrain_def: int, terrain_avoid: int) -> Combatant:
	var s := {
		"hp": max_hp(), "current_hp": current_hp,
		"str": stat("str"), "mag": stat("mag"), "skl": stat("skl"),
		"spd": stat("spd"), "lck": stat("lck"), "def": stat("def"), "res": stat("res"),
	}
	return Combatant.make(unit_def.display_name, s, weapon(), terrain_def, terrain_avoid)


## Award XP; roll and apply any level-ups that result (each 100 XP, capped at 20).
## Rolls flow through the shared `rng` for replayability. Returns one result dict
## per level gained: { "level": int, "gains": {stat->0/1} }.
func gain_xp(amount: int, rng: CombatRNG) -> Array:
	var results: Array = []
	if amount <= 0 or unit_def == null:
		return results
	xp += amount
	while xp >= CombatXP.XP_PER_LEVEL and level < CombatXP.LEVEL_CAP:
		xp -= CombatXP.XP_PER_LEVEL
		results.append(_apply_level_up(rng))
	if level >= CombatXP.LEVEL_CAP:
		xp = 0
	return results


func _apply_level_up(rng: CombatRNG) -> Dictionary:
	var gains := LevelUp.roll(unit_def.growths(), rng)
	for key in gains:
		_stat_bonus[key] = int(_stat_bonus.get(key, 0)) + int(gains[key])
	level += 1
	current_hp += int(gains.get("hp", 0))  # HP growth also raises current HP
	queue_redraw()
	return {"level": level, "gains": gains}


## Restore HP up to max; returns the amount actually healed.
func heal(amount: int) -> int:
	var before := current_hp
	current_hp = clampi(current_hp + amount, 0, max_hp())
	if current_hp != before:
		flash()
		queue_redraw()
	return current_hp - before


func save_state() -> Dictionary:
	return {
		"id": unit_id(),
		"cell": {"x": cell.x, "y": cell.y},
		"team": team,
		"current_hp": current_hp,
		"level": level,
		"xp": xp,
		"has_acted": has_acted,
		"ai_awake": ai_awake,
		"stat_bonus": _stat_bonus.duplicate(true),
		"class_override": _resource_path(_class_override),
		"move_bonus": _move_bonus,
		"inventory": _inventory_save_state(),
	}


func apply_save_state(state: Dictionary) -> void:
	var saved_cell: Dictionary = state.get("cell", {})
	cell = Vector2i(int(saved_cell.get("x", cell.x)), int(saved_cell.get("y", cell.y)))
	position = _grid.cell_center(cell) if _grid != null else position
	team = int(state.get("team", team))
	level = int(state.get("level", level))
	xp = int(state.get("xp", xp))
	has_acted = bool(state.get("has_acted", has_acted))
	ai_awake = bool(state.get("ai_awake", ai_awake))
	_apply_stat_bonus(state.get("stat_bonus", {}))
	_move_bonus = int(state.get("move_bonus", _move_bonus))
	_apply_class_override(str(state.get("class_override", "")))
	_apply_inventory_state(state.get("inventory", []))
	current_hp = clampi(int(state.get("current_hp", current_hp)), 0, max_hp())
	queue_redraw()


## Between-battle progression only (level/XP/stat gains/promotion/inventory) — no
## board position, current HP, or turn flags. Used by Campaign so redeploying to a
## new battle keeps growth but resets position and heals to full.
func progression_state() -> Dictionary:
	return {
		"id": unit_id(),
		"level": level,
		"xp": xp,
		"stat_bonus": _stat_bonus.duplicate(true),
		"class_override": _resource_path(_class_override),
		"move_bonus": _move_bonus,
		"inventory": _inventory_save_state(),
	}


func apply_progression_state(state: Dictionary) -> void:
	level = int(state.get("level", level))
	xp = int(state.get("xp", xp))
	_apply_stat_bonus(state.get("stat_bonus", {}))
	_move_bonus = int(state.get("move_bonus", _move_bonus))
	_apply_class_override(str(state.get("class_override", "")))
	_apply_inventory_state(state.get("inventory", []))
	_ensure_innate_weapons()  # AW-53: saves that predate an innate weapon gain it
	current_hp = max_hp()  # full HP for a fresh deployment
	queue_redraw()


## AW-53: a saved inventory REPLACES the character sheet's kit — so a save from
## before an innate weapon existed (Neal's campaign vs Crownspark) would never
## receive it. Merge any missing innate def weapon back in; it's part of the
## character, not their baggage.
func _ensure_innate_weapons() -> void:
	if unit_def == null:
		return
	var kit: Array = [unit_def.weapon]
	kit.append_array(unit_def.extra_weapons)
	for w in kit:
		if w == null or not (w as WeaponDef).innate or inventory.is_full():
			continue
		var have := false
		for item in inventory.items:
			if item.is_weapon() and item.weapon() != null and item.weapon().id == w.id:
				have = true
		if not have:
			inventory.add(InventoryItem.from_weapon(w))


func _apply_stat_bonus(saved: Dictionary) -> void:
	for key in _stat_bonus:
		_stat_bonus[key] = int(saved.get(key, 0))


func _apply_class_override(path: String) -> void:
	_class_override = null
	if path != "" and ResourceLoader.exists(path):
		_class_override = load(path)


func _inventory_save_state() -> Array:
	var out: Array = []
	for item in inventory.items:
		out.append({
			"type": "weapon" if item.is_weapon() else "item",
			"path": _resource_path(item.def),
			"id": str(item.def.get("id")) if item.def != null else "",
			"uses": item.uses,
		})
	return out


func _apply_inventory_state(saved_items: Array) -> void:
	var restored := Inventory.new()
	for entry in saved_items:
		if not entry is Dictionary:
			continue
		var path := str(entry.get("path", ""))
		if path == "" or not ResourceLoader.exists(path):
			continue
		var def: Resource = load(path)
		if not (def is WeaponDef or def is ItemDef):
			continue
		var item := InventoryItem.from_weapon(def as WeaponDef) if def is WeaponDef else InventoryItem.from_item(def as ItemDef)
		item.uses = int(entry.get("uses", item.uses))
		restored.add(item)
	inventory = restored


static func _resource_path(res: Resource) -> String:
	if res == null:
		return ""
	return res.resource_path


## Apply a resolved HP value (from CombatResult), with a brief hit flash.
func set_hp(new_hp: int) -> void:
	current_hp = clampi(new_hp, 0, max_hp())
	flash()
	queue_redraw()


func flash() -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
		queue_redraw()
	if _hovered:
		_hover_phase += delta
		queue_redraw()  # AW-33: pulse the signature gleam


## Animate along a cell path (as returned by Pathfinder.find_path). Awaitable.
func move_along_path(path: Array) -> void:
	if path.size() <= 1:
		cell = path[-1] if not path.is_empty() else cell
		position = _grid.cell_center(cell)
		move_finished.emit()
		return
	_moving = true
	for i in range(1, path.size()):
		var target: Vector2 = _grid.cell_center(path[i])
		if _anim != null:
			var step: Vector2i = Vector2i(path[i]) - Vector2i(path[i - 1])
			if absi(step.y) > absi(step.x) and (step.y < 0 and _has_walk_n or step.y > 0 and _has_walk_s):
				_anim.play("walk_n" if step.y < 0 else "walk_s")
				_anim.flip_h = false
			else:
				_anim.play("walk")
				if absf(target.x - position.x) > 1.0:
					_anim.flip_h = target.x < position.x  # faces right by default
		while position.distance_to(target) > 1.0:
			var delta: float = get_process_delta_time()
			position = position.move_toward(target, MOVE_SPEED_PX * delta)
			await get_tree().process_frame
		position = target
	cell = path[-1]
	_moving = false
	if _anim != null:
		_anim.play("idle")
	move_finished.emit()


## House tint for the token/HP bar (§4). Unset (alpha 0) falls back to team color.
var house_color := Color(0, 0, 0, 0)


func set_house_color(c: Color) -> void:
	house_color = c
	queue_redraw()


func _team_color() -> Color:
	if house_color.a > 0.0:
		return house_color
	return PLAYER_COLOR if team == 0 else ENEMY_COLOR


func _draw() -> void:
	if _grid == null:
		return
	if _anim != null:
		_draw_sprite_underlay()
		return
	if _standee != null:
		_draw_standee()
		return
	var r: float = _grid.cell_size * 0.34
	var base := _team_color()
	if has_acted:
		base = base.darkened(0.4)  # greyed-out once the unit has acted this turn
	# House/team base ring (§8 art rule 3).
	draw_circle(Vector2.ZERO, r + 4.0, base.darkened(0.35))
	draw_circle(Vector2.ZERO, r, base)
	if _flash > 0.0:
		draw_circle(Vector2.ZERO, r, Color(1, 1, 1, _flash))
	_draw_letter()
	_draw_hp_bar(r)


## Ring + HP bar under the AW-7 animated sprite; the sprite child draws itself.
func _draw_sprite_underlay() -> void:
	var cs: float = float(_grid.cell_size)
	var base := _team_color()
	var ring := base.darkened(0.4) if has_acted else base
	var foot_y := cs * 0.40
	draw_set_transform(Vector2(0, foot_y), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, cs * 0.32, Color(ring.r, ring.g, ring.b, 0.28))
	draw_arc(Vector2.ZERO, cs * 0.32, 0.0, TAU, 40, ring, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_anim.modulate = Color(0.55, 0.55, 0.58) if has_acted else Color.WHITE
	if _flash > 0.0:
		_anim.modulate = Color(1.0 + _flash, 1.0 + _flash, 1.0 + _flash)
	if _hovered:
		_draw_hover_flourish(cs)
	_draw_hp_bar(cs * 0.32)


## AW-37: a calm looping hover idle in the unit's signature colour. Neal's call —
## the literal-weapon choreographies read as noisy, so fighters/archers/beasts get
## a soft breathing GLOW aura instead; mages keep the orbiting-element motes he
## liked. Each character's hue comes from signature_color() (Kai green, Perrin
## gold, Serra tide-blue, …), so hovering reads as "this one, and who they are."
func _hover_archetype() -> String:
	var w := weapon()
	if w != null and w.weapon_type == WeaponDef.WeaponType.TOME:
		return "tome"
	return "glow"


func _draw_hover_flourish(cs: float) -> void:
	var col := signature_color()
	var p := fposmod(_hover_phase, 1.7) / 1.7  # normalised loop position
	if _hover_archetype() == "tome":
		_flourish_tome(cs, col, p)
	else:
		_flourish_glow(cs, col)


## A soft breathing halo around the unit — reads around the sprite's silhouette
## since it's drawn under the sprite and larger than it.
func _flourish_glow(cs: float, col: Color) -> void:
	var centre := Vector2(0, -cs * 0.18)
	var pulse := 0.5 + 0.5 * sin(_hover_phase * 3.4)
	for k in range(4):
		var r := cs * (0.30 + k * 0.11) * (0.94 + 0.10 * pulse)
		var a := (0.16 - k * 0.03) * (0.65 + 0.5 * pulse)
		if a > 0.0:
			draw_circle(centre, r, Color(col.r, col.g, col.b, a))
	# a bright little core spark keeps it lively
	draw_circle(centre, cs * 0.05, Color(col.r, col.g, col.b, 0.35 + 0.35 * pulse))


## Two motes orbit the caster while a rune pulses at the core (mages keep this).
func _flourish_tome(cs: float, col: Color, p: float) -> void:
	var core := Vector2(cs * 0.10, -cs * 0.22)
	var pulse := 0.5 + 0.5 * sin(p * TAU)
	draw_circle(core, cs * (0.07 + 0.03 * pulse), Color(col.r, col.g, col.b, 0.35 + 0.35 * pulse))
	for k in range(2):
		var a := p * TAU + k * PI
		var m := core + Vector2(cos(a), sin(a) * 0.55) * cs * 0.24
		draw_circle(m, cs * 0.045, Color(col.r, col.g, col.b, 0.95))


## Banner-Saga-style painted standee: house ring at the feet, figure ~1.5 cells
## tall, HP bar below. All the tweens (move/lunge/flash/dissolve) apply unchanged.
func _draw_standee() -> void:
	var cs: float = float(_grid.cell_size)
	var base := _team_color()
	var ring := base.darkened(0.4) if has_acted else base
	var foot_y := cs * 0.42
	# House-colored ground ring (flattened circle).
	draw_set_transform(Vector2(0, foot_y), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, cs * 0.34, Color(ring.r, ring.g, ring.b, 0.30))
	draw_arc(Vector2.ZERO, cs * 0.34, 0.0, TAU, 40, ring, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var h := cs * 1.5
	var w := _standee.get_width() * (h / _standee.get_height())
	var rect := Rect2(Vector2(-w * 0.5, foot_y - h), Vector2(w, h))
	var mod := Color(0.55, 0.55, 0.58) if has_acted else Color.WHITE
	draw_texture_rect(_standee, rect, false, mod)
	if _flash > 0.0:
		draw_rect(Rect2(rect.position, rect.size), Color(1, 1, 1, _flash * 0.5), true)
	_draw_hp_bar(cs * 0.34)


func _draw_letter() -> void:
	var font := ThemeDB.fallback_font
	var letter := token_letter()
	var size := int(_grid.cell_size * 0.4)
	var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
	var pos := Vector2(-text_size.x * 0.5, text_size.y * 0.32)
	draw_string(font, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)


func _draw_hp_bar(r: float) -> void:
	var w := r * 2.0
	var h := _grid.cell_size * 0.09
	var y := r + 8.0
	var frac := float(current_hp) / float(max_hp()) if max_hp() > 0 else 0.0
	var origin := Vector2(-w * 0.5, y)
	draw_rect(Rect2(origin, Vector2(w, h)), Color(0, 0, 0, 0.7), true)
	var fill := house_color.lightened(0.2) if house_color.a > 0.0 else (Color(0.35, 0.85, 0.4) if team == 0 else Color(0.9, 0.5, 0.3))
	draw_rect(Rect2(origin, Vector2(w * frac, h)), fill, true)
	draw_rect(Rect2(origin, Vector2(w, h)), Color(0, 0, 0, 0.9), false, 1.0)
