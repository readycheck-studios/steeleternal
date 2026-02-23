# grunt.gd
# Basic enemy — patrols, detects the active pawn, chases, lunges on attack.
# Vulnerable to everything: N.O.V.A. cannon, crush damage, Jason's Data-Spike.
extends EnemyBase

const LUNGE_FORCE: float = 160.0
const LUNGE_COOLDOWN: float = 1.2

var _lunge_timer: float = 0.0


func _on_enemy_ready() -> void:
	max_hp = 30.0
	move_speed = 65.0
	detection_radius = 190.0
	attack_radius = 30.0
	contact_damage = 8.0
	hp = max_hp


func _state_attack(delta: float) -> void:
	_lunge_timer = maxf(_lunge_timer - delta, 0.0)

	if not _has_valid_target() or not _target_in_range(attack_radius * 1.3):
		state = State.CHASE
		return

	# Lunge at target on cooldown
	if _lunge_timer <= 0.0:
		var dir := (target.global_position - global_position).normalized()
		velocity = dir * LUNGE_FORCE
		_lunge_timer = LUNGE_COOLDOWN
	else:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * get_physics_process_delta_time())
