extends GutTest
## AW-39: the Academy Journal book UI — builds a live roster snapshot, cycles
## tabs, and drives multi-slot save/load + volume settings. (Runs under GUT so
## the autoloads it reads — Campaign, AudioManager — are registered.)

const TEST_SLOT := 2  # keep clear of a player's slots 0/1 during the run

var _journal
var _prefs_path: String
var _music_volume: float


func before_each() -> void:
	_prefs_path = AudioManager.prefs_path
	_music_volume = AudioManager.music_volume
	AudioManager.prefs_path = "user://test_journal_preferences_%d.cfg" % Time.get_ticks_usec()
	Campaign.reset_new_game(false)
	_journal = load("res://src/ui/academy_journal.gd").new()
	# AW-76 (Codex finding #4): never touch the player's real user://saves
	_journal._save = SaveSystem.new("user://test_journal_saves_%d" % Time.get_ticks_usec())
	add_child_autofree(_journal)
	await wait_frames(1)


func after_each() -> void:
	DirAccess.remove_absolute(AudioManager.prefs_path)
	AudioManager.prefs_path = _prefs_path
	AudioManager.music_volume = _music_volume
	Campaign.reset_new_game(false)


func test_builds_a_snapshot_for_every_fielded_unit():
	assert_eq(_journal._snaps.size(), Roster.player_units().size(), "one card per fielded unit")
	var s: Dictionary = _journal._snaps[0]
	for key in ["id", "name", "class", "level", "stats", "items", "skills"]:
		assert_true(s.has(key), "snapshot has %s" % key)
	assert_true(s["stats"].has("hp") and int(s["stats"]["hp"]) > 0, "real stats captured")


## A promoted student's card names the promoted class — the def's base class
## is only the starting point (Unit._class_override carries the promotion).
func test_roster_card_shows_the_promoted_class():
	var def: UnitDef = null
	for d in Roster.player_units():
		if d.id == "kai":
			def = d
	assert_not_null(def, "Kai is fielded")
	var promoted: ClassDef = load("res://data/classes/warder_lord.tres")
	var scratch := Unit.new()
	scratch.setup(def.duplicate(), Grid.new(1, 1), Vector2i.ZERO)
	scratch._class_override = promoted
	Campaign.set_unit_state("kai", scratch.save_state())
	scratch.free()
	_journal._build_snaps()
	var card: Dictionary = {}
	for s in _journal._snaps:
		if s["id"] == "kai":
			card = s
	assert_eq(card.get("class", ""), promoted.display_name, "the card shows the promoted class")
	assert_ne(card.get("class", ""), def.char_class.display_name, "not the base class")


## A card must show the level the student actually deploys at. A bare Unit
## (without setup()) starts at Lv 1, so every un-promoted card read as Lv 1 —
## Perrin and Rina are authored at Lv 2, Serra at Lv 5.
func test_roster_card_shows_the_authored_starting_level():
	var card := _card_for("perrin")
	assert_false(card.is_empty(), "Perrin is on the roster")
	assert_eq(int(card["level"]), 2, "Perrin deploys at his authored Lv 2")


## A saved level still wins over the authored one.
func test_roster_card_shows_the_saved_level():
	Campaign.set_unit_state("perrin", {"level": 7, "xp": 12})
	_journal._build_snaps()
	var card := _card_for("perrin")
	assert_eq(int(card["level"]), 7, "the card follows the campaign's progression")


func test_tabs_cycle():
	assert_eq(_journal._tab, 0)
	_journal._switch_tab(1)
	assert_eq(_journal._tab, 1, "roster → calendar")
	_journal._switch_tab(-1)
	assert_eq(_journal._tab, 0, "wraps back")
	for i in range(_journal.TAB_NAMES.size()):
		_journal._switch_tab(1)
	assert_eq(_journal._tab, 0, "a full cycle of tabs wraps to the start")
	assert_eq(_journal.TAB_NAMES.slice(0, 6),
		["Roster", "Calendar", "Inventory", "Grades", "System", "Fish Log"],
		"the existing tab indices and order stay fixed")
	assert_eq(_journal.TAB_NAMES[6], "Supports", "the support reference is appended")


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


## The System rows read "Slot 1/2/3"; the toasts must say the same number or
## saving Slot 1 visibly reports "Saved to slot 0".
func test_system_toasts_use_one_based_slot_numbers():
	_journal._tab = 4
	_journal._do_load(0)
	assert_eq(_journal._toast, "Slot 1 is empty")
	_journal._do_save(TEST_SLOT)  # the third System row
	assert_eq(_journal._toast, "Saved to slot 3")


## A resumed battle is a different kind of save; the System tab should warn
## before the player loads it instead of showing it like a campus checkpoint.
func test_system_slot_label_marks_a_live_battle():
	var payload := {
		"campaign": Campaign.to_dict(),
		"battle": {"chapter_id": "mock_battle", "battle_over": false},
		"roster": [],
	}
	assert_true(_journal._save.save_slot(0, payload))
	_journal._refresh_slots()
	assert_string_contains(_journal._slot_label(0), "⚔ mid-battle")
	payload["battle"]["battle_over"] = true
	assert_true(_journal._save.save_slot(0, payload))
	_journal._refresh_slots()
	assert_false(_journal._slot_label(0).contains("⚔ mid-battle"),
		"a finished battle is an ordinary save")


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


func test_fish_log_has_clear_empty_state_and_stable_exact_entries():
	Campaign.fish_log = {}
	assert_true(_journal._fish_log_entries().is_empty(), "empty saves produce the empty state")
	Campaign.fish_log = {
		"Vael Kingfish": 2,
		"Warded Coin": 1,
		"Silver Dace": 4,
		"Old Unknown Catch": 7,
		"Lakeperch": 3,
	}
	var before := Campaign.fish_log.duplicate(true)
	var entries: Array = _journal._fish_log_entries()
	var names: Array = []
	var counts := {}
	for entry: Dictionary in entries:
		names.append(entry["name"])
		counts[entry["name"]] = entry["count"]
	assert_eq(names, ["Lakeperch", "Old Unknown Catch", "Silver Dace", "Vael Kingfish", "Warded Coin"],
		"known and unknown saved names have stable readable order")
	assert_eq(counts, {
		"Lakeperch": 3, "Old Unknown Catch": 7, "Silver Dace": 4,
		"Vael Kingfish": 2, "Warded Coin": 1,
	}, "all exact quantities are shown without renaming unknown data")
	assert_eq(Campaign.fish_log, before, "building the display never changes saved data")


func test_normal_fishing_then_journal_save_and_campaign_reload_keeps_catches():
	Campaign.fish_log = {}
	var fishing := FishingGame.new(41)
	add_child_autofree(fishing)
	fishing.tick(5.0)
	fishing.strike()
	assert_eq(fishing.phase, FishingGame.Phase.DONE, "the normal fishing state machine resolves")
	assert_eq(Campaign.fish_log.size(), 1, "a normal catch is earned into the campaign")
	var earned_log := Campaign.fish_log.duplicate(true)
	_journal._do_save(TEST_SLOT)
	Campaign.reset_new_game(false)
	assert_true(Campaign.load_from_slot(TEST_SLOT, _journal._save), "ordinary Journal System save reloads")
	_journal.hide()  # keep input owned by the fresh Journal only
	var reopened: AcademyJournal = load("res://src/ui/academy_journal.gd").new()
	add_child_autofree(reopened)
	await wait_frames(1)
	assert_eq(reopened._fish_log_entries().size(), 1, "fresh Journal reads the loaded catch")
	assert_eq(JSON.parse_string(JSON.stringify(Campaign.fish_log)),
		JSON.parse_string(JSON.stringify(earned_log)), "the earned count survives the normal save round-trip")


func test_fish_log_read_and_navigation_preserve_campaign_and_rng():
	Campaign.fish_log = {"Lakeperch": 2, "Warded Coin": 1, "Unknown Saved Catch": 5}
	var before := Campaign.to_dict()
	_journal._tab = 5
	_journal._move_row(1)
	_journal._fish_log_entries()
	_journal._move_row(-1)
	assert_eq(Campaign.to_dict(), before,
		"reading and navigating catches do not mutate campaign values or its saved RNG state")


func test_support_page_shows_only_current_roster_chains_and_explicit_empty_state():
	var before := Campaign.to_dict()
	var entries: Array = _journal._support_entries()
	assert_eq(entries.size(), 2, "Emberwing shows its two authored Kai chains")
	assert_eq([entries[0]["name"], entries[1]["name"]], ["Kael", "Liora"],
		"companions use current roster names in stable order")
	for entry: Dictionary in entries:
		assert_eq(entry["rank"], "", "unset pairs have no achieved rank")
		assert_true(entry["conversations"].is_empty(), "zero-rank pairs expose no conversations")
	Roster.active_house = "tidemark"
	assert_true(_journal._support_entries().is_empty(),
		"the page excludes authored chains whose companion is not on the current roster")
	_journal._tab = 6
	_journal.queue_redraw()
	await wait_frames(1)
	assert_eq(Campaign.to_dict(), before, "temporary state and empty rendering leave the whole Campaign unchanged")
	Roster.active_house = "emberwing"


func test_support_page_shows_earned_ranks_and_only_unlocked_viewed_states():
	Campaign.support_save = {
		"points": {"kai_kael": 60, "kai_liora": 20},
		"ranks": {"kai_kael": "B", "kai_liora": "C"},
		"viewed": {"kai_kael:C": true, "kai_kael:B": false, "kai_liora:C": true},
	}
	var entries: Array = _journal._support_entries()
	var kael: Dictionary = _entry_for_support(entries, "kael")
	var liora: Dictionary = _entry_for_support(entries, "liora")
	assert_eq(kael["rank"], "B", "earned rank comes from the current campaign snapshot")
	assert_eq(liora["rank"], "C", "multiple current roster pairs are shown")
	assert_eq(kael["conversations"].size(), 2, "only C and B are unlocked for Kael")
	assert_eq(kael["conversations"][0]["rank"], "C")
	assert_true(kael["conversations"][0]["viewed"])
	assert_eq(kael["conversations"][1]["rank"], "B")
	assert_false(kael["conversations"][1]["viewed"])
	assert_eq(liora["conversations"].size(), 1, "Liora's locked future ranks are omitted")
	assert_eq(liora["conversations"][0]["rank"], "C")
	assert_true(liora["conversations"][0]["viewed"])
	var before := Campaign.to_dict()
	_journal._tab = 6
	_journal.queue_redraw()
	await wait_frames(1)
	_journal._support_i = 1
	_journal.queue_redraw()
	await wait_frames(1)
	assert_eq(Campaign.to_dict(), before, "default/compact page rendering is read-only")


func test_support_page_reopen_reads_latest_campaign_state():
	Campaign.support_save = {"points": {"kai_kael": 20}, "ranks": {"kai_kael": "C"}, "viewed": {}}
	assert_eq(_entry_for_support(_journal._support_entries(), "kael")["rank"], "C")
	Campaign.support_save = {"points": {"kai_kael": 60}, "ranks": {"kai_kael": "B"},
		"viewed": {"kai_kael:C": true, "kai_kael:B": false}}
	_journal.hide()
	var reopened: AcademyJournal = load("res://src/ui/academy_journal.gd").new()
	reopened._save = SaveSystem.new("user://test_journal_saves_%d" % Time.get_ticks_usec())
	add_child_autofree(reopened)
	await wait_frames(1)
	var kael := _entry_for_support(reopened._support_entries(), "kael")
	assert_eq(kael["rank"], "B", "a new Journal reads current earned rank")
	assert_eq(kael["conversations"].size(), 2, "a new Journal reads current unlocked conversations")
	assert_true(kael["conversations"][0]["viewed"])
	assert_false(kael["conversations"][1]["viewed"])


func test_support_rows_scroll_when_conversation_statuses_fill_compact_page():
	Campaign.support_save = {"points": {"kai_kael": 120, "kai_liora": 120},
		"ranks": {"kai_kael": "A", "kai_liora": "A"}, "viewed": {}}
	var entries: Array = _journal._support_entries()
	assert_eq(entries.size(), 2, "layout uses the two authored roster pairs")
	assert_eq(_journal._support_visible_indices(entries, 400.0), [0, 1],
		"default Journal height fits both companion records")
	assert_eq(_journal._support_visible_indices(entries, 162.0), [0],
		"compact Journal height scrolls the longer support records")
	assert_true(_journal._support_visible_indices(entries, 80.0).is_empty(),
		"layout never reports an oversized first companion as fully visible")
	_journal._support_i = 1
	assert_eq(_journal._support_visible_indices(entries, 162.0), [1],
		"down navigation scrolls the selected companion into the compact viewport")


func test_support_rank_and_viewed_state_survive_journal_save_load_round_trip():
	Campaign.support_save = {"points": {"kai_kael": 60}, "ranks": {"kai_kael": "B"},
		"viewed": {"kai_kael:C": true, "kai_kael:B": false}}
	var expected := Campaign.support_save.duplicate(true)
	_journal._do_save(TEST_SLOT)
	Campaign.reset_new_game(false)
	assert_true(Campaign.load_from_slot(TEST_SLOT, _journal._save), "ordinary Campaign/SaveSystem load succeeds")
	var kael := _entry_for_support(_journal._support_entries(), "kael")
	assert_eq(kael["rank"], "B", "the earned rank survives the real save round-trip")
	assert_true(kael["conversations"][0]["viewed"], "viewed receipt survives the real save round-trip")
	assert_false(kael["conversations"][1]["viewed"], "unviewed state survives the real save round-trip")
	assert_eq(int(Campaign.support_save["points"]["kai_kael"]), int(expected["points"]["kai_kael"]),
		"the earned points survive JSON's numeric normalization")
	assert_eq(Campaign.support_save["ranks"]["kai_kael"], expected["ranks"]["kai_kael"])


func _entry_for_support(entries: Array, companion_id: String) -> Dictionary:
	for entry: Dictionary in entries:
		if str(entry["id"]) == companion_id:
			return entry
	return {}


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


func _card_for(id: String) -> Dictionary:
	for s in _journal._snaps:
		if str(s["id"]) == id:
			return s
	return {}
