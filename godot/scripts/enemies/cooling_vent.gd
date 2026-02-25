# cooling_vent.gd
# Hackable node embedded in the Bulwark's back.
# Jason must approach from behind the Bulwark to access it.
# On a successful Synaptic Bypass, fires vent_hacked → Bulwark loses armor.
extends Node2D

const HACK_AMP:   float = 0.70
const HACK_FREQ:  float = 2.50
const HACK_PHASE: float = 1.00

# Stun refreshed every tick while the hack is active — Bulwark stays frozen
# for the entire hack regardless of how long it takes.
const HACK_COVER_STUN: float = 2.0  # Re-applied every process tick; value just needs to be > 0

@export var minigame_scene: PackedScene = null

var is_hacked: bool = false
var _hacking: bool = false

signal vent_hacked


func _ready() -> void:
	add_to_group("hackable")


func _process(_delta: float) -> void:
	if not _hacking:
		return
	# Continuously refresh the stun so the Bulwark stays frozen for the entire
	# hack — no matter how long it takes, it will not walk off to N.O.V.A.
	var bulwark := get_parent()
	if bulwark.has_method("stun"):
		bulwark.stun(HACK_COVER_STUN)


func start_hack(jason_node: Node2D) -> void:
	if is_hacked or minigame_scene == null:
		return
	_hacking = true
	Events.on_hack_started.emit(2)
	var mg: Node2D = minigame_scene.instantiate()
	jason_node.add_child(mg)
	mg.position = Vector2(0, -88)
	mg.setup(HACK_AMP, HACK_FREQ, HACK_PHASE, 2)
	mg.hack_succeeded.connect(_on_hack_succeeded)
	mg.hack_cancelled.connect(_on_hack_cancelled)
	mg.firewall_triggered.connect(_on_firewall_triggered)


func _on_hack_succeeded() -> void:
	_hacking = false
	is_hacked = true
	Events.on_hack_completed.emit()
	vent_hacked.emit()


func _on_hack_cancelled() -> void:
	_hacking = false
	Events.on_hack_failed.emit()


const FIREWALL_ALERT_RADIUS: float = 400.0

func _on_firewall_triggered() -> void:
	# Alert nearby enemies — the Bulwark itself is stunned, but other enemies in range engage.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == get_parent():
			continue  # Don't un-stun the Bulwark being hacked
		if enemy.has_method("alert"):
			if global_position.distance_to(enemy.global_position) <= FIREWALL_ALERT_RADIUS:
				enemy.alert()
