# jason.gd
# Jason — the player pilot pawn. Agile platformer with glass-cannon health.
# Implements coyote time (0.15s) and jump buffering (0.1s) for responsive feel.
#
# Collision Layer: 3 (Jason)  → value 4
# Collision Mask:  1 (World) | 5 (NeuralVents) | 7 (Enemies) = 81
extends CharacterBody2D

const MOVE_SPEED: float = 150.0
const JUMP_VELOCITY: float = -430.0
const GRAVITY_MULTIPLIER: float = 1.0
const COYOTE_TIME: float = 0.15
const JUMP_BUFFER_TIME: float = 0.1
const MAX_HP: float = 30.0

const SPIKE_COOLDOWN: float = 0.8      # Seconds between Data-Spike uses
const SPIKE_ACTIVE_TIME: float = 0.15  # How long the hitbox stays live
const SPIKE_STUN_DURATION: float = 3.0 # How long the target is stunned

var hp: float = MAX_HP
var is_hacking: bool = false

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = false
var _facing: float = 1.0        # 1.0 = right, -1.0 = left
var _spike_cooldown: float = 0.0
var _spike_active: float = 0.0
var _spike_hitbox: Area2D

var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready() -> void:
	collision_layer = 4   # Layer 3
	collision_mask = 81   # World(1) + NeuralVents(16) + Enemies(64)
	visible = false
	_create_spike_hitbox()


func _create_spike_hitbox() -> void:
	_spike_hitbox = Area2D.new()
	_spike_hitbox.collision_layer = 0
	_spike_hitbox.collision_mask = 64  # Enemies only
	_spike_hitbox.monitoring = false
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 18)
	shape_node.shape = rect
	_spike_hitbox.add_child(shape_node)
	add_child(_spike_hitbox)
	_spike_hitbox.body_entered.connect(_on_spike_hit)


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_apply_gravity(delta)
	_handle_movement()
	_handle_jump()
	_handle_data_spike(delta)
	move_and_slide()
	_was_on_floor = is_on_floor()


func _update_timers(delta: float) -> void:
	# Coyote time — brief jump window after walking off a ledge
	if _was_on_floor and not is_on_floor():
		_coyote_timer = COYOTE_TIME
	elif _coyote_timer > 0.0:
		_coyote_timer -= delta

	# Jump buffer — register a jump input slightly before landing
	if Input.is_action_just_pressed("p_jump"):
		_jump_buffer_timer = JUMP_BUFFER_TIME
	elif _jump_buffer_timer > 0.0:
		_jump_buffer_timer -= delta


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * GRAVITY_MULTIPLIER * delta


func _handle_movement() -> void:
	if is_hacking:
		velocity.x = 0.0
		return
	var dir := Input.get_axis("p_move_left", "p_move_right")
	if dir != 0.0:
		_facing = signf(dir)
	velocity.x = dir * MOVE_SPEED


func _handle_jump() -> void:
	if is_hacking:
		return
	var can_jump := is_on_floor() or _coyote_timer > 0.0
	if _jump_buffer_timer > 0.0 and can_jump:
		velocity.y = JUMP_VELOCITY
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0


# --- Data-Spike ---

func _handle_data_spike(delta: float) -> void:
	_spike_cooldown = maxf(_spike_cooldown - delta, 0.0)
	if _spike_active > 0.0:
		_spike_active -= delta
		if _spike_active <= 0.0:
			_spike_hitbox.monitoring = false
		return
	if _spike_cooldown <= 0.0 and not is_hacking \
			and Input.is_action_just_pressed("p_attack"):
		_fire_data_spike()


func _fire_data_spike() -> void:
	# Centre the hitbox 20px in front of Jason at chest height
	_spike_hitbox.position = Vector2(_facing * 20.0, -6.0)
	_spike_hitbox.monitoring = true
	_spike_active = SPIKE_ACTIVE_TIME
	_spike_cooldown = SPIKE_COOLDOWN


func _on_spike_hit(body: Node) -> void:
	if body.has_method("stun"):
		body.stun(SPIKE_STUN_DURATION)
		Events.on_data_spike_hit.emit()
		Events.on_screen_shake.emit(0.25)


# --- Health ---

func take_hit(damage: float) -> void:
	hp = clampf(hp - damage, 0.0, MAX_HP)
	Events.on_jason_health_changed.emit(hp)
	if hp <= 0.0:
		# Freeze Jason in place so enemies don't keep pushing the corpse.
		set_physics_process(false)
		set_process_unhandled_input(false)
		Events.on_run_ended.emit("jason_died")


func heal(amount: float) -> void:
	hp = clampf(hp + amount, 0.0, MAX_HP)
	Events.on_jason_health_changed.emit(hp)
