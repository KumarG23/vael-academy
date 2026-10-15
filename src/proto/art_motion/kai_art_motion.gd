class_name KaiArtMotion
extends Node2D
## CP-5: existing Kai art driven by actual authored UAL joint positions.
## Original head/torso and weapon pixels; existing clean cloth layers fill the
## occluded limbs. No procedural stride and no substitute face/model.

const ART := preload("res://assets/art/illustrated_pilot/kai/idle.png")
const LAYERS := "res://assets/art/kai_motion_transfer/"
const ANCHOR := Vector2(350,604)
const SOURCE_HEIGHT := 459.28
var driver: AuthoredModelActor
var source_scale := 238.0 / SOURCE_HEIGHT
var parts: Array[Dictionary] = []
var reference: Dictionary = {}
var east := true
var torso: Polygon2D
var cape: Sprite2D
var carry: Polygon2D
var _crown: ShaderMaterial
var _textures: Dictionary = {}


func setup(motion: AuthoredModelActor) -> void:
	driver = motion
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	scale = Vector2.ONE * source_scale
	position = -ANCHOR * source_scale
	for bone: String in ["pelvis","thigh_l","thigh_r","calf_l","calf_r","foot_l","foot_r","ball_l","ball_r","upperarm_l","upperarm_r","lowerarm_l","lowerarm_r","hand_l","hand_r"]:
		reference[bone] = projected_bone(bone)
	for name: String in ["cape","thigh","shin","foot","upper_arm","forearm"]:
		_textures[name] = load(LAYERS+name+".png")
	cape = _sprite("cape",Vector2(128,20),5)
	torso = Polygon2D.new()
	torso.name = "OriginalHeadAndTorso"
	torso.texture = ART
	torso.z_index = 13
	torso.polygon = PackedVector2Array([Vector2(0,0),Vector2(640,0),Vector2(640,237),Vector2(430,237),Vector2(414,254),Vector2(418,319),Vector2(421,401),Vector2(339,401),Vector2(342,323),Vector2(342,281),Vector2(326,248),Vector2(310,237),Vector2(0,237)])
	torso.uv = torso.polygon
	add_child(torso)
	for side: String in ["l","r"]:
		var near := side=="r"
		parts.append({"bones":["thigh_"+side,"calf_"+side,"foot_"+side,"ball_"+side],
			"hip":Vector2(363 if near else 393,361),
			"upper":_sprite("thigh",Vector2(64,18),9 if near else 8),
			"lower":_sprite("shin",Vector2(64,18),9 if near else 8),
			"foot":_sprite("foot",Vector2(50,19),9 if near else 8),"type":"leg"})
		var forearm := _sprite("forearm",Vector2(64,18),14 if near else 10)
		if near:
			# Keep the original illustrated carrying hand; no regenerated fist.
			forearm.region_enabled = true
			forearm.region_rect = Rect2(0,0,128,75)
		parts.append({"bones":["upperarm_"+side,"lowerarm_"+side,"hand_"+side],
			"hip":Vector2(328 if near else 417,263),
			"rest":[Vector2(328 if near else 417,263),Vector2(320 if near else 431,332 if near else 331),Vector2(315 if near else 442,395)],
			"upper":_sprite("upper_arm",Vector2(64,18),14 if near else 10),
			"lower":forearm,"type":"arm","near":near})
	carry = Polygon2D.new()
	carry.name = "OriginalPaintedHandAndSword"
	carry.texture = ART
	carry.z_index = 15
	carry.uv = PackedVector2Array([Vector2(298,381),Vector2(321,381),Vector2(335,363),Vector2(344,365),Vector2(336,394),Vector2(354,413),Vector2(189,584),Vector2(172,578),Vector2(299,408),Vector2(297,397)])
	carry.polygon = carry.uv
	carry.offset = -Vector2(315,395)
	add_child(carry)
	set_carrying(driver.carrying)
	update_from_motion()


func projected_bone(name: String) -> Vector2:
	var point := driver.skeleton.get_bone_global_pose(driver.skeleton.find_bone(name)).origin
	# This drawing provides one view; the mannequin supplies the true turn.
	point = point.rotated(Vector3.UP,AuthoredModelActor.YAW)
	return (driver.camera.unproject_position(point)-driver.camera.unproject_position(Vector3.ZERO))*driver.pixel_factor/source_scale+ANCHOR


func _sprite(part_name: String,pivot: Vector2,layer: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _textures[part_name]
	sprite.centered = false
	sprite.offset = -pivot
	sprite.z_index = layer
	add_child(sprite)
	return sprite


static func _align(sprite: Sprite2D,a: Vector2,b: Vector2,length: float) -> void:
	sprite.position = a
	sprite.rotation = (b-a).angle()-PI*0.5
	sprite.scale = Vector2(1.0,a.distance_to(b)/length)


func _process(_delta: float) -> void:
	update_from_motion()


func update_from_motion() -> void:
	if driver == null:
		return
	east = driver.target_yaw>=0.0
	scale.x = source_scale if east else -source_scale
	position.x = -ANCHOR.x*scale.x
	var body_shift: Vector2 = projected_bone("pelvis")-reference["pelvis"]
	torso.position = body_shift
	cape.position = Vector2(367,244)+body_shift
	_apply_mark()
	for part: Dictionary in parts:
		var bones: Array = part["bones"]
		var offset: Vector2 = part["hip"]-reference[bones[0]]
		var points := PackedVector2Array()
		for index in range(bones.size()):
			var name: String = bones[index]
			if part["type"] == "arm":
				# The drawing's arms are shorter than the mannequin's. Preserve its
				# rest registration, applying the authored joint displacement only.
				points.append(Vector2(part["rest"][index])+projected_bone(name)-Vector2(reference[name]))
			else:
				points.append(projected_bone(name)+offset)
		_align(part["upper"],points[0],points[1],96.0 if part["type"]=="leg" else 60.0)
		_align(part["lower"],points[1],points[2],94.0 if part["type"]=="leg" else 54.0)
		if part["type"]=="leg":
			var foot: Sprite2D = part["foot"]
			var toe := projected_bone(str(bones[3]).replace("ball_", "ball_leaf_"))+offset
			foot.rotation = (toe-points[3]).angle()-Vector2(43.7,3.9).angle()
			# Register the painted toe at the actual planted ball joint. This keeps
			# source stance travel rather than inventing heel/toe trajectories.
			foot.position = points[3]-(Vector2(87,41.4)+foot.offset).rotated(foot.rotation)
		elif part["near"]:
			carry.position = points[2]
			carry.rotation = (points[2]-points[1]).angle()-Vector2(-5,63).angle()


func set_carrying(value: bool) -> void:
	carry.visible = value
	for part: Dictionary in parts:
		if part["type"] == "arm" and part["near"]:
			var forearm: Sprite2D = part["lower"]
			forearm.region_enabled = value


func _apply_mark() -> void:
	if east:
		torso.material = null
		return
	if _crown == null:
		_crown = ShaderMaterial.new()
		_crown.shader = preload("res://src/ui/illustrated_crown_facing.gdshader")
		_crown.set_shader_parameter("source_mark",Vector4(408,180,8,10))
		_crown.set_shader_parameter("target_mark",Vector4(376,183,8,10))
		_crown.set_shader_parameter("skin_sample",Vector2(398,187))
	torso.material = _crown
