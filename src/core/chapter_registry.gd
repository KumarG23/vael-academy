class_name ChapterRegistry
extends RefCounted
## WO-7.1: the campaign's chapter table — ids to scenes, house-routed where a
## chapter has rival variants (WO-5.6). The calendar speaks chapter ids; only
## this registry knows scene paths.

const VARIANTS := {
	"mock_battle": {
		"emberwing": "res://scenes/battle/mock_battle.tscn",
		"tidemark": "res://scenes/battle/mock_battle_vs_thornrook.tscn",
		"thornrook": "res://scenes/battle/mock_battle_vs_emberwing.tscn",
	},
	"closing_rite": {
		"emberwing": "res://scenes/battle/closing_rite_emberwing.tscn",
		"tidemark": "res://scenes/battle/closing_rite_tidemark.tscn",
		"thornrook": "res://scenes/battle/closing_rite_thornrook.tscn",
	},
}
const SCENES := {
	"prologue": "res://scenes/battle/prologue.tscn",
	"indoor_demo": "res://scenes/battle/indoor_demo.tscn",
}


static func scene_for(chapter_id: String, house_id: String = "emberwing") -> String:
	if VARIANTS.has(chapter_id):
		var by_house: Dictionary = VARIANTS[chapter_id]
		return by_house.get(house_id, by_house.values()[0])
	return SCENES.get(chapter_id, "")
