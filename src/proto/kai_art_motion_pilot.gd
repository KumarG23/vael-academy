class_name KaiArtMotionPilot
extends AuthoredMotionPilot
## CP-5: limited existing-art transfer test, not a finished drawn walk/turn.
var illustration: KaiArtMotion
var show_art := true


func _build_ui() -> void:
	super._build_ui()
	var top := _status.get_parent()
	(top.get_child(0) as Label).text = "Kai's existing art • motion transfer test"
	(top.get_child(1) as Label).text = "Original face and body art • authored movement reference"
	for button: Button in find_children("*", "Button", true, false):
		if button.text == "Turn":
			button.text = "3D turn reference"
	for label: Label in find_children("*", "Label", true, false):
		if label.text.begins_with("Left / Right:"):
			label.text = "← / →: walk • 6: demo • K: compare • F: normal/formal • T: 3D turn reference • Esc: title"
	var compare := Button.new()
	compare.text = "Original Kai art / mannequin (K)"
	compare.pressed.connect(_compare)
	_status.get_parent().add_child(compare)


func _make_actor() -> void:
	super._make_actor()
	actor.player.play("Idle",0.0)
	actor.player.advance(0.0)
	illustration = KaiArtMotion.new()
	actor.add_child(illustration)
	illustration.setup(actor)
	_update_comparison()


func _compare() -> void:
	show_art = not show_art
	_update_comparison()


func _update_comparison() -> void:
	illustration.visible = show_art
	actor.sprite.visible = not show_art
	_status.text = "Existing Kai artwork • authored-motion transfer TEST" if show_art else "Accepted mannequin • authored motion reference"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		get_viewport().set_input_as_handled()
		_compare()
	else:
		super._unhandled_input(event)


func _act(action: String) -> void:
	if action == "turn" and show_art:
		# There is no painted back view. Show the real 3D reference honestly.
		show_art = false
		_update_comparison()
	super._act(action)
	if illustration != null:
		illustration.set_carrying(actor.carrying)
