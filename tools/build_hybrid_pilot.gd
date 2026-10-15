extends SceneTree
## CP-6 isolated map; no campaign resources or canon authored.
func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var chapter: Resource = load("res://src/core/chapter_def.gd").new()
	chapter.id = "hybrid_combat_pilot"
	chapter.display_name = "The Sunlit Cloister — combat study"
	chapter.non_lethal = true
	chapter.width = 14
	chapter.height = 8
	chapter.fill(Terrain.Type.PLAINS)
	for y in range(8):
		for x in range(14):
			if y in [3, 4]:
				chapter.set_terrain(x, y, Terrain.Type.PATH)
			elif x < 2 or x > 11 or y == 0:
				chapter.set_terrain(x, y, Terrain.Type.FOREST)
			elif y == 6 and x % 3 == 0:
				chapter.set_terrain(x, y, Terrain.Type.FLOWERS)
	var kai: Resource = load("res://src/units/unit_spawn.gd").new()
	kai.unit = load("res://data/units/kai.tres")
	kai.cell = Vector2i(6, 4)
	chapter.player_spawns.append(kai)
	var serra: Resource = load("res://src/units/unit_spawn.gd").new()
	serra.unit = load("res://data/units/serra_prologue.tres")
	serra.cell = Vector2i(7, 4)
	serra.team_override = 1
	chapter.enemy_spawns.append(serra)
	for item in [["banner", Vector2i(4, 1)], ["banner", Vector2i(9, 1)], ["archery_target", Vector2i(3, 6)], ["well", Vector2i(10, 6)]]:
		var decor := MapDecor.new()
		decor.texture = load("res://assets/art/pixellab/props/%s.png" % item[0])
		decor.cell = item[1]
		chapter.decor.append(decor)
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "res://data/proto/hybrid_cloister.tres"
	var error := ResourceSaver.save(chapter, output)
	print("CP-6 chapter saved: ", error)
	quit(error)
