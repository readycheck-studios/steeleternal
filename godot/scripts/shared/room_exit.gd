# room_exit.gd
# Area2D placed at the right edge of each room.
# Any body in the nova_tank group or named Jason_Pilot triggers a room transition.
extends Area2D

var _triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if body.is_in_group("nova_tank") or body.name == "Jason_Pilot":
		_triggered = true
		RunManager.next_room()
