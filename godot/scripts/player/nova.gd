# nova.gd
# N.O.V.A. (Neural Operations Versatile Armature) — the player tank pawn.
# Momentum-based movement, 1.5x gravity, Stability meter (not HP).
# Zero Stability triggers Stalled state — Jason must perform a manual restart.
#
# Collision Layer: 2 (NOVA)
# Collision Mask:  1 (World) | 4 (HeavyGates) | 7 (Enemies) = 73
extends CharacterBody2D

const MOVE_SPEED: float = 180.0
const ACCELERATION: float = 600.0
const FRICTION: float = 800.0
const GRAVITY_MULTIPLIER: float = 1.5
const MAX_STABILITY: float = 100.0
const CRUSH_SPEED_THRESHOLD: float = 120.0  # Min horizontal speed for crush damage

var stability: float = MAX_STABILITY
var is_stalled: bool = false

var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready() -> void:
	collision_layer = 2
	collision_mask = 73  # World(1) + HeavyGates(8) + Enemies(64)


func _physics_process(delta: float) -> void:
	if is_stalled:
		return
	_apply_gravity(delta)
	_handle_movement(delta)
	move_and_slide()
	_check_crush_damage()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * GRAVITY_MULTIPLIER * delta


func _handle_movement(delta: float) -> void:
	var dir := Input.get_axis("p_move_left", "p_move_right")
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * MOVE_SPEED, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)


func _check_crush_damage() -> void:
	# High-speed collision with an enemy layer body deals crush damage.
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_collider() == null:
			continue
		var collider := col.get_collider()
		if collider is CharacterBody2D and (collider.collision_layer & 64):
			if absf(velocity.x) > CRUSH_SPEED_THRESHOLD:
				# TODO: route damage to enemy via Events once enemy system is built
				pass


# --- Stability ---

func take_hit(damage: float) -> void:
	if is_stalled:
		return
	stability = clampf(stability - damage, 0.0, MAX_STABILITY)
	Events.on_tank_stability_changed.emit(stability)
	if stability <= 0.0:
		_enter_stalled()


func restore_stability(amount: float) -> void:
	stability = clampf(stability + amount, 0.0, MAX_STABILITY)
	if is_stalled and stability > 0.0:
		is_stalled = false
	Events.on_tank_stability_changed.emit(stability)


func _enter_stalled() -> void:
	is_stalled = true
	velocity = Vector2.ZERO
	Events.on_tank_stalled.emit()
