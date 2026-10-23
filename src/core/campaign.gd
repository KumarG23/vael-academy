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
## GH-81: actual public academy entries in this campaign, never inferred.
var academy_visits: Array[String] = []
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

## AW-54 (GRADING_SYSTEM.md): the report-card state — saved. Samples hold the raw
## inputs so marks recompute cleanly; report_cards is the locked history.
var semester: int = 1
var grade_samples: Dictionary = {
	"quiz_scores": [], "battle_scores": [], "arena_best_wave": 0, "conduct_points": 0,
}
var report_cards: Array = []
## GH-56: only cards closed by this version get receipts. Absence means historical,
## with no evidence of prior payout. History indices remain stable and immutable.
var report_card_deliveries: Array = []

var _training_rng := CombatRNG.new(1)
## Set by load_from_slot so the first hub visit after loading keeps the saved
## training_used instead of treating the load as a fresh visit (WO-4.3).
var _skip_next_hub_reset := false


func _ready() -> void:
	# AW-54: bonds grown feed the Conduct mark ("did you show up and be part of
	# the school" — GRADING_SYSTEM.md).
	EventBus.support_rank_up.connect(func(_pair: String, _rank: String) -> void: add_conduct(4))


## Start a brand-new campaign (called from New Game / WO-4.3).
func reset_new_game(is_casual: bool, seed_value: int = 1) -> void:
	house_locked = false
	set_house("emberwing")  # the prologue precedes the choice; 5.3b flows it
	fish_log = {}
	academy_visits = []
	week = 1
	flags = {}
	unit_states = {}
	support_save = {}
	casual = is_casual
	last_result = ""
	active = false
	training_used = false
	semester = 1
	grade_samples = {"quiz_scores": [], "battle_scores": [], "arena_best_wave": 0, "conduct_points": 0}
	report_cards = []
	report_card_deliveries = []
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
	# AW-54: crossing a semester's end locks its report card. AW-76 (Codex
	# finding #6): semester 2 closes too — the YEAR-END ceremony was never firing.
	if semester <= 2 and week > semester_end_week():
		close_semester()


## The week a semester's report card locks (the calendar's halfway point).
func semester_end_week() -> int:
	var total := calendar().size()
	return maxi(1, ceili(total / 2.0)) if semester == 1 else maxi(1, total)


# --- AW-54: the report card (GRADING_SYSTEM.md) --------------------------------

func record_quiz(pct: int) -> void:
	(grade_samples["quiz_scores"] as Array).append(clampi(pct, 0, 100))


func record_battle_score(score: int) -> void:
	(grade_samples["battle_scores"] as Array).append(clampi(score, 0, 100))


func record_arena_run(waves_cleared: int) -> void:
	grade_samples["arena_best_wave"] = maxi(int(grade_samples["arena_best_wave"]), waves_cleared)


func add_conduct(points: int) -> void:
	grade_samples["conduct_points"] = int(grade_samples["conduct_points"]) + points


## The grade you'd get if the semester ended today — {score, rank, rank_name,
## marks, hints}. Pure math lives in Grading; the Journal draws this.
func running_grade() -> Dictionary:
	return Grading.running(grade_samples)


## Lock this semester's report card and start the next term fresh.
func close_semester() -> void:
	var g := running_grade()
	report_cards.append({"semester": semester, "rank": g["rank"],
		"rank_name": g["rank_name"], "score": g["score"]})
	report_card_deliveries.append({"card_index": report_cards.size() - 1, "delivered": false})
	semester += 1
	grade_samples = {"quiz_scores": [], "battle_scores": [], "arena_best_wave": 0, "conduct_points": 0}


## AW-64: award a consumable/item into a unit's persisted kit (report-card
## chest at rank S). Same channel as grant_weapon.
func grant_item(id: String, item_path: String) -> bool:
	var def := _roster_def(id)
	if def == null or not ResourceLoader.exists(item_path):
		return false
	var u := Unit.new()
	u.setup(def.duplicate(), Grid.new(1, 1), Vector2i.ZERO)
	if has_unit_state(id):
		u.apply_progression_state(get_unit_state(id))
	if u.inventory.is_full():
		u.free()
		return false
	u.inventory.add(InventoryItem.from_item(load(item_path)))
	set_unit_state(id, u.save_state())
	u.free()
	return true


## AW-54: award a weapon into a unit's PERSISTED kit (spellbook rewards — the
## 100%-exam payoff). Builds the unit's live state (journal pattern), adds the
## weapon, and writes it back through unit_states so deployments carry it.
func grant_weapon(id: String, weapon_path: String) -> bool:
	var def := _roster_def(id)
	if def == null or not ResourceLoader.exists(weapon_path):
		return false
	var u := Unit.new()
	u.setup(def.duplicate(), Grid.new(1, 1), Vector2i.ZERO)
	if has_unit_state(id):
		u.apply_progression_state(get_unit_state(id))
	if u.inventory.is_full():
		u.free()
		return false
	u.inventory.add(InventoryItem.from_weapon(load(weapon_path)))
	set_unit_state(id, u.save_state())
	u.free()
	return true


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
	# AW-76 (Codex finding #1): only a YEAR battle moves the calendar. The
	# prologue is won before the house oath (house_locked false) — advancing
	# there burned Week 1 before Kai ever reached Vael.
	if result == "victory" and house_locked:
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
		"academy_visits": academy_visits.duplicate(),
		"week": week,
		"flags": flags.duplicate(true),
		"house_locked": house_locked,
		"last_result": last_result,
		"training_used": training_used,
		"rng_state": str(_training_rng.state_value()),
		"semester": semester,
		"grade_samples": grade_samples.duplicate(true),
		"report_cards": report_cards.duplicate(true),
		"report_card_deliveries": report_card_deliveries.duplicate(true),
	}


## Untrusted save boundary shared by campus loads and battle resume. Validate
## every collection before from_dict changes live state; omitted fields retain
## the loader's defaults for older saves.
func restore_save(data: Dictionary) -> bool:
	for key: String in ["unit_states", "support_save", "fish_log", "flags", "grade_samples"]:
		if data.has(key) and not (data[key] is Dictionary):
			return false
	if data.has("report_cards") and not (data["report_cards"] is Array):
		return false
	if not AcademyTravel.valid_visits(data.get("academy_visits", [])):
		return false
	if not _valid_deliveries(data):
		return false
	from_dict(data)
	return true


## Validate the new collection, including every referenced card, before any live
## campaign/roster/RNG mutation. JSON integers arrive as floats. Unknown keys are
## ignored like other campaign fields; legacy history without receipts stays opaque.
func _valid_deliveries(data: Dictionary) -> bool:
	var receipts: Variant = data.get("report_card_deliveries", [])
	if not receipts is Array:
		return false
	var cards: Array = data.get("report_cards", [])
	var seen: Dictionary = {}
	for receipt: Variant in receipts:
		if not receipt is Dictionary or not receipt.get("delivered") is bool:
			return false
		var index: Variant = receipt.get("card_index")
		if not (index is int or index is float):
			return false
		if not is_finite(float(index)) or float(index) != floor(float(index)):
			return false
		if index < 0 or index >= cards.size() or seen.has(int(index)):
			return false
		seen[int(index)] = true
		var card: Variant = cards[int(index)]
		if not card is Dictionary or not card.get("rank") in ["S", "A", "B", "C", "D"]:
			return false
		if not card.get("rank_name") is String:
			return false
		for key: String in ["semester", "score"]:
			var value: Variant = card.get(key)
			if not (value is int or value is float) or not is_finite(float(value)):
				return false
			if float(value) != floor(float(value)):
				return false
		if card["semester"] < 1 or card["semester"] > 2 or card["score"] < 0 or card["score"] > 100:
			return false
	return true


func pending_report_cards() -> Array[int]:
	var pending: Array[int] = []
	for receipt: Dictionary in report_card_deliveries:
		if not receipt["delivered"]:
			pending.append(int(receipt["card_index"]))
	pending.sort()
	return pending


## The caller commits on completed presentation, synchronously with the receipt.
## A full inventory still forfeits the S seal (existing AW-64 behavior).
func complete_report_card(index: int, gold: int) -> bool:
	for receipt: Dictionary in report_card_deliveries:
		if int(receipt["card_index"]) == index and not receipt["delivered"]:
			flags["gold"] = int(flags.get("gold", 0)) + gold
			if report_cards[index]["rank"] == "S":
				grant_item("kai", "res://data/items/promotion_seal.tres")
			flags["merchant_unlocked"] = true
			receipt["delivered"] = true
			return true
	return false


## Preview the unchanged full-inventory rule for the shipped reward line. Campus
## input is held during presentation, so inventory cannot change between the line
## and completion through normal player actions.
func can_receive_item(id: String, reserved_slots: int = 0) -> bool:
	var def := _roster_def(id)
	if def == null:
		return false
	var unit := Unit.new()
	unit.setup(def.duplicate(), Grid.new(1, 1), Vector2i.ZERO)
	if has_unit_state(id):
		unit.apply_progression_state(get_unit_state(id))
	var available := unit.inventory.size() + reserved_slots < Inventory.MAX_SLOTS
	unit.free()
	return available


func record_academy_entry(entered: CastleRoomDef) -> void:
	if AcademyTravel.is_public(entered) and not academy_visits.has(entered.id):
		academy_visits.append(entered.id)


func from_dict(data: Dictionary) -> void:
	academy_visits = []
	var known := AcademyTravel.public_rooms()
	for id: String in data.get("academy_visits", []):
		if known.has(id) and not academy_visits.has(id):
			academy_visits.append(id)
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
	semester = int(data.get("semester", 1))
	grade_samples = (data.get("grade_samples",
		{"quiz_scores": [], "battle_scores": [], "arena_best_wave": 0, "conduct_points": 0}) as Dictionary).duplicate(true)
	report_cards = (data.get("report_cards", []) as Array).duplicate(true)
	report_card_deliveries = (data.get("report_card_deliveries", []) as Array).duplicate(true)
	_training_rng = CombatRNG.new(1)
	if data.has("rng_state"):
		_training_rng.set_state(int(str(data["rng_state"])))


## Injectable slot IO so tests never write the player's real user://saves.
var save_system_override: SaveSystem = null


func save_to_slot(slot: int, save_system: SaveSystem = null) -> bool:
	return _sys(save_system).save_slot(slot, {"campaign": to_dict()})


func save_autosave(save_system: SaveSystem = null) -> bool:
	return _sys(save_system).save_autosave({"campaign": to_dict()})


func load_autosave(save_system: SaveSystem = null) -> bool:
	var data := _sys(save_system).load_autosave()
	# This checkpoint is campaign-only. Never convert a battle payload or accept
	# an empty envelope as a new campaign, and never try a manual slot instead.
	if data.has("battle") or not Resume.has_campaign(data):
		return false
	return _restore_campaign_envelope(data)


func load_from_slot(slot: int, save_system: SaveSystem = null) -> bool:
	var data := _sys(save_system).load_slot(slot)
	return _restore_campaign_envelope(data)


func _restore_campaign_envelope(data: Dictionary) -> bool:
	if not (data.get("campaign") is Dictionary):
		return false
	if not restore_save(data["campaign"]):
		return false
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
