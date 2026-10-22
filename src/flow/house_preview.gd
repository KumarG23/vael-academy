class_name HousePreview
extends RefCounted
## Read-only, native starting roster data, independent of campaign progression.
## `starting_weapon` includes primary/extra weapons AND starting items. UI must
## label it STARTING equipment; these labels do not imply current usability or
## bypass any story permission, class restriction, or inventory state.


static func members(house_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not Roster.HOUSE_ROSTERS.has(house_id):
		return result
	for file_id in Roster.HOUSE_ROSTERS[house_id]:
		var unit: UnitDef = load("res://data/units/%s.tres" % file_id)
		var equipment: PackedStringArray = []
		if unit.weapon != null:
			equipment.append(unit.weapon.display_name)
		for weapon in unit.extra_weapons:
			if weapon != null:
				equipment.append(weapon.display_name)
		for item in unit.starting_items:
			if item != null:
				equipment.append(item.display_name)
		result.append({
			"id": unit.id,
			"name": unit.display_name,
			"class_name": unit.char_class.display_name if unit.char_class != null else "",
			"starting_weapon": ", ".join(equipment),
		})
	return result
