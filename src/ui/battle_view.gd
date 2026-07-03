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

var _menu: ChoiceMenu
var _menu_context := ""
var _menu_actions: Array = []      # action ids for the "action" context
var _menu_items: Array = []        # InventoryItems for item/equip/trade_give
var _menu_partners: Array[Unit] = []  # allies for trade_ally
var _trade_partner: Unit = null
var _battle_over := false
var _lord_unit: Unit = null
var _lord_alive := true


func _ready() -> void:
	if chapter == null:
		chapter = _build_fallback_chapter()
	_terrain_db = TerrainDB.create_default()
	_grid = chapter.make_grid()
	_rng = CombatRNG.new(combat_seed if combat_seed >= 0 else int(Time.get_ticks_usec()))
	_setup_overlay()
	_setup_range_overlay()
	_setup_threat_overlay()
	_setup_units_root()
	_setup_cursor()
	_setup_camera()
	_setup_ui()
	_spawn_demo_units()
	queue_redraw()
	_begin_player_phase()


func _draw() -> void:
	var size := _grid.pixel_size()
	if chapter.backdrop != null:
		draw_texture_rect(chapter.backdrop, Rect2(Vector2.ZERO, size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), backdrop_color, true)
	_draw_terrain_tints()
	_draw_seize_marker()


func _draw_seize_marker() -> void:
	if chapter.objective != ChapterDef.Objective.SEIZE:
		return
	var c := chapter.seize_cell
	if not _grid.in_bounds(c):
		return
	var cs := _grid.cell_size
	var rect := Rect2(c.x * cs + 6, c.y * cs + 6, cs - 12, cs - 12)
	draw_rect(rect, Color(0.95, 0.82, 0.35, 0.18), true)
	draw_rect(rect, Color(0.95, 0.82, 0.35, 0.9), false, 3.0)


func _draw_terrain_tints() -> void:
	var cs := _grid.cell_size
	for y in range(chapter.height):
		for x in range(chapter.width):
			var tint: Color = TERRAIN_TINTS.get(chapter.get_terrain(x, y), Color(0, 0, 0, 0))
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
	_units.append(u)
	return u


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
		# Cancel the attack but keep the move: end the action as a "wait".
		_finish_action()
	elif _phase == Phase.SELECTED:
		_deselect()


func _try_select(cell: Vector2i) -> void:
	var u := unit_at(cell)
	if u == null or u.team != 0 or u.has_acted or not u.is_alive():
		return
	_selected = u
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
	_menu_actions.append("wait"); labels.append("Wait")
	_open_menu("action", "Action", labels)


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


func _on_menu_cancelled() -> void:
	if _busy:
		return
	match _menu_context:
		"action":
			_menu.close()
			_finish_action()          # cancel on the command menu = wait
		"trade_give":
			_menu.close()
			_finish_action()          # done handing items over
		_:
			_open_action_menu()       # item / equip / trade_ally -> back to action


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
		_finish_action()  # confirming off-target = wait
		return
	if _targeting_heal:
		await _execute_heal(_selected, target)
	else:
		await _execute_attack(_selected, target)
	_finish_action()


func _show_forecast_for(enemy: Unit) -> void:
	var attacker := _selected
	var dist := _manhattan(attacker.cell, enemy.cell)
	var atk_c := attacker.to_combatant(_terrain_def_at(attacker.cell), _terrain_avoid_at(attacker.cell))
	var def_c := enemy.to_combatant(_terrain_def_at(enemy.cell), _terrain_avoid_at(enemy.cell))
	var ex := CombatForecast.exchange(atk_c, def_c, dist)
	_forecast_panel.show_forecast(attacker, enemy, ex)


func _execute_attack(attacker: Unit, defender: Unit) -> void:
	var was_busy := _busy  # keep busy set if we're inside the enemy phase
	_busy = true
	_forecast_panel.hide_panel()
	var dist := _manhattan(attacker.cell, defender.cell)
	var atk_level := attacker.level
	var def_level := defender.level
	var atk_c := attacker.to_combatant(_terrain_def_at(attacker.cell), _terrain_avoid_at(attacker.cell))
	var def_c := defender.to_combatant(_terrain_def_at(defender.cell), _terrain_avoid_at(defender.cell))
	var result := CombatResolver.resolve(atk_c, def_c, dist, _rng)

	for strike in result.strikes:
		# Route by the counter flag, not the display name (names aren't unique —
		# e.g. multiple "Tidemark Soldier"). A counter strike hits the attacker.
		var target := attacker if strike.is_counter else defender
		_play_strike(strike, target)
		if strike_delay > 0.0:
			await get_tree().create_timer(strike_delay).timeout
		else:
			await get_tree().process_frame
		if not target.is_alive():
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
	_pop_text(unit.position, "X", Color(0.9, 0.2, 0.2))
	EventBus.unit_died.emit(unit)
	if unit == _lord_unit:
		_lord_alive = false
	_units.erase(unit)
	if unit == _selected:
		_selected = null
	unit.queue_free()


func _finish_action() -> void:
	if _selected != null and is_instance_valid(_selected):
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
	_deselect()
	if _threat_overlay.is_shown():
		_refresh_threat_overlay()  # enemies moved last phase
	_turn_banner.announce("Player Phase — Round %d" % _turn.round_number, true)


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
	)
	if outcome == ObjectiveResolver.Outcome.VICTORY:
		_end_battle(true)
	elif outcome == ObjectiveResolver.Outcome.DEFEAT:
		_end_battle(false)


func _end_battle(victory: bool) -> void:
	if _battle_over:
		return
	_battle_over = true
	_deselect()
	_range_overlay.clear()
	if victory:
		EventBus.battle_won.emit()
		_result_screen.show_victory()
	else:
		_result_screen.show_defeat()


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

	var decision := AIBrain.decide(enemy, _units, chapter, _terrain_db, effective)
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


func _setup_camera() -> void:
	var camera := Camera2D.new()
	add_child(camera)
	var map := _grid.pixel_size()
	camera.position = map * 0.5
	var vp := get_viewport_rect().size
	var fit := minf(vp.x / map.x, vp.y / map.y) * 0.96
	camera.zoom = Vector2(fit, fit)
	camera.make_current()


func _setup_ui() -> void:
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)
	_debug_label = Label.new()
	_debug_label.position = Vector2(12, 10)
	_debug_label.add_theme_color_override("font_color", Color.WHITE)
	_debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_debug_label.add_theme_constant_override("outline_size", 6)
	_ui_layer.add_child(_debug_label)
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


func _on_result_dismissed() -> void:
	# Reload the battle for another attempt (title/hub flow arrives in WO-4.3).
	get_tree().reload_current_scene()


func _spawn_demo_units() -> void:
	var myrmidon: ClassDef = _try_load("res://data/classes/myrmidon.tres")
	var knight: ClassDef = _try_load("res://data/classes/knight.tres")
	var soldier: ClassDef = _try_load("res://data/classes/soldier.tres")
	var sword: WeaponDef = _try_load("res://data/weapons/iron_sword.tres")
	var lance: WeaponDef = _try_load("res://data/weapons/iron_lance.tres")
	var axe: WeaponDef = _try_load("res://data/weapons/iron_axe.tres")
	var heal_staff: WeaponDef = _try_load("res://data/weapons/heal.tres")
	var vulnerary: ItemDef = _try_load("res://data/items/vulnerary.tres")
	var seal: ItemDef = _try_load("res://data/items/promotion_seal.tres")
	if myrmidon == null:
		return
	var kael_def := _demo_unit("kael", "Kael", myrmidon, sword, 0, 6, {"spd": 12, "skl": 12, "str": 8})
	kael_def.is_lord = true  # demo lord: his death is a game over (§3)
	if axe != null:
		kael_def.extra_weapons = [axe]      # a second weapon so Equip is available
	kael_def.starting_items = []
	if vulnerary != null:
		kael_def.starting_items.append(vulnerary)
	if seal != null:
		kael_def.starting_items.append(seal)   # Master Seal — promote at level 10+
	_lord_unit = add_unit(kael_def, Vector2i(3, 7))
	var brenna_def := _demo_unit("brenna", "Brenna", knight, lance, 0, 5, {"def": 10, "hp": 28, "spd": 5})
	if vulnerary != null:
		brenna_def.starting_items = [vulnerary]
	add_unit(brenna_def, Vector2i(4, 9))
	if heal_staff != null:
		add_unit(_demo_unit("wren", "Wren", _cleric(), heal_staff, 0, 5, {"mag": 6, "hp": 20, "def": 3}), Vector2i(3, 9))
	# One of each AI tier (§5): an aggressor advances, a sentinel holds until
	# threatened, a boss holds the fort at (16,4).
	add_unit(_demo_unit("tide_a", "Tidemark Soldier", soldier, lance, 1, 5, {"spd": 6}), Vector2i(6, 7))
	var sentinel := _demo_unit("tide_b", "Tidemark Sentinel", soldier, sword, 1, 5, {"spd": 7, "hp": 22})
	sentinel.ai_behavior = AIBrain.Behavior.SENTINEL
	add_unit(sentinel, Vector2i(11, 8))
	var boss := _demo_unit("serra", "Serra", soldier, lance, 1, 5, {"spd": 6, "hp": 30, "def": 8})
	boss.ai_behavior = AIBrain.Behavior.BOSS
	add_unit(boss, Vector2i(16, 4))  # the fort tile


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
	return d


## Placeholder healer class (a real Cleric ClassDef .tres lands with the roster WOs).
func _cleric() -> ClassDef:
	var c := ClassDef.new()
	c.id = "cleric"
	c.display_name = "Cleric"
	c.token_letter = "C"
	c.movement_type = ClassDef.MovementType.FOOT
	return c


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
