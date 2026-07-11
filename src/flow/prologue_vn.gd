class_name PrologueVN
extends Control
## AW-78: the awakening VN — plays the prologue's dialogue scripts in sequence
## over full-screen backdrops with the hearth narrator's voice (co-write
## 2026-07-10, scenes 1–2 wired first). When the last script ends, hands off:
## in the campaign flow that will be the road; standalone (dev jump) it returns
## to the title.

## The scripts, in order. Backdrops/voice ride inside the scripts themselves.
@export var scripts: Array[String] = [
	"res://data/dialogue/prologue_forest_intro.json",
	"res://data/dialogue/prologue_cave_awakening.json",
]
## Where to go when the sequence ends ("" = stay; tests set "").
@export var exit_scene: String = "res://scenes/title/title.tscn"
## Seconds per line for unattended playback (movie renders); 0 = input-driven.
@export var autoplay_delay: float = 0.0

var _i := -1
var _dialogue: DialogueScene
var _auto_t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	AudioManager.stop_music()  # the narrator opens in silence; music cues later
	_dialogue = DialogueScene.new()
	_dialogue.finished.connect(_next_script)
	add_child(_dialogue)
	_next_script()


func _next_script() -> void:
	_i += 1
	if _i >= scripts.size():
		if exit_scene != "":
			get_tree().change_scene_to_file.call_deferred(exit_scene)
		return
	var s := DialogueScript.from_file(scripts[_i])
	if not s.ok():
		push_warning("PrologueVN: %s — %s" % [scripts[_i], s.error])
		_next_script()
		return
	_dialogue.play(s)


func _process(delta: float) -> void:
	if autoplay_delay <= 0.0 or _dialogue.is_finished():
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
