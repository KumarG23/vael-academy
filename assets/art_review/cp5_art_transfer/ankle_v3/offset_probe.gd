extends SceneTree
var pilot: Node
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 pilot=(load("res://scenes/proto/kai_art_motion_pilot.tscn") as PackedScene).instantiate()
 root.add_child(pilot)
 pilot.set_process(false)
 pilot.actor.set_process(false)
 pilot.illustration.set_process(false)
 var rig: Node=pilot.illustration
 for clip: String in ["Walk","Walk_Formal"]:
  pilot.actor.player.play(clip,0.0)
  var max_gap:=0.0
  var worst: Dictionary={}
  for frame in range(80):
   pilot.actor.player.seek(pilot.actor.player.current_animation_length*frame/80.0,true)
   pilot.actor.player.advance(0.0)
   rig.update_from_motion()
   for part: Dictionary in rig.parts:
    if part["type"]!="leg": continue
    var shin: Sprite2D=part["lower"]
    var foot: Sprite2D=part["foot"]
    var shaft_end:=shin.to_global(Vector2(64,112)+shin.offset)
    var ankle:=foot.to_global(Vector2(50,19)+foot.offset)
    var gap:=shaft_end.distance_to(ankle)
    if gap>max_gap:
     max_gap=gap
     worst={"frame":frame,"side":part["bones"][0],"shaft_end":shaft_end,"ankle":ankle,"gap_px":gap}
  print(clip," worst ",worst)
 quit()
