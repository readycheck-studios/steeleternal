# enemy_base.gd
# Base class for all enemies. Provides shared state machine, health, gravity,
# contact damage with cooldown, and target tracking via the Events bus.
#
# Collision Layer: 7 (Enemies) → value 64
# Collision Mask:  1 (World) | 2 (NOVA) | 3 (Jason) | 6 (Projectiles) = 39
extends CharacterBody2D
class_name EnemyBase

enum State { IDLE, PATROL, CHASE, ATTACK, STUNNED, DEAD }

@export var max_hp: float = 30.0
@export var move_speed: float = 60.0
@export var detection_radius: float = 200.0
@export var attack_radius: float = 32.0
@export var contact_damage: float = 8.0

var hp: float
var state: State = State.IDLE
var target: Node2D = null
var patrol_direction: float = 1.0

const PATROL_FLIP_TIME: float = 2.0
const CONTACT_DAMAGE_INTERVAL: float = 0.5
const GRAVITY_MULT: float = 1.0
const STUN_TINT := Color(0.35, 0.70, 1.0, 1.0)  # Blue-white when stunned

var _patrol_timer: float = 0.0
var _contact_timer: float = 0.0
var _stun_timer: float = 0.0
var _pre_stun_state: State = State.PATROL
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready() -> void:
	collision_layer = 64   # Layer 7
	collision_mask = 39    # World(1) + NOVA(2) + Jason(4) + Projectiles(32)
	hp = max_hp
	Events.on_pawn_swapped.connect(_on_pawn_swapped)
	_on_enemy_ready()


# Override in subclasses for type-specific setup.
func _on_enemy_ready() -> void:
	pass


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_apply_gravity(delta)
	_contact_timer = maxf(_contact_timer - delta, 0.0)
	_tick_state(delta)
	move_and_slide()
	_check_contact_damage()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * GRAVITY_MULT * delta


# --- State Helpers ---

func _is_combat_state(s: State) -> bool:
	return s == State.CHASE or s == State.ATTACK


# Central state setter — emits aggro/deaggro signals when crossing combat boundary.
func _transition_state(new_state: State) -> void:
	var was_combat := _is_combat_state(state)
	var will_combat := _is_combat_state(new_state)
	state = new_state
	if not was_combat and will_combat:
		Events.on_enemy_aggro.emit()
	elif was_combat and not will_combat:
		Events.on_enemy_deaggro.emit()


# --- State Machine ---

func _tick_state(delta: float) -> void:
	match state:
		State.IDLE:    _state_idle(delta)
		State.PATROL:  _state_patrol(delta)
		State.CHASE:   _state_chase(delta)
		State.ATTACK:  _state_attack(delta)
		State.STUNNED: _state_stunned(delta)


func _state_stunned(delta: float) -> void:
	velocity.x = 0.0
	_stun_timer = maxf(_stun_timer - delta, 0.0)
	if _stun_timer <= 0.0:
		modulate = Color.WHITE
		_transition_state(_pre_stun_state)


func _state_idle(_delta: float) -> void:
	velocity.x = 0.0
	_transition_state(State.PATROL)


func _state_patrol(delta: float) -> void:
	if _target_in_range(detection_radius):
		_transition_state(State.CHASE)
		return
	velocity.x = patrol_direction * move_speed
	_patrol_timer += delta
	if _patrol_timer >= PATROL_FLIP_TIME or is_on_wall():
		_patrol_timer = 0.0
		patrol_direction *= -1.0


func _state_chase(_delta: float) -> void:
	if not _has_valid_target():
		_transition_state(State.PATROL)
		return
	if not _target_in_range(detection_radius * 1.5):
		_transition_state(State.PATROL)
		return
	if _target_in_range(attack_radius):
		_transition_state(State.ATTACK)
		return
	var dir := signf(target.global_position.x - global_position.x)
	velocity.x = dir * move_speed


func _state_attack(_delta: float) -> void:
	velocity.x = 0.0
	if not _has_valid_target() or not _target_in_range(attack_radius * 1.3):
		_transition_state(State.CHASE)


# --- Damage ---

func _check_contact_damage() -> void:
	if state == State.STUNNED:
		return  # Stunned enemies are temporarily harmless to touch
	if _contact_timer > 0.0:
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider == null:
			continue
		var layer: int = collider.collision_layer
		if (layer & 2 or layer & 4) and collider.has_method("take_hit"):
			collider.take_hit(contact_damage)
			_contact_timer = CONTACT_DAMAGE_INTERVAL
			break


func stun(duration: float) -> void:
	if state == State.DEAD:
		return
	# Allow refreshing an active stun — only save pre_stun_state on first entry
	# so we always return to the correct state when it expires.
	if state != State.STUNNED:
		_pre_stun_state = state
	_stun_timer = duration
	_transition_state(State.STUNNED)
	velocity.x = 0.0
	modulate = STUN_TINT


func take_damage(amount: float) -> void:
	if state == State.DEAD:
		return
	hp = clampf(hp - amount, 0.0, max_hp)
	if state != State.CHASE and state != State.ATTACK:
		_transition_state(State.CHASE)  # Aggro on hit
	if hp <= 0.0:
		_die()


func _die() -> void:
	_transition_state(State.DEAD)
	velocity = Vector2.ZERO
	set_physics_process(false)
	Events.on_enemy_died.emit(global_position)
	queue_free()


# --- Helpers ---

func _has_valid_target() -> bool:
	return target != null and is_instance_valid(target)


func _target_in_range(radius: float) -> bool:
	if not _has_valid_target():
		return false
	return global_position.distance_to(target.global_position) <= radius


func _on_pawn_swapped(active_node: Node2D) -> void:
	target = active_node
