class_name ExchangeSkip
extends RefCounted
## WO-9.5 (#65/#75): skip and held 2× clock for ONE battle exchange.
##
## Presenters await their timers, tweens and animation signals through this
## object instead of directly. At normal speed it is transparent: every wait
## resumes on the very signal it replaced, in the same frame. After a skip the
## remaining waits return at once and awaited tweens jump to their final state,
## so the SAME presentation code runs to its end — every contact still applies
## the resolver's HP in order and every teardown still happens — only the
## elapsed time is removed. It never touches Engine.time_scale or rendering.

signal requested

## Far enough to complete any finite presentation tween in one step.
const _FAR := 3600.0

var skipped := false
var _tracked: Array[Tween] = []
## GH-75: local presentation rate; never a world/audio time scale.
var speed := 1.0
var was_fast := false
var _timers: Array[WeakRef] = []
var _animations: Array[Dictionary] = []


## Rescale remaining time on the existing native timer, retaining its signal,
## process mode and hit-stop immunity. Tweens/sprites change in this input frame.
func set_fast(held: bool) -> void:
	var rate := 2.0 if held and not skipped else 1.0
	if rate == speed:
		return
	was_fast = was_fast or held
	var ratio := speed / rate
	speed = rate
	for ref: WeakRef in _timers:
		var timer: SceneTreeTimer = ref.get_ref()
		if timer != null and timer.time_left > 0.0:
			timer.time_left *= ratio
	for t: Tween in _tracked:
		if t.is_valid():
			t.set_speed_scale(speed)
	for entry: Dictionary in _animations:
		var sprite: AnimatedSprite2D = entry["ref"].get_ref()
		if is_instance_valid(sprite):
			sprite.speed_scale = float(entry["base"]) * speed


func animation(sprite: AnimatedSprite2D) -> void:
	for entry: Dictionary in _animations:
		if entry["ref"].get_ref() == sprite:
			return
	_animations.append({"ref": weakref(sprite), "base": sprite.speed_scale})
	sprite.speed_scale *= speed


func request() -> void:
	if skipped:
		return
	set_fast(false)
	skipped = true
	requested.emit()


## Replaces `await get_tree().create_timer(seconds).timeout`.
func wait(node: Node, seconds: float, ignore_time_scale := false) -> void:
	if skipped:
		return
	var timer := node.get_tree().create_timer(seconds / speed, true, false, ignore_time_scale)
	_timers.append(weakref(timer))
	await until(timer.timeout)


## Replaces `await tween.finished`; a skipped tween lands on its final values.
func tween(t: Tween) -> void:
	track(t)
	if not skipped:
		await until(t.finished)
	if skipped:
		finish(t)


## Replaces `await some_signal` (argument-free signals only).
func until(sig: Signal) -> void:
	if skipped:
		return
	var gate := _Gate.new()
	sig.connect(gate.open)
	requested.connect(gate.open)
	await gate.opened
	if is_instance_valid(sig.get_object()) and sig.is_connected(gate.open):
		sig.disconnect(gate.open)
	if requested.is_connected(gate.open):
		requested.disconnect(gate.open)


## Registers a fire-and-forget presentation tween so a skip can settle it.
## (Not finished here: the caller has not added its tweeners yet.)
func track(t: Tween) -> Tween:
	if _tracked.has(t):
		return t
	t.set_speed_scale(speed)
	if _tracked.size() >= 64:
		_tracked = _tracked.filter(func(old: Tween) -> bool: return old.is_valid())
	_tracked.append(t)
	return t


## After skip or accelerated playback: land leftover feedback at exchange end.
func settle() -> void:
	if not skipped and not was_fast:
		return
	var pending := _tracked
	_tracked = []
	for t in pending:
		finish(t)


static func finish(t: Tween) -> void:
	if t != null and t.is_valid() and t.is_running():
		t.custom_step(_FAR)


class _Gate:
	signal opened
	var _open := false

	func open() -> void:
		if _open:
			return
		_open = true
		opened.emit()
