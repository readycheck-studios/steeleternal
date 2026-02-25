# tether_handler.gd
# Monitors proximity between Jason and N.O.V.A. and drives the Neural Tether stress signal.
# Zones:
#   Safe   — < 80% of MAX_TETHER_DISTANCE  → severity 0.0..0.8 (no visible effect)
#   Danger — ≥ 80%                         → severity 0.8..1.0 (glitch intensifies)
#   Severed — severity ≥ 1.0               → Jason takes HP drain each tick
extends Node

const MAX_TETHER_DISTANCE: float = 400.0
const SEVERED_DRAIN_RATE: float = 10.0  # HP per second when severed

# Neural Imprint bonus — set by player_manager._apply_neural_imprints()
var distance_bonus: float = 0.0  # ghost_2: +100px

var _nova: Node2D = null
var _jason: Node2D = null
var _is_tracking: bool = false

@onready var tether_timer: Timer = $TetherTimer


func _ready() -> void:
	tether_timer.wait_time = 0.1
	tether_timer.one_shot = false
	tether_timer.timeout.connect(_check_tether)


func setup(nova: Node2D, jason: Node2D) -> void:
	_nova = nova
	_jason = jason


func start_tracking() -> void:
	_is_tracking = true
	tether_timer.start()


func stop_tracking() -> void:
	_is_tracking = false
	tether_timer.stop()
	Events.on_tether_strained.emit(0.0)


func _check_tether() -> void:
	if not _is_tracking or not _nova or not _jason:
		return

	var dist := _jason.global_position.distance_to(_nova.global_position)
	var severity := clampf(dist / (MAX_TETHER_DISTANCE + distance_bonus), 0.0, 1.0)
	Events.on_tether_strained.emit(severity)

	# Tether severed — drain Jason HP each tick
	if severity >= 1.0:
		var jason_pawn := _jason as CharacterBody2D
		if jason_pawn and jason_pawn.has_method("take_hit"):
			jason_pawn.take_hit(SEVERED_DRAIN_RATE * tether_timer.wait_time)
