extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	Engine.max_fps = 60
	var rig_script = load("res://src/ui/combat_rig.gd")
	var strike_script = load("res://src/combat/strike_result.gd")
	var rig = rig_script.new()
	root.add_child(rig)
	rig.setup("kai", 0, 1.0)
	var strike = strike_script.new()
	strike.connected = true
	strike.damage = 1
	rig.set_outcome(strike, false)
	rig._slash_trail(false)
	var low: Dictionary = rig._fx_items.back().duplicate(true)
	rig._fx_items.clear()
	strike.damage = 20
	rig.set_outcome(strike, false)
	rig._slash_trail(false)
	var high: Dictionary = rig._fx_items.back().duplicate(true)
	print("PROBE trail damage1_vs20_identical=", low == high, " power_high=", rig._power())
	rig._fx_items.clear()
	strike.connected = false
	rig.set_outcome(strike, false)
	rig._slash_trail(false)
	print("PROBE miss_vs_hit_trail_identical=", low == rig._fx_items.back())
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	img.fill_rect(Rect2i(44, 16, 40, 96), Color.WHITE)
	var texture := ImageTexture.create_from_image(img)
	rig.set_pose_textures(texture)
	var bounds := img.get_used_rect()
	var visible_foot: float = rig._body.position.y + (float(bounds.end.y) - 64.0) * rig._body.scale.y
	print("PROBE padded128 visible_foot=", visible_foot, " expected=16 offset=", visible_foot - 16.0)
	var fx_script = load("res://src/combat/combat_fx_profile.gd")
	var corvin = load("res://data/units/corvin.tres")
	var tome = load("res://src/combat/weapon_def.gd").new()
	tome.weapon_type = 4
	tome.school = "reason"
	print("PROBE caster=", corvin.fx_magic_style, " unset_weapon_fx_style=", tome.fx_style, " resolved=", fx_script.build(corvin,tome).magic_style)
	var default_rig = rig_script.new()
	var sig = load("res://data/weapons/sig_rina.tres")
	var profile = fx_script.build(load("res://data/units/rina.tres"),sig)
	print("PROBE rina profile=",profile.ranged_style," configured_color=",sig.fx_color," default_rig_profile=",default_rig._fx_profile.ranged_style)
	default_rig.free()
	rig.free()
	var grid = load("res://src/core/grid.gd").new(3,3,128)
	var unit_script = load("res://src/units/unit.gd")
	var def_script = load("res://src/units/unit_def.gd")
	var adef = def_script.new()
	adef.id = "audit_noart_a"
	adef.char_class = load("res://data/classes/soldier.tres")
	var bdef = adef.duplicate()
	bdef.id = "audit_noart_b"
	var a = unit_script.new()
	var b = unit_script.new()
	a.setup(adef, grid, Vector2i(0,1))
	b.setup(bdef, grid, Vector2i(1,1))
	root.add_child(a)
	root.add_child(b)
	var juice = load("res://src/ui/juice_controller.gd").new()
	root.add_child(juice)
	var config = load("res://src/combat/juice_config.gd").new()
	config.hitstop_hit = 0.0
	config.splash_on_crit = false
	config.splash_on_kill = false
	var numbers := Node2D.new()
	root.add_child(numbers)
	juice.setup(config,null,numbers,null)
	var ahome: Vector2 = a.position
	var bhome: Vector2 = b.position
	strike.connected = true
	strike.was_crit = false
	strike.damage = 1
	strike.defender_hp_after = b.current_hp - 1
	juice._react_target(b, Vector2.RIGHT, strike, false)
	for n in 8:
		await create_timer(0.025).timeout
		print("PROBE flinch sample=",n," pos=", b.position-bhome," scale=", b.scale)
	strike.was_crit = true
	juice._react_target(b, Vector2.RIGHT, strike, false)
	for n in 8:
		await create_timer(0.025).timeout
		print("PROBE stagger sample=",n," pos=", b.position-bhome," scale=", b.scale," rot=",b.rotation)
	strike.connected = false
	juice._react_target(b, Vector2.RIGHT, strike, false)
	await create_timer(0.04).timeout
	print("PROBE dodge_control pos=",b.position-bhome)
	await create_timer(0.3).timeout
	var control = b.create_tween().set_parallel(true)
	control.tween_property(b,"position",bhome+Vector2(8,0),0.07)
	control.tween_property(b,"scale",Vector2(1.07,0.86),0.07)
	control.chain().tween_property(b,"position",bhome,0.16)
	control.parallel().tween_property(b,"scale",Vector2.ONE,0.16)
	await create_timer(0.04).timeout
	print("PROBE correctly_chained_control pos=",b.position-bhome," scale=",b.scale)
	await control.finished
	strike.connected = true
	strike.was_crit = false
	await juice.play_strike(a,b,strike,false)
	print("PROBE fallback_target_offset_on_return=",b.position-bhome)
	strike.defender_hp_after = a.current_hp - 1
	await juice.play_strike(b,a,strike,false)
	await create_timer(0.4).timeout
	print("PROBE fallback_after_counter_a=",a.position-ahome," b=",b.position-bhome)
	a.free()
	b.free()
	juice.free()
	numbers.free()
	quit()
