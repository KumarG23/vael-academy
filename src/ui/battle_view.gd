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

const TERRAIN_TINTS := {
	Terrain.Type.PLAINS: Color(0.0, 0.0, 0.0, 0.0),
	Terrain.Type.FOREST: Color(0.20, 0.45, 0.20, 0.35),
	Terrain.Type.MOUNTAIN: Color(0.45, 0.36, 0.28, 0.45),
	Terrain.Type.FORT: Color(0.70, 0.62, 0.25, 0.40),
	Terrain.Type.WALL: Color(0.10, 0.10, 0.12, 0.75),
	Terrain.Type.WATER: Color(0.15, 0.35, 0.60, 0.55),
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
## DEFEAT_BOSS objective (WO-4.1): the chapter's boss and whether it still stands.
var _boss_unit: Unit = null
var _boss_alive := true
var _boss_quote_played := false
var _dialogue_playing := false
var _objective_label: Label
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
	_terrain_db = TerrainDB.create_default()
	_grid = chapter.make_grid()
	_rng = CombatRNG.new(combat_seed if combat_seed >= 0 else int(Time.get_ticks_usec()))
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
	queue_redraw()
	_begin_battle()


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
## doctrine); the tint fallback keeps working without art. With tiles
## active, only WALL still tints (no tileset for it yet).
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
			if tiles_active and t != Terrain.Type.WALL:
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
	if _phase == Phase.TARGETING:
		var enemy := unit_at(cell)
		if enemy != null and _targets.has(enemy):
			_show_forecast_for(enemy)


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
	if u == null or not u.is_alive():
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


# --- command menu -------------------------------------------------------------

func _open_action_menu() -> void:
	var unit := _selected
	var labels: Array = []
	_menu_actions = []
	if unit.can_attack() and not _attackable_targets(unit.cell, unit).is_empty():
		_menu_actions.append("attack"); labels.append("Attack")
	var w := unit.weapon()
	if w != null and w.is_staff() and not _heal_targets(unit.cell, unit).is_empty():
		_menu_actions.append("heal"); labels.append("Heal")
	if not _usable_consumables(unit).is_empty():
		_menu_actions.append("item"); labels.append("Item")
	if not _adjacent_allies(unit).is_empty():
		_menu_actions.append("trade"); labels.append("Trade")
	if _weapon_count(unit) > 1:
		_menu_actions.append("equip"); labels.append("Equip")
	if not _unviewed_conversations(unit.unit_def.id).is_empty():
		_menu_actions.append("supports"); labels.append("Supports")
	_menu_actions.append("stats"); labels.append("Stats")
	_menu_actions.append("wait"); labels.append("Wait")
	_open_menu("action", "Action", labels)


## Unlocked support conversations this unit hasn't watched yet — the in-battle
## Supports menu only offers new scenes; the Common Hall keeps the full archive.
func _unviewed_conversations(unit_id: String) -> Array:
	var out: Array = []
	for entry in _support_state.unlocked_conversations_for_unit(unit_id):
		if not bool(entry.get("viewed", false)):
			out.append(entry)
	return out


func _open_menu(context: String, title: String, labels: Array) -> void:
	_menu_context = context
	_phase = Phase.MENU
	_cursor.active = false
	_menu.open(title, labels, Vector2(40, 110))


func _on_menu_chosen(index: int) -> void:
	if _busy:
		return
	match _menu_context:
		"action":
			await _do_action(_menu_actions[index])
		"item":
			await _use_consumable(index)
		"equip":
			_do_equip(index)
		"trade_ally":
			_pick_trade_ally(index)
		"trade_give":
			_do_give(index)
		"supports":
			_view_support_entry(index)


func _on_menu_cancelled() -> void:
	if _busy:
		return
	match _menu_context:
		"action":
			_undo_move_and_deselect()  # cancel the command menu = take the move back
		_:
			_open_action_menu()       # any submenu -> back to the command menu


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


func _do_action(id: String) -> void:
	match id:
		"attack":
			_menu.close()
			_cursor.active = true
			_begin_targeting(false)
		"heal":
			_menu.close()
			_cursor.active = true
			_begin_targeting(true)
		"item":
			_open_item_menu()
		"trade":
			_open_trade_ally_menu()
		"equip":
			_open_equip_menu()
		"supports":
			_open_support_menu()
		"stats":
			_menu.close()
			_stats_from_menu = true
			_open_stats_for(_selected)
		"wait":
			_menu.close()
			_finish_action()


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


## Consumables the unit can meaningfully use right now: a Vulnerary only when
## damaged, a Promotion item only when the unit is eligible to promote (§3).
func _usable_consumables(unit: Unit) -> Array[InventoryItem]:
	var out: Array[InventoryItem] = []
	for it in unit.inventory.consumables():
		var def := it.item()
		if def.heals() and unit.current_hp < unit.max_hp():
			out.append(it)
		elif def.is_promotion() and unit.can_promote():
			out.append(it)
	return out


func _open_item_menu() -> void:
	_menu_items = _usable_consumables(_selected)
	var labels: Array = []
	for it in _menu_items:
		labels.append("%s (%d)" % [it.display_name(), it.uses])
	_open_menu("item", "Item", labels)


func _use_consumable(index: int) -> void:
	var item: InventoryItem = _menu_items[index]
	var def: ItemDef = item.item()
	# Only usable items reach this menu.
	if def.is_promotion():
		var result := _selected.promote()
		_pop_text(_selected.position, "→ %s!" % result["class_name"], Color(0.95, 0.82, 0.35))
	else:
		var healed := _selected.heal(def.power)
		_pop_text(_selected.position, "+%d" % healed, Color(0.4, 0.9, 0.5))
	_selected.inventory.use_consumable(item)
	_menu.close()
	_finish_action()


func _open_equip_menu() -> void:
	_menu_items = []
	var labels: Array = []
	for it in _selected.inventory.items:
		if it.is_weapon():
			_menu_items.append(it)
			var eq := " *" if it == _selected.inventory.equipped_weapon_item() else ""
			labels.append("%s (%d)%s" % [it.display_name(), it.uses, eq])
	_open_menu("equip", "Equip", labels)


func _do_equip(index: int) -> void:
	_selected.inventory.equip(_menu_items[index])
	_open_action_menu()  # equipping is free — return to the command menu


func _open_trade_ally_menu() -> void:
	_menu_partners = _adjacent_allies(_selected)
	var labels: Array = []
	for a in _menu_partners:
		labels.append("%s (%d items)" % [a.unit_def.display_name, a.inventory.size()])
	_open_menu("trade_ally", "Trade with", labels)


func _pick_trade_ally(index: int) -> void:
	_trade_partner = _menu_partners[index]
	_open_trade_give_menu()


func _open_trade_give_menu() -> void:
	_menu_items = _selected.inventory.items.duplicate()
	var labels: Array = []
	for it in _menu_items:
		labels.append("Give %s" % it.display_name())
	_open_menu("trade_give", "Give to %s" % _trade_partner.unit_def.display_name, labels)


func _do_give(index: int) -> void:
	var item: InventoryItem = _menu_items[index]
	if _selected.inventory.transfer_to(item, _trade_partner.inventory):
		_pop_text(_trade_partner.position, "got %s" % item.display_name(), Color(0.7, 0.85, 1.0))
	# Stay in the give menu so multiple items can be handed over; cancel finishes.
	if _selected.inventory.is_empty():
		_menu.close()
		_finish_action()
	else:
		_open_trade_give_menu()


func _open_support_menu() -> void:
	_support_menu_entries = _unviewed_conversations(_selected.unit_def.id)
	var labels: Array = []
	for entry in _support_menu_entries:
		labels.append(entry["label"])
	if labels.is_empty():
		_open_action_menu()
	else:
		_open_menu("supports", "Supports", labels)


## Play the chosen support conversation as a VN overlay (WO-4.2), then return to
## the command menu — viewing a conversation doesn't consume the unit's action.
## Once watched it stops appearing in battle (WO-4.4); the Common Hall keeps it.
func _view_support_entry(index: int) -> void:
	var entry: Dictionary = _support_menu_entries[index]
	var path := str(entry.get("path", ""))
	_menu.close()
	if dialogue_enabled and path != "" and FileAccess.file_exists(path):
		await _play_dialogue(path)
		_support_state.mark_viewed(str(entry["pair_id"]), str(entry["rank"]))
	else:
		_pop_text(_selected.position, "%s ready" % entry["label"], Color(0.95, 0.75, 0.35))
	_open_action_menu()


# --- unit inspection (WO-4.4) ------------------------------------------------------

func _open_stats_for(unit: Unit) -> void:
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


func _weapon_count(unit: Unit) -> int:
	var n := 0
	for it in unit.inventory.items:
		if it.is_weapon():
			n += 1
	return n


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


func _execute_attack(attacker: Unit, defender: Unit) -> void:
	var was_busy := _busy  # keep busy set if we're inside the enemy phase
	_busy = true
	_forecast_panel.hide_panel()
	# Boss quote (WO-4.1): once, the first time the boss enters combat.
	if not _boss_quote_played and _boss_unit != null and (attacker == _boss_unit or defender == _boss_unit):
		_boss_quote_played = true
		await _play_dialogue(chapter.boss_quote_dialogue)
	var dist := _manhattan(attacker.cell, defender.cell)
	var atk_level := attacker.level
	var def_level := defender.level
	var atk_c := _combatant_for(attacker, attacker.cell)
	var def_c := _combatant_for(defender, defender.cell)
	var result := CombatResolver.resolve(atk_c, def_c, dist, _rng)

	for strike in result.strikes:
		# Route by the counter flag, not the display name (names aren't unique —
		# e.g. multiple "Tidemark Soldier"). A counter strike hits the attacker.
		var striker := defender if strike.is_counter else attacker
		var target := attacker if strike.is_counter else defender
		var lethal := strike.connected and strike.defender_hp_after <= 0
		if strike_delay > 0.0 and _juice != null:
			await _juice.play_strike(striker, target, strike, lethal)  # applies hp at impact
		else:
			_play_strike(strike, target)
			await get_tree().process_frame
		if not target.is_alive():
			if strike_delay > 0.0 and _juice != null:
				await _juice.play_death(target)
			_kill(target)

	# Weapon durability: 1 use per combat per side that swung — GBA-accurate
	# (a doubling unit still spends only one use, not one per strike). The attacker
	# always swung; the defender swung only if it countered.
	var defender_countered := false
	for s in result.strikes:
		if s.is_counter:
			defender_countered = true
			break
	if is_instance_valid(attacker):
		_spend_weapon(attacker)
	if is_instance_valid(defender) and defender_countered:
		_spend_weapon(defender)

	# XP: attacker for its strikes, defender for its counter (players only, §3/§4).
	# A slain combatant has been freed by now — guard before passing it on.
	if is_instance_valid(attacker):
		await _award_combat_xp(attacker, def_level, _side_connected(result, false), result.defender_defeated())
	if is_instance_valid(defender):
		await _award_combat_xp(defender, atk_level, _side_connected(result, true), result.attacker_defeated())

	_busy = was_busy
	_check_objective()


func _execute_heal(healer: Unit, ally: Unit) -> void:
	var was_busy := _busy
	_busy = true
	var amount := healer.weapon().heal_amount + healer.stat("mag")
	var healed := ally.heal(amount)
	_pop_text(ally.position, "+%d" % healed, Color(0.4, 0.9, 0.5))
	_accrue_support_points(healer, ally, SupportState.POINTS_HEAL)
	_spend_weapon(healer)  # staves have uses too
	await _award_heal_xp(healer, healed)
	_busy = was_busy
	_check_objective()


## Spend one use of `unit`'s equipped weapon and announce a break.
func _spend_weapon(unit: Unit) -> void:
	var broke := unit.spend_weapon_use()
	if broke != null:
		_pop_text(unit.position, "%s broke!" % broke.display_name(), Color(0.9, 0.7, 0.3))


## Whether one side landed a hit. `counter_side` false = the initiating attacker's
## strikes; true = the defender's counter strikes.
func _side_connected(result: CombatResult, counter_side: bool) -> bool:
	for s in result.strikes:
		if s.is_counter == counter_side and s.connected:
			return true
	return false


func _award_combat_xp(unit: Unit, opponent_level: int, connected: bool, killed: bool) -> void:
	if not is_instance_valid(unit) or not unit.is_alive() or unit.team != 0:
		return
	var amount := CombatXP.award(unit.level, opponent_level, connected, killed)
	await _apply_xp(unit, amount)


func _award_heal_xp(unit: Unit, healed: int) -> void:
	if unit.team != 0:
		return
	await _apply_xp(unit, CombatXP.award_heal(healed))


func _apply_xp(unit: Unit, amount: int) -> void:
	for result in unit.gain_xp(amount, _rng):
		await _level_up_screen.play(unit.unit_def.display_name, result)


func _play_strike(strike: StrikeResult, target: Unit) -> void:
	if not strike.connected:
		_pop_text(target.position, "Miss", Color(0.85, 0.85, 0.9))
		target.flash()
		return
	target.set_hp(strike.defender_hp_after)
	var text := ("CRIT " + str(strike.damage)) if strike.was_crit else str(strike.damage)
	var color := Color(1.0, 0.85, 0.2) if strike.was_crit else Color(1.0, 0.4, 0.35)
	_pop_text(target.position, text, color)


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
	for u in _living_units_on_team(0):
		u.has_acted = false
		u.queue_redraw()
	_apply_terrain_heal(0)
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
	_turn_banner.announce("Enemy Phase", false)
	# Deterministic acting order (§5): stable by board position.
	var enemies := _living_units_on_team(1)
	enemies.sort_custom(func(a, b): return AIBrain._cell_key(a.cell) < AIBrain._cell_key(b.cell))
	for enemy in enemies:
		if _battle_over:
			break
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
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
	return Roster.PLAYER_IDS.has(id)


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
	var c := unit.to_combatant(_terrain_def_at(assumed_cell), _terrain_avoid_at(assumed_cell))
	# Support and House Camaraderie bonuses fold into the same combat inputs.
	var bonus := _support_bonus_for(unit, assumed_cell)
	var cam := _camaraderie_bonus_for(unit, assumed_cell)
	c.apply_support_bonus({
		"hit": int(bonus["hit"]) + int(cam["hit"]),
		"avoid": int(bonus["avoid"]) + int(cam["avoid"]),
		"damage": int(bonus["damage"]) + int(cam["damage"]),
		"crit": int(bonus["crit"]) + int(cam["crit"]),
	})
	return c


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


func _setup_camera() -> void:
	_camera = Camera2D.new()
	add_child(_camera)
	var map := _grid.pixel_size()
	_camera.position = map * 0.5
	var vp := get_viewport_rect().size
	var fit := minf(vp.x / map.x, vp.y / map.y) * 0.96
	_camera.zoom = Vector2(fit, fit)
	_camera.make_current()


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
			get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/title/title.tscn")
	else:
		get_tree().reload_current_scene()


func _spawn_units() -> void:
	# Player roster (shared with the Academy Hub, §4 / WO-3.5). Chapters author
	# their own deploy cells (WO-4.1); the test map falls back to Roster's.
	var cells: Dictionary = chapter.deploy_cells if not chapter.deploy_cells.is_empty() else Roster.deploy_cells()
	for def in Roster.player_units():
		var u := add_unit(def, cells.get(def.id, Vector2i.ZERO))
		if def.is_lord:
			_lord_unit = u
	if chapter.enemy_spawns.is_empty():
		_spawn_demo_enemies()
	else:
		# Authored enemy force (WO-4.1). Defs are duplicated so runtime state
		# never leaks into the cached .tres resources.
		for spawn in chapter.enemy_spawns:
			if spawn == null or spawn.unit == null:
				continue
			var u := add_unit(spawn.unit.duplicate(), spawn.cell)
			if chapter.boss_unit_id != "" and u.unit_id() == chapter.boss_unit_id:
				_boss_unit = u
	# When deployed from the hub, overlay campaign progression + supports (WO-3.5).
	if Campaign.active:
		_apply_campaign_state()


## Legacy demo force for chapters without authored spawns (the WO-0.2 test map).
## One of each AI tier (§5): an aggressor advances, a sentinel holds until
## threatened, a boss holds the fort at (16,4).
func _spawn_demo_enemies() -> void:
	var soldier: ClassDef = _try_load("res://data/classes/soldier.tres")
	var sword: WeaponDef = _try_load("res://data/weapons/iron_sword.tres")
	var lance: WeaponDef = _try_load("res://data/weapons/iron_lance.tres")
	if soldier == null:
		return
	add_unit(_demo_unit("tide_a", "Tidemark Soldier", soldier, lance, 1, 5, {"spd": 6}), Vector2i(6, 7))
	var sentinel := _demo_unit("tide_b", "Tidemark Sentinel", soldier, sword, 1, 5, {"spd": 7, "hp": 22})
	sentinel.ai_behavior = AIBrain.Behavior.SENTINEL
	add_unit(sentinel, Vector2i(11, 8))
	var boss := _demo_unit("serra", "Serra", soldier, lance, 1, 5, {"spd": 6, "hp": 30, "def": 8})
	boss.ai_behavior = AIBrain.Behavior.BOSS
	add_unit(boss, Vector2i(16, 4))  # the fort tile


## Overlay between-battle campaign state onto the freshly-spawned player units.
func _apply_campaign_state() -> void:
	casual_mode = Campaign.casual
	_support_state.apply_save_state(Campaign.support_save)
	for u in _units:
		if u.team == 0:
			Campaign.apply_to_unit(u)


func _demo_unit(
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
	d.house_id = player_house_id if team == 0 else enemy_house_id  # overridable per unit
	return d


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
