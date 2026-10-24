extends GutTest
## Issue #139 / AW-50: the arena Trial report (title, remark, waves, best,
## winnings, hint) stays completely readable through 1280x720, 800x450, 640x360
## and live shrink/restore. Presentation only: dismissal, ownership and the
## normal Victory/Defeat card are unchanged.

const SIZES := [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(640, 360)]
const TITLE := "The Trial Ends"
const ACCENT := Color(0.55, 0.92, 0.65)


func _variants() -> Array:
	var out: Array = []
	# every shipped remark x (retreat/fall), with the actual producer line shapes
	var remarks := [
		ArenaController.reward(0)["remark"], ArenaController.reward(1)["remark"],
		ArenaController.reward(3)["remark"], ArenaController.reward(6)["remark"],
		"You retire from the sand with your winnings — the crowd approves.",
		"An early exit. The sand will wait.",
	]
	for remark in remarks:
		for waves in [0, 2, 12, 99]:
			var r := ArenaController.reward(waves)
			for best in [true, false]:
				out.append([remark, "Waves cleared: %d" % waves,
					"★ NEW PERSONAL BEST! ★" if best else "Personal best: %d" % maxi(waves, 123),
					"Winnings: %d gold  ·  +%d extra credit" % [int(r["gold"]), int(r["credit"])]])
	return out


func _make(size: Vector2i) -> Array:
	var sv := SubViewport.new()
	sv.size = size
	sv.handle_input_locally = true
	add_child_autofree(sv)
	var rs := ResultScreen.new()
	sv.add_child(rs)
	return [sv, rs]


func _assert_readable(rs: ResultScreen, vp: Vector2, lines: Array, tag: String) -> void:
	var lay: Dictionary = rs.compute_layout(vp)
	var panel: Rect2 = lay["panel"]
	var view := Rect2(Vector2.ZERO, vp)
	assert_true(view.encloses(panel), "%s panel inside viewport %s" % [tag, panel])
	var inner := panel.grow(-8.0)
	var texts := {"title": [], "lines": []}
	for r in lay["rows"]:
		var rect: Rect2 = r["rect"]
		if not inner.encloses(rect):
			fail_test("%s row '%s' %s escapes panel %s" % [tag, r["text"], rect, panel])
		assert_true(view.encloses(rect), "%s row inside viewport" % tag)
		if r["kind"] == "title":
			texts["title"].append(r["text"])
		else:
			texts["lines"].append(r["text"])
		var font_size: int = r["size"]
		assert_true(font_size in [64, 26, 22], "%s keeps shipped font sizes" % tag)
	var hint: Dictionary = lay["hint"]
	assert_true(view.encloses(hint["rect"]), "%s hint inside viewport %s" % [tag, hint["rect"]])
	assert_gt(hint["rect"].position.y, panel.end.y - 1.0, "%s hint below the panel" % tag)
	assert_eq(hint["text"], "Press any key")
	assert_eq(" ".join(texts["title"]), TITLE, "%s complete title" % tag)
	# every report line is wholly present: its wrapped rows rejoin to the original
	var joined := " ".join(texts["lines"])
	assert_eq(joined, " ".join(lines), "%s complete report text" % tag)
	for i in range(lay["rows"].size() - 1):
		var a: Rect2 = lay["rows"][i]["rect"]
		var b: Rect2 = lay["rows"][i + 1]["rect"]
		assert_lte(a.end.y, b.position.y + 0.01, "%s rows do not overlap" % tag)


func test_every_variant_is_readable_at_each_size():
	for size in SIZES:
		var pair := _make(size)
		var rs: ResultScreen = pair[1]
		for lines in _variants():
			rs.show_report(TITLE, ACCENT, lines)
			await get_tree().process_frame
			_assert_readable(rs, Vector2(size), lines, "%s %s" % [size, lines[0]])
		pair[0].queue_free()


func test_live_shrink_and_restore_reflows_and_returns():
	var pair := _make(Vector2i(1280, 720))
	var sv: SubViewport = pair[0]
	var rs: ResultScreen = pair[1]
	var lines: Array = _variants()[0]
	rs.show_report(TITLE, ACCENT, lines)
	await get_tree().process_frame
	var big: Dictionary = rs.compute_layout(Vector2(1280, 720))
	for size in [Vector2i(800, 450), Vector2i(640, 360), Vector2i(800, 450), Vector2i(1280, 720)]:
		sv.size = size
		await get_tree().process_frame
		await get_tree().process_frame
		assert_eq(rs.size, Vector2(size), "overlay refits %s" % size)
		assert_true(rs.is_shown(), "resize does not dismiss")
		_assert_readable(rs, Vector2(size), lines, "live %s" % size)
	assert_eq(rs.compute_layout(Vector2(1280, 720))["panel"], big["panel"], "restore returns the layout")


func test_dismissal_still_works_after_compact_reflow_and_emits_once():
	for kind in ["key", "click"]:
		var pair := _make(Vector2i(640, 360))
		var sv: SubViewport = pair[0]
		var rs: ResultScreen = pair[1]
		var lines: Array = _variants()[0]
		rs.show_report(TITLE, ACCENT, lines)
		await get_tree().process_frame
		var count := [0]
		rs.dismissed.connect(func() -> void: count[0] += 1)
		sv.size = Vector2i(800, 450)
		await get_tree().process_frame
		if kind == "key":
			var echo := InputEventKey.new()
			echo.keycode = KEY_SPACE
			echo.pressed = true
			echo.echo = true
			sv.push_input(echo)
			await get_tree().process_frame
			assert_eq(count[0], 0, "an echo key does not dismiss")
			var k := InputEventKey.new()
			k.keycode = KEY_SPACE
			k.pressed = true
			sv.push_input(k)
		else:
			var c := InputEventMouseButton.new()
			c.button_index = MOUSE_BUTTON_LEFT
			c.pressed = true
			c.position = Vector2(400, 225)
			c.global_position = c.position
			sv.push_input(c)
		await get_tree().process_frame
		assert_eq(count[0], 1, "%s dismisses once" % kind)
		assert_false(rs.is_shown())
		sv.size = Vector2i(640, 360)
		await get_tree().process_frame
		assert_false(rs.visible, "resize after dismissal does not resurrect the overlay")
		assert_eq(count[0], 1)
		pair[0].queue_free()


func test_report_snapshot_and_normal_results_unchanged_by_layout():
	var pair := _make(Vector2i(640, 360))
	var rs: ResultScreen = pair[1]
	var lines: Array = _variants()[0].duplicate()
	var expected := lines.duplicate()
	rs.show_report(TITLE, ACCENT, lines)
	rs.compute_layout(Vector2(640, 360))
	assert_eq(lines, expected, "layout never mutates the caller's lines")
	lines[0] = "changed"
	assert_eq(rs._lines, expected, "snapshot is independent")
	rs.show_victory()
	assert_true(rs._lines.is_empty())
	var lay: Dictionary = rs.compute_layout(Vector2(640, 360))
	assert_eq(lay["rows"].size(), 1, "normal Victory is a single title row")
	assert_eq(lay["rows"][0]["text"], "Victory")
	assert_true(Rect2(Vector2.ZERO, Vector2(640, 360)).encloses(lay["rows"][0]["rect"]))
	rs.show_defeat()
	assert_eq(rs.compute_layout(Vector2(640, 360))["rows"][0]["text"], "Defeat")
