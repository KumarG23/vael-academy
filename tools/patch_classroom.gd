extends SceneTree
## AW-54: add the "Attend the lesson" point (fn_class) to the classroom, beside
## Professor Callan's lectern. Idempotent — re-running won't stack points.

func _initialize() -> void:
	var p := "res://data/castle_v2/classroom.tres"
	var rm: CastleRoomDef = load(p)
	for pt: CastlePoint in rm.points:
		if pt.id == "fn_class":
			print("classroom already has fn_class")
			quit()
			return
	var pt := CastlePoint.new()
	pt.id = "fn_class"
	pt.label = "Attend the lesson"
	pt.cell = Vector2i(12, 3)  # beside Callan (9,3), on open floor
	rm.points.append(pt)
	print("classroom patched err=%d points=%d" % [ResourceSaver.save(rm, p), rm.points.size()])
	quit()
