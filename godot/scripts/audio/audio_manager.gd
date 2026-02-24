# audio_manager.gd
# Central audio system. Listens to Events signals and plays the appropriate
# sounds. Positional sounds are spawned as temporary AudioStreamPlayer2D nodes
# at the world position of the source. UI / global sounds use persistent players.
#
# Drop .ogg files into godot/assets/audio/sfx/ with these exact names:
#   cannon_fire.ogg       — N.O.V.A. fires the kinetic cannon
#   cannon_impact.ogg     — projectile hits an enemy or wall
#   data_spike.ogg        — Jason's Data-Spike melee stun
#   tether_strain_loop.ogg — looping danger tone (modulated by tether severity)
#   hack_success.ogg      — Synaptic Bypass completed
#   phase_shift.ogg       — Quantum Core world shift
#   tank_stalled.ogg      — N.O.V.A. Stability hits zero
#
# All sounds are optional — missing files are skipped silently.
extends Node

const SFX_PATH := "res://assets/audio/sfx/"

const TETHER_DANGER_THRESHOLD: float = 0.80  # Mirrors hud.gd

# Loaded streams (null if file not present yet)
var _sfx: Dictionary = {}

# Persistent non-positional players
var _player_ui:    AudioStreamPlayer
var _player_ui2:   AudioStreamPlayer
var _tether_loop:  AudioStreamPlayer


func _ready() -> void:
	_build_players()
	_load_streams()
	_connect_signals()


func _build_players() -> void:
	_player_ui   = AudioStreamPlayer.new()
	_player_ui2  = AudioStreamPlayer.new()
	_tether_loop = AudioStreamPlayer.new()
	add_child(_player_ui)
	add_child(_player_ui2)
	add_child(_tether_loop)
	# Manual loop: restart as soon as the clip ends
	_tether_loop.finished.connect(_tether_loop.play)


func _load_streams() -> void:
	var names := [
		"cannon_fire", "cannon_impact", "data_spike",
		"tether_strain_loop", "hack_success", "phase_shift", "tank_stalled",
	]
	for sfx_name: String in names:
		var path := SFX_PATH + sfx_name + ".ogg"
		_sfx[sfx_name] = load(path) if ResourceLoader.exists(path) else null


func _connect_signals() -> void:
	Events.on_sfx_play_at.connect(_on_sfx_play_at)
	Events.on_hack_completed.connect(func(): _play_ui(_player_ui, "hack_success"))
	Events.on_world_shifted.connect(func(_p): _play_ui(_player_ui2, "phase_shift"))
	Events.on_tank_stalled.connect(func(): _play_ui(_player_ui2, "tank_stalled"))
	Events.on_tether_strained.connect(_on_tether_strained)
	Events.on_pawn_swapped.connect(_on_pawn_swapped)


# --- Positional sounds ---

func _on_sfx_play_at(sfx_key: String, world_pos: Vector2) -> void:
	var stream: AudioStream = _sfx.get(sfx_key, null)
	if stream == null:
		return
	var p := AudioStreamPlayer2D.new()
	get_tree().current_scene.add_child(p)
	p.stream = stream
	p.global_position = world_pos
	p.play()
	p.finished.connect(p.queue_free)


# --- Tether strain loop ---

func _on_tether_strained(severity: float) -> void:
	var stream: AudioStream = _sfx.get("tether_strain_loop", null)
	if stream == null:
		return

	var in_danger := severity >= TETHER_DANGER_THRESHOLD
	if in_danger and not _tether_loop.playing:
		_tether_loop.stream = stream
		_tether_loop.play()
	elif not in_danger and _tether_loop.playing:
		_tether_loop.stop()

	if _tether_loop.playing:
		# Volume: -18 dB at threshold, 0 dB at full severity
		var t := clampf((severity - TETHER_DANGER_THRESHOLD) / (1.0 - TETHER_DANGER_THRESHOLD), 0.0, 1.0)
		_tether_loop.volume_db  = lerpf(-18.0, 0.0, t)
		_tether_loop.pitch_scale = lerpf(0.88, 1.12, t)


func _on_pawn_swapped(_node: Node2D) -> void:
	_tether_loop.stop()  # Clear on any pawn swap — tether_handler restarts tracking


# --- Helpers ---

func _play_ui(player: AudioStreamPlayer, sfx_key: String) -> void:
	var stream: AudioStream = _sfx.get(sfx_key, null)
	if stream == null:
		return
	player.stream = stream
	player.play()
