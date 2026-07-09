class_name HouseChoiceScene
extends Control
## AW-38: the campaign's house-choice screen. After the prologue raid, the player
## swears their oath to one of the three Great Houses — which sets the roster and
## theming (Campaign.set_house) and LOCKS it, then enters the castle to begin the
## school year. Plays the house's pitch (draft VN) before committing.
##
## Flow wiring: TitleScreen routes New Game here-or-prologue-or-castle by campaign
## state (house_locked / prologue_done); the prologue's victory sends the player
## here.

const HOUSES := ["emberwing", "tidemark", "thornrook"]
const CASTLE := "res://scenes/castle/castle.tscn"
const TAGLINES := {
	"emberwing": "The firebird's fury — swords, cavalry, and the first strike.",
	"tidemark": "The leviathan's faith — lances, armor, and the line unbroken.",
	"thornrook": "The stag's cunning — bows, reason, and the patient shot.",
}

var _defs := {}
var _index := 0
var _dialogue: DialogueScene = null
var _committing := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for h in HOUSES:
		var path := "res://data/houses/%s.tres" % h
		if ResourceLoader.exists(path):
			_defs[h] = load(path)
	AudioManager.play_music("res://assets/audio/music/campus_chill.mp3")
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _dialogue != null or _committing:
		return
	if event.is_action_pressed("cursor_left"):
		_move(-1)
	elif event.is_action_pressed("cursor_right"):
		_move(1)
	elif event.is_action_pressed("cursor_confirm"):
		AudioManager.play_sfx("confirm")
		get_viewport().set_input_as_handled()
		pick(HOUSES[_index])


func _move(dir: int) -> void:
	_index = (_index + dir + HOUSES.size()) % HOUSES.size()
	AudioManager.play_sfx("cursor")
	get_viewport().set_input_as_handled()
	queue_redraw()


## Chosen a house: play its pitch (if authored), then commit. Public so the flow
## can be driven headlessly in tests.
func pick(house_id: String) -> void:
	var path := "res://data/dialogue/house_pitch_%s.json" % house_id
	if ResourceLoader.exists(path) and DialogueScript.from_file(path).ok():
		_play_pitch(path, house_id)
	else:
		commit(house_id)


func _play_pitch(path: String, house_id: String) -> void:
	_dialogue = DialogueScene.new()
	add_child(_dialogue)
	_dialogue.finished.connect(func() -> void:
		if _dialogue != null:
			_dialogue.queue_free()
		_dialogue = null
		commit(house_id))
	_dialogue.play(DialogueScript.from_file(path))


## Bind the house and enter the castle. set_house must run BEFORE locking (it
## refuses once locked), so order matters here.
func commit(house_id: String) -> void:
	if _committing:
		return
	_committing = true
	Campaign.set_house(house_id)
	Campaign.house_locked = true
	Campaign.flags["prologue_done"] = true
	if is_inside_tree():
		get_tree().change_scene_to_file.call_deferred(CASTLE)


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.07, 0.08, 0.12))
	var font := ThemeDB.fallback_font
	# heading
	var title := "Swear Your Oath"
	var tsize := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 40)
	draw_string(font, Vector2((vp.x - tsize.x) * 0.5, 84), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.86, 0.78, 0.45))
	var sub := "Three houses will have you. Choose where you belong."
	var ssize := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
	draw_string(font, Vector2((vp.x - ssize.x) * 0.5, 116), sub,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.72, 0.74, 0.82))
	# three house cards
	var margin := 60.0
	var gap := 24.0
	var cw := (vp.x - margin * 2 - gap * 2) / 3.0
	var top := 160.0
	var ch := vp.y - top - 110.0
	for i in range(HOUSES.size()):
		_draw_card(HOUSES[i], Rect2(margin + i * (cw + gap), top, cw, ch), i == _index, font)
	# footer hint
	var hint := "← →  choose        Enter  swear the oath"
	var hsize := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 17)
	draw_string(font, Vector2((vp.x - hsize.x) * 0.5, vp.y - 46), hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.6, 0.63, 0.72))


func _draw_card(house_id: String, r: Rect2, selected: bool, font: Font) -> void:
	var def: HouseDef = _defs.get(house_id, null)
	var primary := def.primary_color if def != null else Color.GRAY
	var accent := def.secondary_color if def != null else Color(0.85, 0.78, 0.45)
	var name_txt := def.display_name if def != null else house_id.capitalize()
	# card body
	draw_rect(r, Color(0.11, 0.12, 0.17, 0.96), true)
	# colour band at the top
	draw_rect(Rect2(r.position, Vector2(r.size.x, 10)), primary, true)
	# border — bright + accented when selected
	var bcol := accent if selected else Color(0.26, 0.29, 0.4)
	draw_rect(r, bcol, false, 3.0 if selected else 1.5)
	if selected:
		draw_rect(r.grow(4.0), Color(accent.r, accent.g, accent.b, 0.5), false, 2.0)
	var x := r.position.x + 22.0
	var y := r.position.y + 58.0
	draw_string(font, Vector2(x, y), name_txt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 44, 26, primary.lightened(0.2))
	y += 12.0
	if def != null and def.banner_animal != "":
		draw_string(font, Vector2(x, y + 18), def.banner_animal.to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 44, 12, Color(accent.r, accent.g, accent.b, 0.85))
	y += 44.0
	# tagline (wrapped)
	draw_multiline_string(font, Vector2(x, y), TAGLINES.get(house_id, ""),
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40, 16, -1, Color(0.82, 0.83, 0.9))
	# roster: heir + count
	var files: Array = Roster.HOUSE_ROSTERS.get(house_id, [])
	var yb := r.position.y + r.size.y - 70.0
	draw_line(Vector2(x, yb - 14), Vector2(r.position.x + r.size.x - 22, yb - 14),
		Color(0.26, 0.29, 0.4), 1.0)
	var heir := _heir_name(files)
	draw_string(font, Vector2(x, yb + 6), "Heir  —  " + heir,
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 44, 15, Color(0.9, 0.88, 0.78))
	draw_string(font, Vector2(x, yb + 30), "%d students" % files.size(),
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 44, 14, Color(0.62, 0.65, 0.74))


func _heir_name(files: Array) -> String:
	if files.is_empty():
		return "?"
	var def: UnitDef = load("res://data/units/%s.tres" % files[0])
	return def.display_name if def != null else str(files[0])
