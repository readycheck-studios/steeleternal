# player_manager.gd
# Central manager for the player system.
# Controls pawn swapping between N.O.V.A. and Jason, routes the camera,
# and coordinates the Neural Tether. This node is always active regardless of active pawn.
extends Node2D

@onready var nova: CharacterBody2D = $NOVA_Tank
@onready var jason: CharacterBody2D = $Jason_Pilot
@onready var camera_manager: Camera2D = $CameraManager
@onready var tether_handler: Node = $NeuralTetherLogic

enum Pawn { NOVA, JASON }

var active_pawn: Pawn = Pawn.NOVA
var _run_over: bool = false

# Jason must be within this radius of N.O.V.A. to remount or restart her.
const MOUNT_RADIUS: float = 48.0


func _ready() -> void:
	tether_handler.setup(nova, jason)
	_activate_pawn(Pawn.NOVA)
	Events.on_tank_stalled.connect(_on_tank_stalled)
	Events.on_run_ended.connect(_on_run_ended)
	# Deferred so all enemy _ready() calls finish connecting before this fires.
	call_deferred("_emit_initial_pawn")


func _emit_initial_pawn() -> void:
	Events.on_pawn_swapped.emit(nova)


func _process(_delta: float) -> void:
	# Keep camera snapped to active pawn each frame.
	# Camera2D's position_smoothing handles the lerped follow effect.
	camera_manager.global_position = _get_pawn_node(active_pawn).global_position


func _unhandled_input(event: InputEvent) -> void:
	if _run_over:
		return
	if event.is_action_pressed("p_interact"):
		_try_swap_pawn()


# --- Pawn Swap ---

func _try_swap_pawn() -> void:
	match active_pawn:
		Pawn.NOVA:
			# Disembark: always allowed
			_swap_to(Pawn.JASON)
		Pawn.JASON:
			if jason.global_position.distance_to(nova.global_position) <= MOUNT_RADIUS:
				if nova.is_stalled:
					# Simplified restart — Quick-Fix rhythm mini-game comes later.
					_emergency_restart_nova()
				else:
					_swap_to(Pawn.NOVA)


func _swap_to(target: Pawn) -> void:
	# Disable current pawn
	var current_node := _get_pawn_node(active_pawn)
	current_node.set_physics_process(false)
	current_node.set_process_unhandled_input(false)

	# Enable target pawn
	var target_node := _get_pawn_node(target)
	target_node.set_physics_process(true)
	target_node.set_process_unhandled_input(true)

	# Tether and spawn logic
	if target == Pawn.JASON:
		# Spawn Jason just above the hatch
		jason.global_position = nova.global_position + Vector2(0, -28)
		jason.visible = true
		tether_handler.start_tracking()
	else:
		jason.visible = false
		tether_handler.stop_tracking()

	active_pawn = target
	Events.on_pawn_swapped.emit(target_node)


func _activate_pawn(pawn: Pawn) -> void:
	nova.set_physics_process(pawn == Pawn.NOVA)
	nova.set_process_unhandled_input(pawn == Pawn.NOVA)
	jason.set_physics_process(pawn == Pawn.JASON)
	jason.set_process_unhandled_input(pawn == Pawn.JASON)
	jason.visible = (pawn == Pawn.JASON)


func _emergency_restart_nova() -> void:
	# Restores 50 stability and re-enables N.O.V.A.
	# The real Quick-Fix rhythm mini-game will replace this later.
	nova.restore_stability(50.0)
	_swap_to(Pawn.NOVA)


# --- Event Handlers ---

func _on_tank_stalled() -> void:
	# Auto-eject Jason so the player can navigate back to restart N.O.V.A.
	if active_pawn == Pawn.NOVA:
		_swap_to(Pawn.JASON)


func _on_run_ended(_cause: String) -> void:
	_run_over = true
	# Reload the scene after the HUD has had time to show the failure message.
	await get_tree().create_timer(2.5).timeout
	get_tree().reload_current_scene()


func _get_pawn_node(pawn: Pawn) -> CharacterBody2D:
	return nova if pawn == Pawn.NOVA else jason
