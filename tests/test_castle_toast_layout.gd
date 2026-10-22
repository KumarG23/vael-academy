extends GutTest
## Issue #15 / WO-4.4 / WO-6.4: castle feedback toasts must stay readable inside
## the viewport. A live castle runs in a real-size SubViewport; checks read the
## toast's laid-out global rect and measure the wrapped text against it, at the
## default 1280×720, a smaller viewport and after a live resize.

const FISHING_RESULT := "Caught a Warded Coin! (x1)"

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
	await wait_frames(1)


## The longest castle toasts a player can actually see: support availability,
## tavern/cooking bond feedback and the mission-week refusal.
func _long_messages() -> Array:
	return [
		"No bonds strong enough yet — fight beside your housemates.",
		"That conversation isn't ready to play yet.",
		"Stew, stories, and something more — bond with Liora deepens to A!",
		"Week 5: The Clash of Three Banners awaits — the year holds its breath until you answer it.",
		"Your oath is sworn: House Emberwing, for this year and always.",
	]


func _assert_toast_readable(label: String) -> void:
	var toast: Label = _castle._toast_label
	var view := Rect2(Vector2.ZERO, Vector2(_viewport.size))
	var rect := toast.get_global_rect()
	assert_true(toast.visible, "%s: toast is shown" % label)
	assert_true(view.encloses(rect),
		"%s: toast rect %s lies inside the %s viewport" % [label, rect, view.size])
	var font := toast.get_theme_font("font")
	var font_size := toast.get_theme_font_size("font_size")
	var text_size := font.get_multiline_string_size(toast.text, HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x, font_size)
	assert_true(text_size.x <= rect.size.x + 0.5,
		"%s: widest line %.1f fits the toast width %.1f" % [label, text_size.x, rect.size.x])
	assert_true(text_size.y <= rect.size.y + 0.5,
		"%s: wrapped text height %.1f fits the toast height %.1f" % [label, text_size.y, rect.size.y])
	assert_eq(toast.get_visible_line_count(), toast.get_line_count(),
		"%s: every wrapped line is drawn" % label)
	assert_eq(toast.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING,
		"%s: text is never trimmed with an ellipsis" % label)


func _catch(fish: String) -> void:
	# The real Waterside path: open the minigame, let it report a catch.
	Campaign.fish_log[fish] = int(Campaign.fish_log.get(fish, 0)) + 1
	_castle._start_fishing()
	_castle._fishing.finished.emit({"caught": true, "fish": fish})
	await wait_frames(1)


func test_fishing_catch_is_whole_and_inside_the_default_viewport():
	await _open_castle(Vector2i(1280, 720))
	await _catch("Warded Coin")
	assert_eq(_castle._toast_label.text, FISHING_RESULT, "catch text and count are unchanged")
	_assert_toast_readable("1280×720 catch")
	var rect := _castle._toast_label.get_global_rect()
	assert_almost_eq(rect.get_center().x, 640.0, 1.0, "the toast stays horizontally centered")


func test_long_messages_wrap_inside_default_and_small_viewports():
	for size in [Vector2i(1280, 720), Vector2i(640, 360)]:
		await _open_castle(size)
		for msg in _long_messages():
			_castle._toast(msg)
			await wait_frames(1)
			_assert_toast_readable("%s %s" % [size, msg.left(24)])
		_viewport.queue_free()
		await wait_frames(1)


func test_toast_follows_a_live_viewport_resize():
	await _open_castle(Vector2i(1280, 720))
	await _catch("Warded Coin")
	_assert_toast_readable("before resize")
	_viewport.size = Vector2i(800, 450)
	await wait_frames(2)
	_assert_toast_readable("shrunk to 800×450")
	_castle._toast(_long_messages()[3])
	await wait_frames(1)
	_assert_toast_readable("long message after resize")
	_viewport.size = Vector2i(1280, 720)
	await wait_frames(2)
	_castle._toast(FISHING_RESULT)
	await wait_frames(1)
	_assert_toast_readable("restored to 1280×720")
	assert_almost_eq(_castle._toast_label.get_global_rect().get_center().x, 640.0, 1.0,
		"centered again after the resize")


func test_short_toast_after_long_one_does_not_keep_stale_height():
	await _open_castle(Vector2i(640, 360))
	_castle._toast(_long_messages()[3])
	await wait_frames(1)
	var tall := _castle._toast_label.get_global_rect().size.y
	_castle._toast("Game saved.")
	await wait_frames(1)
	var short := _castle._toast_label.get_global_rect().size.y
	assert_lt(short, tall, "a one-line toast shrinks back from a wrapped one")
	_assert_toast_readable("short after long")
