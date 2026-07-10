extends GutTest
## AW-39: the Academy Journal book UI — builds a live roster snapshot, cycles
## tabs, and drives multi-slot save/load + volume settings. (Runs under GUT so
## the autoloads it reads — Campaign, AudioManager — are registered.)

const TEST_SLOT := 2  # keep clear of a player's slots 0/1 during the run

var _journal


func before_each() -> void:
	Campaign.reset_new_game(false)
	_journal = load("res://src/ui/academy_journal.gd").new()
	# AW-76 (Codex finding #4): never touch the player's real user://saves
	_journal._save = SaveSystem.new("user://test_journal_saves_%d" % Time.get_ticks_usec())
	add_child_autofree(_journal)
	await wait_frames(1)


func after_each() -> void:
	Campaign.reset_new_game(false)


func test_builds_a_snapshot_for_every_fielded_unit():
	assert_eq(_journal._snaps.size(), Roster.player_units().size(), "one card per fielded unit")
	var s: Dictionary = _journal._snaps[0]
	for key in ["id", "name", "class", "level", "stats", "items", "skills"]:
		assert_true(s.has(key), "snapshot has %s" % key)
	assert_true(s["stats"].has("hp") and int(s["stats"]["hp"]) > 0, "real stats captured")


func test_tabs_cycle():
	assert_eq(_journal._tab, 0)
	_journal._switch_tab(1)
	assert_eq(_journal._tab, 1, "roster → calendar")
	_journal._switch_tab(-1)
	assert_eq(_journal._tab, 0, "wraps back")
	for i in range(_journal.TAB_NAMES.size()):
		_journal._switch_tab(1)
	assert_eq(_journal._tab, 0, "a full cycle of tabs wraps to the start")


func test_roster_selection_moves_and_wraps():
	_journal._tab = 0
	var n: int = _journal._snaps.size()
	_journal._move_row(-1)
	assert_eq(_journal._roster_i, n - 1, "up from the top wraps to the bottom")


func test_saving_writes_a_slot_and_the_label_updates():
	_journal._tab = 4  # System (AW-54 slid it right for Grades)
	_journal._do_save(TEST_SLOT)
	assert_true(_journal._save.has_slot(TEST_SLOT), "the slot now exists on disk")
	_journal._refresh_slots()
	assert_ne(_journal._slot_label(TEST_SLOT), "— empty —", "the System tab shows it as filled")


## AW-76 (Codex finding #3): a journal save must be LOADABLE — the raw
## to_dict() payload looked occupied but Campaign.load_from_slot refused it.
func test_journal_saves_round_trip_through_campaign_load():
	Campaign.flags["gold"] = 321
	Campaign.week = 2
	_journal._do_save(TEST_SLOT)
	Campaign.reset_new_game(false)
	assert_true(Campaign.load_from_slot(TEST_SLOT, _journal._save), "the slot loads back")
	assert_eq(int(Campaign.flags.get("gold", 0)), 321, "with the campaign inside")
	assert_eq(Campaign.week, 2)


# --- AW-52: the Inventory hub ---------------------------------------------------

func test_inventory_hub_trades_an_item_and_persists():
	_journal._tab = 2
	_journal._inv_i = 0
	var giver: Dictionary = _journal._inv_units[0]
	var taker: Dictionary = _journal._inv_units[1]
	var before_g: int = giver["unit"].inventory.items.size()
	var before_t: int = taker["unit"].inventory.items.size()
	assert_gt(before_g, 0, "the first student carries something")
	var moved_name: String = giver["unit"].inventory.items[0].display_name()
	_journal._inv_confirm()                    # open the pack
	assert_eq(_journal._inv_mode, 1)
	_journal._inv_item_i = 0
	_journal._inv_confirm()                    # choose the item -> pick recipient
	assert_eq(_journal._inv_mode, 2)
	_journal._inv_give_i = 1
	_journal._inv_confirm()                    # hand it over
	assert_eq(giver["unit"].inventory.items.size(), before_g - 1, "it left the giver")
	assert_eq(taker["unit"].inventory.items.size(), before_t + 1, "and reached the taker")
	assert_eq(taker["unit"].inventory.items[-1].display_name(), moved_name)
	# the trade persists through the campaign channel deployments read
	assert_true(Campaign.has_unit_state(giver["id"]), "giver state written")
	assert_true(Campaign.has_unit_state(taker["id"]), "taker state written")
	var saved: Array = Campaign.get_unit_state(taker["id"])["inventory"]
	assert_eq(saved.size(), before_t + 1, "the saved inventory carries the trade")


func test_inventory_full_pack_bounces_the_trade():
	_journal._tab = 2
	var giver: Dictionary = _journal._inv_units[0]
	var taker: Dictionary = _journal._inv_units[1]
	var filler: WeaponDef = load("res://data/weapons/iron_sword.tres")
	while not taker["unit"].inventory.is_full():
		taker["unit"].inventory.add(InventoryItem.from_weapon(filler))
	var before_g: int = giver["unit"].inventory.items.size()
	_journal._inv_i = 0
	_journal._inv_mode = 2
	_journal._inv_item_i = 0
	_journal._inv_give_i = 1
	_journal._inv_transfer()
	assert_eq(giver["unit"].inventory.items.size(), before_g, "a full pack refuses the item")


func test_innate_magic_cannot_be_traded_away():
	_journal._tab = 2
	# find Kai and his Crownspark
	var kai_i := -1
	for i in range(_journal._inv_units.size()):
		if _journal._inv_units[i]["id"] == "kai":
			kai_i = i
	assert_gt(kai_i, -1, "Kai is in the hub")
	var kai: Dictionary = _journal._inv_units[kai_i]
	var spark_i := -1
	for i in range(kai["unit"].inventory.items.size()):
		var w: WeaponDef = kai["unit"].inventory.items[i].weapon()
		if w != null and w.id == "crownspark":
			spark_i = i
	assert_gt(spark_i, -1, "Crownspark is in his pack")
	var before: int = kai["unit"].inventory.items.size()
	_journal._inv_i = kai_i
	_journal._inv_mode = 2
	_journal._inv_item_i = spark_i
	_journal._inv_give_i = 0 if kai_i != 0 else 1
	_journal._inv_transfer()
	assert_eq(kai["unit"].inventory.items.size(), before, "royal magic stays bound to Kai")


func test_inventory_cancel_backs_out_before_closing():
	_journal._tab = 2
	_journal._inv_mode = 2
	var ev := InputEventAction.new()
	ev.action = "cursor_cancel"
	ev.pressed = true
	_journal._unhandled_input(ev)
	assert_eq(_journal._inv_mode, 1, "cancel steps give -> item")
	assert_true(_journal.visible, "the book stays open")
	_journal._unhandled_input(ev)
	assert_eq(_journal._inv_mode, 0, "cancel steps item -> students")
	assert_true(_journal.visible, "still open at the student list")


func test_volume_adjust_changes_the_audio_setting():
	_journal._tab = 4  # System (AW-54 slid it right for Grades)
	# find the Music Volume row
	for i in range(_journal.SYS_ROWS.size()):
		if _journal.SYS_ROWS[i][1] == "music":
			_journal._sys_i = i
			break
	var before: float = AudioManager.music_volume
	var changed: bool = _journal._adjust_volume(-1)
	assert_true(changed, "the volume row consumes ←/→")
	assert_lt(AudioManager.music_volume, before + 0.001, "music volume went down")
	AudioManager.music_volume = 0.7
