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
 var shin_image: Image=load("res://assets/art/kai_motion_transfer/shin.png").get_image()
 var foot_image: Image=load("res://assets/art/kai_motion_transfer/foot.png").get_image()
 if shin_image.is_compressed(): shin_image.decompress()
 if foot_image.is_compressed(): foot_image.decompress()
 for clip: String in ["Walk","Walk_Formal"]:
  pilot.actor.player.play(clip,0.0)
  var least_overlap:=99999
  var worst: Dictionary={}
  for frame in range(80):
   pilot.actor.player.seek(pilot.actor.player.current_animation_length*frame/80.0,true)
   pilot.actor.player.advance(0.0)
   rig.update_from_motion()
   for part: Dictionary in rig.parts:
    if part["type"]!="leg": continue
    var shin: Sprite2D=part["lower"]
    var foot: Sprite2D=part["foot"]
    var overlap:=0
    for y in range(12,28,2):
     for x in range(40,58,2):
      if foot_image.get_pixel(x,y).a<0.9: continue
      var sample:=shin.to_local(foot.to_global(Vector2(x,y)+foot.offset))-shin.offset
      if Rect2(Vector2.ZERO,shin_image.get_size()).has_point(sample) and shin_image.get_pixelv(Vector2i(sample)).a>0.9: overlap+=1
    if overlap<least_overlap:
     least_overlap=overlap
     worst={"frame":frame,"side":part["bones"][0],"overlap_pixels":overlap}
  print(clip," minimum painted ankle cuff overlap ",worst)
 quit()
