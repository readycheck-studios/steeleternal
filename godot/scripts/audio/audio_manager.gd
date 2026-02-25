# audio_manager.gd
# Central audio system. Listens to Events signals and plays the appropriate
# sounds. Positional sounds are spawned as temporary AudioStreamPlayer2D nodes
# at the world position of the source. UI / global sounds use persistent players.
#
# All sounds are generated procedurally at startup — no audio files required.
# To use real audio, drop .ogg files into godot/assets/audio/sfx/ with these
# exact names and they will automatically override the procedural placeholders:
#   cannon_fire.ogg        — N.O.V.A. fires the kinetic cannon
#   cannon_impact.ogg      — projectile hits an enemy or wall
#   data_spike.ogg         — Jason's Data-Spike melee stun
#   tether_strain_loop.ogg — looping danger tone (modulated by tether severity)
#   hack_success.ogg       — Synaptic Bypass completed
#   phase_shift.ogg        — Quantum Core world shift
#   tank_stalled.ogg       — N.O.V.A. Stability hits zero
extends Node

const SFX_PATH := "res://assets/audio/sfx/"
const SAMPLE_RATE: int = 22050
const TETHER_DANGER_THRESHOLD: float = 0.80  # Mirrors hud.gd

var _sfx: Dictionary = {}

# Persistent non-positional players
var _player_ui:   AudioStreamPlayer
var _player_ui2:  AudioStreamPlayer
var _tether_loop: AudioStreamPlayer


func _ready() -> void:
	_build_players()
	_generate_streams()   # procedural placeholders — works with zero files
	_load_streams()       # override with real .ogg files if present in sfx/
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


# ---------------------------------------------------------------------------
# Procedural audio synthesis — no external files required
# ---------------------------------------------------------------------------

func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format   = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = SAMPLE_RATE
	s.stereo   = false
	s.data     = data
	return s


# White noise burst with exponential decay.
func _make_noise(duration: float, vol: float, decay: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var env := exp(-decay * 5.0 * float(i) / n)
		var s := int(randf_range(-1.0, 1.0) * env * vol * 32767.0)
		s = clampi(s, -32768, 32767)
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	return _wav(data)


# Sine wave with exponential decay.
func _make_sine(freq: float, duration: float, vol: float, decay: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in range(n):
		var env := exp(-decay * 5.0 * float(i) / n)
		phase += TAU * freq / SAMPLE_RATE
		var s := int(sin(phase) * env * vol * 32767.0)
		s = clampi(s, -32768, 32767)
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	return _wav(data)


# Frequency sweep with sine-curve amplitude envelope (soft fade in/out).
func _make_sweep(freq_start: float, freq_end: float, duration: float, vol: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in range(n):
		var t    := float(i) / n
		var freq := lerpf(freq_start, freq_end, t)
		var env  := sin(PI * t)          # fade in then out
		phase += TAU * freq / SAMPLE_RATE
		var s := int(sin(phase) * env * vol * 32767.0)
		s = clampi(s, -32768, 32767)
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	return _wav(data)


# Two consecutive sine notes — each decays linearly. Used for success chimes.
func _make_two_tone(freq1: float, freq2: float, note_dur: float, vol: float) -> AudioStreamWAV:
	var spn  := int(SAMPLE_RATE * note_dur)   # samples per note
	var data := PackedByteArray()
	data.resize(spn * 4)                      # 2 notes × 2 bytes/sample
	var phase := 0.0
	for i in range(spn * 2):
		var freq          := freq1 if i < spn else freq2
		var note_progress := float(i % spn) / spn
		var env           := 1.0 - note_progress  # linear decay per note
		phase += TAU * freq / SAMPLE_RATE
		var s := int(sin(phase) * env * vol * 32767.0)
		s = clampi(s, -32768, 32767)
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	return _wav(data)


func _generate_streams() -> void:
	# cannon_fire  : punchy mid-frequency noise burst
	_sfx["cannon_fire"]        = _make_noise(0.18, 0.70, 1.2)
	# cannon_impact: shorter, sharper crack on hit
	_sfx["cannon_impact"]      = _make_noise(0.08, 0.55, 2.5)
	# data_spike   : high-pitched electric blip
	_sfx["data_spike"]         = _make_sine(880.0, 0.10, 0.60, 2.0)
	# tether_strain: low ominous tone that loops and pitches up as danger grows
	_sfx["tether_strain_loop"] = _make_sweep(80.0, 150.0, 0.55, 0.40)
	# hack_success : satisfying ascending two-tone chime
	_sfx["hack_success"]       = _make_two_tone(440.0, 880.0, 0.12, 0.55)
	# phase_shift  : rising sweep signalling world geometry change
	_sfx["phase_shift"]        = _make_sweep(180.0, 540.0, 0.35, 0.50)
	# tank_stalled : descending groan when N.O.V.A. loses all stability
	_sfx["tank_stalled"]       = _make_sweep(320.0, 60.0, 0.55, 0.65)


func _load_streams() -> void:
	# Override any procedural placeholder with a real .ogg if the file exists.
	var names := [
		"cannon_fire", "cannon_impact", "data_spike",
		"tether_strain_loop", "hack_success", "phase_shift", "tank_stalled",
	]
	for sfx_name: String in names:
		var path := SFX_PATH + sfx_name + ".ogg"
		if ResourceLoader.exists(path):
			_sfx[sfx_name] = load(path)


func _connect_signals() -> void:
	Events.on_sfx_play_at.connect(_on_sfx_play_at)
	Events.on_hack_completed.connect(func(): _play_ui(_player_ui,  "hack_success"))
	Events.on_world_shifted.connect(func(_p): _play_ui(_player_ui2, "phase_shift"))
	Events.on_tank_stalled.connect(func(): _play_ui(_player_ui2,  "tank_stalled"))
	Events.on_tether_strained.connect(_on_tether_strained)
	Events.on_pawn_swapped.connect(_on_pawn_swapped)


# ---------------------------------------------------------------------------
# Positional sounds
# ---------------------------------------------------------------------------

func _on_sfx_play_at(sfx_key: String, world_pos: Vector2) -> void:
	var stream: AudioStream = _sfx.get(sfx_key, null)
	if stream == null:
		return
	var p := AudioStreamPlayer2D.new()
	get_tree().current_scene.add_child(p)
	p.stream          = stream
	p.global_position = world_pos
	p.play()
	p.finished.connect(p.queue_free)


# ---------------------------------------------------------------------------
# Tether strain loop
# ---------------------------------------------------------------------------

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
		var t := clampf(
			(severity - TETHER_DANGER_THRESHOLD) / (1.0 - TETHER_DANGER_THRESHOLD),
			0.0, 1.0
		)
		_tether_loop.volume_db   = lerpf(-18.0, 0.0, t)
		_tether_loop.pitch_scale = lerpf(0.88,  1.12, t)


func _on_pawn_swapped(_node: Node2D) -> void:
	_tether_loop.stop()  # Clear on pawn swap — tether_handler restarts tracking


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _play_ui(player: AudioStreamPlayer, sfx_key: String) -> void:
	var stream: AudioStream = _sfx.get(sfx_key, null)
	if stream == null:
		return
	player.stream = stream
	player.play()
