extends GutTest
## AW-75: save anywhere — the field menu saves mid-battle, mission snapshots
## carry the whole campaign, and loading a live slot resumes INTO the fight.

const MOCK := "res://scenes/battle/mock_battle.tscn"
const ARENA := "res://scenes/battle/arena.tscn"

var _view


func before_each() -> void:
	BattleView.next_prep = false
	BattleView.next_resume = {}
	Campaign.reset_new_game(false)
	Campaign.set_house("emberwing")
	Campaign.deploy()


func after_each() -> void:
	BattleView.next_resume = {}


func _mock() -> Node2D:
	var v: Node2D = (load(MOCK) as PackedScene).instantiate()
	v.dialogue_enabled = false
	add_child_autofree(v)
	return v


func test_field_menu_offers_save_and_it_opens_the_slot_list():
	_view = _mock()
	_view._menu_ctrl.open_field_menu()
	assert_eq(_view._menu._options.size(), 4, "End Turn / Objective / Save game / Cancel")
	_view._menu_ctrl.field_choice(2)  # Save game
	assert_eq(_view._menu_context, "save_slot", "the slot list opens")
	_view._menu.close()


func test_mission_payload_carries_the_whole_campaign():
	Campaign.flags["gold"] = 777
	Campaign.week = 3
	_view = _mock()
	var payload: Dictionary = _view.make_save_payload()
	assert_true(Resume.has_campaign(payload), "a real campaign rides along")
	assert_eq(int(payload["campaign"]["flags"]["gold"]), 777)
	assert_eq(int(payload["campaign"]["week"]), 3)
	assert_eq(str(payload["campaign"]["current_chapter_id"]), "mock_battle",
		"the slot-list header keys are still written")
	assert_true(payload["battle"].has("rng_seed"), "combat RNG lives in the battle block")


func test_resume_stage_restores_campaign_and_stages_the_battle():
	Campaign.flags["gold"] = 555
	_view = _mock()
	var payload: Dictionary = _view.make_save_payload()
	Campaign.reset_new_game(false)  # wander off: title screen state
	assert_eq(int(Campaign.flags.get("gold", 0)), 0)
	var scene := Resume.stage(payload)
	assert_eq(scene, MOCK, "the saved chapter knows its scene")
	assert_eq(int(Campaign.flags.get("gold", 0)), 555, "the campaign walked back in")
	assert_true(Campaign.active)
	assert_false(BattleView.next_resume.is_empty(), "the battle is staged")
	assert_false(Resume.battle_live({}), "an empty payload resumes nothing")


func test_finished_battles_do_not_resume():
	_view = _mock()
	_view._battle_over = true
	var payload: Dictionary = _view.make_save_payload()
	assert_false(Resume.battle_live(payload), "a done fight stays done")
	assert_eq(Resume.stage(payload), "")


func test_resumed_scene_walks_back_into_the_fight():
	_view = _mock()
	var kael: Unit = _view.unit_by_id("kael")
	kael.current_hp = 7
	kael.cell = Vector2i(4, 7)
	kael.position = _view._grid.cell_center(kael.cell)
	var payload: Dictionary = _view.make_save_payload()
	BattleView.next_resume = payload
	var loaded: Node2D = (load(MOCK) as PackedScene).instantiate()
	loaded.dialogue_enabled = false
	add_child_autofree(loaded)
	assert_true(BattleView.next_resume.is_empty(), "the staging flag is consumed")
	var lk: Unit = loaded.unit_by_id("kael")
	assert_eq(lk.current_hp, 7, "mid-fight HP came back")
	assert_eq(lk.cell, Vector2i(4, 7))
	assert_false(loaded._prep_active, "no preparations on a resume")


func test_arena_run_survives_a_save_and_resume():
	var v: Node2D = (load(ARENA) as PackedScene).instantiate()
	v.dialogue_enabled = false
	add_child_autofree(v)
	await wait_physics_frames(2)
	for foe in v._living_foes_of(0).duplicate():
		v._kill(foe)
	v._check_objective()  # wave 1 cleared, wave 2 pending
	assert_eq(v._arena_pending_wave, 2)
	var payload: Dictionary = v.make_save_payload()

	BattleView.next_resume = payload
	var loaded: Node2D = (load(ARENA) as PackedScene).instantiate()
	loaded.dialogue_enabled = false
	add_child_autofree(loaded)
	await wait_physics_frames(2)
	assert_eq(loaded._arena_wave, 1, "the run's floor came back")
	assert_eq(loaded._arena_pending_wave, 2, "with the next wave still queued")
	assert_eq(loaded._living_foes_of(0).size(), 0, "the cleared floor stays cleared")
	loaded._begin_player_phase()
	assert_gt(loaded._living_foes_of(0).size(), 0, "and wave 2 files in on schedule")


func test_slot_list_marks_live_battles():
	var saves := SaveSystem.new("user://test_resume_saves_%d" % Time.get_ticks_usec())
	_view = _mock()
	_view._save_system = saves
	assert_true(_view.save_to_slot(0))
	var slots := saves.list_slots(3)
	assert_eq(slots.size(), 1)
	assert_true(bool(slots[0]["in_battle"]), "a live fight is flagged for the ⚔ label")
