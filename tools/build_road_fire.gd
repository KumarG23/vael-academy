extends SceneTree
## VS-1B: build the reviewed uniform VFX Creator clip, preserving native pixels.
func _initialize() -> void:
	var source := "res://assets/source/pixellab/vs1b_fire/pack/manifest.json"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
	var clip: Dictionary = manifest.clips[0]
	assert(clip.name == "whole" and clip.frames == 12)
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", float(manifest.fps))
	frames.set_animation_loop("default", true)
	var tex: Texture2D = load("res://assets/art/pixellab/vfx/road_cottage_fire/whole.png")
	for i in range(int(clip.frames)):
		var frame := AtlasTexture.new()
		frame.atlas = tex
		frame.region = Rect2((i % 4) * int(clip.frame.w), (i / 4) * int(clip.frame.h), clip.frame.w, clip.frame.h)
		frames.add_frame("default", frame)
	assert(ResourceSaver.save(frames, "res://data/vfx/road_cottage_fire.tres") == OK)
	print("Built 12 pixel frames at 10fps; native offset ", clip.offset)
	quit()
