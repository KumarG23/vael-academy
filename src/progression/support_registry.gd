class_name SupportRegistry
extends RefCounted
## Loads every SupportChainDef under a directory (WO-4.2). Replaces the two
## hard-coded single-chain loading sites so adding a support pair is adding a
## .tres file, not code (§2 rule 4).

const DEFAULT_DIR := "res://data/supports"


## Every SupportChainDef in `dir_path`, sorted by pair id for deterministic order.
static func load_all(dir_path: String = DEFAULT_DIR) -> Array[SupportChainDef]:
	var out: Array[SupportChainDef] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for file in dir.get_files():
		# Exported builds rename resources to <name>.tres.remap; load by real name.
		var res_name := file.trim_suffix(".remap")
		if not res_name.ends_with(".tres"):
			continue
		var res: Resource = load(dir_path.path_join(res_name))
		if res is SupportChainDef:
			out.append(res)
	out.sort_custom(func(a: SupportChainDef, b: SupportChainDef) -> bool:
		return a.pair_id() < b.pair_id())
	return out


## A fresh SupportState carrying every authored chain.
static func build_state(dir_path: String = DEFAULT_DIR) -> SupportState:
	var state := SupportState.new()
	for chain in load_all(dir_path):
		state.add_chain(chain)
	return state
