# void_walker.gd
# Void-Walker — a phase-shifting enemy that cycles between intangible and material
# states based on the active Quantum Core phase.
#
# Intangible (default — Phase A): ghostly, semi-transparent, passes through
# projectiles and players. Cannot deal or receive damage.
#
# Material (Phase B): solid, aggressive, chases the active pawn and deals
# contact damage. Vulnerable to N.O.V.A. cannon and Data-Spike.
#
# Tactical loop: park N.O.V.A. near the Core for power, have Jason hack it
# to materialise the Void-Walker, then blast it before it closes in.
#
# Collision Layer: 7 (Enemies) → value 64  (only when material)
# Collision Mask:  1 (World only)          (intangible)
#                  39 (World+NOVA+Jason+Projectiles) (material)
extends "res://scripts/enemies/enemy_base.gd"

@export var tangible_phase: int = 1  # Phase in which this enemy is material (default = Phase B)

const SPEED_MATERIAL:   float = 80.0
const SPEED_INTANGIBLE: float = 38.0
const ALPHA_MATERIAL:   float = 1.00
const ALPHA_INTANGIBLE: float = 0.22  # Barely-there ghost

var _is_material: bool = false


func _on_enemy_ready() -> void:
	max_hp           = 35.0
	move_speed       = SPEED_INTANGIBLE
	detection_radius = 250.0
	attack_radius    = 30.0
	contact_damage   = 12.0
	hp = max_hp
	Events.on_world_shifted.connect(_on_world_shifted)
	_set_phase(0)  # World starts in Phase A — begin intangible


# --- Phase switching ---

func _on_world_shifted(new_phase: int) -> void:
	_set_phase(new_phase)


func _set_phase(phase: int) -> void:
	_is_material = (phase == tangible_phase)

	if _is_material:
		collision_layer = 64   # Layer 7 — projectiles can now hit it
		collision_mask  = 39   # World + N.O.V.A. + Jason + Projectiles
		move_speed      = SPEED_MATERIAL
		modulate        = Color(1.0, 1.0, 1.0, ALPHA_MATERIAL)
		# Resume hunting the active pawn
		if state != State.DEAD and state != State.STUNNED and target != null:
			state = State.CHASE
	else:
		collision_layer = 0    # Nothing can collide with it
		collision_mask  = 1    # Only the world floor keeps it grounded
		move_speed      = SPEED_INTANGIBLE
		modulate        = Color(0.75, 0.55, 1.0, ALPHA_INTANGIBLE)
		target = null
		if state != State.DEAD:
			state = State.PATROL


# Only track the active pawn while material — intangible state ignores all pawns.
func _on_pawn_swapped(active_node: Node2D) -> void:
	if _is_material:
		target = active_node


# --- Damage overrides ---

func take_damage(amount: float) -> void:
	if not _is_material:
		return  # Cannon rounds phase through — no effect
	super.take_damage(amount)
