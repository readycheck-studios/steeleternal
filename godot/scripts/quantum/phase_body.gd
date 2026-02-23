# phase_body.gd
# A StaticBody2D that activates or deactivates based on the current world phase.
# Set active_phase = 0 for Phase A geometry (default state),
#     active_phase = 1 for Phase B geometry (appears after first Core shift).
# Listens to Events.on_world_shifted to toggle visibility and collision.
extends StaticBody2D

@export var active_phase: int = 0


func _ready() -> void:
	Events.on_world_shifted.connect(_on_world_shifted)
	_apply_phase(0)


func _on_world_shifted(new_phase: int) -> void:
	_apply_phase(new_phase)


func _apply_phase(phase: int) -> void:
	var active := (phase == active_phase)
	visible = active
	collision_layer = 1 if active else 0
