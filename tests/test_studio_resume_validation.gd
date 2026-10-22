extends GutTest
## Malformed save sections and campaign collections must not change live state.

const MOCK := "res://scenes/battle/mock_battle.tscn"
const ARENA := "res://scenes/battle/arena.tscn"
const PROLOGUE := "res://scenes/battle/prologue.tscn"


func before_each() -> void:
	Campaign.reset_new_game(true, 17)
	Campaign.set_house("tidemark")
	Campaign.week = 3
	Campaign.training_used = true
	Campaign.set_unit_state("kai", {"level": 2, "xp": 17})
	BattleView.next_resume = {"existing_resume": true}


func after_each() -> void:
	BattleView.next_resume = {}
	Campaign.reset_new_game(false)


func _malformed_sections() -> Array:
	return [null, [], ["mock_battle"], "", "mock_battle", 0, 42, 1.5, false, true]


func _live_payload() -> Dictionary:
	return {
		"battle": {"chapter_id": "mock_battle", "battle_over": false},
		"roster": [],
	}


func _assert_stage_rejected(payload: Dictionary) -> void:
	var before := Campaign.to_dict()
	var was_active: bool = Campaign.active
	var house: String = Roster.active_house
	var staged: Dictionary = BattleView.next_resume
	var staged_before := staged.duplicate(true)
	var payload_before := payload.duplicate(true)
	assert_eq(Resume.stage(payload), "", "invalid payload has no resume route")
	assert_eq(Campaign.to_dict(), before, "rejection must not restore or reset the campaign")
	assert_eq(Campaign.active, was_active)
	assert_eq(Roster.active_house, house)
	assert_eq(BattleView.next_resume, staged_before, "existing staged battle stays intact")
	assert_true(is_same(BattleView.next_resume, staged), "rejection must not replace staging")
	assert_eq(payload, payload_before, "validation must not rewrite the save")


func test_malformed_battle_sections_have_no_live_battle_or_route() -> void:
	for section: Variant in _malformed_sections():
		var payload := {"battle": section, "roster": [], "campaign": Campaign.to_dict()}
		assert_false(Resume.battle_live(payload), "malformed battle: %s" % [section])
		assert_eq(Resume.battle_scene(payload), "")
		_assert_stage_rejected(payload)


func test_missing_and_unknown_battles_do_not_restore_campaign_or_stage() -> void:
	for battle: Dictionary in [{}, {"chapter_id": "unknown_chapter"}]:
		var payload := {"battle": battle, "roster": [], "campaign": Campaign.to_dict()}
		assert_eq(Resume.battle_scene(payload), "")
		_assert_stage_rejected(payload)
	var missing := {"campaign": Campaign.to_dict(), "roster": []}
	assert_false(Resume.battle_live(missing))
	assert_eq(Resume.battle_scene(missing), "")
	_assert_stage_rejected(missing)


func test_malformed_campaign_sections_are_not_campaigns_and_cannot_stage() -> void:
	for section: Variant in _malformed_sections():
		var payload := _live_payload()
		payload["campaign"] = section
		assert_true(Resume.battle_live(payload), "battle itself is a valid positive control")
		assert_eq(Resume.battle_scene(payload), MOCK)
		assert_false(Resume.has_campaign(payload), "malformed campaign: %s" % [section])
		_assert_stage_rejected(payload)


func test_campaign_detection_preserves_full_and_thin_header_distinction() -> void:
	assert_true(Resume.has_campaign({"campaign": Campaign.to_dict()}))
	for header: Dictionary in [{}, {"week": 3}, {"house_id": "tidemark"},
			{"current_chapter_id": "mock_battle", "hub_state": {}, "casual_mode": true}]:
		assert_false(Resume.has_campaign({"campaign": header}))
	assert_false(Resume.has_campaign({}))


func test_known_battle_routes_remain_available() -> void:
	var routes := {"mock_battle": MOCK, "arena": ARENA, "prologue": PROLOGUE,
		"hamlet_cottage": PROLOGUE}
	for chapter_id: String in routes:
		var payload := _live_payload()
		payload["battle"]["chapter_id"] = chapter_id
		assert_true(Resume.battle_live(payload))
		assert_eq(Resume.battle_scene(payload), routes[chapter_id])
		assert_eq(Resume.stage(payload), routes[chapter_id])
		assert_eq(BattleView.next_resume, payload)


func test_completed_battle_keeps_route_but_cannot_restore_or_stage() -> void:
	var payload := _live_payload()
	payload["battle"]["battle_over"] = true
	payload["campaign"] = Campaign.to_dict()
	Campaign.reset_new_game(false)
	Campaign.active = true
	assert_false(Resume.battle_live(payload))
	assert_eq(Resume.battle_scene(payload), MOCK)
	_assert_stage_rejected(payload)


func test_battle_without_roster_cannot_stage() -> void:
	var payload := _live_payload()
	payload.erase("roster")
	assert_false(Resume.battle_live(payload))
	_assert_stage_rejected(payload)


func test_valid_full_campaign_restores_and_stages_live_battle() -> void:
	var saved := Campaign.to_dict()
	var payload := _live_payload()
	payload["campaign"] = saved.duplicate(true)
	Campaign.reset_new_game(false)
	assert_false(Campaign.active)
	assert_true(Resume.has_campaign(payload))
	assert_true(Resume.battle_live(payload))
	assert_eq(Resume.stage(payload), MOCK)
	assert_eq(Campaign.to_dict(), saved, "the entire campaign is restored")
	assert_eq(Roster.active_house, "tidemark")
	assert_true(Campaign.active)
	assert_eq(BattleView.next_resume, payload)


func test_malformed_campaign_dictionaries_cannot_partially_restore_or_stage() -> void:
	for key: String in ["unit_states", "support_save", "fish_log", "flags", "grade_samples"]:
		for section: Variant in _malformed_sections():
			var payload := _live_payload()
			payload["campaign"] = Campaign.to_dict()
			# Ensure even a failure late in from_dict would overwrite live state.
			payload["campaign"]["unit_states"] = {}
			payload["campaign"]["week"] = 8
			payload["campaign"]["house_id"] = "thornrook"
			payload["campaign"][key] = section
			_assert_stage_rejected(payload)


func test_malformed_campaign_report_cards_cannot_partially_restore_or_stage() -> void:
	for section: Variant in [null, {}, {"semester": 1}, "", "report", 0, 42, 1.5, false, true]:
		var payload := _live_payload()
		payload["campaign"] = Campaign.to_dict()
		payload["campaign"]["week"] = 8
		payload["campaign"]["house_id"] = "thornrook"
		payload["campaign"]["report_cards"] = section
		_assert_stage_rejected(payload)


func test_legacy_campaign_without_optional_collections_still_restores() -> void:
	var payload := _live_payload()
	payload["campaign"] = {"week": 2, "house_id": "emberwing"}
	assert_eq(Resume.stage(payload), MOCK)
	assert_true(Campaign.active)
	assert_eq(Campaign.week, 2)
	assert_eq(Roster.active_house, "emberwing")
	assert_eq(Campaign.unit_states, {})
	assert_eq(Campaign.support_save, {})
	assert_eq(Campaign.fish_log, {})
	assert_eq(Campaign.flags, {})
	assert_eq(Campaign.grade_samples,
		{"quiz_scores": [], "battle_scores": [], "arena_best_wave": 0, "conduct_points": 0})
	assert_eq(Campaign.report_cards, [])
	assert_eq(BattleView.next_resume, payload)


func test_standalone_thin_header_and_missing_campaign_preserve_campaign() -> void:
	var before := Campaign.to_dict()
	var was_active: bool = Campaign.active
	for has_header: bool in [false, true]:
		var payload := _live_payload()
		if has_header:
			payload["campaign"] = {
				"current_chapter_id": "mock_battle", "hub_state": {}, "casual_mode": true,
			}
		assert_false(Resume.has_campaign(payload))
		assert_eq(Resume.stage(payload), MOCK)
		assert_eq(BattleView.next_resume, payload)
		assert_eq(Campaign.to_dict(), before, "standalone battle must not restore campaign")
		assert_eq(Campaign.active, was_active)
		assert_eq(Roster.active_house, "tidemark")
