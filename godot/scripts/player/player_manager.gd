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
var _is_hacking: bool = false
var _shake_intensity: float = 0.0

const SHAKE_DECAY: float = 10.0
const SHAKE_PIXELS: float = 8.0  # Max pixel offset at intensity 1.0

# Jason must be within this radius of N.O.V.A. to remount or restart her.
const MOUNT_RADIUS: float = 48.0
const REGEN_RATE_PCT: float = 0.10  # 10% of MAX_HP restored per second while boarded

var _regen_timer: float = 0.0


func _ready() -> void:
	tether_handler.setup(nova, jason)
	_activate_pawn(Pawn.NOVA)
	_restore_from_save()
	Events.on_tank_stalled.connect(_on_tank_stalled)
	Events.on_run_ended.connect(_on_run_ended)
	Events.on_screen_shake.connect(_on_screen_shake)
	Events.on_hack_started.connect(func(_d): _is_hacking = true; jason.is_hacking = true)
	Events.on_hack_completed.connect(func(): _is_hacking = false; jason.is_hacking = false)
	Events.on_hack_failed.connect(func(): _is_hacking = false; jason.is_hacking = false)
	# Deferred so all enemy _ready() calls finish connecting before this fires.
	call_deferred("_emit_initial_pawn")


func _restore_from_save() -> void:
	# Restore HP and stability from the last saved run state.
	nova.stability = GameData.current_stability_nova
	Events.on_tank_stability_changed.emit(nova.stability)
	jason.hp = GameData.current_hp_jason
	Events.on_jason_health_changed.emit(jason.hp)


func _emit_initial_pawn() -> void:
	Events.on_pawn_swapped.emit(nova)


func _process(delta: float) -> void:
	camera_manager.global_position = _get_pawn_node(active_pawn).global_position
	_update_screen_shake(delta)
	if active_pawn == Pawn.NOVA:
		_regen_timer += delta
		if _regen_timer >= 1.0:
			_regen_timer -= 1.0
			jason.heal(jason.MAX_HP * REGEN_RATE_PCT)


func _update_screen_shake(delta: float) -> void:
	if _shake_intensity > 0.0:
		camera_manager.offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
		_shake_intensity = lerpf(_shake_intensity, 0.0, SHAKE_DECAY * delta)
	else:
		camera_manager.offset = Vector2.ZERO


func _on_screen_shake(intensity: float) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity * SHAKE_PIXELS)


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
			# Cancel active hack
			if _is_hacking:
				var mg := jason.get_node_or_null("HackingMinigame")
				if mg and mg.has_method("cancel"):
					mg.cancel()
				return
			# Remount / restart N.O.V.A. — checked first so the tank always takes priority
			# over any nearby hackable that might overlap with N.O.V.A.'s position.
			if jason.global_position.distance_to(nova.global_position) <= MOUNT_RADIUS:
				if nova.is_stalled:
					_emergency_restart_nova()
				else:
					_swap_to(Pawn.NOVA)
				return
			# Start hack if near a terminal (only when not adjacent to N.O.V.A.)
			var terminal := _find_nearby_terminal()
			if terminal:
				terminal.start_hack(jason)


func _find_nearby_terminal() -> Node:
	const TERMINAL_RADIUS: float = 40.0
	for terminal in get_tree().get_nodes_in_group("hackable"):
		if not terminal.is_hacked and \
		   jason.global_position.distance_to(terminal.global_position) <= TERMINAL_RADIUS:
			return terminal
	return null


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
		# Re-enable collision before spawning so Jason is tangible immediately
		jason.get_node("CollisionShape2D").disabled = false
		jason.global_position = nova.global_position + Vector2(0, -28)
		jason.visible = true
		tether_handler.start_tracking()
	else:
		# Disable collision so enemies can't hit Jason's invisible body while boarded
		jason.get_node("CollisionShape2D").disabled = true
		_regen_timer = 0.0
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
	jason.get_node("CollisionShape2D").disabled = (pawn == Pawn.NOVA)


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
