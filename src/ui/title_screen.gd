class_name TitleScreen
extends Control
## The title screen (WO-4.3): New Game (Classic/Casual) / Load Game / Quit.
## Entry point of the game flow — title → campaign (hub) → battle → results →
## hub → back here via "Return to Title". Placeholder painted-title until AW-5;
## the three house stripes reflect that all three houses are equal now (§4).

const HUB_SCENE := "res://scenes/castle/castle.tscn"  # WO-6.2a: the castle IS the home now
const OPENING_SCENE := "res://scenes/flow/opening.tscn"  # VS-1A: Awakening → road
const PROLOGUE_SCENE := "res://scenes/battle/prologue.tscn"       # AW-38: the game opens on the raid
const HOUSE_CHOICE_SCENE := "res://scenes/flow/house_choice.tscn"  # AW-38: then the oath
const MAX_SLOTS := 3

var _menu: ChoiceMenu
var _context := "main"
var _slots: Array = []           # SaveSystem.list_slots() entries shown in Load
var _status := ""                # Issue #83: truthful load-failure feedback
var _houses: Array[HouseDef] = []
var _save_system := SaveSystem.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for id in ["emberwing", "tidemark", "thornrook"]:
		var h: HouseDef = load("res://data/houses/%s.tres" % id)
		if h != null:
			_houses.append(h)
	_menu = ChoiceMenu.new()
	_menu.chosen.connect(_on_chosen)
	_menu.cancelled.connect(_on_cancelled)
	add_child(_menu)
	get_viewport().size_changed.connect(_layout_title)
	_open_main()


## Keep the established heading/font and short-menu appearance. At compact
## heights the same title block moves up to leave a separate menu region.
func heading_layout() -> Dictionary:
	var vp := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	var lines := ChoiceMenu.wrapped_lines("EMBERLINE TACTICS", font, 64, vp.x - 12.0)
	var pitch := ceilf(font.get_height(64))
	var height := font.get_ascent(64) + (lines.size() - 1) * pitch + 40.0 + font.get_descent(22)
	var top := minf(vp.y * 0.34 - font.get_ascent(64), vp.y - 30.0 - 230.0 - 12.0 - height)
	top = maxf(54.0 if _status != "" else 14.0, top)
	var rect := Rect2(6, top, vp.x - 12.0, height)
	return {"rect": rect, "lines": lines, "pitch": pitch,
		"baseline": top + font.get_ascent(64),
		"subtitle": top + font.get_ascent(64) + (lines.size() - 1) * pitch + 40.0}


func _menu_pos() -> Vector2:
	var vp := get_viewport_rect().size
	var heading: Rect2 = heading_layout()["rect"]
	var margin := 6.0 if vp.x <= 640.0 else 16.0
	_menu.layout_bounds = Rect2(margin, heading.end.y + 12.0, vp.x - margin * 2,
		maxf(0.0, vp.y - 30.0 - heading.end.y - 12.0))
	# Use extra horizontal room only when complete summaries need it.
	_menu.width_limit = vp.x - margin * 2
	var width := minf(_menu._fit_width(), _menu.layout_bounds.size.x)
	return Vector2((vp.x - width) * 0.5, maxf(heading.end.y + 12.0, vp.y * 0.58))


func _layout_title() -> void:
	if is_instance_valid(_menu):
		_menu._preferred_position = _menu_pos()
		_menu._layout_panel()
		# open() computes the new content width after _menu_pos() was called.
		_menu.position.x = (get_viewport_rect().size.x - _menu.size.x) * 0.5
	queue_redraw()


## AW-42: dev scene-jump targets (label, kind). Lets Neal hop into any part of
## the game for checking without playing through — F6 is a Mac system key.
const DEV_JUMPS := [
	["▶ Campus (walk the school)", "castle"],
	["▶ The Classroom (lesson & quiz)", "classroom"],
	["▶ The Arena (Kai vs waves)", "arena"],
	["▶ Mock Battle (3 houses)", "mock"],
	["▶ House-Choice screen", "housechoice"],
	["▶ Prologue battle", "prologue"],
	["▶ The Awakening (prologue VN)", "awakening"],
	["▶ Illustrated art pilot", "illustrated"],
	["▶ Authored motion pilot", "authored_motion"],
	["▶ Kai art motion test", "kai_art_motion"],
	["▶ Battle art A/B comparison", "hybrid_combat"],
	["▶ Dodge / block practice", "active_defense"],
	["Back", "back"],
]


func _open_main() -> void:
	_context = "main"
	_status = ""
	_menu.open("", ["New Game", "Load Game", "Dev Jump ▶", "Quit"], _menu_pos())
	_layout_title()
	queue_redraw()


func _open_dev() -> void:
	_context = "dev"
	_status = ""
	var labels: Array = []
	for j in DEV_JUMPS:
		labels.append(j[0])
	var pos := _menu_pos()
	var height := ChoiceMenu.PAD * 2 + ChoiceMenu.ROW_H * (labels.size() + 1)
	pos.y = minf(pos.y, get_viewport_rect().size.y - height - 20.0)
	_menu.open("Dev Jump", labels, pos)
	_layout_title()


func _dev_jump(kind: String) -> void:
	match kind:
		"active_defense":
			get_tree().change_scene_to_file.call_deferred("res://scenes/proto/active_defense_pilot.tscn")
		"hybrid_combat":
			get_tree().change_scene_to_file.call_deferred("res://scenes/proto/hybrid_combat_pilot.tscn")
		"kai_art_motion":
			get_tree().change_scene_to_file.call_deferred("res://scenes/proto/kai_art_motion_pilot.tscn")
		"authored_motion":
			get_tree().change_scene_to_file.call_deferred("res://scenes/proto/authored_motion_pilot.tscn")
		"illustrated":
			get_tree().change_scene_to_file.call_deferred("res://scenes/proto/illustrated_pilot.tscn")
		"castle":
			Campaign.reset_new_game(false)
			Campaign.set_house("emberwing")
			Campaign.house_locked = true  # mid-year, so it enters the castle hub
			get_tree().change_scene_to_file.call_deferred("res://scenes/castle/castle.tscn")
		"classroom":
			# AW-54: straight to the lesson hall — walk to "Attend the lesson".
			# A couple of lore flags are pre-set so gated questions show in the mix.
			Campaign.reset_new_game(false)
			Campaign.set_house("emberwing")
			Campaign.house_locked = true
			Campaign.flags["read_shelf_houses"] = true
			Campaign.flags["read_first_crown_stone"] = true
			CastleScene.next_room = "classroom"
			CastleScene.next_spawn = Vector2i(12, 5)
			get_tree().change_scene_to_file.call_deferred("res://scenes/castle/castle.tscn")
		"arena":
			Campaign.reset_new_game(false)
			Campaign.set_house("emberwing")
			Campaign.deploy()
			get_tree().change_scene_to_file.call_deferred("res://scenes/battle/arena.tscn")
		"mock":
			Campaign.reset_new_game(false)
			Campaign.set_house("emberwing")
			Campaign.deploy()
			BattleView.next_prep = true  # AW-74: see the preparations screen too
			get_tree().change_scene_to_file.call_deferred("res://scenes/battle/mock_battle.tscn")
		"housechoice":
			Campaign.reset_new_game(false)
			Campaign.active = true
			get_tree().change_scene_to_file.call_deferred("res://scenes/flow/house_choice.tscn")
		"prologue":
			Campaign.reset_new_game(false)
			Campaign.active = true
			get_tree().change_scene_to_file.call_deferred("res://scenes/battle/prologue.tscn")
		"awakening":
			# VS-1A: all five authored scenes, preview only; no campaign writes
			get_tree().change_scene_to_file.call_deferred("res://scenes/flow/prologue_vn.tscn")
		_:
			_open_main()


func _open_new_game() -> void:
	_context = "new"
	_status = ""
	_menu.open("New Game", ["Classic (permadeath)", "Casual", "Back"], _menu_pos())
	_layout_title()


func _open_load() -> void:
	_context = "load"
	_status = ""
	_slots = _save_system.list_slots(MAX_SLOTS)
	if _save_system.has_autosave():
		_slots.append(_save_system.autosave_entry())
	_menu.open("Load Game", _slot_labels(), _menu_pos())
	_layout_title()


func _slot_labels() -> Array:
	var labels: Array = []
	for s in _slots:
		if bool(s.get("autosave", false)):
			if str(s["chapter_id"]) == "" or int(s["week"]) < 1:
				labels.append("Autosave (unavailable)")
				continue
			labels.append("Autosave — %s W%d (%s)" % [str(s["chapter_id"]),
				int(s["week"]), "Casual" if bool(s["casual_mode"]) else "Classic"])
			continue
		var battle_tag := "  ⚔ mid-battle" if bool(s.get("in_battle", false)) else ""
		labels.append("Slot %d — %s (%s)%s" % [
			int(s["slot"]), str(s["chapter_id"]),
			"Casual" if bool(s["casual_mode"]) else "Classic",
			battle_tag,
		])
	if labels.is_empty():
		labels.append("(no saves found)")
	labels.append("Back")
	return labels


func _on_chosen(index: int) -> void:
	match _context:
		"main":
			match index:
				0: _open_new_game()
				1: _open_load()
				2: _open_dev()
				3: get_tree().quit()
		"dev":
			_dev_jump(DEV_JUMPS[index][1])
		"new":
			match index:
				0: _start_new_game(false)
				1: _start_new_game(true)
				_: _open_main()
		"load":
			_choose_slot(index)


func _on_cancelled() -> void:
	if _context != "main":
		_open_main()


func _start_new_game(casual: bool) -> void:
	prepare_new_game(casual)
	_enter_campaign()


func _choose_slot(index: int) -> void:
	_status = ""
	queue_redraw()  # erase a prior manual error when choosing Autosave too
	if index >= _slots.size():
		# The "(no saves found)" placeholder or "Back".
		if index == _slot_labels().size() - 1:
			_open_main()
		return
	if bool(_slots[index].get("autosave", false)):
		if prepare_autosave():
			_enter_campaign()
		else:
			# Keep the same occupied entry, even if removed after browsing, so
			# retry never changes the player's selection to a different save.
			_menu.open("Autosave unavailable. Retry or Back.", _slot_labels(), _menu_pos())
			_menu._index = index
			_layout_title()
		return
	# An Autosave rejection temporarily names the menu; manual feedback uses
	# the accepted #83 status band and the ordinary Load Game heading.
	_menu._title = "Load Game"
	_menu._layout_panel()
	var slot := int(_slots[index]["slot"])
	# AW-75: a slot holding a live battle resumes INTO the battle, mid-fight.
	if bool(_slots[index].get("in_battle", false)):
		var scene := Resume.stage(_save_system.load_slot(slot))
		if scene != "":
			get_tree().change_scene_to_file.call_deferred(scene)
			return
	if prepare_load(slot):
		_enter_campaign()
		return
	_report_load_failure(slot)


## Issue #83: an occupied file the existing loader rejects must say so instead
## of silently doing nothing. The Load menu stays open for another slot or Back.
func _report_load_failure(slot: int) -> void:
	if not _save_system.has_slot(slot):
		_status = "Slot %d is empty." % slot
	else:
		_status = "Slot %d couldn't be loaded — choose another slot." % slot
	AudioManager.play_sfx("cancel")
	_layout_title()


## Top-wide feedback band, measured so it stays readable at compact sizes.
func status_rect() -> Rect2:
	var vp := get_viewport_rect().size
	var width := clampf(vp.x - 80.0, 240.0, 720.0)
	return Rect2((vp.x - width) * 0.5, 14.0, width, 34.0)


func prepare_autosave(save_system: SaveSystem = null) -> bool:
	if not Campaign.load_autosave(save_system if save_system != null else _save_system):
		return false
	Campaign.active = true
	return true


## Reset the campaign for a fresh run. Split from the scene change so tests can
## exercise the flow headless.
func prepare_new_game(casual: bool) -> void:
	Campaign.reset_new_game(casual, int(Time.get_ticks_usec()))
	Campaign.flags["opening_started"] = true
	CastleScene.next_room = ""
	CastleScene.next_spawn = Vector2i(-1, -1)
	BattleView.next_resume = {}
	BattleView.next_prep = false
	Campaign.active = true  # AW-38: the campaign is live from the prologue on, so
	# the prologue battle routes through the campaign flow (→ house choice), not
	# the standalone "reload the scene" path. The castle resets this per visit.


## Load a campaign save into the Campaign autoload. Returns success.
func prepare_load(slot: int, save_system: SaveSystem = null) -> bool:
	if not Campaign.load_from_slot(slot, save_system if save_system != null else _save_system):
		return false
	# Campaign-only pre-oath saves must retain campaign battle routing too.
	Campaign.active = true
	return true


## VS-1A: new runs open with Awakening → raid → oath → castle. Only runs
## explicitly started with this opening opt in; older saves retain their route.
## Completed raid / sworn house take priority over any partial opening flags.
func _enter_campaign() -> void:
	get_tree().change_scene_to_file.call_deferred(next_campaign_scene())


func next_campaign_scene() -> String:
	if Campaign.house_locked:
		return HUB_SCENE
	if bool(Campaign.flags.get("prologue_done", false)) or bool(Campaign.flags.get("road_aftermath_seen", false)):
		return HOUSE_CHOICE_SCENE
	if bool(Campaign.flags.get("opening_started", false)) and not bool(Campaign.flags.get("opening_complete", false)):
		return OPENING_SCENE
	return PROLOGUE_SCENE


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.09, 0.08, 0.10), true)
	# Three equal house stripes across the top — nobody's house leads the banner.
	var stripe_w := vp.x / 3.0
	for i in range(_houses.size()):
		var c := _houses[i].primary_color
		draw_rect(Rect2(i * stripe_w, 0, stripe_w, 10), Color(c.r, c.g, c.b, 0.9), true)
	var font := ThemeDB.fallback_font
	# Title block (placeholder until AW-5 title art).
	var heading := heading_layout()
	var lines: Array = heading["lines"]
	for i in range(lines.size()):
		var ts := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 64)
		draw_string(font, Vector2((vp.x - ts.x) * 0.5, heading["baseline"] + i * heading["pitch"]), lines[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(0.95, 0.90, 0.80))
	var sub := "A year at Vael Academy"
	var ss := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 22)
	draw_string(font, Vector2(vp.x * 0.5 - ss.x * 0.5, heading["subtitle"]), sub,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.65, 0.62, 0.68))
	if _status != "":
		var sr := status_rect()
		# Issue #83: a 34 px band is too short for UITheme.draw_panel's ornate
		# nine-patch corners — the filigree overruns the message. This transient
		# band therefore uses the same plain navy fill + gold rule as the Journal
		# toast, so both load-failure messages read the same way.
		draw_rect(sr, Color(0.1, 0.11, 0.16, 0.95), true)
		draw_rect(sr, Color(0.86, 0.78, 0.45, 0.8), false, 1.5)
		draw_string(font, Vector2(sr.position.x + 16, sr.position.y + 23), _status,
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x - 32.0, 16, Color(0.95, 0.87, 0.70))
	var hint := "working title"
	draw_string(font, Vector2(16, vp.y - 16), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.4, 0.4, 0.45))
