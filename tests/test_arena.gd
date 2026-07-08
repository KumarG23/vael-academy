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


func test_clearing_a_wave_summons_the_next():
	var v := _arena()
	await wait_physics_frames(2)
	for foe in v._living_foes_of(0).duplicate():
		v._kill(foe)
	v._check_objective()
	assert_eq(v._arena_wave, 2, "a cleared floor calls the next wave")
	assert_gt(v._living_foes_of(0).size(), 0, "and it's populated")
	assert_false(v._battle_over, "the arena keeps going")


func test_kai_falling_ends_the_bout_with_winnings():
	var v := _arena()
	await wait_physics_frames(2)
	# push to wave 3 so there's something cleared to be paid for
	for _i in range(2):
		for foe in v._living_foes_of(0).duplicate():
			v._kill(foe)
		v._check_objective()
	assert_eq(v._arena_wave, 3)
	v._kill(v._lord_unit)   # Kai yields
	v._check_objective()
	assert_true(v._battle_over, "the bout ends when Kai falls")
	assert_true(v._battle_victory, "you always leave with your winnings — no game over")
	assert_eq(int(Campaign.flags.get("arena_best_wave", 0)), 2, "cleared 2 waves before falling on 3")
	assert_true(bool(Campaign.flags.get("arena_used_this_week", false)), "weekly cooldown set")
