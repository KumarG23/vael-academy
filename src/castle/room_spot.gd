class_name RoomSpot
extends Resource
## An interaction spot in a room: an NPC, a notice board, a training dummy.
## Confirming plays `dialogue` (VN overlay) when set; the castle scene emits
## `spot_activated` either way so systems can hook in (6.2a wires functions).

@export var id: String = ""
@export var label: String = ""
@export var x: float = 0.5
@export var dialogue: String = ""
