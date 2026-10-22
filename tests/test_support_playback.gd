extends GutTest
## WO-4.2: the support-chain registry, the authored Kai–Kael conversations, and
## conversation playback from the Common Hall and the in-battle Supports menu.

const BAD_DIALOGUE := "user://issue3_support_malformed.json"
const EMPTY_DIALOGUE := "user://issue3_support_empty.json"
const MISSING_DIALOGUE := "user://issue3_support_missing.json"


func before_each() -> void:
	_write(BAD_DIALOGUE, "[{\"speaker\":\"Kai\",")  # malformed JSON
	_write(EMPTY_DIALOGUE, "[]")
	_remove(MISSING_DIALOGUE)


func after_each() -> void:
	Campaign.reset_new_game(false)
	for path in [BAD_DIALOGUE, EMPTY_DIALOGUE, MISSING_DIALOGUE]:
		_remove(path)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _remove(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute)


func _entry_with_path(path: String) -> Dictionary:
	return {"pair_id": "kai_kael", "rank": "C", "label": "Kai & Kael — C", "path": path}


func _find_dialogue(node: Node) -> DialogueScene:
	if node is DialogueScene:
		return node
	for child in node.get_children():
		var found := _find_dialogue(child)
		if found != null:
			return found
	return null


func _drive_to_end(dlg: DialogueScene) -> void:
	var guard := 0
	while not dlg.is_finished() and guard < 200:
		dlg.advance()
		guard += 1


# --- registry ----------------------------------------------------------------

func test_registry_loads_all_authored_chains():
	var chains := SupportRegistry.load_all()
	assert_gt(chains.size(), 0, "at least one chain authored")
	var ids: Array = []
	for c in chains:
		ids.append(c.pair_id())
	assert_has(ids, "kai_kael", "the Kai–Kael chain is found from data alone")


func test_registry_handles_a_missing_directory():
	assert_eq(SupportRegistry.load_all("res://data/does_not_exist").size(), 0)


func test_build_state_carries_every_chain():
	var state := SupportRegistry.build_state()
	assert_not_null(state.chain_for_units("kai", "kael"))


# --- authored conversations ----------------------------------------------------

func test_every_rank_conversation_exists_parses_and_stays_in_voice():
	var chain: SupportChainDef = load("res://data/supports/kai_kael.tres")
	for rank in SupportChainDef.RANKS:
		var path := chain.conversation_path(rank)
		assert_ne(path, "", "%s conversation path authored" % rank)
		assert_true(FileAccess.file_exists(path), path + " exists")
		var s := DialogueScript.from_file(path)
		assert_true(s.ok(), "%s parses: %s" % [path, s.error])
		assert_gt(s.size(), 4, "%s has a real conversation's worth of lines" % rank)
		for i in range(s.size()):
			var step := s.get_step(i)
			if step.is_line():
				assert_true(step.speaker in ["Kai", "Kael"], "only the pair speaks in a support")


# --- Common Hall playback --------------------------------------------------------

func test_common_hall_plays_an_unlocked_conversation():
	Campaign.reset_new_game(false)
	Campaign.support_save = {"points": {"kai_kael": 20}, "ranks": {"kai_kael": "C"}}
	var hub: HubScene = load("res://scenes/hub/hub.tscn").instantiate()
	add_child_autofree(hub)
	await wait_physics_frames(1)

	hub._open_common_hall()
	assert_eq(hub._hall_entries.size(), 1, "the C conversation is listed")
	hub._play_support_entry(0)
	await wait_physics_frames(1)
	var dlg := _find_dialogue(hub)
	assert_not_null(dlg, "conversation overlay is playing")
	assert_true(hub._dialogue_playing)
	assert_false(hub._support_state.is_viewed("kai_kael", "C"),
		"opening a conversation does not mark it watched")

	_drive_to_end(dlg)
	await wait_physics_frames(2)
	assert_false(hub._dialogue_playing, "playback released the hub")
	assert_eq(hub._context, "commonhall", "returned to the Common Hall")
	assert_true(hub._support_state.is_viewed("kai_kael", "C"),
		"completed playback marks it watched")
	var hub_saved: Dictionary = Campaign.support_save.get("viewed", {})
	assert_true(bool(hub_saved.get("kai_kael:C", false)),
		"the watched flag is persisted to the campaign")


func test_common_hall_placeholder_row_is_inert():
	Campaign.reset_new_game(false)  # nothing unlocked
	var hub: HubScene = load("res://scenes/hub/hub.tscn").instantiate()
	add_child_autofree(hub)
	await wait_physics_frames(1)
	hub._open_common_hall()
	assert_eq(hub._hall_entries.size(), 0)
	hub._play_support_entry(0)  # the "(no supports unlocked yet)" row
	await wait_physics_frames(1)
	assert_null(_find_dialogue(hub), "placeholder row plays nothing")


# --- in-battle viewing ------------------------------------------------------------

func test_battle_supports_menu_plays_the_conversation():
	var view: Node2D = load("res://scenes/battle/battle.tscn").instantiate()
	view.strike_delay = 0.0
	view.dialogue_enabled = true  # test map has no chapter dialogue, so no intro fires
	add_child_autofree(view)
	await wait_physics_frames(2)

	view._support_state.add_points("kai", "kael", 20)  # -> C
	var kai: Unit = view.unit_by_id("kai")
	view._selected = kai
	view._support_menu_entries = view._support_state.unlocked_conversations_for_unit("kai")
	assert_eq(view._support_menu_entries.size(), 1)

	view._view_support_entry(0)
	await wait_physics_frames(1)
	var dlg := _find_dialogue(view)
	assert_not_null(dlg, "in-battle conversation overlay is up")
	assert_false(view._support_state.is_viewed("kai_kael", "C"),
		"opening a conversation does not mark it watched")
	_drive_to_end(dlg)
	await wait_physics_frames(2)
	assert_eq(view._menu_context, "action", "viewing returns to the command menu")
	assert_false(kai.has_acted, "viewing a conversation doesn't consume the action")
	assert_true(view._support_state.is_viewed("kai_kael", "C"),
		"completed playback marks it watched")
	assert_eq(view._unviewed_conversations("kai").size(), 0,
		"the watched scene is no longer offered in battle")


## Issue #3: an unwritten or broken conversation must stay available rather than
## being consumed as if the player had watched it.
func test_battle_support_playback_failure_does_not_mark_viewed():
	for path in [MISSING_DIALOGUE, BAD_DIALOGUE, EMPTY_DIALOGUE]:
		var view: Node2D = load("res://scenes/battle/battle.tscn").instantiate()
		view.strike_delay = 0.0
		view.dialogue_enabled = true
		add_child_autofree(view)
		await wait_physics_frames(2)

		view._support_state.add_points("kai", "kael", 20)  # -> C
		view._selected = view.unit_by_id("kai")
		view._support_menu_entries = [_entry_with_path(path)]

		view._view_support_entry(0)
		await wait_physics_frames(2)

		assert_false(view._support_state.is_viewed("kai_kael", "C"),
			"%s must not consume the C conversation" % path)
		assert_eq(view._unviewed_conversations("kai").size(), 1,
			"%s stays offered after failed playback" % path)
		assert_eq(view._menu_context, "action", "the command menu remains usable")
		view.queue_free()
		await wait_physics_frames(1)


# --- castle Common Hall ------------------------------------------------------------

func test_castle_hall_marks_viewed_after_completed_playback():
	Campaign.reset_new_game(false)
	Campaign.support_save = {"points": {"kai_kael": 20}, "ranks": {"kai_kael": "C"}, "viewed": {}}
	var castle: CastleScene = load("res://scenes/castle/castle.tscn").instantiate()
	add_child_autofree(castle)
	await wait_physics_frames(1)

	castle._open_hall_archive()
	assert_eq(castle._hall_entries.size(), 1, "the C conversation is listed")
	castle._view_hall_entry(0)
	await wait_physics_frames(1)
	var dlg := castle._dialogue
	assert_not_null(dlg, "the castle plays the conversation")
	assert_false(castle._support_state.is_viewed("kai_kael", "C"),
		"starting playback does not mark it watched")

	_drive_to_end(dlg)
	await wait_physics_frames(2)
	assert_true(castle._support_state.is_viewed("kai_kael", "C"),
		"completed playback marks it watched")
	var castle_saved: Dictionary = Campaign.support_save.get("viewed", {})
	assert_true(bool(castle_saved.get("kai_kael:C", false)),
		"the watched flag is persisted")
	assert_eq(castle._menu_context, "hall", "the archive returns after playback")


func test_castle_hall_playback_failure_does_not_mark_viewed():
	for path in [MISSING_DIALOGUE, BAD_DIALOGUE, EMPTY_DIALOGUE]:
		Campaign.reset_new_game(false)
		Campaign.support_save = {"points": {"kai_kael": 20}, "ranks": {"kai_kael": "C"}, "viewed": {}}
		var castle: CastleScene = load("res://scenes/castle/castle.tscn").instantiate()
		add_child_autofree(castle)
		await wait_physics_frames(1)

		castle._open_hall_archive()
		castle._hall_entries = [_entry_with_path(path)]
		castle._view_hall_entry(0)
		await wait_physics_frames(2)

		assert_false(castle._support_state.is_viewed("kai_kael", "C"),
			"%s must not consume the C conversation" % path)
		assert_null(castle._dialogue, "%s cannot start a playback" % path)
		var saved: Dictionary = Campaign.support_save.get("viewed", {})
		assert_false(bool(saved.get("kai_kael:C", false)),
			"%s must not persist a watched flag" % path)
		castle.queue_free()
		await wait_physics_frames(1)
