# projectile.gd
# A single fired projectile. Travels in a straight line, deals damage on
# enemy contact, and despawns on world contact or lifetime expiry.
#
# Collision Layer: 6 (Projectiles) → value 32
# Collision Mask:  1 (World) | 7 (Enemies) = 65
extends CharacterBody2D

var damage: float = 25.0
var speed: float = 500.0
var direction: Vector2 = Vector2.RIGHT
var lifetime: float = 2.0

var _age: float = 0.0


func _ready() -> void:
	collision_layer = 32  # Layer 6
	collision_mask = 65   # World(1) + Enemies(64)


func setup(dir: Vector2, spd: float, dmg: float) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	# Rotate visual to match travel direction
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	velocity = direction * speed
	move_and_slide()

	# Check for hits after move
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider == null:
			continue
		# Damage enemies
		if collider.collision_layer & 64 and collider.has_method("take_damage"):
			collider.take_damage(damage)
		queue_free()
		return
