class_name AuthoredSwordGrip
extends SkeletonModifier3D
## CP-4: only the right fingers use the artist's Sword_Idle pose.
## Gait, shoulders and elbow remain authored; the carrying wrist adds a tilt.
var rotations: Dictionary = {}
var wrist := -1
var wrist_tilt := deg_to_rad(-35.0)

func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	for bone: int in rotations:
		skeleton.set_bone_pose_rotation(bone, rotations[bone])
	if wrist >= 0:
		var authored := skeleton.get_bone_pose_rotation(wrist)
		skeleton.set_bone_pose_rotation(wrist, authored * Quaternion(Vector3.RIGHT, wrist_tilt))
