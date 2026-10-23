extends Node
## GH-65 QA: READ-ONLY battle state reporter. Writes one JSON line whenever the
## observable state changes, plus every native illustrated contact and a full
## battle/roster payload each time an exchange settles. It never calls a game
## action, input, combat or save handler.

var out_path := ""
var _file: FileAccess
var _last := ""
var _hooked := {}
var _was_busy := false
var _t0 := 0
var _keys := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_msec()
	_file = FileAccess.open(out_path, FileAccess.WRITE)


func _write(kind: String, data: Variant) -> void:
	_file.store_line(JSON.stringify({"ms": Time.get_ticks_msec() - _t0, "kind": kind, "data": data}))
	_file.flush()


func _process(_delta: float) -> void:
	var view := get_tree().current_scene
	if view == null or not view.has_method("make_save_payload"):
		var name := str(view.name) if view != null else ""
		if name != _last:
			_last = name
			_write("scene", name)
		return
	if not _hooked.has(view.get_instance_id()) and view.get("_illustrated_combat") != null:
		_hooked[view.get_instance_id()] = true
		view._illustrated_combat.impact_applied.connect(func(source: Node, strike: Object) -> void:
			_write("contact", {"unit": source.unit_id(), "hp": source.current_hp, "strike": str(strike)}))
	# Physical key edges as the OS delivered them (Input state is read only).
	for key in [KEY_ESCAPE, KEY_ENTER, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		var down := Input.is_physical_key_pressed(key)
		if down != _keys.get(key, false):
			_keys[key] = down
			_write("key", {"key": OS.get_keycode_string(key), "down": down})
	var state := _summary(view)
	var line := JSON.stringify(state)
	if line != _last:
		_last = line
		_write("state", state)
	var busy: bool = view._busy
	if _was_busy and not busy:
		var payload: Dictionary = view.make_save_payload()
		_write("settled", {"battle": payload["battle"], "roster": payload["roster"], "supports": payload["supports"]})
	_was_busy = busy


func _summary(view: Node) -> Dictionary:
	var units := []
	for u in view._units:
		if not is_instance_valid(u):
			continue
		var uses := []
		for item in u.inventory.items:
			uses.append(item.uses)
		var px: Vector2 = view._cursor.get_global_transform_with_canvas() * view._grid.cell_center(u.cell)
		units.append([u.unit_id(), u.team, u.current_hp, [u.cell.x, u.cell.y], u.has_acted, u.xp, u.level, uses, u.visible, [roundi(px.x), roundi(px.y)]])
	var skip = view._combat_exec.get("_skip_input")
	var cursor = view._cursor
	return {
		"phase": view._phase,
		"busy": view._busy,
		"armed": skip != null and is_instance_valid(skip) and skip.is_armed(),
		"hint": skip != null and is_instance_valid(skip) and skip.hint_visible(),
		"cursor": [cursor.cell.x, cursor.cell.y],
		"selected": view._selected.unit_id() if view._selected != null and is_instance_valid(view._selected) else "",
		"menu": view._menu.visible,
		"menu_context": view._menu_context,
		"menu_actions": view._menu_actions,
		"round": view._turn.round_number,
		"team": int(view._turn.active_team),
		"over": view._battle_over,
		"victory": view._battle_victory,
		"result": view._result_screen.is_shown(),
		"level_up": view._level_up_screen.visible,
		"rng": str(view._rng.state_value()),
		"ui_layer": view._ui_layer.visible,
		"stage": view._illustrated_combat != null and view._illustrated_combat._stage.visible,
		"beat": view._illustrated_combat.current_beat if view._illustrated_combat != null else "",
		"popup": view._battle_popup._root.visible,
		"cam": view._combat_cam_active,
		"time_scale": Engine.time_scale,
		"dialogue": view._dialogue_playing,
		"units": units,
	}
