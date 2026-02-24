# neural_parasite.gd
# Neural Parasite — a fast predator that exclusively hunts Jason (the pilot).
# Ignores N.O.V.A. entirely. Drops target when Jason boards; immediately
# aggros when Jason disembarks. Leaps diagonally so it can reach platforms.
#
# Tactical response: Data-Spike to stun, N.O.V.A. cannon to kill,
# or remount N.O.V.A. to make it go passive.
#
# Collision Layer: 7 (Enemies) → value 64
# Collision Mask:  1 (World) | 2 (N.O.V.A.) | 3 (Jason) | 6 (Projectiles) = 39
extends "res://scripts/enemies/enemy_base.gd"

const LEAP_FORCE: float    = 220.0
const LEAP_COOLDOWN: float = 0.90


var _leap_timer: float = 0.0


func _on_enemy_ready() -> void:
	max_hp           = 18.0
	move_speed       = 100.0
	detection_radius = 220.0
	attack_radius    = 28.0
	contact_damage   = 10.0
	hp = max_hp


# Only tracks Jason — completely ignores N.O.V.A.
func _on_pawn_swapped(active_node: Node2D) -> void:
	if active_node.is_in_group("nova_tank"):
		target = null          # Tank is active — lose interest, go back to patrol
	else:
		target = active_node
		if state != State.DEAD and state != State.STUNNED:
			state = State.CHASE    # Instantly aggro the moment Jason disembarks


func _state_attack(delta: float) -> void:
	_leap_timer = maxf(_leap_timer - delta, 0.0)

	if not _has_valid_target() or not _target_in_range(attack_radius * 1.3):
		state = State.CHASE
		return

	# Diagonal leap directly toward Jason — reaches platforms, not just floor targets.
	if _leap_timer <= 0.0:
		var dir := (target.global_position - global_position).normalized()
		velocity = dir * LEAP_FORCE
		_leap_timer = LEAP_COOLDOWN
