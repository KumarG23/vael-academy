class_name SupportChainDef
extends Resource
## Static definition for one support chain. Conversations are intentionally just
## paths/labels in WO-3.2; WO-4.2 replaces the placeholder scripts with real copy.

const RANKS := ["C", "B", "A"]

@export var id: String = ""
@export var unit_a_id: String = ""
@export var unit_a_name: String = ""
@export var unit_b_id: String = ""
@export var unit_b_name: String = ""

@export_group("Thresholds")
@export var c_threshold: int = 20
@export var b_threshold: int = 60
@export var a_threshold: int = 120

@export_group("Conversation Paths")
@export var c_conversation: String = ""
@export var b_conversation: String = ""
@export var a_conversation: String = ""


static func canonical_pair_id(a_id: String, b_id: String) -> String:
	if a_id <= b_id:
		return "%s_%s" % [a_id, b_id]
	return "%s_%s" % [b_id, a_id]


func pair_id() -> String:
	return id if id != "" else canonical_pair_id(unit_a_id, unit_b_id)


func includes(unit_id: String) -> bool:
	return unit_id == unit_a_id or unit_id == unit_b_id


func matches(a_id: String, b_id: String) -> bool:
	return (a_id == unit_a_id and b_id == unit_b_id) or (a_id == unit_b_id and b_id == unit_a_id)


func partner_id(unit_id: String) -> String:
	if unit_id == unit_a_id:
		return unit_b_id
	if unit_id == unit_b_id:
		return unit_a_id
	return ""


func display_pair() -> String:
	var a := unit_a_name if unit_a_name != "" else unit_a_id
	var b := unit_b_name if unit_b_name != "" else unit_b_id
	return "%s + %s" % [a, b]


func threshold_for_rank(rank: String) -> int:
	match rank:
		"C":
			return c_threshold
		"B":
			return b_threshold
		"A":
			return a_threshold
		_:
			return 1 << 30


func rank_for_points(value: int) -> String:
	var unlocked := ""
	for rank in RANKS:
		if value >= threshold_for_rank(rank):
			unlocked = rank
	return unlocked


func rank_index(rank: String) -> int:
	return RANKS.find(rank)


func conversation_path(rank: String) -> String:
	match rank:
		"C":
			return c_conversation
		"B":
			return b_conversation
		"A":
			return a_conversation
		_:
			return ""


func conversation_label(rank: String) -> String:
	return "%s %s" % [display_pair(), rank]
