# jason_shot.gd
# Jason's ranged energy pistol projectile. Weak but fast — lets him chip at
# enemies he can't reach with the Data-Spike, including vent threats.
#
# Collision Layer: 6 (Projectiles) → value 32
# Collision Mask:  1 (World) | 7 (Enemies) = 65
extends CharacterBody2D

const DAMAGE: float  = 8.0
const SPEED:  float  = 400.0
const LIFETIME: float = 0.5   # ~200 px effective range

var direction: Vector2 = Vector2.RIGHT
var _age: float = 0.0


func _ready() -> void:
	collision_layer = 32  # Layer 6
	collision_mask  = 65  # World(1) + Enemies(64)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return

	velocity = direction * SPEED
	move_and_slide()

	for i in get_slide_collision_count():
		var col      := get_slide_collision(i)
		var collider := col.get_collider()
		if collider == null:
			continue
		if collider.collision_layer & 64 and collider.has_method("take_damage"):
			collider.take_damage(DAMAGE)
			Events.on_screen_shake.emit(0.10)
		queue_free()
		return
