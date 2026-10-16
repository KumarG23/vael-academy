extends GutTest
## VS-1B package reconciliation: authored contracts, assets and scene boundaries.

const ROOT := "res://data/dialogue/"
const DRAFTS := "res://docs/story_packages/vs1b/dialogue_drafts/"
const SCENES := ["prologue_home_morning", "prologue_road_waystation", "road_bandit_intro", "road_bandit_outro"]


func test_approved_package_words_preserved_and_no_new_story_unlocks():
	for name: String in SCENES:
		var approved := DialogueScript.from_file(DRAFTS + name + ".json")
		var live := DialogueScript.from_file(ROOT + name + ".json")
		assert_true(live.ok(), name)
		assert_eq(live.size(), approved.size(), name + " has no repeated or omitted beat")
		for i in range(live.size()):
			assert_eq(live.get_step(i).text, approved.get_step(i).text, name + " approved prose")
			assert_true(live.get_step(i).is_line(), "no hidden unlock/calendar event")


func test_road_strangers_are_unnamed_until_aftermath_and_escort_has_an_exit():
	var intro := DialogueScript.from_file(ROOT + "road_bandit_intro.json")
	var speakers: Array[String] = []
	for i in range(intro.size()):
		speakers.append(intro.get_step(i).speaker)
	assert_false(speakers.has("Perrin"))
	assert_false(speakers.has("Serra"))
	assert_false(speakers.has("Rina"))
	assert_true(speakers.has("Rider"))
	assert_true(speakers.has("Lancer"))
	assert_true(speakers.has("Traveler"))
	assert_string_contains(intro.get_step(22).text, "I have her!")
	assert_string_contains(intro.get_step(intro.size()-1).text, "The child is safe")
	var chapter: ChapterDef = load("res://data/chapters/prologue.tres")
	assert_eq(chapter.player_spawns.size(), 4)
	assert_eq(chapter.enemy_spawns.size(), 5)


func test_all_live_stills_and_portraits_exist_and_only_one_morning_backdrop():
	for name: String in SCENES:
		var script := DialogueScript.from_file(ROOT + name + ".json")
		var backdrops: Array[String] = []
		for i in range(script.size()):
			var step := script.get_step(i)
			if step.backdrop != "":
				assert_true(ResourceLoader.exists(step.backdrop), step.backdrop)
				backdrops.append(step.backdrop)
			if step.portrait != "":
				assert_true(ResourceLoader.exists(DialogueScene.portrait_path(step.portrait, step.expression)), step.portrait)
		if name == "prologue_home_morning":
			assert_eq(backdrops, ["res://assets/art/vn/painted/oakstead_kitchen_morning.png"] as Array[String])
	var outro := DialogueScript.from_file(ROOT + "road_bandit_outro.json")
	assert_string_contains(outro.get_step(8).backdrop, "road_bread_gift.png")
	assert_eq(outro.get_step(11).portrait, "kai_travel", "bread still retains dialogue portraits")
	assert_string_contains(outro.get_step(15).backdrop, "road_aftermath_square.png", "return from held bread shot for group exchange")


func test_new_script_clears_previous_cast_but_keeps_existing_in_scene_portrait_behavior():
	var scene := DialogueScene.new()
	add_child_autofree(scene)
	scene.typewriter_speed = 0.0
	scene.play(DialogueScript.from_json('[{"speaker":"Essa","portrait":"essa","side":"right","text":"Home."}]'))
	assert_eq(scene._right_portrait, "essa")
	scene.play(DialogueScript.from_json('[{"speaker":"Kai","portrait":"kai_travel_nomark","text":"Woods."},{"speaker":"Tam","portrait":"tam","side":"right","text":"Basket."}]'))
	assert_eq(scene._right_portrait, "", "Essa cannot haunt the next forest/waystation scene")
	assert_eq(scene._left_portrait, "kai_travel_nomark")
	scene.advance()
	assert_eq(scene._left_portrait, "kai_travel_nomark", "normal same-scene two-speaker display retained")
	assert_eq(scene._right_portrait, "tam")


func test_bread_insets_hold_through_lines_and_restore_afterward_and_on_new_script():
	var scene := DialogueScene.new()
	add_child_autofree(scene)
	scene.typewriter_speed = 0.0
	scene.play(DialogueScript.from_file(ROOT + "road_bandit_outro.json"))
	assert_eq(scene._portrait_layout, "standard")
	for i in range(8):
		scene.advance()
	assert_eq(scene._portrait_layout, "inset", "the bread painting gets space")
	for i in range(7):
		assert_eq(scene._portrait_layout, "inset", "narration and both speakers retain compact portraits")
		scene.advance()
	assert_eq(scene._portrait_layout, "standard", "group exchange returns to regular VN layout")
	scene.play(DialogueScript.from_json('[{"text":"Bread","portrait_layout":"inset"}]'))
	assert_eq(scene._portrait_layout, "inset")
	scene.play(DialogueScript.from_json('[{"text":"Other scene"}]'))
	assert_eq(scene._portrait_layout, "standard", "layout cannot leak into oath or supports")
