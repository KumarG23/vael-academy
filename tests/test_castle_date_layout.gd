extends GutTest
## Issue #40 / WO-4.4 / WO-7.1: the live calendar date stays visible and
## aligned to the upper-right corner as the native viewport is resized.

var _viewport: SubViewport
var _castle: CastleScene


func before_each() -> void:
	Campaign.reset_new_game(false)
	CastleScene.next_room = ""
	CastleScene.next_spawn = Vector2i(-1, -1)


func after_each() -> void:
	Campaign.reset_new_game(false)


func _open_castle(size: Vector2i) -> void:
	_viewport = SubViewport.new()
	_viewport.size = size
	add_child_autofree(_viewport)
	_castle = (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
	_viewport.add_child(_castle)
	await wait_process_frames(2)


func _assert_date_readable(size: Vector2i, label: String) -> void:
	var date: Label = _castle._date_label
	var view := Rect2(Vector2.ZERO, Vector2(size))
	var rect := date.get_global_rect()
	assert_eq(date.text, "Week 2 — Term begins", "%s: the saved week/event text is preserved" % label)
	assert_true(view.encloses(rect), "%s: date rect %s stays within %s" % [label, rect, view.size])
	assert_eq(date.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT,
		"%s: calendar content remains right-aligned" % label)
	assert_almost_eq(rect.end.x, float(size.x - 12), 1.0,
		"%s: date band keeps its 12 px right inset" % label)
	var font := date.get_theme_font("font")
	var font_size := date.get_theme_font_size("font_size")
	var text_size := font.get_multiline_string_size(date.text, HORIZONTAL_ALIGNMENT_RIGHT,
		rect.size.x, font_size)
	assert_true(text_size.x <= rect.size.x + 0.5,
		"%s: date text width %.1f fits %.1f" % [label, text_size.x, rect.size.x])
	assert_true(text_size.y <= rect.size.y + 0.5,
		"%s: date text height %.1f fits %.1f" % [label, text_size.y, rect.size.y])
	assert_eq(date.get_visible_line_count(), date.get_line_count(),
		"%s: every date line is visible" % label)


func test_date_stays_readable_through_resize_to_compact_viewports():
	Campaign.week = 2  # Match the accepted-code QA repro: the free Term begins week.
	await _open_castle(Vector2i(1280, 720))
	_assert_date_readable(Vector2i(1280, 720), "1280×720")
	for size in [Vector2i(800, 450), Vector2i(640, 360), Vector2i(1280, 720)]:
		_viewport.size = size
		await wait_process_frames(2)
		_assert_date_readable(size, "%d×%d" % [size.x, size.y])
