extends SceneTree
## AW-43: the Arena chapter — a sand pit ringed by wall, Kai alone in the middle.
## is_arena drives the wave system in battle_view; enemy_spawns stays empty.
func _initialize() -> void:
	var ch := ChapterDef.new()
	ch.id = "arena"
	ch.display_name = "The Arena"
	ch.is_arena = true
	ch.non_lethal = true
	ch.objective = ChapterDef.Objective.ROUT
	ch.width = 17
	ch.height = 15
	ch.base_terrain = Terrain.Type.PLAINS
	# AW-48: the pit floor is PATH (the sandy/dirt wang set) — plain grass read as
	# "an empty field", not a colosseum bout.
	ch.fill(Terrain.Type.PATH)
	# a wall ring (the colosseum barrier)
	for x in range(ch.width):
		ch.set_terrain(x, 0, Terrain.Type.WALL); ch.set_terrain(x, ch.height - 1, Terrain.Type.WALL)
	for y in range(ch.height):
		ch.set_terrain(0, y, Terrain.Type.WALL); ch.set_terrain(ch.width - 1, y, Terrain.Type.WALL)
	# a couple of pillars for cover, Kai's mark glowing in the sand
	for p in [[4, 4], [12, 4], [4, 10], [12, 10]]:
		ch.set_terrain(p[0], p[1], Terrain.Type.PILLAR)
	# Kai spawns dead centre, solo
	var spawn := UnitSpawn.new()
	spawn.unit = load("res://data/units/kai.tres")
	spawn.cell = Vector2i(8, 7)
	ch.player_spawns.append(spawn)
	print("arena chapter err=", ResourceSaver.save(ch, "res://data/chapters/arena.tres"))
	quit()
