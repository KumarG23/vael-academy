class_name DialogueStep
extends RefCounted
## One step of a dialogue script (§4): a spoken LINE, an EVENT hook
## (start_battle, give_item, ...), or — since WO-4.6 — the branching steps:
## a CHOICE the player answers, a LABEL marking a jump target, and a GOTO
## jumping to one. Parsed from JSON by DialogueScript.

enum Kind { LINE, EVENT, CHOICE, LABEL, GOTO }

var kind: Kind

# LINE fields (CHOICE reuses `text` as its prompt).
var speaker: String = ""
var text: String = ""
var side: String = "left"          # "left" or "right"
var portrait: String = ""          # portrait id (art swaps in at AW-6)
var expression: String = "neutral"
# AW-78 (VN prologue): optional per-line narration voice clip and backdrop.
# `backdrop` is a res:// image path, or the specials "black" / "white".
var voice: String = ""
var backdrop: String = ""
var music: String = ""   # AW-79: music change on this line ("" = no change, "stop" = silence)

# EVENT fields.
var event_name: String = ""
var params: Dictionary = {}

# CHOICE fields: each option is {"text": String, "goto": String, "flag": String}
# ("goto" empty = fall through to the next step; "flag" empty = nothing recorded).
var options: Array = []

# LABEL / GOTO fields: the label's name / the jump's destination label.
var target: String = ""


static func make_line(speaker: String, text: String, side := "left", portrait := "", expression := "neutral", voice := "", backdrop := "") -> DialogueStep:
	var s := DialogueStep.new()
	s.kind = Kind.LINE
	s.speaker = speaker
	s.text = text
	s.side = side
	s.portrait = portrait
	s.expression = expression
	s.voice = voice
	s.backdrop = backdrop
	return s


static func make_line_full(entry: Dictionary) -> DialogueStep:
	## AW-79: dictionary form so new optional fields stop growing the signature.
	var s := make_line(str(entry.get("speaker", "")), str(entry["text"]),
		str(entry.get("side", "left")), str(entry.get("portrait", "")),
		str(entry.get("expression", "neutral")), str(entry.get("voice", "")),
		str(entry.get("backdrop", "")))
	s.music = str(entry.get("music", ""))
	return s


## AW-78: a line with no speaker and no portrait is the STORYTELLER — rendered
## as letterboxed narration (no box, no plate, no portraits), optionally voiced.
func is_narration() -> bool:
	return kind == Kind.LINE and speaker == "" and portrait == ""


static func make_event(event_name: String, params: Dictionary = {}) -> DialogueStep:
	var s := DialogueStep.new()
	s.kind = Kind.EVENT
	s.event_name = event_name
	s.params = params
	return s


static func make_choice(prompt: String, options: Array) -> DialogueStep:
	var s := DialogueStep.new()
	s.kind = Kind.CHOICE
	s.text = prompt
	s.options = options
	return s


static func make_label(name: String) -> DialogueStep:
	var s := DialogueStep.new()
	s.kind = Kind.LABEL
	s.target = name
	return s


static func make_goto(target: String) -> DialogueStep:
	var s := DialogueStep.new()
	s.kind = Kind.GOTO
	s.target = target
	return s


func is_line() -> bool:
	return kind == Kind.LINE


func is_event() -> bool:
	return kind == Kind.EVENT


func is_choice() -> bool:
	return kind == Kind.CHOICE


func is_label() -> bool:
	return kind == Kind.LABEL


func is_goto() -> bool:
	return kind == Kind.GOTO
