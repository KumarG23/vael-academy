class_name BattlePopupHPBar
extends Control
## GBA-FE style HP readout for the battle screen (popup v3): big numeric HP
## beside a chunky segmented bar in a framed trough. `shown_hp` is tweened by
## the popup so the bar DRAINS on impact instead of snapping (the reference
## GIFs never show floating damage numbers — the bar is the damage).

var max_hp: int = 1
var shown_hp: float = 1.0:
	set(v):
		shown_hp = v
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var hp := int(ceil(shown_hp))
	# numeric HP
	draw_string(font, Vector2(0, 34), "%d" % hp, HORIZONTAL_ALIGNMENT_RIGHT, 46, 30,
		Color(0.98, 0.96, 0.9))
	draw_string_outline(font, Vector2(0, 34), "%d" % hp, HORIZONTAL_ALIGNMENT_RIGHT, 46, 30,
		5, Color(0.08, 0.08, 0.12, 0.9))
	# framed trough
	var bar := Rect2(56, 10, size.x - 60, 20)
	draw_rect(bar.grow(3), Color(0.86, 0.78, 0.55), false, 2.0)
	draw_rect(bar, Color(0.07, 0.09, 0.07), true)
	# green segments, one per HP, with 1px separators
	if max_hp <= 0:
		return
	var seg_w := bar.size.x / float(max_hp)
	for i in range(mini(hp, max_hp)):
		var r := Rect2(bar.position.x + i * seg_w + 1, bar.position.y + 2,
			maxf(seg_w - 2.0, 1.0), bar.size.y - 4)
		draw_rect(r, Color(0.30, 0.85, 0.25), true)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color(0.55, 0.98, 0.45), true)
