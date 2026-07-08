extends Node2D
## Battle scene root. Renders a chapter map and drives the player action loop:
##   select unit -> move range (blue) + attack range (red) -> pick a tile to move ->
##   choose a target in range -> combat forecast -> confirm -> resolver runs ->
##   HP bars update, hit/miss/crit feedback, death removes the unit + EventBus.
##
## Orchestration/presentation only. Terrain numbers come from ChapterDef/TerrainDB;
## reachability from Pathfinder/MovementRange; combat from the pure CombatResolver.

@export var chapter: ChapterDef
@export var backdrop_color: Color = Color(0.16, 0.20, 0.15)
@export var demo_attack_ranges: Array = [1]
## Pause between animated strikes (seconds). Tests set this to 0 for speed.
@export var strike_delay: float = 0.45
## Fixed combat/level-up RNG seed for deterministic runs (§3 replayability). < 0
## means seed from the clock. Tests set this for reproducible outcomes.
@export var combat_seed: int = -1
## Casual mode revives non-lord player casualties after a chapter. Classic mode
## records them as permadead in save data (§3 / WO-3.3).
@export var casual_mode: bool = false
## Chapter dialogue (intro/outro/boss quotes, WO-4.1). Tests disable to skip the
## VN overlays; paths live on the ChapterDef so the test map is unaffected anyway.
@export var dialogue_enabled: bool = true
## Battle direction v2 (2026-07): the full-screen popup is RETIRED. Combat plays
## ON THE MAP (unit lunges/attacks on its tile, camera pushes in on the clash).
## Left as a toggle for now; default off. Tests never see either path (strike_delay 0).
@export var battle_popups_enabled: bool = false

const TERRAIN_TINTS := {
	Terrain.Type.PLAINS: Color(0.0, 0.0, 0.0, 0.0),
	Terrain.Type.FOREST: Color(0.20, 0.45, 0.20, 0.35),
	Terrain.Type.MOUNTAIN: Color(0.45, 0.36, 0.28, 0.45),
	Terrain.Type.FORT: Color(0.70, 0.62, 0.25, 0.40),
	Terrain.Type.WALL: Color(0.10, 0.10, 0.12, 0.75),
	Terrain.Type.WATER: Color(0.15, 0.35, 0.60, 0.55),
	Terrain.Type.PATH: Color(0.72, 0.60, 0.38, 0.35),
	Terrain.Type.FLOOR: Color(0.62, 0.56, 0.46, 0.30),
	Terrain.Type.PILLAR: Color(0.80, 0.78, 0.72, 0.55),
	Terrain.Type.CARPET: Color(0.25, 0.30, 0.65, 0.45),
	Terrain.Type.SPRING: Color(0.35, 0.75, 0.85, 0.50),
	Terrain.Type.FLOWERS: Color(0.85, 0.75, 0.35, 0.30),
	Terrain.Type.SITE: Color(0, 0, 0, 0),
}

enum Phase { IDLE, SELECTED, MENU, TARGETING }

var _grid: Grid
var _terrain_db: TerrainDB
var _overlay: GridOverlay
var _range_overlay: RangeOverlay
var _threat_overlay: ThreatOverlay
var _units_root: Node2D
var _cursor: BattleCursor
var _ui_layer: CanvasLayer
var _debug_label: Label
var _forecast_panel: CombatForecastPanel
var _rng: CombatRNG

var _turn := TurnManager.new()
var _turn_banner: TurnBanner
var _result_screen: ResultScreen
var _level_up_screen: LevelUpScreen
var _units: Array[Unit] = []
var _phase: Phase = Phase.IDLE
var _selected: Unit = null
var _standable: Array = []
var _targets: Array[Unit] = []
var _targeting_heal := false
var _busy := false

var _camera: Camera2D
var _juice: JuiceController
var _juice_config: JuiceConfig
var _splash: ClashSplash

var _menu: ChoiceMenu
var _menu_context := ""
var _menu_actions: Array = []      # action ids for the "action" context
var _menu_items: Array = []        # InventoryItems for item/equip/trade_give
var _menu_partners: Array[Unit] = []  # allies for trade_ally
var _support_menu_entries: Array = []
var _trade_partner: Unit = null
## Where the selected unit stood before moving — cancel on the command menu
## undoes the move (FE semantics, WO-4.4).
var _move_origin := Vector2i.ZERO
var _stats_panel: UnitStatsPanel
var _stats_from_menu := false
var _battle_over := false
var _battle_victory := false
var _lord_unit: Unit = null
var _lord_alive := true
## Visited spot ids this battle (maps v3 FE villages) — each spot is once-only.
var _visited_spot_ids: Array[String] = []


## The unvisited VisitSpot under this cell, or null.
func _visit_spot_at(cell: Vector2i) -> VisitSpot:
	for spot in chapter.visits:
		if spot != null and spot.cell == cell and not _visited_spot_ids.has(spot.id):
			return spot
	return null


## DEFEAT_BOSS objective (WO-4.1): the chapter's boss and whether it still stands.
var _boss_unit: Unit = null
var _boss_alive := true
var _boss_quote_played := false
var _dialogue_playing := false
var _objective_label: Label
var _hover_info: Control      # FE-style unit info box (name/Lv/HP/XP) on hover
var _hover_unit: Unit = null
var _support_state := SupportState.new()
var _houses: Dictionary = {}        # house_id -> HouseDef
## The player's active house — drives UI theming. Swap this resource to re-theme.
@export var player_house_id: String = "emberwing"
@export var enemy_house_id: String = "tidemark"
var _save_system := SaveSystem.new()
var _defeated_unit_ids: Array[String] = []
var _permadead_unit_ids: Array[String] = []


func _ready() -> void:
	Engine.time_scale = 1.0  # defensive: never inherit a hit-stop freeze from before
	if chapter == null:
		chapter = _build_fallback_chapter()
	if Campaign.active:
		player_house_id = Campaign.house_id  # WO-5.3a: theming follows the choice
	_terrain_db = TerrainDB.create_default()
	_grid = chapter.make_grid()
	_rng = CombatRNG.new(combat_seed if combat_seed >= 0 else int(Time.get_ticks_usec()))
	_combat_exec = BattleCombatExecutor.new(self)
	_menu_ctrl = BattleActionMenuController.new(self)
	_spawner = BattleUnitSpawner.new(self)
	_battle_popup = BattlePopup.new()
	_battle_popup.stage_base = chapter.base_terrain
	add_child(_battle_popup)
	_setup_houses()
	_setup_supports()
	_setup_terrain_tiles()
	_setup_overlay()
	_setup_range_overlay()
	_setup_threat_overlay()
	_setup_units_root()
	_setup_cursor()
	_setup_camera()
	_setup_ui()
	_setup_juice()
	_spawn_units()
	_focus_player_start()
	queue_redraw()
	_begin_battle()


## Open on the player's team: cursor on the first living player unit (the
## lord), camera snapped there — not drifting in from the map's center.
func _focus_player_start() -> void:
	for u in _units:
		if u.team == 0 and u.is_alive():
			_cursor.move_to(u.cell)
			break
	var cs := float(_grid.cell_size)
	_camera.position = _camera_clamp(Vector2(_cursor.cell) * cs + Vector2(cs, cs) * 0.5)


## Chapter opening: play the intro dialogue (if any), then start the player phase.
func _begin_battle() -> void:
	if chapter.intro_dialogue != "":
		await _play_dialogue(chapter.intro_dialogue)
	_begin_player_phase()


func _draw() -> void:
	var size := _grid.pixel_size()
	# with Wang tiles active they ARE the ground — the opaque backdrop would
	# occlude them (tiles render show_behind_parent, i.e. below this canvas)
	if _terrain_tiles == null or not _terrain_tiles.is_active():
		if chapter.backdrop != null:
			draw_texture_rect(chapter.backdrop, Rect2(Vector2.ZERO, size), false)
		else:
			draw_rect(Rect2(Vector2.ZERO, size), backdrop_color, true)
	_draw_terrain_tints()
	_draw_seize_marker()
	_draw_visit_markers()


## FE door sparkle: unvisited visit cells pulse a small gold diamond so the
## player can spot which houses will talk to them (maps v3).
func _draw_visit_markers() -> void:
	if chapter.visits.is_empty():
		return
	var cs := float(_grid.cell_size)
	var pulse := 0.55 + 0.35 * sin(Time.get_ticks_msec() / 280.0)
	for spot in chapter.visits:
		if spot == null or _visited_spot_ids.has(spot.id):
			continue
		var c := Vector2((spot.cell.x + 0.5) * cs, (spot.cell.y + 0.35) * cs)
		var r := cs * 0.16
		var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0),
			c + Vector2(0, r), c + Vector2(-r, 0)])
		draw_colored_polygon(pts, Color(1.0, 0.88, 0.35, pulse))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.55, 0.4, 0.05, pulse), 2.0)


## Gold marker on the objective tile: the seize cell, or the boss's fort so a
## first-time player can see where to go (WO-4.1).
func _draw_seize_marker() -> void:
	var c := Vector2i(-1, -1)
	match chapter.objective:
		ChapterDef.Objective.SEIZE:
			c = chapter.seize_cell
		ChapterDef.Objective.DEFEAT_BOSS:
			if _boss_unit != null and is_instance_valid(_boss_unit):
				c = _boss_unit.cell
	if not _grid.in_bounds(c):
		return
	var cs := _grid.cell_size
	var rect := Rect2(c.x * cs + 6, c.y * cs + 6, cs - 12, cs - 12)
	draw_rect(rect, Color(0.95, 0.82, 0.35, 0.18), true)
	draw_rect(rect, Color(0.95, 0.82, 0.35, 0.9), false, 3.0)


## AW-2a: pixel Wang-tile terrain when the atlases exist (hybrid maps
## doctrine); the tint fallback keeps working without art, per terrain
## type (a type whose atlas is missing still tints).
var _terrain_tiles: TerrainTiles


func _setup_terrain_tiles() -> void:
	_terrain_tiles = TerrainTiles.new()
	# render below the battle view's own canvas (WALL tint + seize marker
	# draw there and must stay visible above the tiles)
	_terrain_tiles.show_behind_parent = true
	add_child(_terrain_tiles)
	_terrain_tiles.setup(_grid, chapter)


func _draw_terrain_tints() -> void:
	var cs := _grid.cell_size
	var tiles_active := _terrain_tiles != null and _terrain_tiles.is_active()
	for y in range(chapter.height):
		for x in range(chapter.width):
			var t := chapter.get_terrain(x, y)
			if tiles_active and _terrain_tiles.covers(t):
				continue
			var tint: Color = TERRAIN_TINTS.get(t, Color(0, 0, 0, 0))
			if tint.a > 0.0:
				draw_rect(Rect2(x * cs, y * cs, cs, cs), tint, true)


# --- unit / terrain helpers ---------------------------------------------------

func unit_at(cell: Vector2i) -> Unit:
	for u in _units:
		if u.is_alive() and u.cell == cell:
			return u
	return null


func occupancy() -> Dictionary:
	var occ := {}
	for u in _units:
		if u.is_alive():
			occ[u.cell] = u.team
	return occ


func add_unit(def: UnitDef, cell: Vector2i) -> Unit:
	var u := Unit.new()
	_units_root.add_child(u)
	u.setup(def, _grid, cell)
	var house: HouseDef = _houses.get(def.house_id, null)
	if house != null:
		u.set_house_color(house.primary_color)  # §4 unit tinting from HouseDef
	_units.append(u)
	return u


func unit_by_id(id: String) -> Unit:
	for u in _units:
		if u.unit_id() == id and u.is_alive():
			return u
	return null


func _terrain_def_at(cell: Vector2i) -> int:
	return _terrain_db.defense(chapter.get_terrain(cell.x, cell.y))


func _terrain_avoid_at(cell: Vector2i) -> int:
	return _terrain_db.avoid(chapter.get_terrain(cell.x, cell.y))


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Living enemies of `unit` that it could strike from `from_cell`.
func _attackable_targets(from_cell: Vector2i, unit: Unit) -> Array[Unit]:
	var out: Array[Unit] = []
	if not unit.can_attack():
		return out
	var w := unit.weapon()
	for u in _units:
		if u.team != unit.team and u.is_alive() and w.in_range(_manhattan(from_cell, u.cell)):
			out.append(u)
	return out


## AW-26: does `unit` have any enemy in reach of the specific weapon `w` from its
## current cell? Powers the Attack/Magic weapon-choice menus, which gate a
## category on whether ANY weapon in it can actually hit something right now.
func _weapon_has_target(unit: Unit, w: WeaponDef) -> bool:
	if w == null or not w.can_attack():
		return false
	for u in _units:
		if u.team != unit.team and u.is_alive() and w.in_range(_manhattan(unit.cell, u.cell)):
			return true
	return false


## Living, damaged allies (excluding self) a staff-user could heal from `from_cell`.
func _heal_targets(from_cell: Vector2i, unit: Unit) -> Array[Unit]:
	var out: Array[Unit] = []
	var w := unit.weapon()
	if w == null or not w.is_staff():
		return out
	for u in _units:
		if u == unit or u.team != unit.team or not u.is_alive():
			continue
		if u.current_hp < u.max_hp() and w.in_range(_manhattan(from_cell, u.cell)):
			out.append(u)
	return out


# --- selection / action flow --------------------------------------------------

func _on_cell_changed(cell: Vector2i) -> void:
	_update_debug(cell)
	_update_hover_info(cell)
	if _phase == Phase.TARGETING:
		var enemy := unit_at(cell)
		if enemy != null and _targets.has(enemy):
			_show_forecast_for(enemy)


## FE-style: pointing the cursor at any living unit shows its stats box.
func _update_hover_info(cell: Vector2i) -> void:
	if _hover_info == null:
		return
	var u := unit_at(cell)
	if u != null and u.is_alive():
		_hover_unit = u
		_hover_info.visible = true
		_hover_info.queue_redraw()
	else:
		_hover_unit = null
		_hover_info.visible = false


func _draw_hover_info() -> void:
	if _hover_unit == null:
		return
	var u := _hover_unit
	var font := ThemeDB.fallback_font
	var rect := Rect2(Vector2.ZERO, _hover_info.size)
	var team_col := Color(0.16, 0.25, 0.55, 0.92) if u.team == 0 else Color(0.5, 0.14, 0.14, 0.92)
	_hover_info.draw_rect(rect, Color(0.08, 0.09, 0.13, 0.92), true)
	_hover_info.draw_rect(Rect2(0, 0, rect.size.x, 30), team_col, true)
	_hover_info.draw_rect(rect, Color(0.86, 0.78, 0.55, 0.9), false, 2.0)
	var cls := u.unit_def.char_class.display_name if u.unit_def != null and u.unit_def.char_class != null else ""
	_hover_info.draw_string(font, Vector2(12, 22), u.unit_def.display_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.98, 0.96, 0.9))
	_hover_info.draw_string(font, Vector2(12, 50), "%s   Lv %d" % [cls, u.level],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.85, 0.9))
	_hover_info.draw_string(font, Vector2(12, 76), "HP  %d / %d" % [u.current_hp, u.max_hp()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.95, 0.7))
	# HP bar
	_hover_info.draw_rect(Rect2(120, 64, 118, 14), Color(0.2, 0.1, 0.1), true)
	var hp_frac := clampf(float(u.current_hp) / maxf(u.max_hp(), 1), 0.0, 1.0)
	_hover_info.draw_rect(Rect2(120, 64, 118 * hp_frac, 14), Color(0.4, 0.85, 0.4), true)
	# XP bar (100 per level)
	_hover_info.draw_string(font, Vector2(12, 104), "XP  %d / 100" % (u.xp % 100),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.9, 0.55))
	_hover_info.draw_rect(Rect2(120, 92, 118, 12), Color(0.15, 0.13, 0.05), true)
	_hover_info.draw_rect(Rect2(120, 92, 118 * (float(u.xp % 100) / 100.0), 12), Color(0.95, 0.82, 0.35), true)


func _unhandled_input(event: InputEvent) -> void:
	if _dialogue_playing:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# 'T'/Tab ends the player phase when idle.
	if event.keycode == KEY_T or event.keycode == KEY_TAB:
		if not _battle_over and _turn.is_player_phase() and not _busy and _phase == Phase.IDLE:
			_end_player_phase()
			get_viewport().set_input_as_handled()
	# 'H' toggles the enemy threat-range overlay.
	elif event.keycode == KEY_H:
		_toggle_threat_overlay()
		get_viewport().set_input_as_handled()


func _toggle_threat_overlay() -> void:
	var show_it := not _threat_overlay.is_shown()
	if show_it:
		_refresh_threat_overlay()
	_threat_overlay.set_shown(show_it)


## Recompute the union of every living enemy's threat range (boss-aware).
func _refresh_threat_overlay() -> void:
	var tiles := {}
	for u in _units:
		if u.team == 0 or not u.is_alive():
			continue
		for t in AIBrain.threat_tiles(u, _units, chapter, _terrain_db, u.ai_behavior()):
			tiles[t] = true
	_threat_overlay.set_tiles(tiles.keys())


func _on_cursor_confirmed(cell: Vector2i) -> void:
	if _busy or _battle_over or not _turn.is_player_phase():
		return
	match _phase:
		Phase.IDLE:
			_try_select(cell)
		Phase.SELECTED:
			await _handle_selected_confirm(cell)
		Phase.TARGETING:
			await _handle_targeting_confirm(cell)


func _on_cursor_cancelled(_cell: Vector2i) -> void:
	if _busy:
		return
	if _phase == Phase.TARGETING:
		# Cancel targeting: back to the command menu, nothing spent (WO-4.4).
		_forecast_panel.hide_panel()
		_open_action_menu()
	elif _phase == Phase.SELECTED:
		_deselect()


func _try_select(cell: Vector2i) -> void:
	var u := unit_at(cell)
	if u == null:
		_menu_ctrl.open_field_menu()  # empty tile → End Turn / Objective
		return
	if not u.is_alive():
		return
	if u.team != 0 or u.has_acted:
		_open_stats_for(u)  # anyone who can't act can still be inspected (WO-4.4)
		return
	_selected = u
	_move_origin = u.cell
	_phase = Phase.SELECTED
	_standable = MovementRange.standable_tiles(u.cell, _mov(u), _make_context(u))
	var attack := MovementRange.attack_tiles(_standable, _weapon_ranges(u), _make_context(u))
	_range_overlay.show_ranges(_standable, attack)


func _handle_selected_confirm(cell: Vector2i) -> void:
	if _selected.is_moving():
		return
	var occupied_by_other := unit_at(cell) != null and cell != _selected.cell
	if not _standable.has(cell) or occupied_by_other:
		_deselect()
		return
	_range_overlay.clear()
	var mover := _selected
	if cell != mover.cell:
		var path := Pathfinder.find_path(mover.cell, cell, _make_context(mover))
		if not path.is_empty():
			_busy = true
			await mover.move_along_path(path)
			_busy = false
	_arrive(mover)


## After a unit lands, open its command menu (Attack / Heal / Item / Trade /
## Equip / Wait), showing only the actions available from here.
func _arrive(unit: Unit) -> void:
	_open_action_menu()


# --- command menu (WO-4.5: driven by BattleActionMenuController; menu state
# stays here — tests inspect it — and the view keeps signal-facing delegates) --

var _menu_ctrl: BattleActionMenuController


func _open_action_menu() -> void:
	_menu_ctrl.open_action_menu()


func _unviewed_conversations(unit_id: String) -> Array:
	return _menu_ctrl.unviewed_conversations(unit_id)


func _on_menu_chosen(index: int) -> void:
	await _menu_ctrl.choose(index)


func _on_menu_cancelled() -> void:
	_menu_ctrl.cancel()


## Cancel out of the command menu: the unit returns to where it stood before
## moving and may act again this turn (FE semantics, WO-4.4). Items already
## traded away stay traded — only the movement is undone.
func _undo_move_and_deselect() -> void:
	_menu.close()
	if _selected != null and is_instance_valid(_selected) and _selected.cell != _move_origin:
		_selected.cell = _move_origin
		_selected.position = _grid.cell_center(_move_origin)
	_forecast_panel.hide_panel()
	_deselect()


func _begin_targeting(heal: bool) -> void:
	_targeting_heal = heal
	_targets = _heal_targets(_selected.cell, _selected) if heal else _attackable_targets(_selected.cell, _selected)
	if _targets.is_empty():
		_finish_action()
		return
	_phase = Phase.TARGETING
	_cursor.move_to(_targets[0].cell)
	if not heal:
		_show_forecast_for(_targets[0])


func _view_support_entry(index: int) -> void:
	await _menu_ctrl.view_support_entry(index)


# --- unit inspection (WO-4.4) ------------------------------------------------------

func _open_stats_for(unit: Unit) -> void:
	_recompute_auras()  # AW-27: show aura-buffed stats in the panel
	_stats_panel.show_unit(unit)
	if _cursor != null:
		_cursor.active = false


func _on_stats_closed() -> void:
	if _stats_from_menu and _selected != null and is_instance_valid(_selected):
		_stats_from_menu = false
		_open_action_menu()
	else:
		_stats_from_menu = false
		if _cursor != null and not _battle_over:
			_cursor.active = true


func _adjacent_allies(unit: Unit) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in _units:
		if u != unit and u.team == unit.team and u.is_alive() and _manhattan(u.cell, unit.cell) == 1:
			out.append(u)
	return out


func _handle_targeting_confirm(cell: Vector2i) -> void:
	var target := unit_at(cell)
	if target == null or not _targets.has(target):
		# Confirming off-target: back to the command menu, nothing spent (WO-4.4).
		_forecast_panel.hide_panel()
		_open_action_menu()
		return
	if _targeting_heal:
		await _execute_heal(_selected, target)
	else:
		await _execute_attack(_selected, target)
	_finish_action()


func _show_forecast_for(enemy: Unit) -> void:
	var attacker := _selected
	var dist := _manhattan(attacker.cell, enemy.cell)
	var atk_c := _combatant_for(attacker, attacker.cell)
	var def_c := _combatant_for(enemy, enemy.cell)
	var ex := CombatForecast.exchange(atk_c, def_c, dist)
	_forecast_panel.show_forecast(attacker, enemy, ex)


## WO-4.5: combat execution lives in BattleCombatExecutor; these delegates
## keep the view's public surface (tests, targeting flow) unchanged.
var _combat_exec: BattleCombatExecutor
var _battle_popup: BattlePopup


func _execute_attack(attacker: Unit, defender: Unit) -> void:
	await _combat_exec.execute_attack(attacker, defender)


func _execute_heal(healer: Unit, ally: Unit) -> void:
	await _combat_exec.execute_heal(healer, ally)


func _kill(unit: Unit) -> void:
	# Non-lethal chapter (WO-4.1): defeated units yield and retreat instead of dying.
	if chapter.non_lethal:
		_pop_text(unit.position, "Yields!", Color(0.75, 0.85, 1.0))
	else:
		_pop_text(unit.position, "X", Color(0.9, 0.2, 0.2))
	EventBus.unit_died.emit(unit)
	_record_defeat(unit)
	if unit == _lord_unit:
		_lord_alive = false
	if unit == _boss_unit:
		_boss_alive = false
	_units.erase(unit)
	if unit == _selected:
		_selected = null
	unit.queue_free()


func _finish_action() -> void:
	if _selected != null and is_instance_valid(_selected):
		_accrue_support_end_turn(_selected)
		_selected.has_acted = true
		_selected.queue_redraw()
	_forecast_panel.hide_panel()
	_deselect()
	_check_objective()  # a move onto the seize tile can win here
	if _battle_over:
		return
	if _turn.is_player_phase() and _all_player_units_acted():
		_end_player_phase()


# --- turn / phase loop --------------------------------------------------------

func _living_units_on_team(team: int) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in _units:
		if u.team == team and u.is_alive():
			out.append(u)
	return out


func _all_player_units_acted() -> bool:
	for u in _living_units_on_team(0):
		if not u.has_acted:
			return false
	return true


func _begin_player_phase() -> void:
	_camera_follow = null  # back to cursor-follow
	for u in _living_units_on_team(0):
		u.has_acted = false
		u.queue_redraw()
	_apply_terrain_heal(0)
	_recompute_auras()  # AW-27: keep aura stats fresh for overlays/inspection
	_deselect()
	if _threat_overlay.is_shown():
		_refresh_threat_overlay()  # enemies moved last phase
	_turn_banner.announce("Player Phase — Round %d" % _turn.round_number, true)


## §3 terrain healing (Fort: 10% max HP at the owner's phase start).
func _apply_terrain_heal(team: int) -> void:
	for u in _living_units_on_team(team):
		var info := _terrain_db.get_info(chapter.get_terrain(u.cell.x, u.cell.y))
		if info == null or info.heal_pct <= 0.0 or u.current_hp >= u.max_hp():
			continue
		var healed := u.heal(ceili(u.max_hp() * info.heal_pct))
		if healed > 0:
			_pop_text(u.position, "+%d" % healed, Color(0.4, 0.9, 0.5))


func _end_player_phase() -> void:
	_deselect()
	_turn.advance()  # -> enemy phase
	await _run_enemy_phase()
	if _battle_over:
		return
	_turn.advance()  # -> back to player, next round
	_begin_player_phase()


func _run_enemy_phase() -> void:
	_busy = true
	_apply_terrain_heal(1)
	_recompute_auras()  # AW-27: AI reads aura-buffed stats when predicting combat
	_turn_banner.announce("Enemy Phase", false)
	# Deterministic acting order (§5): stable by board position.
	var enemies := _living_units_on_team(1)
	enemies.sort_custom(func(a, b): return AIBrain._cell_key(a.cell) < AIBrain._cell_key(b.cell))
	for enemy in enemies:
		if _battle_over:
			break
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		_camera_follow = enemy  # the camera tracks whoever is acting
		await _execute_enemy_unit(enemy)
	_busy = false
	_check_objective()


# --- win / loss ---------------------------------------------------------------

func _check_objective() -> void:
	if _battle_over:
		return
	var has_lord := _lord_unit != null
	var lord_cell := Vector2i(-1, -1)
	if has_lord and _lord_alive and is_instance_valid(_lord_unit):
		lord_cell = _lord_unit.cell
	var outcome := ObjectiveResolver.evaluate(
		chapter.objective, chapter.seize_cell,
		has_lord, _lord_alive, lord_cell,
		_living_units_on_team(0).size(), _living_units_on_team(1).size(),
		_boss_alive,
	)
	if outcome == ObjectiveResolver.Outcome.VICTORY:
		_end_battle(true)
	elif outcome == ObjectiveResolver.Outcome.DEFEAT:
		_end_battle(false)


func _end_battle(victory: bool) -> void:
	if _battle_over:
		return
	_battle_over = true
	_battle_victory = victory
	_deselect()
	_range_overlay.clear()
	if victory and casual_mode:
		_apply_casual_post_chapter_revival()
	# Carry the roster's progression + supports back to the campaign (WO-3.5).
	if Campaign.active:
		Campaign.capture(_captured_roster_progression(), _support_state.save_state(),
			"victory" if victory else "defeat")
	if victory:
		EventBus.battle_won.emit()
		# Boss yield + chapter outro (WO-4.1) play before the result screen.
		if not _boss_alive:
			await _play_dialogue(chapter.boss_yield_dialogue)
		await _play_dialogue(chapter.outro_dialogue)
		_result_screen.show_victory()
	else:
		_result_screen.show_defeat()


## Progression (level/XP/gains/inventory) of every surviving player unit, keyed by id.
func _captured_roster_progression() -> Dictionary:
	var out := {}
	for u in _units:
		if u.team == 0 and u.is_alive():
			out[u.unit_id()] = u.progression_state()
	return out


func _execute_enemy_unit(enemy: Unit) -> void:
	var behavior := enemy.ai_behavior()
	# A sleeping sentinel holds until a player enters its threat range, then wakes
	# and acts as an Aggressor from now on (§5).
	if behavior == AIBrain.Behavior.SENTINEL and not enemy.ai_awake:
		if AIBrain.has_enemy_in_threat(enemy, _units, chapter, _terrain_db, behavior):
			enemy.ai_awake = true
		else:
			return  # stays asleep this turn
	var effective := AIBrain.Behavior.AGGRESSOR if behavior == AIBrain.Behavior.SENTINEL else behavior

	var decision := AIBrain.decide(enemy, _units, chapter, _terrain_db, effective, _support_state)
	if decision.move_to != enemy.cell:
		var path := Pathfinder.find_path(enemy.cell, decision.move_to, _make_context(enemy))
		if not path.is_empty():
			await enemy.move_along_path(path)
	if decision.has_attack() and is_instance_valid(decision.target) and decision.target.is_alive():
		await _execute_attack(enemy, decision.target)


func _deselect() -> void:
	_selected = null
	_phase = Phase.IDLE
	_standable = []
	_targets = []
	_range_overlay.clear()
	_forecast_panel.hide_panel()
	if _menu != null:
		_menu.close()
	if _cursor != null:
		_cursor.active = true


# --- save / load ---------------------------------------------------------------

func save_to_slot(slot: int) -> bool:
	return _save_system.save_slot(slot, make_save_payload())


func load_from_slot(slot: int) -> bool:
	var payload := _save_system.load_slot(slot)
	if payload.is_empty():
		return false
	apply_save_payload(payload)
	return true


func make_save_payload() -> Dictionary:
	return {
		"version": SaveSystem.VERSION,
		"campaign": {
			"current_chapter_id": chapter.id,
			"casual_mode": casual_mode,
			"rng_seed": str(_rng.seed_value()),
			"rng_state": str(_rng.state_value()),
			"hub_state": {},
		},
		"battle": {
			"chapter_id": chapter.id,
			"round_number": _turn.round_number,
			"active_team": int(_turn.active_team),
			"battle_over": _battle_over,
			"battle_victory": _battle_victory,
			"lord_alive": _lord_alive,
			"boss_quote_played": _boss_quote_played,
			"defeated_unit_ids": _defeated_unit_ids.duplicate(),
			"permadead_unit_ids": _permadead_unit_ids.duplicate(),
			"objective": int(chapter.objective),
			"seize_cell": {"x": chapter.seize_cell.x, "y": chapter.seize_cell.y},
		},
		"supports": _support_state.save_state(),
		"roster": _roster_save_state(),
	}


func apply_save_payload(payload: Dictionary) -> void:
	var campaign: Dictionary = payload.get("campaign", {})
	var battle: Dictionary = payload.get("battle", {})
	casual_mode = bool(campaign.get("casual_mode", casual_mode))
	combat_seed = int(str(campaign.get("rng_seed", combat_seed)))
	_rng = CombatRNG.new(combat_seed)
	_rng.set_state(int(str(campaign.get("rng_state", _rng.state_value()))))

	_turn.round_number = int(battle.get("round_number", 1))
	var saved_team := int(battle.get("active_team", TurnManager.Team.PLAYER))
	_turn.active_team = TurnManager.Team.ENEMY if saved_team == TurnManager.Team.ENEMY else TurnManager.Team.PLAYER
	_battle_over = bool(battle.get("battle_over", false))
	_battle_victory = bool(battle.get("battle_victory", false))
	_lord_alive = bool(battle.get("lord_alive", true))
	_boss_quote_played = bool(battle.get("boss_quote_played", false))
	chapter.objective = int(battle.get("objective", chapter.objective))
	var seize: Dictionary = battle.get("seize_cell", {})
	chapter.seize_cell = Vector2i(int(seize.get("x", chapter.seize_cell.x)), int(seize.get("y", chapter.seize_cell.y)))
	_defeated_unit_ids = _string_array(battle.get("defeated_unit_ids", []))
	_permadead_unit_ids = _string_array(battle.get("permadead_unit_ids", []))

	_setup_supports()
	_support_state.apply_save_state(payload.get("supports", {}))
	_rebuild_units_from_save(payload.get("roster", []))
	_restore_post_load_ui()


func _roster_save_state() -> Array:
	var out: Array = []
	for u in _units:
		if u.is_alive():
			out.append(u.save_state())
	return out


func _rebuild_units_from_save(roster: Array) -> void:
	_clear_units()
	_spawn_units()
	var state_by_id := {}
	for entry in roster:
		if entry is Dictionary:
			state_by_id[str(entry.get("id", ""))] = entry
	for id in _defeated_unit_ids:
		var defeated := unit_by_id(id)
		if defeated != null:
			_remove_unit_without_events(defeated)
	for id in state_by_id:
		var unit := unit_by_id(id)
		if unit != null:
			unit.apply_save_state(state_by_id[id])
	if not _lord_alive and _lord_unit != null and is_instance_valid(_lord_unit):
		if _defeated_unit_ids.has(_lord_unit.unit_id()):
			_remove_unit_without_events(_lord_unit)
	_boss_alive = chapter.boss_unit_id == "" or not _defeated_unit_ids.has(chapter.boss_unit_id)


func _clear_units() -> void:
	for u in _units.duplicate():
		if is_instance_valid(u):
			u.queue_free()
	_units.clear()
	_lord_unit = null
	_boss_unit = null


func _remove_unit_without_events(unit: Unit) -> void:
	_units.erase(unit)
	if unit == _selected:
		_selected = null
	unit.queue_free()


func _restore_post_load_ui() -> void:
	_deselect()
	if _threat_overlay.is_shown():
		_refresh_threat_overlay()
	if _battle_over:
		if _battle_victory:
			_result_screen.show_victory()
		else:
			_result_screen.show_defeat()
	else:
		_turn_banner.announce("%s — Round %d" % [_turn.phase_name(), _turn.round_number], _turn.is_player_phase())
	queue_redraw()


func _string_array(values: Array) -> Array[String]:
	var out: Array[String] = []
	for value in values:
		out.append(str(value))
	return out


func _record_defeat(unit: Unit) -> void:
	var id := unit.unit_id()
	if id == "":
		return
	if not _defeated_unit_ids.has(id):
		_defeated_unit_ids.append(id)
	# Non-lethal chapters never permadeath anyone — yields, not deaths (WO-4.1).
	if chapter.non_lethal:
		return
	if unit.team == 0 and not casual_mode and not _permadead_unit_ids.has(id):
		_permadead_unit_ids.append(id)


func _apply_casual_post_chapter_revival() -> void:
	var kept_defeated: Array[String] = []
	for id in _defeated_unit_ids:
		if not _is_player_unit_id(id) or id == (_lord_unit.unit_id() if _lord_unit != null and is_instance_valid(_lord_unit) else ""):
			kept_defeated.append(id)
	_defeated_unit_ids = kept_defeated


func _is_player_unit_id(id: String) -> bool:
	return Roster.all_player_ids().has(id)


# --- chapter dialogue (WO-4.1) ---------------------------------------------------

## Play a JSON dialogue script as a VN overlay and await its end. No-ops when
## dialogue is disabled (tests), the path is empty, or the script fails to parse.
func _play_dialogue(path: String) -> void:
	if not dialogue_enabled or path == "":
		return
	var script := DialogueScript.from_file(path)
	if not script.ok():
		push_warning("battle dialogue skipped (%s): %s" % [path, script.error])
		return
	_dialogue_playing = true
	if _cursor != null:
		_cursor.active = false
	var layer := CanvasLayer.new()
	layer.layer = 8  # above battle UI and splash
	add_child(layer)
	var scene := DialogueScene.new()
	layer.add_child(scene)
	scene.play(script)
	# An all-event/empty script finishes inside play(); awaiting then would hang.
	if not scene.is_finished():
		await scene.finished
	layer.queue_free()
	_dialogue_playing = false
	if _cursor != null and not _battle_over:
		_cursor.active = true


func _pop_text(world_pos: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(_grid.cell_size * 0.5))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.position = world_pos + Vector2(-20, -_grid.cell_size * 0.5)
	label.z_index = 100
	_units_root.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 60.0, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)


func _mov(u: Unit) -> int:
	return u.move_points()  # promotion-aware


func _weapon_ranges(u: Unit) -> Array:
	var w := u.weapon()
	if w == null:
		return []
	var ranges: Array = []
	for r in range(w.min_range, w.max_range + 1):
		ranges.append(r)
	return ranges if not ranges.is_empty() else demo_attack_ranges


func _make_context(u: Unit) -> BattleMoveContext:
	return BattleMoveContext.new(chapter, _terrain_db, _movement_type(u), occupancy(), u.team)


func _movement_type(u: Unit) -> ClassDef.MovementType:
	return u.movement_type()  # promotion-aware


# --- supports -----------------------------------------------------------------

func _setup_houses() -> void:
	_houses = {}
	for id in ["emberwing", "tidemark", "thornrook"]:
		var h: HouseDef = _try_load("res://data/houses/%s.tres" % id)
		if h != null:
			_houses[id] = h


func player_house() -> HouseDef:
	return _houses.get(player_house_id, null)


func enemy_house() -> HouseDef:
	return _houses.get(enemy_house_id, null)


func _house_for(unit: Unit) -> HouseDef:
	if unit.unit_def == null:
		return null
	return _houses.get(unit.unit_def.house_id, null)


## House Camaraderie bonus (§4) for a unit standing at `cell`: +hit/+avoid if a
## living housemate is within range. Returns the combat-bonus dict shape.
func _camaraderie_bonus_for(unit: Unit, cell: Vector2i) -> Dictionary:
	var house := _house_for(unit)
	if house == null:
		return Camaraderie.ZERO.duplicate()
	var housemate_cells: Array = []
	for other in _units:
		if other == unit or not other.is_alive() or other.unit_def == null:
			continue
		if other.unit_def.house_id == unit.unit_def.house_id:
			housemate_cells.append(other.cell)
	return Camaraderie.bonus(house, cell, housemate_cells)


func _setup_supports() -> void:
	# Every authored chain, from data — adding a pair is a .tres, not code (WO-4.2).
	_support_state = SupportRegistry.build_state()


func _combatant_for(unit: Unit, assumed_cell: Vector2i) -> Combatant:
	# AW-27: refresh aura bonuses from live positions before snapshotting stats
	# (stat auras fold into stat(), so this MUST precede to_combatant).
	_recompute_auras()
	var c := unit.to_combatant(_terrain_def_at(assumed_cell), _terrain_avoid_at(assumed_cell))
	# Support and House Camaraderie bonuses fold into the same combat inputs.
	var bonus := _support_bonus_for(unit, assumed_cell)
	var cam := _camaraderie_bonus_for(unit, assumed_cell)
	var sk := unit.skill_combat_bonus()  # WO-8.1: same fold as supports
	var aura := unit.aura_combat_bonus()  # WO-8.1 path, AW-27 source
	c.apply_support_bonus({
		"hit": int(bonus["hit"]) + int(cam["hit"]) + int(sk["hit"]) + int(aura["hit"]),
		"avoid": int(bonus["avoid"]) + int(cam["avoid"]) + int(sk["avoid"]) + int(aura["avoid"]),
		"damage": int(bonus["damage"]) + int(cam["damage"]) + int(sk["damage"]) + int(aura["damage"]),
		"crit": int(bonus["crit"]) + int(cam["crit"]) + int(sk["crit"]) + int(aura["crit"]),
	})
	return c


## AW-27: recompute every unit's aura bonuses from current positions. Each living
## unit projects its aura skills onto allied units within range (Manhattan),
## never onto itself — so a synergy like Pack Hunter needs the pair to stand
## close. Cheap (O(units²)); run before any Combatant is built or stats shown.
func _recompute_auras() -> void:
	for u in _units:
		u.clear_auras()
	for src in _units:
		if not src.is_alive():
			continue
		for sk in src.aura_skills():
			for u in _units:
				if u == src or u.team != src.team or not u.is_alive():
					continue
				if _manhattan(src.cell, u.cell) <= sk.aura_range:
					u.add_aura(sk)


func _support_bonus_for(unit: Unit, assumed_cell: Vector2i) -> Dictionary:
	var nearby_partner_ids: Array = []
	for other in _units:
		if other == unit or other.team != unit.team or not other.is_alive():
			continue
		if _manhattan(assumed_cell, other.cell) <= SupportState.BONUS_RANGE:
			nearby_partner_ids.append(other.unit_def.id)
	return _support_state.bonus_for_unit(unit.unit_def.id, nearby_partner_ids)


func _accrue_support_end_turn(unit: Unit) -> void:
	for other in _units:
		if other == unit or other.team != unit.team or not other.is_alive():
			continue
		if _manhattan(unit.cell, other.cell) <= SupportState.ACCRUAL_RANGE:
			_accrue_support_points(unit, other, SupportState.POINTS_END_TURN)


func _accrue_support_points(a: Unit, b: Unit, amount: int) -> void:
	var result := _support_state.add_points(a.unit_def.id, b.unit_def.id, amount)
	if result.get("ranked_up", false):
		var pair_id: String = result["pair_id"]
		var rank: String = result["new_rank"]
		EventBus.support_rank_up.emit(pair_id, rank)
		_pop_text(a.position, "Support %s!" % rank, Color(0.95, 0.75, 0.35))


# --- setup --------------------------------------------------------------------

func _setup_overlay() -> void:
	_overlay = GridOverlay.new()
	add_child(_overlay)
	_overlay.setup(_grid)


func _setup_range_overlay() -> void:
	_range_overlay = RangeOverlay.new()
	add_child(_range_overlay)
	_range_overlay.setup(_grid)


func _setup_threat_overlay() -> void:
	_threat_overlay = ThreatOverlay.new()
	add_child(_threat_overlay)
	_threat_overlay.setup(_grid)
	_threat_overlay.set_shown(false)


func _setup_units_root() -> void:
	_units_root = Node2D.new()
	_units_root.name = "Units"
	add_child(_units_root)


func _setup_cursor() -> void:
	_cursor = BattleCursor.new()
	add_child(_cursor)
	_cursor.cell_changed.connect(_on_cell_changed)
	_cursor.confirmed.connect(_on_cursor_confirmed)
	_cursor.cancelled.connect(_on_cursor_cancelled)
	_cursor.setup(_grid, Vector2i(_grid.width / 2, _grid.height / 2))


func _setup_juice() -> void:
	_juice_config = _try_load("res://data/config/juice.tres")
	if _juice_config == null:
		_juice_config = JuiceConfig.new()
	_splash = ClashSplash.new()
	var layer := CanvasLayer.new()
	layer.layer = 5  # above the battle, below menus
	add_child(layer)
	layer.add_child(_splash)
	_juice = JuiceController.new()
	add_child(_juice)
	_juice.setup(_juice_config, _camera, _units_root, _splash)


## Dark Deity-style camera (Neal 2026-07-05): battles play ZOOMED IN and the
## camera pans across maps larger than the screen, following the cursor (or
## the acting enemy). Small maps still fit; big maps scroll.
const TARGET_CELL_PX := 72.0

## When set (enemy phase), the camera follows this unit instead of the cursor.
var _camera_follow: Node2D = null
## While an on-map exchange plays, a tween owns the camera (push-in on the
## clash); the follow-lerp stands down.
var _combat_cam_active := false
var _combat_base_zoom := 1.0


func _setup_camera() -> void:
	_camera = Camera2D.new()
	add_child(_camera)
	var map := _grid.pixel_size()
	var vp := get_viewport_rect().size
	var fit := minf(vp.x / map.x, vp.y / map.y) * 0.96
	var z := maxf(fit, TARGET_CELL_PX / float(_grid.cell_size))
	_camera.zoom = Vector2(z, z)
	_camera.position = _camera_clamp(map * 0.5)
	_camera.make_current()


## Clamp a focus point so the view never leaves the map; axes where the whole
## map fits on screen stay centered.
func _camera_clamp(focus: Vector2) -> Vector2:
	var map := _grid.pixel_size()
	var half := get_viewport_rect().size * 0.5 / _camera.zoom.x
	var out := focus
	out.x = clampf(focus.x, half.x, map.x - half.x) if map.x > half.x * 2.0 else map.x * 0.5
	out.y = clampf(focus.y, half.y, map.y - half.y) if map.y > half.y * 2.0 else map.y * 0.5
	return out


## Cinematic push-in on a clash: frame the midpoint of attacker + defender and
## zoom in. The follow-lerp is suspended until _end_combat_cam.
func _begin_combat_cam(a: Unit, b: Unit) -> void:
	if _camera == null or _grid == null:
		return
	_combat_cam_active = true
	_combat_base_zoom = _camera.zoom.x
	var cs := float(_grid.cell_size)
	var target_zoom := _combat_base_zoom * 1.9
	var mid := (a.position + b.position) * 0.5 + Vector2(cs, cs) * 0.5
	# clamp with the TARGET zoom so we don't drift off-map
	var half := get_viewport_rect().size * 0.5 / target_zoom
	var map := _grid.pixel_size()
	mid.x = clampf(mid.x, half.x, map.x - half.x) if map.x > half.x * 2.0 else map.x * 0.5
	mid.y = clampf(mid.y, half.y, map.y - half.y) if map.y > half.y * 2.0 else map.y * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_camera, "zoom", Vector2.ONE * target_zoom, 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_camera, "position", mid, 0.22).set_trans(Tween.TRANS_SINE)
	await tw.finished


func _end_combat_cam() -> void:
	if _camera == null:
		return
	var tw := create_tween()
	tw.tween_property(_camera, "zoom", Vector2.ONE * _combat_base_zoom, 0.26).set_trans(Tween.TRANS_SINE)
	await tw.finished
	_combat_cam_active = false


func _process(delta: float) -> void:
	if not chapter.visits.is_empty():
		queue_redraw()  # visit markers pulse
	if _camera == null or _grid == null or _combat_cam_active:
		return
	var cs := float(_grid.cell_size)
	var focus: Vector2
	if _camera_follow != null and is_instance_valid(_camera_follow):
		focus = _camera_follow.position + Vector2(cs, cs) * 0.5
	elif _cursor != null:
		# the cursor node never moves — it draws at its cell; follow the cell
		focus = Vector2(_cursor.cell) * cs + Vector2(cs, cs) * 0.5
	else:
		return
	_camera.position = _camera.position.lerp(_camera_clamp(focus), minf(1.0, delta * 9.0))


func _setup_ui() -> void:
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)
	_debug_label = Label.new()
	_debug_label.position = Vector2(12, 10)
	_debug_label.add_theme_color_override("font_color", Color.WHITE)
	_debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_debug_label.add_theme_constant_override("outline_size", 6)
	_ui_layer.add_child(_debug_label)
	# Persistent objective readout so a first-time player knows what to do (WO-4.1).
	_objective_label = Label.new()
	_objective_label.text = _objective_text()
	_objective_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	_objective_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_objective_label.add_theme_constant_override("outline_size", 6)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_objective_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_objective_label.position = Vector2(get_viewport_rect().size.x - 420, 10)
	_objective_label.size = Vector2(400, 24)
	_ui_layer.add_child(_objective_label)
	# hover info box (playtest 3: point at a unit, see its stats)
	_hover_info = Control.new()
	_hover_info.position = Vector2(16, get_viewport_rect().size.y - 150)
	_hover_info.size = Vector2(250, 128)
	_hover_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_info.visible = false
	_hover_info.draw.connect(_draw_hover_info)
	_ui_layer.add_child(_hover_info)
	_forecast_panel = CombatForecastPanel.new()
	_forecast_panel.visible = false
	var vp := get_viewport_rect().size
	_forecast_panel.position = Vector2(vp.x - CombatForecastPanel.PANEL_SIZE.x - 20, vp.y - CombatForecastPanel.PANEL_SIZE.y - 20)
	_ui_layer.add_child(_forecast_panel)
	_turn_banner = TurnBanner.new()
	_turn_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_turn_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_turn_banner)
	_result_screen = ResultScreen.new()
	_result_screen.visible = false
	_result_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_screen.dismissed.connect(_on_result_dismissed)
	_ui_layer.add_child(_result_screen)
	_level_up_screen = LevelUpScreen.new()
	_level_up_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_level_up_screen)
	_menu = ChoiceMenu.new()
	_menu.chosen.connect(_on_menu_chosen)
	_menu.cancelled.connect(_on_menu_cancelled)
	_ui_layer.add_child(_menu)
	_stats_panel = UnitStatsPanel.new()
	_stats_panel.position = Vector2(40, vp.y * 0.5 - UnitStatsPanel.PANEL_SIZE.y * 0.5)
	_stats_panel.closed.connect(_on_stats_closed)
	_ui_layer.add_child(_stats_panel)
	_apply_house_theme()


## Flash the objective (field menu → Objective).
func _toast_objective() -> void:
	_turn_banner.announce(_objective_text(), true)


func _objective_text() -> String:
	match chapter.objective:
		ChapterDef.Objective.SEIZE:
			return "Objective: Seize the marked tile"
		ChapterDef.Objective.DEFEAT_BOSS:
			return "Objective: Defeat %s — or rout them all" % _boss_display_name()
		_:
			return "Objective: Rout the enemy"


func _boss_display_name() -> String:
	for spawn in chapter.enemy_spawns:
		if spawn != null and spawn.unit != null and spawn.unit.id == chapter.boss_unit_id:
			return spawn.unit.display_name
	return "the enemy commander"


## Pull every themed UI element's colors from the active HouseDefs. Swapping the
## player/enemy house resources re-themes the whole UI with no code change (§4).
func _apply_house_theme() -> void:
	var p := player_house()
	var e := enemy_house()
	var p_primary := p.primary_color if p != null else Color(0.30, 0.55, 0.95)
	var e_primary := e.primary_color if e != null else Color(0.90, 0.32, 0.30)
	_turn_banner.set_house_accents(p_primary, e_primary)
	if p != null:
		_menu.accent = p.secondary_color


func _on_result_dismissed() -> void:
	# Campaign flow (WO-4.3): victory returns to the hub with the roster changed;
	# defeat is a game over — back to the title to load or start again. A battle
	# scene run standalone (tests/dev) just reloads for another attempt.
	if Campaign.active:
		if _battle_victory:
			get_tree().change_scene_to_file("res://scenes/castle/castle.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/title/title.tscn")
	else:
		get_tree().reload_current_scene()


## WO-4.5: spawning lives in BattleUnitSpawner; the delegate keeps the
## call sites (_ready, save rebuild) unchanged.
var _spawner: BattleUnitSpawner


func _spawn_units() -> void:
	_spawner.spawn_units()


func _try_load(path: String) -> Resource:
	return load(path) if ResourceLoader.exists(path) else null


func _update_debug(cell: Vector2i) -> void:
	if _debug_label == null:
		return
	if not _grid.in_bounds(cell):
		_debug_label.text = "Cursor: off-map"
		return
	var info := _terrain_db.get_info(chapter.get_terrain(cell.x, cell.y))
	var move_txt := "impassable" if info.impassable else "move %d" % info.move_cost
	var occupant := unit_at(cell)
	var who := "  <%s %d/%d>" % [occupant.unit_def.display_name, occupant.current_hp, occupant.max_hp()] if occupant != null else ""
	_debug_label.text = "(%d, %d)  %s  [%s, def +%d, avoid +%d]%s" % [
		cell.x, cell.y, info.display_name, move_txt, info.defense, info.avoid, who,
	]


func _build_fallback_chapter() -> ChapterDef:
	var c := ChapterDef.new()
	c.id = "fallback"
	c.display_name = "Fallback Plains"
	c.width = 20
	c.height = 15
	c.fill(Terrain.Type.PLAINS)
	return c
