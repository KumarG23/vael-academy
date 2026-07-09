extends GutTest
## AW-43: the Arena — Kai solo vs procedural escalating waves, no real death,
## depth-scaled rewards. Foes are arena-only (never authored unit files).

const SCENE := "res://scenes/battle/arena.tscn"


# --- the controller (pure) ---------------------------------------------------

func test_waves_escalate_in_count():
	var cells: Array = []
	for i in range(20):
		cells.append(Vector2i(i, 0))
	assert_lt(ArenaController.wave_count(1, 20), ArenaController.wave_count(5, 20),
		"later waves field more foes")
	assert_eq(ArenaController.wave_spawns(1, cells).size(), ArenaController.wave_count(1, 20))


func test_foes_are_arena_only_and_scale_with_depth():
	var w1: UnitDef = ArenaController.wave_spawns(1, [Vector2i(1, 0), Vector2i(2, 0)])[0]["def"]
	var w6: UnitDef = ArenaController.make_enemy("brute", 6, 0)
	assert_true(w1.id.begins_with("arena_"), "arena-only id, never a real unit")
	assert_eq(w1.team, 1, "the house fields them as foes")
	assert_gt(ArenaController.make_enemy("brute", 6, 0).max_hp,
		ArenaController.make_enemy("brute", 1, 0).max_hp, "deeper waves hit harder")


func test_reward_scales_with_waves_cleared():
	assert_eq(ArenaController.reward(0)["gold"], 0)
	assert_gt(ArenaController.reward(5)["credit"], ArenaController.reward(2)["credit"])


## AW-48: arena foes render as REAL sprites — every archetype borrows an existing
## unit's walk frames via UnitDef.sprite_id (Neal's "arena looks broken" fix: no
## letter tokens, and never a dangling alias).
func test_every_archetype_borrows_real_walk_frames():
	for arch in ArenaController.ARCHETYPES:
		var sprite: String = ArenaController.ARCHETYPES[arch]["sprite"]
		assert_true(ResourceLoader.exists("res://assets/sprites/units/%s/walk_f1.png" % sprite),
			"%s -> %s has walk frames" % [arch, sprite])
		var d := ArenaController.make_enemy(arch, 1, 0)
		assert_eq(d.sprite_id, sprite, "%s def carries the alias" % arch)


func test_unit_sprite_id_resolves_the_alias():
	var d := ArenaController.make_enemy("grunt", 1, 0)
	var u := Unit.new()
	u.setup(d, Grid.new(3, 3), Vector2i.ZERO)
	assert_eq(u.sprite_id(), "bandit_a", "the unit resolves art through the alias")
	assert_not_null(u._anim, "and actually built animated frames from it (no token)")
	u.free()


# --- the live bout -----------------------------------------------------------

func before_each() -> void:
	Campaign.reset_new_game(false)


func after_each() -> void:
	Campaign.reset_new_game(false)


func _arena() -> Node2D:
	var v: Node2D = (load(SCENE) as PackedScene).instantiate()
	v.strike_delay = 0.0
	v.dialogue_enabled = false
	add_child_autofree(v)
	return v


func test_kai_stands_alone_and_wave_one_is_on_the_sand():
	var v := _arena()
	await wait_physics_frames(2)
	assert_eq(v._living_units_on_team(0).size(), 1, "Kai fights solo")
	assert_true(v._lord_unit != null and v._lord_unit.unit_id() == "kai", "Kai is the lord")
	assert_gt(v._living_foes_of(0).size(), 0, "wave 1 is out")
	assert_eq(v._arena_wave, 1)


## AW-48: the bout plays on ONE screen — the camera fits the whole pit, so wave
## spawns on the edge rows are never invisible offscreen (the "arena is broken"
## report: default zoom cropped the top/bottom rows and Kai looked alone).
func test_arena_camera_fits_the_whole_pit():
	var v := _arena()
	await wait_physics_frames(2)
	var half: Vector2 = v.get_viewport_rect().size * 0.5 / v._camera.zoom.x
	var map: Vector2 = v._grid.pixel_size()
	var centre: Vector2 = v._camera.position
	# the VIEW covers the whole MAP (fit zoom): its edges reach past both map edges
	assert_gte(centre.y + half.y, map.y - 1.0, "bottom spawn row is in view")
	assert_lte(centre.y - half.y, 1.0, "top spawn row is in view")
	for u in v._living_foes_of(0):
		assert_true(absf(u.position.x - centre.x) <= half.x and absf(u.position.y - centre.y) <= half.y,
			"wave foe at %s is on screen" % str(u.cell))


## AW-50: a cleared floor QUEUES the next wave; it files in at the next player-
## phase start — a legible round boundary, not an instant mid-melee respawn.
func test_clearing_a_wave_queues_the_next_for_phase_start():
	var v := _arena()
	await wait_physics_frames(2)
	for foe in v._living_foes_of(0).duplicate():
		v._kill(foe)
	v._check_objective()
	assert_eq(v._arena_pending_wave, 2, "a cleared floor queues the next wave")
	assert_eq(v._arena_wave, 1, "but it hasn't filed in yet")
	assert_eq(v._living_foes_of(0).size(), 0, "the sand is empty between rounds")
	assert_false(v._battle_over, "the arena keeps going")
	v._begin_player_phase()
	assert_eq(v._arena_wave, 2, "the new wave files in at your phase start")
	assert_eq(v._arena_pending_wave, 0)
	assert_gt(v._living_foes_of(0).size(), 0, "and it's populated")


func _clear_wave(v) -> void:
	for foe in v._living_foes_of(0).duplicate():
		v._kill(foe)
	v._check_objective()
	v._begin_player_phase()


func test_kai_falling_ends_the_bout_with_winnings():
	var v := _arena()
	await wait_physics_frames(2)
	# push to wave 3 so there's something cleared to be paid for
	for _i in range(2):
		_clear_wave(v)
	assert_eq(v._arena_wave, 3)
	v._kill(v._lord_unit)   # Kai yields
	v._check_objective()
	assert_true(v._battle_over, "the bout ends when Kai falls")
	assert_true(v._battle_victory, "you always leave with your winnings — no game over")
	assert_eq(int(Campaign.flags.get("arena_best_wave", 0)), 2, "cleared 2 waves before falling on 3")
	assert_true(bool(Campaign.flags.get("arena_used_this_week", false)), "weekly cooldown set")
	# AW-50: the end screen is the trial REPORT, not a generic Victory banner
	assert_eq(v._result_screen._text, "The Trial Ends", "the trial report card shows")
	var joined := ". ".join(v._result_screen._lines.map(func(l): return str(l)))
	assert_string_contains(joined, "Waves cleared: 2")
	assert_string_contains(joined, "NEW PERSONAL BEST")
	assert_string_contains(joined, "gold")


## AW-63: voluntary retreat between bouts banks everything earned, on your terms.
func test_retreat_between_waves_banks_the_winnings():
	var v := _arena()
	await wait_physics_frames(2)
	for foe in v._living_foes_of(0).duplicate():
		v._kill(foe)
	v._check_objective()          # wave 1 cleared, wave 2 pending
	v._arena_retreat()
	assert_true(v._battle_over, "you walked away")
	assert_true(v._battle_victory, "with your winnings")
	assert_eq(int(Campaign.flags.get("arena_best_wave", 0)), 1, "the cleared floor counts")
	assert_gt(int(Campaign.flags.get("gold", 0)), 0, "and the gold came too")


## AW-70: retreating reads as retiring, never as being "downed".
func test_retreat_remark_never_says_downed():
	var v := _arena()
	await wait_physics_frames(2)
	v._arena_retreat()  # walk out before clearing anything
	var joined := ". ".join(v._result_screen._lines.map(func(l): return str(l)))
	assert_string_contains(joined, "early exit")
	assert_false(joined.contains("Downed"), "a retreat is not a defeat")


func test_retreat_after_a_clear_praises_the_exit():
	var v := _arena()
	await wait_physics_frames(2)
	for foe in v._living_foes_of(0).duplicate():
		v._kill(foe)
	v._check_objective()
	v._arena_retreat()
	var joined := ". ".join(v._result_screen._lines.map(func(l): return str(l)))
	assert_string_contains(joined, "retire from the sand")


## AW-50: falling AFTER clearing a floor (its successor still pending) counts the
## cleared floor — you earned it.
func test_falling_between_waves_still_counts_the_cleared_floor():
	var v := _arena()
	await wait_physics_frames(2)
	for foe in v._living_foes_of(0).duplicate():
		v._kill(foe)
	v._check_objective()             # wave 1 cleared, wave 2 pending
	v._kill(v._lord_unit)
	v._check_objective()
	assert_true(v._battle_over)
	assert_eq(int(Campaign.flags.get("arena_best_wave", 0)), 1, "the cleared floor counts")


## AW-50: a repeat run that doesn't beat the record reports the standing best.
func test_personal_best_survives_a_worse_run():
	Campaign.flags["arena_best_wave"] = 5
	var v := _arena()
	await wait_physics_frames(2)
	v._kill(v._lord_unit)   # downed in the opening bout
	v._check_objective()
	assert_eq(int(Campaign.flags.get("arena_best_wave", 0)), 5, "the record stands")
	var joined := ". ".join(v._result_screen._lines.map(func(l): return str(l)))
	assert_string_contains(joined, "Personal best: 5")
