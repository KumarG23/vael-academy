extends GutTest
## Native starting data only: previewing cannot choose a house or grant gear.


func test_all_house_members_in_native_order_without_kai():
	var expected := {
		"emberwing": ["perrin", "kael", "brenna", "wren", "dain", "liora"],
		"tidemark": ["serra", "osric", "elowen", "isolde", "fenn", "bertram"],
		"thornrook": ["rina", "thessaly", "corvin", "marlow", "vesper", "rurik", "nilu"],
	}
	for house in expected:
		var rows := HousePreview.members(house)
		var ids: Array = []
		for row in rows:
			ids.append(row["id"])
		assert_eq(ids, expected[house], house + " members, including the heir")
		assert_eq(rows.size(), 7 if house == "thornrook" else 6, house + " count")
		assert_false(ids.has("kai"), "the protagonist is house-agnostic")


func test_labels_match_native_unit_class_and_complete_starting_equipment():
	for house in Roster.HOUSE_ROSTERS:
		var rows := HousePreview.members(house)
		var files: Array = Roster.HOUSE_ROSTERS[house]
		assert_eq(rows.size(), files.size())
		for i in range(mini(rows.size(), files.size())):
			var unit: UnitDef = load("res://data/units/%s.tres" % files[i])
			var expected_gear: Array[String] = []
			if unit.weapon != null:
				expected_gear.append(unit.weapon.display_name)
			for weapon in unit.extra_weapons:
				expected_gear.append(weapon.display_name)
			for item in unit.starting_items:
				expected_gear.append(item.display_name)
			assert_eq(rows[i]["id"], unit.id)
			assert_eq(rows[i]["name"], unit.display_name)
			assert_eq(rows[i]["class_name"], unit.char_class.display_name)
			assert_eq(rows[i]["starting_weapon"], ", ".join(expected_gear), unit.id)


func test_starting_equipment_includes_secondary_weapons_and_items():
	# Independent native resource references guard the diagnosed omission of
	# Kael's consumables from the expected secondary-weapon regression string.
	var kael_gear: Array[String] = []
	for path in ["res://data/weapons/sig_kael.tres", "res://data/weapons/iron_axe.tres",
			"res://data/items/vulnerary.tres", "res://data/items/promotion_seal.tres"]:
		kael_gear.append(load(path).display_name)
	var perrin_lance: WeaponDef = load("res://data/weapons/sig_perrin.tres")
	var perrin_staff: WeaponDef = load("res://data/weapons/heal.tres")
	var rows := HousePreview.members("emberwing")
	assert_eq(rows[1]["starting_weapon"], ", ".join(kael_gear),
		"Kael's primary weapon, extra weapon, Vulnerary and Master Seal")
	assert_eq(rows[0]["starting_weapon"],
		", ".join([perrin_lance.display_name, perrin_staff.display_name]),
		"Perrin's starting staff accompanies his primary weapon")


func test_invalid_houses_return_empty_data():
	for house in ["", "unknown", "Emberwing", "../units/kai"]:
		assert_eq(HousePreview.members(house), [] as Array[Dictionary], house)


func test_records_have_only_the_four_primitive_string_fields():
	for house in Roster.HOUSE_ROSTERS:
		for row in HousePreview.members(house):
			assert_eq(row.size(), 4)
			for key in ["id", "name", "class_name", "starting_weapon"]:
				assert_true(row.has(key), key)
				assert_eq(typeof(row.get(key)), TYPE_STRING, key + " is a detached label")


func test_each_call_returns_fresh_array_and_records():
	for house in Roster.HOUSE_ROSTERS:
		var original := HousePreview.members(house)
		var edited := HousePreview.members(house)
		assert_false(is_same(original, edited), "fresh array")
		for i in range(original.size()):
			assert_false(is_same(original[i], edited[i]), "fresh dictionary")
			for key in edited[i]:
				edited[i][key] = "edited preview label"
		edited.remove_at(0)
		edited.clear()
		assert_eq(HousePreview.members(house), original, "caller edits cannot leak")


func test_browsing_and_editing_results_preserve_campaign_roster_and_cached_resources():
	var campaign_before := Campaign.to_dict()
	var active_before: bool = Campaign.active
	var flags_before: Dictionary = Campaign.flags
	var states_before: Dictionary = Campaign.unit_states
	var house_before := Roster.active_house
	var rosters_before: Dictionary = Roster.HOUSE_ROSTERS.duplicate(true)
	var cached_units: Array[UnitDef] = []
	for house in Roster.HOUSE_ROSTERS:
		for file_id in Roster.HOUSE_ROSTERS[house]:
			cached_units.append(load("res://data/units/%s.tres" % file_id))
	# Also watch Kai and his story-gated equipment, although he is not listed.
	cached_units.append(load("res://data/units/kai.tres"))
	var resources_before: Array = []
	for unit in cached_units:
		resources_before.append(_resource_snapshot(unit))
	for house in ["thornrook", "emberwing", "tidemark", "invalid", "thornrook"]:
		var rows := HousePreview.members(house)
		for row in rows:
			row["name"] = "caller edit"
			row["starting_weapon"] = "caller gear edit"
		rows.clear()
	assert_eq(Campaign.to_dict(), campaign_before, "all serialized campaign state, flags and inventory")
	assert_eq(Campaign.active, active_before, "runtime campaign activation")
	assert_true(is_same(Campaign.flags, flags_before), "flags identity for stale-callback guards")
	assert_true(is_same(Campaign.unit_states, states_before), "saved inventory dictionary identity")
	assert_eq(Roster.active_house, house_before)
	assert_eq(Roster.HOUSE_ROSTERS, rosters_before)
	for i in range(cached_units.size()):
		assert_eq(_resource_snapshot(cached_units[i]), resources_before[i],
			cached_units[i].id + " cached unit/class/weapon/item/skill data remains unchanged")


## Capture exported data recursively so shared nested resources are checked too.
func _resource_snapshot(resource: Resource) -> Dictionary:
	var snapshot := {}
	for property in resource.get_property_list():
		if (property.usage & PROPERTY_USAGE_STORAGE) != 0 \
				and (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			snapshot[property.name] = _snapshot_value(resource.get(property.name))
	return snapshot


func _snapshot_value(value: Variant) -> Variant:
	if value is Resource:
		return _resource_snapshot(value)
	if value is Array:
		var snapshot: Array = []
		for entry in value:
			snapshot.append(_snapshot_value(entry))
		return snapshot
	if value is Dictionary:
		var snapshot := {}
		for key in value:
			snapshot[key] = _snapshot_value(value[key])
		return snapshot
	return value
