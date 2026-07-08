class_name CampaignState
extends Node
## Cross-scene campaign state (registered as the `Campaign` autoload). Holds the
## roster's between-battle progression, support state, and flags so the Academy Hub
## and the battle scene share one source of truth across scene changes (WO-3.5).
##
## `unit_states` is keyed by unit id and holds each unit's Unit.save_state() dict;
## the battle applies them on deploy and captures them back when it ends.

const TRAINING_XP := 10  # §4: flat +10 XP, one unit per hub visit

var unit_states: Dictionary = {}     # id -> Unit.save_state() dict
var support_save: Dictionary = {}
var casual: bool = false
var chapter_id: String = "mock_battle"
## WO-5.3a: the chosen house — drives roster, theming, and (in 5.6) rivals.
var house_id: String = "emberwing"
## Neal's playtest rule (FE3H): once sworn, the house binds for the playthrough.
var house_locked: bool = false
## WO-6.4: the waterside fish log (fish name -> count), part of the save.
var fish_log: Dictionary = {}
## WO-7.1: the academy year, week by week (saved). The calendar data lives in
## data/calendar/year_one.tres; this is just the cursor.
var week: int = 1
## WO-7.2/7.3: story/event flags (activity unlocks, seen set-pieces) — saved.
var flags: Dictionary = {}
var _calendar: Array[CalendarEventDef] = []
var last_result: String = ""         # "victory" / "defeat" / ""
## True while the player is deployed — the battle applies campaign state only then,
## so tests that load the battle scene directly are unaffected.
var active: bool = false
## One training session per hub visit (§4).
var training_used: bool = false

var _training_rng := CombatRNG.new(1)
## Set by load_from_slot so the first hub visit after loading keeps the saved
## training_used instead of treating the load as a fresh visit (WO-4.3).
var _skip_next_hub_reset := false


## Start a brand-new campaign (called from New Game / WO-4.3).
func reset_new_game(is_casual: bool, seed_value: int = 1) -> void:
	house_locked = false
	set_house("emberwing")  # the prologue precedes the choice; 5.3b flows it
	fish_log = {}
	week = 1
	flags = {}
	unit_states = {}
	support_save = {}
	casual = is_casual
	last_result = ""
	active = false
	training_used = false
	_skip_next_hub_reset = false
	_training_rng = CombatRNG.new(seed_value)


## Enter the hub: refresh the once-per-visit training and leave deploy state.
## The first visit after a load restores the saved visit instead.
func begin_hub_visit() -> void:
	active = false
	if _skip_next_hub_reset:
		_skip_next_hub_reset = false
		return
	training_used = false


## The academy year (WO-7.1) --------------------------------------------------

func calendar() -> Array[CalendarEventDef]:
	if _calendar.is_empty():
		var res = load("res://data/calendar/year_one.tres")
		if res != null:
			_calendar = res.events
	return _calendar


func current_event() -> CalendarEventDef:
	for e in calendar():
		if e.week == week:
			return e
	return null


func advance_week() -> void:
	week += 1
	flags.erase("arena_used_this_week")  # AW-43: the Arena reopens each week


## Choose the player's house (WO-5.3a): flips the Roster and everything
## downstream that reads house_id (battle theming; rivals ride WO-5.6).
func set_house(id: String) -> void:
	if not Roster.HOUSE_ROSTERS.has(id) or house_locked:
		return
	house_id = id
	Roster.active_house = id


## Mark the player as deployed so the next battle applies campaign state.
func deploy() -> void:
	active = true


func has_unit_state(id: String) -> bool:
	return unit_states.has(id)


func get_unit_state(id: String) -> Dictionary:
	return unit_states.get(id, {})


func set_unit_state(id: String, state: Dictionary) -> void:
	unit_states[id] = state.duplicate(true)


## Apply this unit's saved progression to a freshly-spawned Unit, if any.
func apply_to_unit(unit: Unit) -> void:
	var id := unit.unit_id()
	if unit_states.has(id):
		unit.apply_progression_state(unit_states[id])


func can_train() -> bool:
	return not training_used


## Grant the training session's XP to one unit (§4). Builds a scratch Unit from the
## roster base + saved progression, applies the XP (rolling any level-ups through
## the campaign RNG), and stores the result. Returns the level-up results.
func train_unit(id: String) -> Array:
	if training_used:
		return []
	var def := _roster_def(id)
	if def == null:
		return []
	var scratch := Unit.new()
	scratch.setup(def, Grid.new(1, 1), Vector2i.ZERO)
	if unit_states.has(id):
		scratch.apply_progression_state(unit_states[id])
	var results := scratch.gain_xp(TRAINING_XP, _training_rng)
	unit_states[id] = scratch.progression_state()
	scratch.free()
	training_used = true
	return results


## Capture the roster + supports after a battle so the hub reflects what happened.
func capture(states: Dictionary, support: Dictionary, result: String) -> void:
	for id in states:
		unit_states[id] = states[id]
	support_save = support.duplicate(true)
	last_result = result
	if result == "victory":
		advance_week()  # the week's battle is won — the year moves on (WO-7.1)


# --- save / load --------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"unit_states": unit_states.duplicate(true),
		"support_save": support_save.duplicate(true),
		"casual": casual,
		"chapter_id": chapter_id,
		"house_id": house_id,
		"fish_log": fish_log.duplicate(true),
		"week": week,
		"flags": flags.duplicate(true),
		"house_locked": house_locked,
		"last_result": last_result,
		"training_used": training_used,
		"rng_state": str(_training_rng.state_value()),
	}


func from_dict(data: Dictionary) -> void:
	unit_states = (data.get("unit_states", {}) as Dictionary).duplicate(true)
	support_save = (data.get("support_save", {}) as Dictionary).duplicate(true)
	casual = bool(data.get("casual", false))
	chapter_id = str(data.get("chapter_id", "mock_battle"))
	fish_log = (data.get("fish_log", {}) as Dictionary).duplicate(true)
	week = int(data.get("week", 1))
	flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	house_locked = false
	set_house(str(data.get("house_id", "emberwing")))
	house_locked = bool(data.get("house_locked", false))
	last_result = str(data.get("last_result", ""))
	training_used = bool(data.get("training_used", false))
	_training_rng = CombatRNG.new(1)
	if data.has("rng_state"):
		_training_rng.set_state(int(str(data["rng_state"])))


## Injectable slot IO so tests never write the player's real user://saves.
var save_system_override: SaveSystem = null


func save_to_slot(slot: int, save_system: SaveSystem = null) -> bool:
	return _sys(save_system).save_slot(slot, {"campaign": to_dict()})


func load_from_slot(slot: int, save_system: SaveSystem = null) -> bool:
	var data := _sys(save_system).load_slot(slot)
	if data.is_empty() or not data.has("campaign"):
		return false
	from_dict(data["campaign"])
	_skip_next_hub_reset = true  # the next hub visit resumes the saved one
	return true


func _sys(explicit: SaveSystem) -> SaveSystem:
	if explicit != null:
		return explicit
	if save_system_override != null:
		return save_system_override
	return SaveSystem.new()


func _roster_def(id: String) -> UnitDef:
	for def in Roster.player_units():
		if def.id == id:
			return def
	return null
