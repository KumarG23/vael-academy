class_name ExchangeSkip
extends RefCounted
## WO-9.5 (#65): the skippable presentation clock of ONE battle exchange.
##
## Presenters await their timers, tweens and animation signals through this
## object instead of directly. Until `request()` it is transparent: every wait
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


func request() -> void:
	if skipped:
		return
	skipped = true
	requested.emit()


## Replaces `await get_tree().create_timer(seconds).timeout`.
func wait(node: Node, seconds: float, ignore_time_scale := false) -> void:
	if skipped:
		return
	var timer := node.get_tree().create_timer(seconds, true, false, ignore_time_scale)
	await until(timer.timeout)


## Replaces `await tween.finished`; a skipped tween lands on its final values.
func tween(t: Tween) -> void:
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
	if _tracked.size() >= 64:
		_tracked = _tracked.filter(func(old: Tween) -> bool: return old.is_valid())
	_tracked.append(t)
	return t


## After a skip: land every tracked tween so nothing keeps animating later.
func settle() -> void:
	if not skipped:
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
