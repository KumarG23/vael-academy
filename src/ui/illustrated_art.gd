class_name IllustratedArt
extends RefCounted
## CP-2: one pilot kit with a shared body scale and explicit foot anchors.
## Does not change a UnitDef or combat state. The pilot opts in per actor.

var textures: Dictionary = {}
var anchors: Dictionary = {}
var hands: Dictionary = {}
var source_body_height: float = 400.0
var walk_fps: float = 7.0
var walk_names: Array[String] = []


static func from_directory(directory: String) -> IllustratedArt:
	if not ResourceLoader.exists(directory.path_join("idle.png")):
		return null
	var kit := IllustratedArt.new()
	var manifest: Dictionary = {}
	var path := directory.path_join("kit.json")
	if FileAccess.file_exists(path):
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if raw is Dictionary:
			manifest = raw
	kit.source_body_height = maxf(1.0, float(manifest.get("source_body_height", 400.0)))
	kit.walk_fps = maxf(1.0, float(manifest.get("walk_fps", 7.0)))
	for name in manifest.get("walk", []):
		kit.walk_names.append(str(name))
	var names: Array[String] = ["idle", "action", "parry_hit", "cast", "defeat"]
	names.append_array(kit.walk_names)
	for name in names:
		var tex_path := directory.path_join(name + ".png")
		if ResourceLoader.exists(tex_path):
			kit.textures[name] = load(tex_path)
			var anchor: Array = manifest.get("anchors", {}).get(name, [])
			if anchor.size() == 2:
				kit.anchors[name] = Vector2(float(anchor[0]), float(anchor[1]))
			var hand: Array = manifest.get("hands", {}).get(name, [])
			if hand.size() == 2:
				kit.hands[name] = Vector2(float(hand[0]), float(hand[1]))
	return kit


func texture_for(pose: String) -> Texture2D:
	return textures.get(pose, textures.get("idle"))


func foot_for(pose: String) -> Vector2:
	var tex := texture_for(pose)
	return anchors.get(pose, anchors.get("idle", Vector2(tex.get_width() * 0.5, tex.get_height())))


func apply(sprite: Sprite2D, pose: String, feet: Vector2, height: float) -> void:
	var tex := texture_for(pose)
	var factor := height / source_body_height
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.centered = false
	sprite.offset = -foot_for(pose)
	sprite.scale = Vector2.ONE * factor
	sprite.position = feet


func hand_for(pose: String) -> Vector2:
	return hands.get(pose, foot_for(pose) - Vector2(0, source_body_height * 0.55))
