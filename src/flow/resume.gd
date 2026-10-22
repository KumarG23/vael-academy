class_name Resume
extends RefCounted
## AW-75: save-anywhere routing. A slot may hold a campus save (campaign only)
## or a mid-battle snapshot (campaign + live battle). This helper answers, for
## any loaded payload: is there a battle to walk back into, which scene hosts
## it, and should the Campaign autoload be restored first. Title screen and the
## Journal both route loads through here.


## True when the payload holds an UNFINISHED battle worth resuming.
static func battle_live(payload: Dictionary) -> bool:
	if not (payload.get("battle") is Dictionary):
		return false
	var b: Dictionary = payload["battle"]
	return not bool(b.get("battle_over", false)) and payload.get("roster") is Array


## The scene that hosts the saved battle ("" when unknown — fall back to campus).
static func battle_scene(payload: Dictionary) -> String:
	if not (payload.get("battle") is Dictionary):
		return ""
	var b: Dictionary = payload.get("battle", {})
	return ChapterRegistry.resume_scene(str(b.get("chapter_id", "")))


## True when the payload's campaign section is a REAL campaign (campus saves and
## mission snapshots), not the thin header a standalone dev battle writes.
static func has_campaign(payload: Dictionary) -> bool:
	if not (payload.get("campaign") is Dictionary):
		return false
	var c: Dictionary = payload.get("campaign", {})
	return c.has("week") and c.has("house_id")


## Restore the Campaign autoload (when the payload carries one) and stage the
## battle payload for the scene to consume. Returns the scene path to change to,
## or "" when the payload has no resumable battle.
static func stage(payload: Dictionary) -> String:
	if not battle_live(payload):
		return ""
	# An explicit malformed section cannot be consumed by the battle scene.
	if payload.has("campaign") and not (payload["campaign"] is Dictionary):
		return ""
	var scene := battle_scene(payload)
	if scene == "":
		return ""
	if has_campaign(payload):
		var campaign: Dictionary = payload["campaign"]
		# from_dict mutates live state before reading all its collections. Check
		# their types first so a malformed save cannot leave a partial restore.
		# Missing fields keep the loader's defaults for older campaign saves.
		for key: String in ["unit_states", "support_save", "fish_log", "flags", "grade_samples"]:
			if campaign.has(key) and not (campaign[key] is Dictionary):
				return ""
		if campaign.has("report_cards") and not (campaign["report_cards"] is Array):
			return ""
		Campaign.from_dict(campaign)
		Campaign.active = true
	BattleView.next_resume = payload
	return scene
