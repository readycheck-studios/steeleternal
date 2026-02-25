# hacking_terminal.gd
# An in-world terminal Jason can hack. Starts the Synaptic Bypass mini-game.
# Add to group "hackable" so player_manager can detect it via scene tree query.
extends Node2D

@export var difficulty: int = 1
@export var target_amplitude: float = 0.70
@export var target_frequency: float = 2.50
@export var target_phase: float = 1.00
@export var minigame_scene: PackedScene = null

var is_hacked: bool = false
var _hacking_jason: Node2D = null

const FIREWALL_DAMAGE: float = 6.0

@onready var visual: Polygon2D = $Visual
@onready var prompt_label: Label = $PromptLabel

const HACKED_COLOR   := Color(0.20, 1.00, 0.40, 1.0)
const UNHACKED_COLOR := Color(0.38, 0.10, 0.80, 1.0)


func _ready() -> void:
	add_to_group("hackable")
	prompt_label.visible = false


func show_prompt(visible_flag: bool) -> void:
	prompt_label.visible = visible_flag and not is_hacked


func start_hack(jason_node: Node2D) -> void:
	if is_hacked or minigame_scene == null:
		return

	_hacking_jason = jason_node
	Events.on_hack_started.emit(difficulty)

	var mg: Node2D = minigame_scene.instantiate()
	jason_node.add_child(mg)
	mg.position = Vector2(0, -88)
	mg.setup(target_amplitude, target_frequency, target_phase, difficulty)
	mg.hack_succeeded.connect(_on_hack_succeeded)
	mg.hack_cancelled.connect(_on_hack_cancelled)
	mg.firewall_triggered.connect(_on_firewall_triggered)

	prompt_label.visible = false


func _on_hack_succeeded() -> void:
	is_hacked = true
	visual.color = HACKED_COLOR
	Events.on_hack_completed.emit()
	# TODO: trigger whatever this terminal unlocks (door, Quantum Core, etc.)


func _on_hack_cancelled() -> void:
	Events.on_hack_failed.emit()
	show_prompt(true)


const FIREWALL_ALERT_RADIUS: float = 400.0

func _on_firewall_triggered() -> void:
	if is_instance_valid(_hacking_jason) and _hacking_jason.has_method("take_hit"):
		_hacking_jason.take_hit(FIREWALL_DAMAGE)
	Events.on_screen_shake.emit(0.35)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("alert"):
			if global_position.distance_to(enemy.global_position) <= FIREWALL_ALERT_RADIUS:
				enemy.alert()
