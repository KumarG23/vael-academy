extends Node2D
## AW-47: a thin overlay drawn ABOVE the avatar/NPCs (high z_index). Props are
## painted in the castle's own _draw, UNDER the child actor sprites, so without
## this the avatar always renders on top of every tree. This overlay redraws any
## prop an actor is standing BEHIND (feet above the prop's base + overlapping it),
## giving proper y-sort occlusion — you walk UNDER the Wardtree, not over it.
## No class_name on purpose (avoids a global-class cache refresh); the castle owns
## the draw logic and just hands us its canvas.

var castle


func _draw() -> void:
	if castle != null:
		castle.draw_occluders(self)
