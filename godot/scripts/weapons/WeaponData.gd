# WeaponData.gd
# Resource defining a weapon's stats. Add new weapons by creating .tres files
# in data/weapons/ via the Godot inspector — no code changes required.
extends Resource
class_name WeaponData

@export var weapon_name: String = ""
@export var damage: float = 10.0
@export var fire_rate: float = 0.3           # Seconds between shots
@export var ammo_type: String = "kinetic"    # "kinetic" | "energy" | "explosive"
@export var projectile_scene: PackedScene
@export var screen_shake_intensity: float = 0.5
@export var is_automatic: bool = false
@export var hardpoint: String = "main"       # "main" | "auxiliary" | "heavy"
