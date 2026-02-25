# settings_manager.gd
# Loads, saves, and applies player preferences (volume, display).
# Persists to user://settings.json between sessions.
# Apply is called once on startup and again whenever the player changes a setting.
extends Node

const SAVE_PATH := "user://settings.json"
const BASE_SIZE  := Vector2i(640, 360)

var master_volume_db: float = 0.0
var fullscreen: bool        = false
var window_scale: int       = 2


func _ready() -> void:
	load_settings()
	apply()


func apply() -> void:
	# Volume — Master bus (index 0 is always Master in Godot)
	AudioServer.set_bus_volume_db(0, master_volume_db)

	# Display mode
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var target := BASE_SIZE * window_scale
		DisplayServer.window_set_size(target)
		# Re-centre on screen after resize
		var screen := DisplayServer.screen_get_size()
		var win    := DisplayServer.window_get_size()
		DisplayServer.window_set_position((screen - win) / 2)


func save_settings() -> void:
	var data := {
		"master_volume_db": master_volume_db,
		"fullscreen":       fullscreen,
		"window_scale":     window_scale,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var result := JSON.parse_string(f.get_as_text())
	if not result is Dictionary:
		return
	master_volume_db = float(result.get("master_volume_db", 0.0))
	fullscreen       = bool(result.get("fullscreen",       false))
	window_scale     = int(result.get("window_scale",      2))
	# Clamp to valid ranges in case the file was hand-edited
	master_volume_db = clampf(master_volume_db, -40.0, 0.0)
	window_scale     = clampi(window_scale, 2, 3)
