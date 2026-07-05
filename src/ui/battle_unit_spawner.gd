class_name BattleUnitSpawner
extends RefCounted
## WO-4.5: unit spawning slice extracted from battle_view (zero behavior
## change). Spawns the player roster + authored or demo enemy forces and
## overlays campaign state; the view keeps `add_unit` and the save-side
## rebuild/clear helpers.

var _v  # BattleView (untyped to avoid a class_name reference cycle)


func _init(view) -> void:
	_v = view


func spawn_units() -> void:
	# Player roster (shared with the Academy Hub, §4 / WO-3.5). Chapters author
	# their own deploy cells (WO-4.1); the test map falls back to Roster's.
	var cells: Dictionary = _v.chapter.deploy_cells if not _v.chapter.deploy_cells.is_empty() else Roster.deploy_cells()
	for def in Roster.player_units():
		var u: Unit = _v.add_unit(def, cells.get(def.id, Vector2i.ZERO))
		if def.is_lord:
			_v._lord_unit = u
	if _v.chapter.enemy_spawns.is_empty():
		spawn_demo_enemies()
	else:
		# Authored enemy force (WO-4.1). Defs are duplicated so runtime state
		# never leaks into the cached .tres resources.
		for spawn in _v.chapter.enemy_spawns:
			if spawn == null or spawn.unit == null:
				continue
			var u: Unit = _v.add_unit(spawn.unit.duplicate(), spawn.cell)
			if _v.chapter.boss_unit_id != "" and u.unit_id() == _v.chapter.boss_unit_id:
				_v._boss_unit = u
	# When deployed from the hub, overlay campaign progression + supports (WO-3.5).
	if Campaign.active:
		apply_campaign_state()


## Legacy demo force for chapters without authored spawns (the WO-0.2 test map).
## One of each AI tier (§5): an aggressor advances, a sentinel holds until
## threatened, a boss holds the fort at (16,4).
func spawn_demo_enemies() -> void:
	var soldier: ClassDef = _try_load("res://data/classes/soldier.tres")
	var sword: WeaponDef = _try_load("res://data/weapons/iron_sword.tres")
	var lance: WeaponDef = _try_load("res://data/weapons/iron_lance.tres")
	if soldier == null:
		return
	_v.add_unit(demo_unit("tide_a", "Tidemark Soldier", soldier, lance, 1, 5, {"spd": 6}), Vector2i(6, 7))
	var sentinel := demo_unit("tide_b", "Tidemark Sentinel", soldier, sword, 1, 5, {"spd": 7, "hp": 22})
	sentinel.ai_behavior = AIBrain.Behavior.SENTINEL
	_v.add_unit(sentinel, Vector2i(11, 8))
	var boss := demo_unit("serra", "Serra", soldier, lance, 1, 5, {"spd": 6, "hp": 30, "def": 8})
	boss.ai_behavior = AIBrain.Behavior.BOSS
	_v.add_unit(boss, Vector2i(16, 4))  # the fort tile


## Overlay between-battle campaign state onto the freshly-spawned player units.
func apply_campaign_state() -> void:
	_v.casual_mode = Campaign.casual
	_v._support_state.apply_save_state(Campaign.support_save)
	for u in _v._units:
		if u.team == 0:
			Campaign.apply_to_unit(u)


func demo_unit(
	id: String, disp: String, cls: ClassDef, wpn: WeaponDef, team: int, mov: int, overrides: Dictionary
) -> UnitDef:
	var d := UnitDef.new()
	d.id = id
	d.display_name = disp
	d.char_class = cls
	d.weapon = wpn
	d.team = team
	d.movement = mov
	d.max_hp = overrides.get("hp", 24)
	d.strength = overrides.get("str", 7)
	d.skill = overrides.get("skl", 7)
	d.speed = overrides.get("spd", 8)
	d.luck = overrides.get("lck", 4)
	d.defense = overrides.get("def", 5)
	d.resistance = overrides.get("res", 2)
	d.house_id = _v.player_house_id if team == 0 else _v.enemy_house_id  # overridable per unit
	return d


func _try_load(path: String) -> Resource:
	return load(path) if ResourceLoader.exists(path) else null
