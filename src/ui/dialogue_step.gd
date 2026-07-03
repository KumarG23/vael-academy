class_name DialogueStep
extends RefCounted
## One step of a dialogue script (§4): either a spoken LINE or an EVENT hook
## (start_battle, give_item, ...). Parsed from JSON by DialogueScript.

enum Kind { LINE, EVENT }

var kind: Kind

# LINE fields.
var speaker: String = ""
var text: String = ""
var side: String = "left"          # "left" or "right"
var portrait: String = ""          # portrait id (art swaps in at AW-6)
var expression: String = "neutral"

# EVENT fields.
var event_name: String = ""
var params: Dictionary = {}


static func make_line(speaker: String, text: String, side := "left", portrait := "", expression := "neutral") -> DialogueStep:
	var s := DialogueStep.new()
	s.kind = Kind.LINE
	s.speaker = speaker
	s.text = text
	s.side = side
	s.portrait = portrait
	s.expression = expression
	return s


static func make_event(event_name: String, params: Dictionary = {}) -> DialogueStep:
	var s := DialogueStep.new()
	s.kind = Kind.EVENT
	s.event_name = event_name
	s.params = params
	return s


func is_line() -> bool:
	return kind == Kind.LINE


func is_event() -> bool:
	return kind == Kind.EVENT
