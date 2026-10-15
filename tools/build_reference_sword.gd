## CP-4: extract KayKit's licensed static sword; preserve raw source model.
extends SceneTree


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var reference := (load("res://assets/source/authored_motion/kaykit/Knight.glb") as PackedScene).instantiate()
	var source := reference.find_child("1H_Sword", true, false) as MeshInstance3D
	var sword := Node3D.new()
	sword.name = "ReferenceSword"
	root.add_child(sword)
	var mesh := MeshInstance3D.new()
	mesh.name = "Sword"
	mesh.mesh = source.mesh
	sword.add_child(mesh)
	mesh.owner = sword
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	DirAccess.make_dir_recursive_absolute("res://assets/art/authored_motion")
	var append := document.append_from_scene(sword, state)
	var write := document.write_to_filesystem(state, "res://assets/art/authored_motion/reference_sword.glb")
	print("SWORD EXPORT ", append, " ", write)
	reference.free()
	sword.free()
	quit()
