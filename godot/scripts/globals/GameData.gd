# GameData.gd
# Singleton holding current session state. Handles save/load to user://save_data.json.
# Persistence tiers:
#   Meta-Progression  — permanent, survives death
#   Run-State         — deleted on N.O.V.A. destruction
#   World-State       — per-run, tracks Core phase alignments
extends Node

const SAVE_PATH := "user://save_data.json"

# --- Meta-Progression (Permanent) ---
var unlocked_cores: Array[String] = []
var phase_dust: int = 0
var upgrade_levels: Dictionary = {}  # upgrade_id -> level (int)

# --- Run-State (Deleted on Death) ---
var current_hp_jason: float = 30.0
var current_stability_nova: float = 100.0
var equipped_modules: Array[String] = []
var current_sector: String = "iron_wastes"

# --- World-State (Run-specific) ---
var core_phases: Dictionary = {}  # core_id (String) -> active phase (int)


func _ready() -> void:
	load_meta_progression()
	load_run_state()
	# Keep run-state in sync with live game values via Events
	Events.on_jason_health_changed.connect(func(v: float) -> void: current_hp_jason = v)
	Events.on_tank_stability_changed.connect(func(v: float) -> void: current_stability_nova = v)
	Events.on_world_shifted.connect(_on_world_shifted)
	Events.on_run_ended.connect(_on_run_ended)
	Events.on_pawn_swapped.connect(func(_n: Node2D) -> void: save_run_state())


# --- Signal Handlers ---

func _on_world_shifted(new_phase: int) -> void:
	core_phases["default"] = new_phase
	save_run_state()


func _on_run_ended(_cause: String) -> void:
	# Wipe run data but keep meta-progression, then persist.
	clear_run_state()
	save_run_state()


# --- Save / Load ---

func save_run_state() -> void:
	var data := {
		"meta": {
			"unlocked_cores": unlocked_cores,
			"phase_dust": phase_dust,
			"upgrade_levels": upgrade_levels,
		},
		"run": {
			"hp_jason": current_hp_jason,
			"stability_nova": current_stability_nova,
			"equipped_modules": equipped_modules,
			"current_sector": current_sector,
		},
		"world": {
			"core_phases": core_phases,
		}
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func load_meta_progression() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		return
	if parsed.has("meta"):
		var meta: Dictionary = parsed["meta"]
		unlocked_cores = Array(meta.get("unlocked_cores", []), TYPE_STRING, "", null)
		phase_dust = meta.get("phase_dust", 0)
		upgrade_levels = meta.get("upgrade_levels", {})


func load_run_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		return
	if parsed.has("run"):
		var run: Dictionary = parsed["run"]
		current_hp_jason       = run.get("hp_jason", 30.0)
		current_stability_nova = run.get("stability_nova", 100.0)
		equipped_modules       = Array(run.get("equipped_modules", []), TYPE_STRING, "", null)
		current_sector         = run.get("current_sector", "iron_wastes")
	if parsed.has("world"):
		var world: Dictionary = parsed["world"]
		core_phases = world.get("core_phases", {})


func clear_run_state() -> void:
	current_hp_jason = 30.0
	current_stability_nova = 100.0
	equipped_modules = []
	current_sector = "iron_wastes"
	core_phases = {}
