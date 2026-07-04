class_name HubScene
extends Control
## The Academy Hub (§4 / WO-3.5): a menu-driven base screen between battles with a
## house-themed backdrop. Four sections — Common Hall (unlocked supports + a flavor
## line), Training Grounds (+10 XP, one unit per visit), Quartermaster (roster +
## inventory), Mission Board (briefing → deploy) — plus Save. Reads/writes the
## Campaign autoload so progression flows hub → battle → hub.

const BATTLE_SCENE := "res://scenes/battle/mock_battle.tscn"

const FLAVOR := [
	"Ash claps you on the back. \"Emberwing fights as one — stay close out there.\"",
	"Kael is already at the training dummies before dawn. He nods as you pass.",
	"Brenna polishes her lance in silence, then offers you the whetstone.",
	"Wren hums a healing hymn in the Common Hall, and the room feels lighter.",
]

var _menu: ChoiceMenu
var _player_house: HouseDef
var _support_state := SupportState.new()
var _roster_defs: Array[UnitDef] = []
var _context := "main"
var _info: Array[String] = []
var _flavor_line := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Campaign.begin_hub_visit()
	_player_house = load("res://data/houses/emberwing.tres")
	_setup_supports()
	_roster_defs = Roster.player_units()
	_flavor_line = FLAVOR[Campaign.unit_states.size() % FLAVOR.size()]
	_menu = ChoiceMenu.new()
	if _player_house != null:
		_menu.accent = _player_house.secondary_color
	_menu.chosen.connect(_on_chosen)
	_menu.cancelled.connect(_on_cancelled)
	add_child(_menu)
	_open_main()


func _setup_supports() -> void:
	var chain: SupportChainDef = load("res://data/supports/ash_kael.tres")
	_support_state = SupportState.new()
	if chain != null:
		_support_state.add_chain(chain)
	_support_state.apply_save_state(Campaign.support_save)


# --- menu flow ----------------------------------------------------------------

func _menu_pos() -> Vector2:
	return Vector2(get_viewport_rect().size.x * 0.60, 150)


func _open_main() -> void:
	_context = "main"
	_info = [
		"Welcome back to Vael Academy.",
		"House Emberwing musters for the inter-house Mock Battle.",
		"",
		"Roster: " + ", ".join(_roster_names()),
	]
	var last := Campaign.last_result
	if last != "":
		_info.append("")
		_info.append("Last battle: " + last.to_upper())
	_menu.open("Vael Academy — Emberwing", [
		"Common Hall", "Training Grounds", "Quartermaster", "Mission Board", "Save Game",
	], _menu_pos())
	queue_redraw()


func _on_chosen(index: int) -> void:
	match _context:
		"main":
			_do_main(index)
		"training":
			_do_train(index)
		"quarter":
			_show_unit_detail(index)
		"commonhall":
			pass  # entries are informational for now (conversations play in WO-4.2)
		"mission":
			_do_mission(index)


func _on_cancelled() -> void:
	if _context != "main":
		_open_main()


func _do_main(index: int) -> void:
	match index:
		0: _open_common_hall()
		1: _open_training()
		2: _open_quartermaster()
		3: _open_mission()
		4: _save_game()


# --- Common Hall --------------------------------------------------------------

func _open_common_hall() -> void:
	_context = "commonhall"
	var convos := _support_state.unlocked_conversations_for_unit("ash")
	var labels: Array = []
	for c in convos:
		labels.append(c["label"])
	if labels.is_empty():
		labels = ["(no supports unlocked yet)"]
	_info = ["Common Hall", "", _flavor_line, "", "Unlocked support conversations:"]
	_menu.open("Common Hall", labels, _menu_pos())
	queue_redraw()


# --- Training Grounds ---------------------------------------------------------

func _open_training() -> void:
	_context = "training"
	_info = ["Training Grounds", "", "Grant one unit +%d XP this visit." % CampaignState.TRAINING_XP]
	if not Campaign.can_train():
		_info.append("")
		_info.append("You have already trained a unit this visit.")
	_menu.open("Training Grounds", _training_labels(), _menu_pos())
	queue_redraw()


func _training_labels() -> Array:
	var labels: Array = []
	for def in _roster_defs:
		labels.append("%s   %s" % [def.display_name, _level_xp_text(def.id)])
	return labels


func _do_train(index: int) -> void:
	var def := _roster_defs[index]
	if not Campaign.can_train():
		_info.append("Already trained this visit.")
		queue_redraw()
		return
	var results := Campaign.train_unit(def.id)
	var msg := "%s trained: +%d XP" % [def.display_name, CampaignState.TRAINING_XP]
	if results.size() > 0:
		msg += "  —  LEVEL UP to %d!" % def_level_after(def.id)
	_info = ["Training Grounds", "", msg]
	# Refresh the labels to show the new XP, but training is spent for this visit.
	_menu.open("Training Grounds", _training_labels(), _menu_pos())
	queue_redraw()


func def_level_after(id: String) -> int:
	return int(Campaign.get_unit_state(id).get("level", 1))


# --- Quartermaster ------------------------------------------------------------

func _open_quartermaster() -> void:
	_context = "quarter"
	_info = ["Quartermaster", "", "Select a unit to inspect."]
	var labels: Array = []
	for def in _roster_defs:
		labels.append(def.display_name)
	_menu.open("Quartermaster", labels, _menu_pos())
	queue_redraw()


func _show_unit_detail(index: int) -> void:
	var def := _roster_defs[index]
	var scratch := _scratch_unit(def)
	var inv: Array = []
	for item in scratch.inventory.items:
		inv.append(item.display_name())
	_info = [
		"Quartermaster — %s" % def.display_name,
		"Class: %s   %s" % [scratch.current_class().display_name, _level_xp_text(def.id)],
		"HP %d   STR %d   SKL %d   SPD %d   DEF %d" % [
			scratch.max_hp(), scratch.stat("str"), scratch.stat("skl"),
			scratch.stat("spd"), scratch.stat("def"),
		],
		"Inventory: " + (", ".join(inv) if not inv.is_empty() else "(empty)"),
	]
	scratch.free()
	queue_redraw()


# --- Mission Board ------------------------------------------------------------

func _open_mission() -> void:
	_context = "mission"
	_info = [
		"Mission Board",
		"",
		"CHAPTER 1 — The Mock Battle",
		"Vael Academy's inter-house exercise. Emberwing takes the field against",
		"Tidemark, who hold the fort. Defeat Serra, or rout them all.",
	]
	_menu.open("Mission Board", ["Deploy to the Mock Battle", "Back"], _menu_pos())
	queue_redraw()


func _do_mission(index: int) -> void:
	if index == 0:
		deploy()
	else:
		_open_main()


func deploy() -> void:
	Campaign.deploy()
	get_tree().change_scene_to_file(BATTLE_SCENE)


# --- Save ---------------------------------------------------------------------

func _save_game() -> void:
	Campaign.save_to_slot(0)
	_info = ["Game saved to slot 0."]
	_open_main()
	_info = ["Game saved to slot 0.", "", "Roster: " + ", ".join(_roster_names())]
	queue_redraw()


# --- helpers ------------------------------------------------------------------

func _roster_names() -> Array:
	var out: Array = []
	for def in _roster_defs:
		out.append(def.display_name)
	return out


func _level_xp_text(id: String) -> String:
	var state := Campaign.get_unit_state(id)
	var lv := int(state.get("level", 1))
	var xp := int(state.get("xp", 0))
	return "Lv %d  (%d/100 XP)" % [lv, xp]


## A throwaway Unit built from the base def + campaign progression, for display.
func _scratch_unit(def: UnitDef) -> Unit:
	var u := Unit.new()
	u.setup(def, Grid.new(1, 1), Vector2i.ZERO)
	if Campaign.has_unit_state(def.id):
		u.apply_progression_state(Campaign.get_unit_state(def.id))
	return u


func _draw() -> void:
	var vp := get_viewport_rect().size
	var tint := _player_house.theme_tint if _player_house != null else Color.WHITE
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.10, 0.09, 0.11), true)
	# House-tinted backdrop band.
	var accent := _player_house.primary_color if _player_house != null else Color(0.5, 0.5, 0.5)
	draw_rect(Rect2(0, 0, vp.x, 90), Color(accent.r, accent.g, accent.b, 0.55) * tint, true)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(40, 60), "Vael Academy", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color.WHITE)
	# Info panel (left).
	var y := 170.0
	for line in _info:
		draw_string(font, Vector2(48, y), line, HORIZONTAL_ALIGNMENT_LEFT, vp.x * 0.5, 20, Color(0.92, 0.93, 0.97))
		y += 30
