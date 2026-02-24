# cooling_vent.gd
# Hackable node embedded in the Bulwark's back.
# Jason must approach from behind the Bulwark to access it.
# On a successful Synaptic Bypass, fires vent_hacked → Bulwark loses armor.
extends Node2D

const HACK_AMP:   float = 0.80
const HACK_FREQ:  float = 3.50
const HACK_PHASE: float = 2.10

@export var minigame_scene: PackedScene = null

var is_hacked: bool = false

signal vent_hacked


func _ready() -> void:
	add_to_group("hackable")


func start_hack(jason_node: Node2D) -> void:
	if is_hacked or minigame_scene == null:
		return
	Events.on_hack_started.emit(2)
	var mg: Node2D = minigame_scene.instantiate()
	jason_node.add_child(mg)
	mg.position = Vector2(0, -88)
	mg.setup(HACK_AMP, HACK_FREQ, HACK_PHASE)
	mg.hack_succeeded.connect(_on_hack_succeeded)
	mg.hack_cancelled.connect(_on_hack_cancelled)


func _on_hack_succeeded() -> void:
	is_hacked = true
	Events.on_hack_completed.emit()
	vent_hacked.emit()


func _on_hack_cancelled() -> void:
	Events.on_hack_failed.emit()
