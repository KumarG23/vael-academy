extends GutTest
## WO-7.4: the Closing Rite — the year's climax fields BOTH unpicked houses
## (both full rival rosters, two heirs), ROUT objective, stakes over the opening.

const RIVALS := {
	"emberwing": ["tidemark", "thornrook"],
	"tidemark": ["thornrook", "emberwing"],
	"thornrook": ["emberwing", "tidemark"],
}


func after_each() -> void:
	Campaign.set_house("emberwing")
	Campaign.active = false


func test_every_route_fields_both_rivals():
	for house in RIVALS:
		Campaign.set_house(house)
		Campaign.deploy()
		var v: Node2D = (load(ChapterRegistry.scene_for("closing_rite", house)) as PackedScene).instantiate()
		v.strike_delay = 0.0
		v.dialogue_enabled = false
		add_child_autofree(v)
		var enemy_houses := {}
		var enemies := 0
		for u in v._units:
			if u.team != 0:
				enemies += 1
				enemy_houses[u.unit_def.house_id] = true
		assert_eq(enemies, 12 if house == "thornrook" else 13, "%s faces both full rival rosters" % house)
		for rival in RIVALS[house]:
			assert_true(enemy_houses.has(rival), "%s faces %s" % [house, rival])
		assert_false(enemy_houses.has(house), "%s never fights itself" % house)
		assert_eq(v.chapter.objective, ChapterDef.Objective.ROUT)
		Campaign.active = false


func test_closing_spawns_are_passable():
	var db := TerrainDB.create_default()
	for house in RIVALS:
		var c: ChapterDef = load("res://data/chapters/closing_rite_%s.tres" % house)
		for spawn in c.enemy_spawns:
			var t := c.get_terrain(spawn.cell.x, spawn.cell.y)
			assert_false(db.is_impassable(t),
				"%s: %s spawns on passable ground" % [house, spawn.unit.id])


func test_year_ends_on_the_closing_rite():
	Campaign.reset_new_game(false)
	Campaign.week = 6
	var e := Campaign.current_event()
	assert_eq(e.chapter_id, "closing_rite")
	assert_ne(ChapterRegistry.scene_for(e.chapter_id, "tidemark"), "")
	Campaign.reset_new_game(false)
