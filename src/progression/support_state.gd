class_name SupportState
extends RefCounted
## Runtime support points/ranks. Pure state: battle scenes decide when to award
## points, save/load later serializes points + ranks, and combat reads bonuses.

const POINTS_END_TURN := 10
const POINTS_HEAL := 15
const POINTS_RESCUE := 15
const ACCRUAL_RANGE := 2
const BONUS_RANGE := 3

const _ZERO_BONUS := {"hit": 0, "avoid": 0, "damage": 0, "crit": 0}
const _BONUS_BY_RANK := {
	"C": {"hit": 5, "avoid": 5, "damage": 0, "crit": 0},
	"B": {"hit": 10, "avoid": 10, "damage": 1, "crit": 0},
	"A": {"hit": 15, "avoid": 15, "damage": 1, "crit": 5},
}

var chains: Array[SupportChainDef] = []
var points: Dictionary = {}
var ranks: Dictionary = {}


func add_chain(chain: SupportChainDef) -> void:
	if chain == null:
		return
	chains.append(chain)
	var pair := chain.pair_id()
	if not points.has(pair):
		points[pair] = 0
	if not ranks.has(pair):
		ranks[pair] = ""


func add_points(a_id: String, b_id: String, amount: int) -> Dictionary:
	var chain := chain_for_units(a_id, b_id)
	if chain == null or amount <= 0:
		return {}
	var pair := chain.pair_id()
	var before_rank: String = ranks.get(pair, "")
	points[pair] = int(points.get(pair, 0)) + amount
	var after_rank := chain.rank_for_points(int(points[pair]))
	if chain.rank_index(after_rank) > chain.rank_index(before_rank):
		ranks[pair] = after_rank
		return {
			"ranked_up": true,
			"pair_id": pair,
			"new_rank": after_rank,
			"chain": chain,
			"points": points[pair],
		}
	return {
		"ranked_up": false,
		"pair_id": pair,
		"rank": before_rank,
		"points": points[pair],
	}


func chain_for_units(a_id: String, b_id: String) -> SupportChainDef:
	for chain in chains:
		if chain.matches(a_id, b_id):
			return chain
	return null


func rank_for_units(a_id: String, b_id: String) -> String:
	var chain := chain_for_units(a_id, b_id)
	return "" if chain == null else ranks.get(chain.pair_id(), "")


func points_for_units(a_id: String, b_id: String) -> int:
	var chain := chain_for_units(a_id, b_id)
	return 0 if chain == null else int(points.get(chain.pair_id(), 0))


func bonus_for_unit(unit_id: String, nearby_partner_ids: Array) -> Dictionary:
	var total := _ZERO_BONUS.duplicate()
	for chain in chains:
		if not chain.includes(unit_id):
			continue
		var partner := chain.partner_id(unit_id)
		if not nearby_partner_ids.has(partner):
			continue
		var rank: String = ranks.get(chain.pair_id(), "")
		if rank == "" or not _BONUS_BY_RANK.has(rank):
			continue
		var bonus: Dictionary = _BONUS_BY_RANK[rank]
		total["hit"] += int(bonus["hit"])
		total["avoid"] += int(bonus["avoid"])
		total["damage"] += int(bonus["damage"])
		total["crit"] += int(bonus["crit"])
	return total


func unlocked_conversations_for_unit(unit_id: String) -> Array:
	var out: Array = []
	for chain in chains:
		if not chain.includes(unit_id):
			continue
		var current_rank: String = ranks.get(chain.pair_id(), "")
		var idx := chain.rank_index(current_rank)
		if idx < 0:
			continue
		for i in range(idx + 1):
			var rank: String = SupportChainDef.RANKS[i]
			out.append({
				"pair_id": chain.pair_id(),
				"rank": rank,
				"label": chain.conversation_label(rank),
				"path": chain.conversation_path(rank),
			})
	return out


func highest_rank_for_pair(pair_id: String) -> String:
	return ranks.get(pair_id, "")


func save_state() -> Dictionary:
	return {
		"points": points.duplicate(true),
		"ranks": ranks.duplicate(true),
	}


func apply_save_state(state: Dictionary) -> void:
	points.clear()
	ranks.clear()
	var saved_points: Dictionary = state.get("points", {})
	for pair_id in saved_points:
		points[pair_id] = int(saved_points[pair_id])
	var saved_ranks: Dictionary = state.get("ranks", {})
	for pair_id in saved_ranks:
		ranks[pair_id] = str(saved_ranks[pair_id])
	for chain in chains:
		var pair := chain.pair_id()
		if not points.has(pair):
			points[pair] = 0
		if not ranks.has(pair):
			ranks[pair] = ""
