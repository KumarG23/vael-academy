class_name DialogueScript
extends RefCounted
## A parsed dialogue script (§4): a validated sequence of DialogueSteps loaded from
## JSON. Format is a JSON array of objects; an object with an "event" key is an
## event hook, otherwise it's a spoken line (requires "text").
##
## Example:
##   [
##     {"speaker":"Kai", "side":"left", "text":"Emberwing takes the field!"},
##     {"event":"give_item", "to":"Kael", "item":"vulnerary"},
##     {"event":"start_battle", "chapter":"mock_battle"}
##   ]

## Event names that end the conversation when reached.
const TERMINAL_EVENTS := ["start_battle"]

var steps: Array[DialogueStep] = []
var error: String = ""


static func from_json(text: String) -> DialogueScript:
	var script := DialogueScript.new()
	# Use an instance parse (not the static parse_string) so malformed input returns
	# an error code instead of printing a global ERROR to the log.
	var json := JSON.new()
	if json.parse(text) != OK:
		script.error = "invalid JSON: %s (line %d)" % [json.get_error_message(), json.get_error_line()]
		return script
	var data: Variant = json.data
	if not (data is Array):
		script.error = "dialogue root must be a JSON array"
		return script
	for i in range(data.size()):
		var entry: Variant = data[i]
		if not (entry is Dictionary):
			script.error = "step %d is not an object" % i
			return script
		var step := _parse_step(entry, i, script)
		if step == null:
			return script  # error already set
		script.steps.append(step)
	return script


static func from_file(path: String) -> DialogueScript:
	if not FileAccess.file_exists(path):
		var s := DialogueScript.new()
		s.error = "file not found: " + path
		return s
	return from_json(FileAccess.get_file_as_string(path))


static func _parse_step(entry: Dictionary, index: int, script: DialogueScript) -> DialogueStep:
	if entry.has("event"):
		var params := entry.duplicate()
		params.erase("event")
		return DialogueStep.make_event(str(entry["event"]), params)
	if not entry.has("text"):
		script.error = "step %d is neither an event nor a line (no \"text\")" % index
		return null
	return DialogueStep.make_line(
		str(entry.get("speaker", "")),
		str(entry["text"]),
		str(entry.get("side", "left")),
		str(entry.get("portrait", "")),
		str(entry.get("expression", "neutral")),
	)


func ok() -> bool:
	return error == ""


func size() -> int:
	return steps.size()


func get_step(i: int) -> DialogueStep:
	return steps[i] if i >= 0 and i < steps.size() else null


static func is_terminal_event(event_name: String) -> bool:
	return TERMINAL_EVENTS.has(event_name)
