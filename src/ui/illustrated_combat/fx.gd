class_name IllustratedCombatFX
extends Node2D
## CP-6: a small HD subset, using the creators' unchanged sheet players.
const RECOLOR := preload("res://src/ui/illustrated_combat/fx_tint.gdshader")
const FLARE := preload("res://assets/art/hybrid_fx/kenney/flare_01.png")
const SPARK := preload("res://assets/art/hybrid_fx/kenney/spark_01.png")
var pace := ExchangeSkip.new()
var rings: Array[Dictionary] = []
var blades: Array[Dictionary] = []


static func configure() -> void:
	CombatFX.sheets_dir = "res://assets/art/hybrid_fx/combat"
	SpellFX.sheets_dir = "res://assets/art/hybrid_fx/spell"


static func tint(sprite: CanvasItem, color: Color) -> void:
	var material := ShaderMaterial.new()
	material.shader = RECOLOR
	material.set_shader_parameter("tint", color)
	sprite.material = material


func _ready() -> void:
	configure()
	texture_filter = TEXTURE_FILTER_LINEAR


func gleam(at: Vector2, color: Color, duration: float, size: float = 0.22) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = FLARE
	sprite.position = to_local(at)
	sprite.modulate = color
	sprite.scale = Vector2.ONE * 0.015
	add_child(sprite)
	var tween := pace.track(sprite.create_tween()).set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2.ONE * size, duration * 0.7).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sprite, "rotation", 0.7, duration)
	tween.tween_property(sprite, "modulate:a", 0.0, duration * 0.3).set_delay(duration * 0.7)
	tween.chain().tween_callback(sprite.queue_free)


func gather(at: Vector2, color: Color, duration: float) -> void:
	gleam(at, color, duration, 0.26)
	rings.append({"at": to_local(at), "color": color, "age": 0.0, "life": duration, "gather": true})
	for index in range(7):
		var mote := Sprite2D.new()
		mote.texture = FLARE
		mote.modulate = color
		mote.scale = Vector2.ONE * 0.045
		mote.position = to_local(at) + Vector2.from_angle(TAU * index / 7.0) * 58.0
		add_child(mote)
		var pull := pace.track(mote.create_tween()).set_parallel(true)
		pull.tween_property(mote, "position", to_local(at), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		pull.tween_property(mote, "modulate:a", 0.0, duration * 0.25).set_delay(duration * 0.75)
		pull.chain().tween_callback(mote.queue_free)


func blade_light(body: Sprite2D, base: Vector2, tip: Vector2, color: Color, duration: float) -> void:
	blades.append({"body": body, "base": base, "tip": tip, "color": color, "age": 0.0, "life": duration})


func burst(at: Vector2, color: Color, critical: bool, magical: bool) -> void:
	if magical:
		var bloom := SpellFX.spawn(self, "arcane_impact", at)
		pace.animation(bloom)
		bloom.scale = Vector2.ONE * 0.85
		tint(bloom, color)
	else:
		var hit := CombatFX.spawn(self, "gold_crit" if critical else "white_hit", at)
		pace.animation(hit)
		hit.scale = Vector2.ONE * (0.78 if critical else 0.48)
		if not critical:
			tint(hit, color.lerp(Color.WHITE, 0.25))
	rings.append({"at": to_local(at), "color": color, "age": 0.0, "life": 0.42, "gather": false})
	# Deterministic trajectories: cosmetic sparks consume no combat RNG.
	for index in range(9 if critical else 5):
		var spark := Sprite2D.new()
		spark.texture = SPARK
		spark.position = to_local(at)
		spark.modulate = color.lerp(Color.WHITE, 0.5)
		spark.rotation = float(index) * 2.4
		spark.scale = Vector2(0.08, 0.025)
		add_child(spark)
		var end := spark.position + Vector2.from_angle(spark.rotation) * (48.0 + index * 9.0)
		var tween := pace.track(spark.create_tween()).set_parallel(true)
		tween.tween_property(spark, "position", end, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, 0.28)
		tween.chain().tween_callback(spark.queue_free)


func _process(delta: float) -> void:
	delta *= pace.speed
	for ring: Dictionary in rings:
		ring["age"] += delta
	rings = rings.filter(func(ring: Dictionary) -> bool: return ring["age"] < ring["life"])
	for blade: Dictionary in blades:
		blade["age"] += delta
	blades = blades.filter(func(blade: Dictionary) -> bool: return blade["age"] < blade["life"] and is_instance_valid(blade["body"]))
	queue_redraw()


func _draw() -> void:
	for blade: Dictionary in blades:
		var body: Sprite2D = blade["body"]
		var start := to_local(body.to_global(Vector2(blade["base"]) + body.offset))
		var end := to_local(body.to_global(Vector2(blade["tip"]) + body.offset))
		var glow: Color = blade["color"]
		glow.a = sin(float(blade["age"]) / float(blade["life"]) * PI) * 0.48
		draw_line(start, end, glow, 9.0, true)
		glow.a = 0.8
		draw_line(start, end, glow, 2.0, true)
	for ring: Dictionary in rings:
		var progress: float = ring["age"] / ring["life"]
		var color: Color = ring["color"]
		color.a = sin(progress * PI) * 0.7
		var radius := lerpf(48.0, 16.0, progress) if ring["gather"] else lerpf(12.0, 94.0, progress)
		draw_arc(ring["at"], radius, progress, TAU + progress, 64, color, 2.0, true)
		if ring["gather"]:
			for point in range(5):
				var angle := TAU * point / 5.0 + progress
				var center: Vector2 = ring["at"] + Vector2.from_angle(angle) * radius
				draw_line(center - Vector2(0, 4), center + Vector2(0, 4), color, 2.0, true)
