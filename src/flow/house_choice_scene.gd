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
var choice_error: String = ""
var _actions: HBoxContainer
var _preview_button: Button
var _preview: PanelContainer
var _preview_scroll: ScrollContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for h in HOUSES:
		var path := "res://data/houses/%s.tres" % h
		if ResourceLoader.exists(path):
			_defs[h] = load(path)
	AudioManager.play_music("res://assets/audio/music/campus_chill.mp3")
	_build_actions()
	queue_redraw()


func _build_actions() -> void:
	_actions = HBoxContainer.new()
	_actions.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_actions.offset_left = 60
	_actions.offset_right = -60
	_actions.offset_top = -104
	_actions.offset_bottom = -62
	_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_actions.add_theme_constant_override("separation", 24)
	add_child(_actions)
	_preview_button = Button.new()
	_preview_button.text = "Preview roster (R)"
	_preview_button.pressed.connect(func() -> void: preview(HOUSES[_index]))
	_actions.add_child(_preview_button)
	var oath := Button.new()
	oath.text = "Swear the oath"
	oath.pressed.connect(func() -> void: pick(HOUSES[_index]))
	_actions.add_child(oath)


## Keep house navigation available after Back restores focus to a button.
## Preview navigation runs before focused controls so arrow keys always scroll.
func _input(event: InputEvent) -> void:
	if _preview == null:
		if _dialogue == null and not _committing:
			if event.is_action_pressed("cursor_left"):
				_move(-1)
			elif event.is_action_pressed("cursor_right"):
				_move(1)
		return
	if event.is_action_pressed("cursor_cancel"):
		get_viewport().set_input_as_handled()
		close_preview()
	elif event.is_action_pressed("cursor_up") or event.is_action_pressed("cursor_down"):
		get_viewport().set_input_as_handled()
		_preview_scroll.scroll_vertical += 64 if event.is_action_pressed("cursor_down") else -64
	elif event is InputEventKey and event.pressed:
		var key: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == KEY_PAGEUP or key == KEY_PAGEDOWN:
			get_viewport().set_input_as_handled()
			var page := int(_preview_scroll.size.y * 0.9)
			_preview_scroll.scroll_vertical += page if key == KEY_PAGEDOWN else -page


func _unhandled_input(event: InputEvent) -> void:
	if _dialogue != null or _committing:
		return
	if _preview != null:
		# Enter can activate Back through GUI focus, but can never reach pick().
		if event.is_action_pressed("cursor_confirm"):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("cursor_left"):
		_move(-1)
	elif event.is_action_pressed("cursor_right"):
		_move(1)
	elif event.is_action_pressed("cursor_confirm") and not event.is_echo():
		AudioManager.play_sfx("confirm")
		get_viewport().set_input_as_handled()
		pick(HOUSES[_index])
	elif event is InputEventKey and event.pressed and not event.echo \
			and (event.physical_keycode == KEY_R or event.keycode == KEY_R):
		get_viewport().set_input_as_handled()
		preview(HOUSES[_index])


func _move(dir: int) -> void:
	if _preview != null or _dialogue != null or _committing:
		return
	_index = (_index + dir + HOUSES.size()) % HOUSES.size()
	AudioManager.play_sfx("cursor")
	get_viewport().set_input_as_handled()
	queue_redraw()


## Native starting labels only; opening and closing never bind a house.
func preview(house_id: String) -> void:
	if _preview != null or _dialogue != null or _committing:
		return
	if Campaign.house_locked or not HOUSES.has(house_id):
		return
	var rows := HousePreview.members(house_id)
	_preview = PanelContainer.new()
	_preview.name = "RosterPreview"
	_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview.offset_left = 60
	_preview.offset_right = -60
	_preview.offset_top = 140
	_preview.offset_bottom = -62
	add_child(_preview)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_preview.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var heading := Label.new()
	var def: HouseDef = load("res://data/houses/%s.tres" % house_id)
	heading.text = "%s — Starting roster" % def.display_name
	heading.add_theme_font_size_override("font_size", 24)
	content.add_child(heading)
	_preview_scroll = ScrollContainer.new()
	_preview_scroll.name = "Members"
	_preview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_preview_scroll)
	var members := VBoxContainer.new()
	members.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	members.add_theme_constant_override("separation", 12)
	_preview_scroll.add_child(members)
	for row in rows:
		var member := VBoxContainer.new()
		members.add_child(member)
		var identity := Label.new()
		identity.text = "%s — %s" % [row["name"], row["class_name"]]
		identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		member.add_child(identity)
		var equipment := Label.new()
		equipment.text = "Starting equipment: %s" % row["starting_weapon"]
		equipment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		member.add_child(equipment)
	var back := Button.new()
	back.name = "Back"
	back.text = "Back to houses (Esc)"
	back.pressed.connect(close_preview)
	content.add_child(back)
	if _actions != null:
		_actions.hide()
	back.grab_focus()
	queue_redraw()


func close_preview() -> void:
	if _preview == null:
		return
	_preview.hide()
	_preview.queue_free()
	_preview = null
	_preview_scroll = null
	if _actions != null:
		_actions.show()
		_preview_button.grab_focus()
	queue_redraw()


## Preview a valid, non-empty house pitch, then bind once it finishes. Missing
## content fails visibly without changing campaign state. Also callable headlessly.
func pick(house_id: String) -> void:
	if _preview != null or _dialogue != null or _committing:
		return
	if Campaign.house_locked or not HOUSES.has(house_id):
		_reject_choice("That house choice is unavailable.")
		return
	var path := _pitch_path(house_id)
	var pitch := DialogueScript.from_file(path)
	var has_content := false
	if pitch.ok():
		for step in pitch.steps:
			if step.is_line() and not step.text.strip_edges().is_empty():
				has_content = true
				break
	if not pitch.ok() or not has_content:
		_reject_choice("House pitch unavailable. Please choose another house.")
		return
	choice_error = ""
	_play_pitch(pitch, house_id)


func _reject_choice(message: String) -> void:
	choice_error = message
	if _actions != null and _preview == null and _dialogue == null and not _committing:
		_actions.show()
	queue_redraw()


func _pitch_path(house_id: String) -> String:
	return "res://data/dialogue/house_pitch_%s.json" % house_id


func _play_pitch(pitch: DialogueScript, house_id: String) -> void:
	var dialogue := DialogueScene.new()
	var origin_flags := Campaign.flags
	var origin_house := Campaign.house_id
	_dialogue = dialogue
	if _actions != null:
		_actions.hide()
	add_child(dialogue)
	dialogue.finished.connect(func() -> void:
		if _dialogue != dialogue:
			return
		_dialogue = null
		dialogue.queue_free()
		# Reset/load replaces flags: an old scene must never bind a new campaign.
		if not is_same(Campaign.flags, origin_flags) or Campaign.house_id != origin_house:
			_reject_choice("Campaign changed. Please choose your house again.")
			return
		commit(house_id), CONNECT_ONE_SHOT)
	dialogue.play(pitch)


## Bind the house and enter the castle. set_house must run BEFORE locking (it
## refuses once locked), so order matters here.
func commit(house_id: String) -> void:
	if _preview != null or _committing:
		return
	if Campaign.house_locked or not HOUSES.has(house_id) or not Roster.HOUSE_ROSTERS.has(house_id):
		_reject_choice("That house choice is unavailable.")
		return
	if _dialogue != null:
		_reject_choice("Finish the current house pitch before swearing.")
		return
	_committing = true
	Campaign.set_house(house_id)
	if Campaign.house_id != house_id or Roster.active_house != house_id:
		_committing = false
		_reject_choice("House choice could not be confirmed. Please try again.")
		return
	choice_error = ""
	Campaign.house_locked = true
	Campaign.flags["prologue_done"] = true
	if _actions != null:
		_actions.hide()
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
	var ch := vp.y - top - 126.0
	if _preview == null:
		for i in range(HOUSES.size()):
			_draw_card(HOUSES[i], Rect2(margin + i * (cw + gap), top, cw, ch), i == _index, font)
	# footer hint
	var hint := "← →  choose        R  preview roster        Enter / Space  activate        Tab  buttons"
	if _preview != null:
		hint = "↑ ↓ / Page Up / Page Down / mouse wheel  scroll        Esc  back"
	elif choice_error != "":
		hint = choice_error
	var hsize := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 17)
	draw_string(font, Vector2((vp.x - hsize.x) * 0.5, vp.y - 26), hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.95, 0.66, 0.44) if choice_error != "" else Color(0.6, 0.63, 0.72))


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
