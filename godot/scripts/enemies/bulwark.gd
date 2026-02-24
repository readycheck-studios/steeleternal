# bulwark.gd
# Bulwark — slow, heavily armoured enemy immune to N.O.V.A.'s cannon while intact.
# Tactical loop:
#   1. Stun with Jason's Data-Spike to freeze it.
#   2. Flank to its back and hack the CoolingVent (harder waveform — difficulty 2).
#   3. Armour drops → remount N.O.V.A. and destroy it with the cannon.
#
# Collision Layer: 7 (Enemies) → value 64
# Collision Mask:  1 (World) | 2 (N.O.V.A.) | 3 (Jason) | 6 (Projectiles) = 39
extends "res://scripts/enemies/enemy_base.gd"

const ARMORED_COLOR    := Color(0.22, 0.22, 0.28, 1.0)  # Dark iron
const VULNERABLE_COLOR := Color(0.75, 0.15, 0.15, 1.0)  # Red — exposed

var _is_armored: bool = true
var _facing: float = 1.0  # 1.0 = right, -1.0 = left

@onready var body_sprite:  Polygon2D = $BodySprite
@onready var shield_front: Polygon2D = $ShieldFront
@onready var vent:         Node2D    = $CoolingVent


func _on_enemy_ready() -> void:
	max_hp           = 80.0
	move_speed       = 35.0
	detection_radius = 240.0
	attack_radius    = 48.0
	contact_damage   = 15.0
	hp = max_hp
	vent.vent_hacked.connect(_on_vent_hacked)


# Bulwark always faces N.O.V.A. — never Jason.
# This keeps the back exposed so Jason can flank and hack the vent.
func _on_pawn_swapped(_active_node: Node2D) -> void:
	var nova_nodes := get_tree().get_nodes_in_group("nova_tank")
	if not nova_nodes.is_empty():
		target = nova_nodes[0]


# --- Armour ---

func take_damage(amount: float) -> void:
	if _is_armored:
		return  # Cannon rounds deflected while armoured
	super.take_damage(amount)


func _on_vent_hacked() -> void:
	_is_armored = false
	body_sprite.color  = VULNERABLE_COLOR
	shield_front.visible = false
	if state != State.DEAD:
		state = State.CHASE  # Re-aggro now that it's exposed


# --- Contact damage — front face only, back is a safe zone for hacking ---

func _check_contact_damage() -> void:
	if state == State.STUNNED or _contact_timer > 0.0:
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider == null:
			continue
		var layer: int = collider.collision_layer
		if (layer & 2 or layer & 4) and collider.has_method("take_hit"):
			# Only deal damage if the collider is on the front (shield) side.
			# Behind the Bulwark is safe — that's where Jason needs to be.
			var side := signf(collider.global_position.x - global_position.x)
			if side == _facing or side == 0.0:
				collider.take_hit(contact_damage)
				_contact_timer = CONTACT_DAMAGE_INTERVAL
				break


# --- Attack override — slow relentless push instead of a lunge ---

func _state_attack(_delta: float) -> void:
	if not _has_valid_target() or not _target_in_range(attack_radius * 1.5):
		state = State.CHASE
		return
	# Grind slowly into the target — contact damage does the work
	var dir := signf(target.global_position.x - global_position.x)
	velocity.x = dir * move_speed * 0.6


# --- Dynamic shield / vent positioning ---

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_facing_visuals()


func _update_facing_visuals() -> void:
	if state == State.DEAD:
		return
	if _has_valid_target():
		var dir := signf(target.global_position.x - global_position.x)
		if dir != 0.0:
			_facing = dir
	# Shield always on the front face; vent always on the back
	shield_front.position.x = _facing * 14.0
	vent.position.x         = -_facing * 20.0
