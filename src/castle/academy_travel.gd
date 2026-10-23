class_name AcademyTravel
extends RefCounted
## WO-9.8: derive destinations and arrivals from the existing room/door data.
## No alternate topology, names, progression gates or world mutations.

static func is_public(room: CastleRoomDef) -> bool:
	return room != null and room.chapter != null and room.id != "grove" \
		and not room.id.begins_with("vael_")


static func public_rooms() -> Dictionary:
	var rooms: Dictionary = {}
	var dir := DirAccess.open("res://data/castle_v2")
	if dir != null:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				var room := load("res://data/castle_v2/" + file) as CastleRoomDef
				if is_public(room):
					rooms[room.id] = room
	return rooms


static func valid_visits(value: Variant) -> bool:
	if not value is Array:
		return false
	for member: Variant in value:
		if not member is String or member.is_empty():
			return false
		for character: String in member:
			if not character in "abcdefghijklmnopqrstuvwxyz0123456789_":
				return false
	return true


## A destination must still be reachable through existing public doors. Doors
## currently have no access-condition field; never route through excluded spaces.
static func reachable(rooms: Dictionary, current: String, terrain: TerrainDB = null) -> Array[String]:
	if terrain == null:
		terrain = TerrainDB.create_default()
	var found: Array[String] = []
	if not rooms.has(current) or not is_public(rooms[current]):
		return found
	found.append(current)
	var index := 0
	while index < found.size():
		var source: CastleRoomDef = rooms[found[index]]
		for door: CastleDoor in source.doors:
			if rooms.has(door.to_room) and is_public(rooms[door.to_room]) and not found.has(door.to_room) \
					and passable_cell(source, door.cell, terrain) \
					and passable_cell(rooms[door.to_room], door.spawn_cell, terrain):
				found.append(door.to_room)
		index += 1
	return found


static func passable_cell(room: CastleRoomDef, cell: Vector2i, terrain: TerrainDB) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= room.chapter.width or cell.y >= room.chapter.height:
		return false
	return not terrain.is_impassable(room.chapter.get_terrain(cell.x, cell.y))


static func safe_cell(room: CastleRoomDef, cell: Vector2i, terrain: TerrainDB) -> bool:
	if not passable_cell(room, cell, terrain):
		return false
	for door: CastleDoor in room.doors:
		if door.cell == cell:
			return false
	for point: CastlePoint in room.points:
		if point.cell == cell:
			return false
	return true


## Only authored inbound spawns qualify. Broken data fails closed, rather than
## guessing a room centre or crossing a wall to invent an arrival.
static func arrival(rooms: Dictionary, current: String, target: String, terrain: TerrainDB) -> Vector2i:
	var accessible := reachable(rooms, current, terrain)
	if not target in accessible:
		return Vector2i(-1, -1)
	var destination: CastleRoomDef = rooms[target]
	for source_id: String in accessible:
		var source: CastleRoomDef = rooms[source_id]
		for door: CastleDoor in source.doors:
			if door.to_room == target and passable_cell(source, door.cell, terrain) \
					and safe_cell(destination, door.spawn_cell, terrain):
				return door.spawn_cell
	return Vector2i(-1, -1)
