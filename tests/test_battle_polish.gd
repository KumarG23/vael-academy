extends GutTest
## WO-4.4 polish: FE cancel semantics (cancel undoes the move instead of wasting
## the turn), the Stats panel, viewed-once support conversations, and the
## ChoiceMenu width fix. From Neal's playtest notes.

var _view: Node2D


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/battle/battle.tscn")
	_view = scene.instantiate()
	_view.strike_delay = 0.0
	_view.combat_seed = 3
	add_child_autofree(_view)
	await wait_physics_frames(2)


func _wait_menu(max_frames := 600) -> void:
	var n := 0
	while not _view._menu.visible and n < max_frames:
		await wait_physics_frames(1)
		n += 1


# --- cancel semantics -------------------------------------------------------------

func test_cancelling_the_command_menu_undoes_the_move():
	var kai: Unit = _view.unit_by_id("kai")
	assert_eq(kai.cell, Vector2i(2, 7))
	_view._on_cursor_confirmed(Vector2i(2, 7))      # select
	_view._handle_selected_confirm(Vector2i(2, 6))  # move one tile
	await _wait_menu()
	assert_true(_view._menu.visible, "command menu opened after the move")

	_view._on_menu_cancelled()
	assert_eq(kai.cell, Vector2i(2, 7), "cancel took the move back")
	assert_false(kai.has_acted, "the unit may still act this turn")
	assert_eq(_view._phase, _view.Phase.IDLE, "back to a clean idle state")


func test_cancelling_targeting_returns_to_the_command_menu():
	var kael: Unit = _view.unit_by_id("kael")
	_view._on_cursor_confirmed(Vector2i(3, 7))      # select Kael
	_view._handle_selected_confirm(Vector2i(5, 7))  # move beside the soldier at (6,7)
	await _wait_menu()
	var idx: int = _view._menu_actions.find("attack")
	assert_true(idx >= 0, "Attack offered beside an enemy")
	await _view._on_menu_chosen(idx)                # -> weapon picker (Kael) or targeting
	# AW-26: Kael carries two physical weapons, so Attack opens a weapon picker first.
	if _view._menu_context in ["attack_weapon", "magic_spell"]:
		await _view._on_menu_chosen(0)              # equipped weapon -> targeting + forecast

	_view._on_cursor_cancelled(Vector2i.ZERO)
	assert_eq(_view._menu_context, "action", "targeting cancel reopens the command menu")
	assert_false(kael.has_acted, "nothing was spent")
	assert_eq(kael.cell, Vector2i(5, 7), "the move itself is kept at this stage")

	# Cancelling the command menu from here still takes the whole move back.
	_view._on_menu_cancelled()
	assert_eq(kael.cell, Vector2i(3, 7), "menu cancel undoes the move")
	assert_false(kael.has_acted)


# --- stats panel -------------------------------------------------------------------

func test_stats_action_opens_the_panel_and_returns_to_the_menu():
	_view._on_cursor_confirmed(Vector2i(2, 7))
	_view._handle_selected_confirm(Vector2i(2, 7))  # stay put
	await _wait_menu()
	var idx: int = _view._menu_actions.find("stats")
	assert_true(idx >= 0, "Stats is always on the command menu")
	await _view._on_menu_chosen(idx)
	assert_true(_view._stats_panel.is_shown(), "stats panel opened")

	_view._stats_panel.close()
	await wait_physics_frames(1)
	assert_true(_view._menu.visible, "closing the panel returns to the command menu")
	assert_eq(_view._menu_context, "action")


## AW-73: first press on a foe shows its danger zone; the second opens its sheet.
func test_selecting_an_enemy_shows_its_danger_zone_then_inspects_it():
	var foe: Unit = _view.unit_at(Vector2i(6, 7))  # the Tidemark soldier
	_view._try_select(Vector2i(6, 7))
	assert_false(_view._stats_panel.is_shown(), "first press is the range, not the sheet")
	assert_eq(_view._danger_unit, foe, "this foe is under study")
	assert_true(_view._threat_overlay.is_shown(), "its reach is painted")
	assert_false(_view._threat_overlay._tiles.is_empty(), "with real tiles")
	_view._try_select(Vector2i(6, 7))
	assert_true(_view._stats_panel.is_shown(), "the second press opens the sheet")
	_view._stats_panel.close()
	await wait_physics_frames(1)
	assert_true(_view._cursor.active, "cursor control returns after inspecting")


## AW-73: commanding your own unit, or Esc, puts the studied range away.
func test_danger_zone_clears_when_you_move_on():
	_view._try_select(Vector2i(6, 7))
	assert_true(_view._threat_overlay.is_shown())
	_view._try_select(Vector2i(2, 7))  # pick up a player unit
	assert_null(_view._danger_unit, "study over")
	assert_false(_view._threat_overlay.is_shown(), "the red carpet rolls up")
	_view._deselect()
	_view._try_select(Vector2i(6, 7))
	_view._on_cursor_cancelled(Vector2i(6, 7))  # Esc
	assert_false(_view._threat_overlay.is_shown(), "Esc clears it too")


## AW-73: the H union view survives a single-foe study — it comes back after.
func test_h_union_mode_restores_after_a_single_foe_study():
	_view._toggle_threat_overlay()  # H: everyone's reach
	var union_size: int = _view._threat_overlay._tiles.size()
	_view._try_select(Vector2i(6, 7))  # study one foe
	assert_true(_view._threat_overlay._tiles.size() <= union_size, "one foe's reach is narrower")
	_view._on_cursor_cancelled(Vector2i(6, 7))
	assert_true(_view._threat_overlay.is_shown(), "the union view returns")
	assert_eq(_view._threat_overlay._tiles.size(), union_size, "at full breadth")
	_view._toggle_threat_overlay()  # H off again


func test_stats_panel_describes_a_healer():
	var wren: Unit = _view.unit_by_id("wren")
	var lines := UnitStatsPanel._build_lines(wren)
	var text := " ".join(lines)
	assert_string_contains(text, "Healer", "Wren's role is spelled out")
	assert_string_contains(text, "cannot attack", "staff limitation is explicit")


# --- viewed-once supports ------------------------------------------------------------

func test_supports_stop_appearing_in_battle_once_viewed():
	_view.dialogue_enabled = true
	_view._support_state.add_points("kai", "kael", 20)  # unlock C
	var kai: Unit = _view.unit_by_id("kai")
	_view._selected = kai
	assert_eq(_view._unviewed_conversations("kai").size(), 1)
	_view._support_menu_entries = _view._unviewed_conversations("kai")
	_view._view_support_entry(0)
	await wait_physics_frames(1)
	# Drive the conversation to its end.
	var stack: Array = [_view]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is DialogueScene:
			var guard := 0
			while not n.is_finished() and guard < 200:
				n.advance()
				guard += 1
			break
		for child in n.get_children():
			stack.append(child)
	await wait_physics_frames(2)
	assert_eq(_view._unviewed_conversations("kai").size(), 0, "watched scene stops being offered")
	assert_true(_view._support_state.is_viewed("kai_kael", "C"))


func test_viewed_flags_survive_save_state_round_trip():
	var state := SupportState.new()
	var chain: SupportChainDef = load("res://data/supports/kai_kael.tres")
	state.add_chain(chain)
	state.add_points("kai", "kael", 20)
	state.mark_viewed("kai_kael", "C")
	var restored := SupportState.new()
	restored.add_chain(chain)
	restored.apply_save_state(state.save_state())
	assert_true(restored.is_viewed("kai_kael", "C"), "viewed flag persists")
	assert_true(bool(restored.unlocked_conversations_for_unit("kai")[0]["viewed"]))


# --- menu width ---------------------------------------------------------------------

func test_choice_menu_widens_for_long_labels():
	var menu := ChoiceMenu.new()
	add_child_autofree(menu)
	menu.open("Load Game", ["Slot 0 — mock_battle (Classic, extra long label)"], Vector2.ZERO)
	assert_gt(menu._width, ChoiceMenu.WIDTH, "menu grows to fit its labels")
	menu.open("A", ["ok"], Vector2.ZERO)
	assert_eq(menu._width, ChoiceMenu.WIDTH, "short menus keep the base width")
