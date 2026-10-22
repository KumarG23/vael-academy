extends GutTest
## Issue #23: every unit the player actually fields in a house-routed school
## rite (opening WO-5.6 + closing WO-7.4) spawns on its OWN authored deploy cell.
## A chapter's nonempty deploy_cells map replaces the Roster fallback entirely,
## so a missing id used to land silently on (0,0) — in bounds, so nothing caught
## it (Nilu on the Thornrook route). Loads the scenes ChapterRegistry routes the
## Mission Board to, with each house's shipped roster + Kai; off-route rosters
## are deliberately not required.

const HOUSES: Array[String] = ["emberwing", "tidemark", "thornrook"]
const RITES: Array[String] = ["mock_battle", "closing_rite"]


func after_each() -> void:
	Campaign.set_house("emberwing")
	Campaign.active = false


func _load_routed(chapter_id: String, house: String) -> Node2D:
	Campaign.set_house(house)
	Campaign.deploy()
	var path := ChapterRegistry.scene_for(chapter_id, house)
	assert_ne(path, "", "%s routes %s" % [house, chapter_id])
	var v: Node2D = (load(path) as PackedScene).instantiate()
	v.strike_delay = 0.0
	v.dialogue_enabled = false
	add_child_autofree(v)
	return v


func test_routed_rites_field_every_roster_id_on_its_authored_cell():
	for house in HOUSES:
		for rite in RITES:
			var v := _load_routed(rite, house)
			var chapter: ChapterDef = v.chapter
			var label := "%s/%s" % [house, chapter.id]
			var fielded := {}
			for u in v._units:
				if u.team != 0:
					continue
				var uid: String = u.unit_id()
				fielded[uid] = true
				# has() first: a missing id must fail even though ZERO is in bounds.
				assert_true(chapter.deploy_cells.has(uid), "%s authors a deploy cell for %s" % [label, uid])
				assert_eq(u.cell, chapter.deploy_cells.get(uid, Vector2i(-1, -1)),
					"%s spawns %s on its authored cell" % [label, uid])
			for uid in Roster.all_player_ids():
				assert_true(fielded.has(uid), "%s fields %s" % [label, uid])
			Campaign.active = false


func test_routed_deploy_cells_are_legal_and_unshared():
	for house in HOUSES:
		for rite in RITES:
			var v := _load_routed(rite, house)
			var chapter: ChapterDef = v.chapter
			var label := "%s/%s" % [house, chapter.id]
			var db := TerrainDB.create_default()
			var taken := {}
			for u in v._units:
				# Opposing spawns count too: no two units of either side share a cell.
				assert_false(taken.has(u.cell), "%s: %s shares %s with %s" % [label, u.unit_id(), u.cell, taken.get(u.cell, "")])
				taken[u.cell] = u.unit_id()
			for u in v._units:
				if u.team != 0:
					continue
				var c: Vector2i = u.cell
				assert_true(chapter.in_bounds(c.x, c.y), "%s: %s in bounds" % [label, u.unit_id()])
				assert_false(db.is_impassable(chapter.get_terrain(c.x, c.y)),
					"%s: %s deploys on passable ground" % [label, u.unit_id()])
				# The live movement rules (this unit's movement type, terrain costs,
				# occupancy) must let it actually leave its deploy cell.
				var tiles := MovementRange.standable_tiles(c, v._mov(u), v._make_context(u))
				assert_gt(tiles.size(), 1, "%s: %s can move off its deploy cell" % [label, u.unit_id()])
			Campaign.active = false


func test_thornrook_rites_deploy_nilu_beside_rina():
	# Same authored cell the generic mock chapter already gives Nilu (4,11),
	# between Rurik (4,10) and Rina (4,12) — no bonded-unit rule implied.
	for rite in RITES:
		var v := _load_routed(rite, "thornrook")
		var nilu: Unit = v.unit_by_id("nilu")
		assert_not_null(nilu, "%s fields Nilu" % rite)
		if nilu != null:
			assert_eq(nilu.cell, Vector2i(4, 11), "%s: Nilu deploys at (4,11)" % rite)
		Campaign.active = false
