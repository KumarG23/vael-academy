class_name PrologueVN
extends Control
## VS-1A: the five authored Awakening scenes (co-write 2026-07-10).
## opening.tscn opts into campaign flags and hands off to the road. The original
## prologue_vn.tscn remains a standalone preview returning to Title.

## The scripts, in order. Backdrops/voice ride inside the scripts themselves.
@export var scripts: Array[String] = [
	"res://data/dialogue/prologue_forest_intro.json",
	"res://data/dialogue/prologue_cave_awakening.json",
	"res://data/dialogue/prologue_oakstead_wake.json",
	"res://data/dialogue/prologue_parent_reveal.json",
	"res://data/dialogue/prologue_director_arrives.json",
]
## Where to go when the sequence ends ("" = stay; tests set "").
@export var exit_scene: String = "res://scenes/title/title.tscn"
## Only the normal New Game opening may write campaign progress.
@export var campaign_opening: bool = false
## Seconds per line for unattended playback (movie renders); 0 = input-driven.
@export var autoplay_delay: float = 0.0

var _i := -1
var _dialogue: DialogueScene
var _auto_t := 0.0
var _parsed: Array[DialogueScript] = []
var _ended: bool = false
var load_error: String = ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	AudioManager.stop_music()  # the narrator opens in silence; music cues later
	# Validate the whole sequence BEFORE playback: missing content must never be
	# silently skipped or mark the opening complete.
	for path in scripts:
		var script := DialogueScript.from_file(path)
		if not script.ok() or script.size() == 0:
			load_error = "Opening unavailable: %s — %s" % [path, script.error]
			break
		_parsed.append(script)
	if scripts.is_empty():
		load_error = "Opening unavailable: no scenes configured."
	if load_error != "":
		var message := Label.new()
		message.text = load_error
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(message)
		return
	_dialogue = DialogueScene.new()
	_dialogue.finished.connect(_next_script)
	_dialogue.event_triggered.connect(_on_dialogue_event)
	add_child(_dialogue)
	_next_script()


func _next_script() -> void:
	if _ended:
		return
	_i += 1
	_auto_t = 0.0
	if _i >= _parsed.size():
		_ended = true
		if campaign_opening:
			Campaign.flags["opening_complete"] = true
		if exit_scene != "":
			get_tree().change_scene_to_file.call_deferred(exit_scene)
		return
	_dialogue.play(_parsed[_i])


func _on_dialogue_event(event_name: String, params: Dictionary) -> void:
	if campaign_opening and event_name == "set_flag":
		Campaign.flags[str(params["flag"])] = true


func _process(delta: float) -> void:
	if autoplay_delay <= 0.0 or _dialogue == null or _dialogue.is_finished():
		return
	if _dialogue.is_revealing():
		return  # let the typewriter finish first
	_auto_t += delta
	if _auto_t >= autoplay_delay:
		_auto_t = 0.0
		if _dialogue.awaiting_choice():
			_dialogue.choose(0)
		else:
			_dialogue.advance()
