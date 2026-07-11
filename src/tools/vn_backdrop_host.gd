extends Node
## AW-78 render rig: loads a VN room (data/vn_rooms/<VN_ROOM>.tres) into a
## castle scene, hides the actor and HUD, fits the camera to the whole map, and
## sits still so --write-movie can grab clean backdrop frames. Not shipped UI.


func _ready() -> void:
	var room_id := OS.get_environment("VN_ROOM")
	if room_id == "":
		room_id = "vn_forest"
	Campaign.reset_new_game(false)
	Campaign.set_house("emberwing")
	Campaign.house_locked = true
	var castle := (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
	add_child(castle)
	var room: CastleRoomDef = load("res://data/vn_rooms/%s.tres" % room_id)
	castle._rooms[room.id] = room
	castle.enter_room(room.id, Vector2i(room.chapter.width / 2, room.chapter.height / 2))
	castle._avatar.visible = false
	castle._date_label.visible = false
	castle._title_card.visible = false
	for npc in castle._npc_sprites:
		npc.visible = false
	# per-room mood: the woods keep daylight; underground goes cold and dark,
	# with the sanctum core re-drawn UNMODULATED so its hearthlight burns through
	match room_id:
		"vn_cave":
			castle.modulate = Color(0.36, 0.38, 0.52)
		"vn_sanctum":
			castle.modulate = Color(0.34, 0.33, 0.46)
			var core := Sprite2D.new()
			core.texture = load("res://assets/art/pixellab/props/sanctum_core.png")
			core.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			core.scale = Vector2.ONE * 2.5
			core.position = castle._grid.pixel_size() * 0.5 - Vector2(0, 20)
			core.z_index = 50
			add_child(core)
	# frame the WHOLE room
	var map: Vector2 = castle._grid.pixel_size()
	var vp := get_viewport().get_visible_rect().size
	castle._camera.zoom = Vector2.ONE * minf(vp.x / map.x, vp.y / map.y)
	castle._camera.position = map * 0.5
	castle._camera.reset_smoothing()
