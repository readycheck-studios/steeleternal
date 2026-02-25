# run_manager.gd
# Autoload — generates the per-run room sequence and handles scene transitions.
# Rooms are shuffled each run with Room_IW_A always anchoring position 0.
extends Node

const HUB_SCENE := "res://scenes/ui/AegisHub.tscn"

const IRON_WASTES_POOL: Array[String] = [
	"res://scenes/levels/Room_IW_A.tscn",
	"res://scenes/levels/Room_IW_B.tscn",
	"res://scenes/levels/Room_IW_C.tscn",
]

var _sequence: Array[String] = []
var _current_index: int = 0


func _ready() -> void:
	_generate_run()


func _generate_run() -> void:
	_sequence = IRON_WASTES_POOL.duplicate()
	_sequence.shuffle()
	# Always start with Room_IW_A as the run-start anchor
	_sequence.erase("res://scenes/levels/Room_IW_A.tscn")
	_sequence.push_front("res://scenes/levels/Room_IW_A.tscn")
	_current_index = 0


func next_room() -> void:
	_current_index += 1
	if _current_index >= _sequence.size():
		# Pool exhausted — reshuffle for endless runs
		_generate_run()
	get_tree().change_scene_to_file(_sequence[_current_index])


func go_to_hub() -> void:
	get_tree().change_scene_to_file(HUB_SCENE)


func restart_run() -> void:
	_generate_run()
	get_tree().change_scene_to_file(_sequence[0])
