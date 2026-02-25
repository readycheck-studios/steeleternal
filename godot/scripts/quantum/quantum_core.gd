# quantum_core.gd
# Quantum Core — the world-shifting device that toggles room geometry between Phase A and B.
# Requires N.O.V.A. within nova_power_radius (power source) AND Jason to complete
# the Synaptic Bypass mini-game. Retogglable: can be hacked repeatedly to shift back.
#
# Group: "hackable" — detected by player_manager's _find_nearby_terminal()
extends Node2D

@export var nova_power_radius: float = 200.0
@export var target_amplitude: float = 0.70
@export var target_frequency: float = 2.50
@export var target_phase: float = 1.00
@export var minigame_scene: PackedScene = null

# Always false — QuantumCore is retogglable, never permanently locked
var is_hacked: bool = false

var current_phase: int = 0
var _hack_difficulty: int = 2  # Base difficulty; reduced by flux_2 upgrade

@onready var visual: Polygon2D = $Visual
@onready var inner_glow: Polygon2D = $InnerGlow
@onready var prompt_label: Label = $PromptLabel
@onready var phase_label: Label = $PhaseLabel

const COLOR_PHASE_A := Color(0.20, 0.40, 1.00, 1.0)
const COLOR_PHASE_B := Color(0.961, 0.620, 0.043, 1.0)
const GLOW_PHASE_A  := Color(0.50, 0.70, 1.00, 0.60)
const GLOW_PHASE_B  := Color(1.00, 0.80, 0.20, 0.60)

var _power_flash_timer: float = 0.0


func _ready() -> void:
	add_to_group("hackable")
	prompt_label.visible = false
	_apply_flux_upgrades()
	_update_visuals()


func _apply_flux_upgrades() -> void:
	var lvl: Dictionary = GameData.upgrade_levels
	# flux_2: reduce hack difficulty by 1 (min 1) — passed to minigame via on_hack_started
	if lvl.get("flux_2", 0) >= 1:
		_hack_difficulty = max(1, _hack_difficulty - 1)
	# flux_3: increase N.O.V.A. power range
	if lvl.get("flux_3", 0) >= 1:
		nova_power_radius += 100.0


func _process(delta: float) -> void:
	if _power_flash_timer > 0.0:
		_power_flash_timer -= delta
		if _power_flash_timer <= 0.0:
			prompt_label.text = "[SPACE]"
			prompt_label.visible = false


func show_prompt(visible_flag: bool) -> void:
	if _power_flash_timer > 0.0:
		return  # Don't interrupt the power-required flash
	prompt_label.text = "[SPACE]"
	prompt_label.visible = visible_flag


func start_hack(jason_node: Node2D) -> void:
	if minigame_scene == null:
		return

	# Check N.O.V.A. is close enough to supply power
	var nova_nodes := get_tree().get_nodes_in_group("nova_tank")
	if nova_nodes.is_empty():
		return
	var nova_node: Node2D = nova_nodes[0]
	if global_position.distance_to(nova_node.global_position) > nova_power_radius:
		_flash_power_required()
		return

	Events.on_hack_started.emit(_hack_difficulty)

	var mg: Node2D = minigame_scene.instantiate()
	jason_node.add_child(mg)
	mg.position = Vector2(0, -88)
	mg.setup(target_amplitude, target_frequency, target_phase, _hack_difficulty)
	mg.hack_succeeded.connect(_on_hack_succeeded)
	mg.hack_cancelled.connect(_on_hack_cancelled)
	mg.firewall_triggered.connect(_on_firewall_triggered)

	prompt_label.visible = false


func cancel() -> void:
	# Called by player_manager if the hack is cancelled externally (e.g. pawn swap).
	# The minigame handles the cancel signal internally; this is a no-op fallback.
	pass


func _on_hack_succeeded() -> void:
	current_phase = 1 - current_phase  # Toggle 0 ↔ 1
	_update_visuals()
	Events.on_world_shifted.emit(current_phase)
	Events.on_screen_shake.emit(0.5)
	Events.on_hack_completed.emit()


func _on_hack_cancelled() -> void:
	Events.on_hack_failed.emit()
	show_prompt(true)


const FIREWALL_ALERT_RADIUS: float = 400.0

func _on_firewall_triggered() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("alert"):
			if global_position.distance_to(enemy.global_position) <= FIREWALL_ALERT_RADIUS:
				enemy.alert()


func _update_visuals() -> void:
	if current_phase == 0:
		visual.color = COLOR_PHASE_A
		inner_glow.color = GLOW_PHASE_A
		phase_label.text = "PHASE A"
	else:
		visual.color = COLOR_PHASE_B
		inner_glow.color = GLOW_PHASE_B
		phase_label.text = "PHASE B"


func _flash_power_required() -> void:
	prompt_label.text = "N.O.V.A. POWER\nREQUIRED"
	prompt_label.visible = true
	_power_flash_timer = 1.5
