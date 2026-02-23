# player_manager.gd
# Central manager for the player system.
# Controls pawn swapping between N.O.V.A. and Jason, routes the camera,
# and coordinates the Neural Tether. This node is always active regardless of active pawn.
extends Node2D

@onready var nova: CharacterBody2D = $NOVA_Tank
@onready var jason: CharacterBody2D = $Jason_Pilot
@onready var camera_manager: Camera2D = $CameraManager
@onready var tether_handler: Node = $NeuralTetherLogic
@onready var remote_transform: RemoteTransform2D = $CameraManager/RemoteTransform2D

enum Pawn { NOVA, JASON }

var active_pawn: Pawn = Pawn.NOVA

# Jason must be within this radius of N.O.V.A. to remount.
const MOUNT_RADIUS: float = 48.0


func _ready() -> void:
	tether_handler.setup(nova, jason)
	_activate_pawn(Pawn.NOVA)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("p_interact"):
		_try_swap_pawn()


# --- Pawn Swap ---

func _try_swap_pawn() -> void:
	match active_pawn:
		Pawn.NOVA:
			# Disembark: always allowed
			_swap_to(Pawn.JASON)
		Pawn.JASON:
			# Remount: only if Jason is close enough
			if jason.global_position.distance_to(nova.global_position) <= MOUNT_RADIUS:
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

	# Redirect camera
	remote_transform.remote_path = target_node.get_path()

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
	remote_transform.remote_path = _get_pawn_node(pawn).get_path()


func _get_pawn_node(pawn: Pawn) -> CharacterBody2D:
	return nova if pawn == Pawn.NOVA else jason
