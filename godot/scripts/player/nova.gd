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
const CRUSH_SPEED_THRESHOLD: float = 120.0
const PROJECTILE_SPEED: float = 500.0

@export var main_weapon: WeaponData = null
@export var projectile_scene: PackedScene = null

@onready var weapon_hardpoint: Marker2D = $WeaponHardpoint

var stability: float = MAX_STABILITY
var is_stalled: bool = false

var _facing_dir: float = 1.0
var _fire_cooldown: float = 0.0

var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready() -> void:
	collision_layer = 2
	collision_mask = 73  # World(1) + HeavyGates(8) + Enemies(64)
	add_to_group("nova_tank")  # QuantumCore queries this group for proximity power check


func _physics_process(delta: float) -> void:
	if is_stalled:
		return
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	_apply_gravity(delta)
	_handle_movement(delta)
	move_and_slide()
	_check_crush_damage()

	# Auto-fire for automatic weapons
	if main_weapon and main_weapon.is_automatic and Input.is_action_pressed("p_attack"):
		_fire_cannon()


func _unhandled_input(event: InputEvent) -> void:
	if is_stalled:
		return
	if event.is_action_pressed("p_attack"):
		_fire_cannon()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * GRAVITY_MULTIPLIER * delta


func _handle_movement(delta: float) -> void:
	var dir := Input.get_axis("p_move_left", "p_move_right")
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * MOVE_SPEED, ACCELERATION * delta)
		_facing_dir = dir
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	# Mirror hardpoint to the facing side
	weapon_hardpoint.position.x = absf(weapon_hardpoint.position.x) * _facing_dir


func _check_crush_damage() -> void:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_collider() == null:
			continue
		var collider := col.get_collider()
		if collider is CharacterBody2D and (collider.collision_layer & 64):
			if absf(velocity.x) > CRUSH_SPEED_THRESHOLD:
				if collider.has_method("take_damage"):
					collider.take_damage(absf(velocity.x) * 0.15)


# --- Cannon ---

func _fire_cannon() -> void:
	if _fire_cooldown > 0.0 or projectile_scene == null:
		return

	var fire_rate := main_weapon.fire_rate if main_weapon else 0.25
	_fire_cooldown = fire_rate

	# Aim toward mouse cursor
	var mouse_world := get_global_mouse_position()
	var aim_dir := (mouse_world - weapon_hardpoint.global_position).normalized()

	var proj: CharacterBody2D = projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = weapon_hardpoint.global_position

	var dmg := main_weapon.damage if main_weapon else 25.0
	proj.setup(aim_dir, PROJECTILE_SPEED, dmg)

	var shake := main_weapon.screen_shake_intensity if main_weapon else 0.5
	Events.on_screen_shake.emit(shake)
	Events.on_sfx_play_at.emit("cannon_fire", weapon_hardpoint.global_position)


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
