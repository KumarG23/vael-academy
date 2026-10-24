extends Node
## Read-only QA observer. No input/action/save/entry handlers are called.

var _last_phase := -1
var _last_room := ""
var _events: FileAccess
var _started := 0


func _ready() -> void:
	_started = Time.get_ticks_msec()
	_events = FileAccess.open(OS.get_environment("QA_OUT") + "/events.jsonl", FileAccess.WRITE)


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if not scene is CastleScene:
		return
	var castle := scene as CastleScene
	var state := {
		"ms": Time.get_ticks_msec() - _started,
		"room": castle.room.id, "position": [castle._avatar.position.x, castle._avatar.position.y],
		"cell": [castle._grid.world_to_cell(castle._avatar.position).x, castle._grid.world_to_cell(castle._avatar.position).y],
		"fade": int(castle._room_fade), "alpha": castle._fade_cover.modulate.a,
		"cover": castle._fade_cover.visible, "busy": castle.busy(), "armed": castle._door_armed,
		"journal": castle._journal != null, "map": castle._room_map != null,
		"editor": castle._editor.active, "menu": castle._menu_context,
		"dialogue": castle._dialogue != null, "prompt": castle._prompt.text,
		"title_alpha": castle._title_card._alpha, "title_visible": castle._title_card.visible,
		"campaign": Campaign.to_dict(), "supports": castle._support_state.save_state(),
		"viewport": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"time_scale": Engine.time_scale,
	}
	if castle._room_map != null:
		var map := castle._room_map
		var destinations: Array = []
		for i in range(map.destinations.size()):
			var label: Control = map._destination_labels[i] if i < map._destination_labels.size() else null
			var centre := label.get_global_rect().get_center() if label != null else Vector2.ZERO
			destinations.append({"id": map.destinations[i].id, "point": [centre.x, centre.y]})
		state["destinations"] = destinations
		state["selected"] = map.selected
		state["travel_list"] = map.showing_destinations
	var file := FileAccess.open(OS.get_environment("QA_OUT") + "/state.json.tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify(state))
	file.close()
	DirAccess.rename_absolute(OS.get_environment("QA_OUT") + "/state.json.tmp", OS.get_environment("QA_OUT") + "/state.json")
	if int(castle._room_fade) != _last_phase or castle.room.id != _last_room:
		_events.store_line(JSON.stringify(state))
		_events.flush()
		_last_phase = int(castle._room_fade)
	if castle.room.id != _last_room:
		_last_room = castle.room.id
		var cells: Array = []
		for y in range(castle._grid.height):
			for x in range(castle._grid.width):
				if not castle._terrain_db.is_impassable(castle.room.chapter.get_terrain(x, y)):
					cells.append([x, y])
		var doors: Array = []
		for door: CastleDoor in castle.room.doors:
			doors.append({"cell": [door.cell.x, door.cell.y], "target": door.to_room})
		var points: Array = []
		for point: CastlePoint in castle.room.points:
			points.append({"id": point.id, "cell": [point.cell.x, point.cell.y]})
		var world := FileAccess.open(OS.get_environment("QA_OUT") + "/world.json", FileAccess.WRITE)
		world.store_string(JSON.stringify({"room": castle.room.id, "cells": cells, "doors": doors, "points": points, "cell_size": castle._grid.cell_size}))
