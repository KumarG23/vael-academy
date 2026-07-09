class_name TitleScreen
extends Control
## The title screen (WO-4.3): New Game (Classic/Casual) / Load Game / Quit.
## Entry point of the game flow — title → campaign (hub) → battle → results →
## hub → back here via "Return to Title". Placeholder painted-title until AW-5;
## the three house stripes reflect that all three houses are equal now (§4).

const HUB_SCENE := "res://scenes/castle/castle.tscn"  # WO-6.2a: the castle IS the home now
const PROLOGUE_SCENE := "res://scenes/battle/prologue.tscn"       # AW-38: the game opens on the raid
const HOUSE_CHOICE_SCENE := "res://scenes/flow/house_choice.tscn"  # AW-38: then the oath
const MAX_SLOTS := 3

var _menu: ChoiceMenu
var _context := "main"
var _slots: Array = []           # SaveSystem.list_slots() entries shown in Load
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
	_open_main()


func _menu_pos() -> Vector2:
	var vp := get_viewport_rect().size
	return Vector2(vp.x * 0.5 - 120, vp.y * 0.58)


## AW-42: dev scene-jump targets (label, kind). Lets Neal hop into any part of
## the game for checking without playing through — F6 is a Mac system key.
const DEV_JUMPS := [
	["▶ Campus (walk the school)", "castle"],
	["▶ The Classroom (lesson & quiz)", "classroom"],
	["▶ The Arena (Kai vs waves)", "arena"],
	["▶ Mock Battle (3 houses)", "mock"],
	["▶ House-Choice screen", "housechoice"],
	["▶ Prologue battle", "prologue"],
	["Back", "back"],
]


func _open_main() -> void:
	_context = "main"
	_menu.open("", ["New Game", "Load Game", "Dev Jump ▶", "Quit"], _menu_pos())
	queue_redraw()


func _open_dev() -> void:
	_context = "dev"
	var labels: Array = []
	for j in DEV_JUMPS:
		labels.append(j[0])
	_menu.open("Dev Jump", labels, _menu_pos())


func _dev_jump(kind: String) -> void:
	match kind:
		"castle":
			Campaign.reset_new_game(false)
			Campaign.set_house("emberwing")
			Campaign.house_locked = true  # mid-year, so it enters the castle hub
			get_tree().change_scene_to_file("res://scenes/castle/castle.tscn")
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
			get_tree().change_scene_to_file("res://scenes/castle/castle.tscn")
		"arena":
			Campaign.reset_new_game(false)
			Campaign.set_house("emberwing")
			Campaign.deploy()
			get_tree().change_scene_to_file("res://scenes/battle/arena.tscn")
		"mock":
			Campaign.reset_new_game(false)
			Campaign.set_house("emberwing")
			Campaign.deploy()
			get_tree().change_scene_to_file("res://scenes/battle/mock_battle.tscn")
		"housechoice":
			Campaign.reset_new_game(false)
			Campaign.active = true
			get_tree().change_scene_to_file("res://scenes/flow/house_choice.tscn")
		"prologue":
			Campaign.reset_new_game(false)
			Campaign.active = true
			get_tree().change_scene_to_file("res://scenes/battle/prologue.tscn")
		_:
			_open_main()


func _open_new_game() -> void:
	_context = "new"
	_menu.open("New Game", ["Classic (permadeath)", "Casual", "Back"], _menu_pos())


func _open_load() -> void:
	_context = "load"
	_slots = _save_system.list_slots(MAX_SLOTS)
	_menu.open("Load Game", _slot_labels(), _menu_pos())


func _slot_labels() -> Array:
	var labels: Array = []
	for s in _slots:
		labels.append("Slot %d — %s (%s)" % [
			int(s["slot"]), str(s["chapter_id"]),
			"Casual" if bool(s["casual_mode"]) else "Classic",
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
	if index >= _slots.size():
		# The "(no saves found)" placeholder or "Back".
		if index == _slot_labels().size() - 1:
			_open_main()
		return
	if prepare_load(int(_slots[index]["slot"])):
		_enter_campaign()


## Reset the campaign for a fresh run. Split from the scene change so tests can
## exercise the flow headless.
func prepare_new_game(casual: bool) -> void:
	Campaign.reset_new_game(casual, int(Time.get_ticks_usec()))
	Campaign.active = true  # AW-38: the campaign is live from the prologue on, so
	# the prologue battle routes through the campaign flow (→ house choice), not
	# the standalone "reload the scene" path. The castle resets this per visit.


## Load a campaign save into the Campaign autoload. Returns success.
func prepare_load(slot: int, save_system: SaveSystem = null) -> bool:
	return Campaign.load_from_slot(slot, save_system if save_system != null else _save_system)


## AW-38: the campaign now opens with the prologue raid, then the house-choice
## oath, then the castle year — routed by how far the save has come. A locked
## house means the year's underway (the usual Load-into-castle case).
func _enter_campaign() -> void:
	get_tree().change_scene_to_file(next_campaign_scene())


func next_campaign_scene() -> String:
	if Campaign.house_locked:
		return HUB_SCENE
	if bool(Campaign.flags.get("prologue_done", false)):
		return HOUSE_CHOICE_SCENE
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
	var title := "EMBERLINE TACTICS"
	var ts := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 64)
	draw_string(font, Vector2(vp.x * 0.5 - ts.x * 0.5, vp.y * 0.34), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(0.95, 0.90, 0.80))
	var sub := "A year at Vael Academy"
	var ss := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 22)
	draw_string(font, Vector2(vp.x * 0.5 - ss.x * 0.5, vp.y * 0.34 + 40), sub,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.65, 0.62, 0.68))
	var hint := "working title"
	draw_string(font, Vector2(16, vp.y - 16), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.4, 0.4, 0.45))
