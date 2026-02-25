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

const SPIKE_COOLDOWN: float = 0.8       # Seconds between Data-Spike uses
const SPIKE_STUN_DURATION: float = 5.0  # How long the target is stunned
const SPIKE_VISUAL_TIME: float = 0.20   # How long the amber flash stays visible
const SPIKE_COLOR := Color(0.961, 0.620, 0.043, 0.80)  # Amber flash

var hp: float = MAX_HP
var is_hacking: bool = false

# Neural Imprint bonuses — set by player_manager._apply_neural_imprints()
var damage_reduction: float        = 0.0  # ghost_1: 0.20
var spike_cooldown_reduction: float = 0.0  # ghost_3: 0.5s off cooldown

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = false
var _facing: float = 1.0         # 1.0 = right, -1.0 = left
var _spike_cooldown: float = 0.0
var _spike_draw_timer: float = 0.0

var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready() -> void:
	collision_layer = 4   # Layer 3
	collision_mask = 81   # World(1) + NeuralVents(16) + Enemies(64)
	visible = false


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
	if _spike_draw_timer > 0.0:
		_spike_draw_timer = maxf(_spike_draw_timer - delta, 0.0)
		queue_redraw()
	if _spike_cooldown <= 0.0 and not is_hacking \
			and Input.is_action_just_pressed("p_attack"):
		_fire_data_spike()


func _fire_data_spike() -> void:
	_spike_cooldown = maxf(SPIKE_COOLDOWN - spike_cooldown_reduction, 0.1)
	_spike_draw_timer = SPIKE_VISUAL_TIME
	queue_redraw()
	Events.on_sfx_play_at.emit("data_spike", global_position)
	# Synchronous shape query — fires instantly, catches enemies already in range
	var params := PhysicsShapeQueryParameters2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 18)
	params.shape = rect
	params.transform = Transform2D(0.0, global_position + Vector2(_facing * 20.0, -6.0))
	params.collision_mask = 64  # Enemies only
	params.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(params):
		var body: Node = hit["collider"]
		if body.has_method("stun"):
			body.stun(SPIKE_STUN_DURATION)
			Events.on_data_spike_hit.emit()
			Events.on_screen_shake.emit(0.25)


func _draw() -> void:
	if _spike_draw_timer <= 0.0:
		return
	# Amber rectangle fades out over SPIKE_VISUAL_TIME — shows exact hit area
	var alpha := _spike_draw_timer / SPIKE_VISUAL_TIME
	var col := Color(SPIKE_COLOR.r, SPIKE_COLOR.g, SPIKE_COLOR.b, SPIKE_COLOR.a * alpha)
	var offset := Vector2(_facing * 20.0, -6.0)
	draw_rect(Rect2(offset - Vector2(12.0, 9.0), Vector2(24.0, 18.0)), col)


# --- Health ---

func take_hit(damage: float) -> void:
	hp = clampf(hp - damage * (1.0 - damage_reduction), 0.0, MAX_HP)
	Events.on_jason_health_changed.emit(hp)
	if hp <= 0.0:
		# Freeze Jason in place so enemies don't keep pushing the corpse.
		set_physics_process(false)
		set_process_unhandled_input(false)
		Events.on_run_ended.emit("jason_died")


func heal(amount: float) -> void:
	hp = clampf(hp + amount, 0.0, MAX_HP)
	Events.on_jason_health_changed.emit(hp)
