extends SceneTree
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 var view := SubViewport.new()
 view.size = Vector2i(800, 700)
 view.transparent_bg = true
 view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(view)
 var art = load("res://src/ui/illustrated_art.gd").from_directory("res://assets/art/illustrated_pilot/kai")
 for east in [true, false]:
  var actor = load("res://src/ui/illustrated_actor.gd").new()
  view.add_child(actor)
  actor.position = Vector2(200 if east else 560, 660)
  actor.setup(art, Vector2.ZERO, art.source_body_height)
  actor.set_process(false)
  actor.face_right = east
  actor._refresh()
 await process_frame
 await RenderingServer.frame_post_draw
 view.get_texture().get_image().save_png("/tmp/vael-cp2-facing-proof.png")
 print("FACING_PROOF saved")
 quit()
