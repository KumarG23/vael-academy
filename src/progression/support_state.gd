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
	"S": {"hit": 20, "avoid": 20, "damage": 2, "crit": 10},
}

var chains: Array[SupportChainDef] = []
var points: Dictionary = {}
var ranks: Dictionary = {}
## "pair_id:rank" -> true once the conversation has been watched (WO-4.4). The
## in-battle menu offers only unwatched scenes; the Common Hall keeps the archive.
var viewed: Dictionary = {}
## WO-5.7: unit id -> partner id, set when a pair reaches the romance rank.
## Romance is exclusive — a unit with a recorded partner can't S another chain.
var romances: Dictionary = {}
## AW-57 (Neal's rule): romance is OPT-IN. The ♥ dialogue choice records consent
## here; without it a pair caps at A no matter how many points accrue — the
## heart is chosen, never automatic.
var consents: Dictionary = {}   # pair_id -> true once the ♥ choice was taken


func mark_viewed(pair_id: String, rank: String) -> void:
	viewed["%s:%s" % [pair_id, rank]] = true


func is_viewed(pair_id: String, rank: String) -> bool:
	return bool(viewed.get("%s:%s" % [pair_id, rank], false))


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
	# WO-5.7: the romance rank is exclusive — if either unit is already
	# spoken for (another chain), this pair stops at A. AW-57: it is also
	# CONSENSUAL — no ♥ choice taken, no S, however deep the points run.
	if after_rank == SupportChainDef.ROMANCE_RANK \
			and (_romance_blocked(chain) or not bool(consents.get(pair, false))):
		after_rank = "A"
	if chain.rank_index(after_rank) > chain.rank_index(before_rank):
		ranks[pair] = after_rank
		if after_rank == SupportChainDef.ROMANCE_RANK:
			romances[chain.unit_a_id] = chain.unit_b_id
			romances[chain.unit_b_id] = chain.unit_a_id
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


## AW-57: the ♥ choice — record the pair's consent; if their bond is already
## deep enough the romance rank blossoms on the spot. Returns the add_points
## result shape ({} when the pair can't romance: ineligible / already spoken
## for), so callers can toast a rank-up.
func consent_romance(a_id: String, b_id: String) -> Dictionary:
	var chain := chain_for_units(a_id, b_id)
	if chain == null or not chain.romance_eligible or _romance_blocked(chain):
		return {}
	var pair := chain.pair_id()
	consents[pair] = true
	var before: String = ranks.get(pair, "")
	var after := chain.rank_for_points(int(points.get(pair, 0)))
	if after == SupportChainDef.ROMANCE_RANK and chain.rank_index(after) > chain.rank_index(before):
		ranks[pair] = after
		romances[chain.unit_a_id] = chain.unit_b_id
		romances[chain.unit_b_id] = chain.unit_a_id
		return {"ranked_up": true, "pair_id": pair, "new_rank": after,
			"chain": chain, "points": int(points.get(pair, 0))}
	return {"ranked_up": false, "pair_id": pair, "rank": before, "points": int(points.get(pair, 0))}


## Either partner already romanced into a DIFFERENT pair?
func _romance_blocked(chain: SupportChainDef) -> bool:
	for uid in [chain.unit_a_id, chain.unit_b_id]:
		if romances.has(uid) and romances[uid] != chain.partner_id(uid):
			return true
	return false


func is_romanced(unit_id: String) -> bool:
	return romances.has(unit_id)


func romance_partner(unit_id: String) -> String:
	return str(romances.get(unit_id, ""))


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
			var rank: String = chain.ranks()[i]
			out.append({
				"pair_id": chain.pair_id(),
				"rank": rank,
				"label": chain.conversation_label(rank),
				"path": chain.conversation_path(rank),
				"viewed": is_viewed(chain.pair_id(), rank),
			})
	return out


func highest_rank_for_pair(pair_id: String) -> String:
	return ranks.get(pair_id, "")


func save_state() -> Dictionary:
	return {
		"points": points.duplicate(true),
		"ranks": ranks.duplicate(true),
		"viewed": viewed.duplicate(true),
		"romances": romances.duplicate(true),
		"consents": consents.duplicate(true),  # AW-57
	}


func apply_save_state(state: Dictionary) -> void:
	points.clear()
	ranks.clear()
	viewed.clear()
	var saved_points: Dictionary = state.get("points", {})
	for pair_id in saved_points:
		points[pair_id] = int(saved_points[pair_id])
	var saved_ranks: Dictionary = state.get("ranks", {})
	for pair_id in saved_ranks:
		ranks[pair_id] = str(saved_ranks[pair_id])
	var saved_viewed: Dictionary = state.get("viewed", {})
	for key in saved_viewed:
		viewed[str(key)] = bool(saved_viewed[key])
	romances.clear()
	var saved_rom: Dictionary = state.get("romances", {})
	for key in saved_rom:
		romances[str(key)] = str(saved_rom[key])
	consents.clear()
	var saved_con: Dictionary = state.get("consents", {})
	for key in saved_con:
		consents[str(key)] = bool(saved_con[key])
	for chain in chains:
		var pair := chain.pair_id()
		if not points.has(pair):
			points[pair] = 0
		if not ranks.has(pair):
			ranks[pair] = ""
