class_name DialogueScript
extends RefCounted
## A parsed dialogue script (§4): a validated sequence of DialogueSteps loaded from
## JSON. Format is a JSON array of objects; an object with an "event" key is an
## event hook, "label"/"goto"/"choice" are the branching steps (WO-4.6), otherwise
## it's a spoken line (requires "text").
##
## Example:
##   [
##     {"speaker":"Kai", "side":"left", "text":"Emberwing takes the field!"},
##     {"event":"give_item", "to":"Kael", "item":"vulnerary"},
##     {"choice":"Take the field?", "options":[
##       {"text":"Charge!", "goto":"charge", "flag":"kai_bold"},
##       {"text":"Hold back."}
##     ]},
##     {"speaker":"Kai", "text":"We wait."}, {"goto":"end"},
##     {"label":"charge"}, {"speaker":"Kai", "text":"With me!"},
##     {"label":"end"}, {"event":"start_battle", "chapter":"mock_battle"}
##   ]
##
## Every "goto" (step or option) must name a "label" that exists — validated at
## parse time so a broken branch can never be authored.

## Event names that end the conversation when reached.
const TERMINAL_EVENTS := ["start_battle"]

var steps: Array[DialogueStep] = []
var labels: Dictionary = {}  # label name -> step index
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
	script._validate_jumps()
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
	if entry.has("label"):
		var name := str(entry["label"])
		if name == "":
			script.error = "step %d has an empty label" % index
			return null
		if script.labels.has(name):
			script.error = "step %d duplicates label \"%s\"" % [index, name]
			return null
		script.labels[name] = index
		return DialogueStep.make_label(name)
	if entry.has("goto"):
		return DialogueStep.make_goto(str(entry["goto"]))
	if entry.has("choice"):
		return _parse_choice(entry, index, script)
	if not entry.has("text"):
		script.error = "step %d is neither an event, label, goto, choice, nor a line (no \"text\")" % index
		return null
	return DialogueStep.make_line(
		str(entry.get("speaker", "")),
		str(entry["text"]),
		str(entry.get("side", "left")),
		str(entry.get("portrait", "")),
		str(entry.get("expression", "neutral")),
	)


static func _parse_choice(entry: Dictionary, index: int, script: DialogueScript) -> DialogueStep:
	var raw: Variant = entry.get("options")
	if not (raw is Array) or (raw as Array).is_empty():
		script.error = "choice at step %d needs a non-empty \"options\" array" % index
		return null
	var options: Array = []
	for o in (raw as Array):
		if not (o is Dictionary) or not (o as Dictionary).has("text"):
			script.error = "choice at step %d has an option without \"text\"" % index
			return null
		options.append({
			"text": str(o["text"]),
			"goto": str(o.get("goto", "")),
			"flag": str(o.get("flag", "")),
			# AW-57: a ♥ option — names who it's for; shown only when the scene's
			# heart_gate allows (rank A + unspoken-for), styled with the heart.
			"heart": str(o.get("heart", "")),
		})
	return DialogueStep.make_choice(str(entry["choice"]), options)


## Every jump destination — goto steps and choice options — must be a real label.
func _validate_jumps() -> void:
	if error != "":
		return
	for i in range(steps.size()):
		var step := steps[i]
		if step.is_goto() and not labels.has(step.target):
			error = "goto at step %d targets unknown label \"%s\"" % [i, step.target]
			return
		if step.is_choice():
			for o in step.options:
				var t: String = o["goto"]
				if t != "" and not labels.has(t):
					error = "choice at step %d targets unknown label \"%s\"" % [i, t]
					return


func ok() -> bool:
	return error == ""


func size() -> int:
	return steps.size()


func get_step(i: int) -> DialogueStep:
	return steps[i] if i >= 0 and i < steps.size() else null


static func is_terminal_event(event_name: String) -> bool:
	return TERMINAL_EVENTS.has(event_name)
