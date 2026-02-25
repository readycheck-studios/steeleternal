# music_manager.gd
# Autoload singleton — dynamic music system for Steel Eternal.
#
# Manages 5 music states (SILENT, TANK, PILOT, COMBAT, HACKING) with
# crossfading between two AudioStreamPlayers. All tracks are generated
# procedurally at startup so the game is playable without audio files.
# Real .ogg files placed in res://assets/audio/music/ auto-override.
#
# State transitions:
#   Pawn swap (non-combat)  → TANK or PILOT
#   on_enemy_aggro          → COMBAT  (combat_count > 0)
#   on_enemy_deaggro        → TANK/PILOT when combat_count reaches 0
#   on_hack_started         → HACKING (saves previous state)
#   on_hack_completed/failed→ restore pre-hack state
#   on_run_ended            → SILENT
extends Node

enum MusicState { SILENT, TANK, PILOT, COMBAT, HACKING }

const SAMPLE_RATE: int = 22050
const LOOP_DURATION: float = 4.0  # seconds per generated loop

# Crossfade durations (seconds)
const FADE_EXPLORE_TO_EXPLORE: float = 1.5
const FADE_TO_COMBAT: float = 0.3
const FADE_FROM_COMBAT: float = 2.0
const FADE_TO_HACKING: float = 0.8
const FADE_FROM_HACKING: float = 1.0
const FADE_TO_SILENT: float = 2.0

var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active: AudioStreamPlayer

var _state: MusicState = MusicState.SILENT
var _pre_hack_state: MusicState = MusicState.TANK
var _active_pawn_state: MusicState = MusicState.TANK  # TANK or PILOT, updated on pawn swap
var _combat_count: int = 0
var _hack_difficulty: int = 1

# Cache generated streams so we only build them once
var _streams: Dictionary = {}


func _ready() -> void:
	_player_a = AudioStreamPlayer.new()
	_player_b = AudioStreamPlayer.new()
	_player_a.bus = "Master"
	_player_b.bus = "Master"
	_player_a.volume_db = -80.0
	_player_b.volume_db = -80.0
	add_child(_player_a)
	add_child(_player_b)
	_active = _player_a

	_build_all_streams()
	_connect_signals()

	# Start on TANK state — the run begins with N.O.V.A.
	_enter_state(MusicState.TANK, FADE_EXPLORE_TO_EXPLORE)


# ---------------------------------------------------------------------------
# Signal Connections
# ---------------------------------------------------------------------------

func _connect_signals() -> void:
	Events.on_pawn_swapped.connect(_on_pawn_swapped)
	Events.on_enemy_aggro.connect(_on_enemy_aggro)
	Events.on_enemy_deaggro.connect(_on_enemy_deaggro)
	Events.on_hack_started.connect(_on_hack_started)
	Events.on_hack_completed.connect(_on_hack_completed)
	Events.on_hack_failed.connect(_on_hack_failed)
	Events.on_run_ended.connect(_on_run_ended)


func _on_pawn_swapped(active_node: Node2D) -> void:
	if active_node == null:
		return
	# Determine which pawn is active by group membership
	if active_node.is_in_group("nova_tank"):
		_active_pawn_state = MusicState.TANK
	else:
		_active_pawn_state = MusicState.PILOT
	# Only switch music if not in combat or hacking
	if _state == MusicState.COMBAT or _state == MusicState.HACKING:
		return
	_enter_state(_active_pawn_state, FADE_EXPLORE_TO_EXPLORE)


func _on_enemy_aggro() -> void:
	_combat_count += 1
	if _state != MusicState.COMBAT and _state != MusicState.HACKING:
		_enter_state(MusicState.COMBAT, FADE_TO_COMBAT)


func _on_enemy_deaggro() -> void:
	_combat_count = maxi(_combat_count - 1, 0)
	if _combat_count == 0 and _state == MusicState.COMBAT:
		_enter_state(_active_pawn_state, FADE_FROM_COMBAT)


func _on_hack_started(difficulty: int) -> void:
	_hack_difficulty = difficulty
	_pre_hack_state = _state
	_enter_state(MusicState.HACKING, FADE_TO_HACKING)


func _on_hack_completed() -> void:
	_enter_state(_pre_hack_state, FADE_FROM_HACKING)


func _on_hack_failed() -> void:
	_enter_state(_pre_hack_state, FADE_FROM_HACKING)


func _on_run_ended(_cause: String) -> void:
	_combat_count = 0
	_enter_state(MusicState.SILENT, FADE_TO_SILENT)


# ---------------------------------------------------------------------------
# State Entry
# ---------------------------------------------------------------------------

func _enter_state(new_state: MusicState, fade_duration: float) -> void:
	_state = new_state
	var stream := _stream_for_state(new_state)
	if stream == null:
		# No stream available → fade out current
		_fade_out(fade_duration)
		return
	_crossfade(stream, fade_duration)


func _stream_for_state(s: MusicState) -> AudioStream:
	match s:
		MusicState.TANK:
			return _streams.get("music_tank")
		MusicState.PILOT:
			return _streams.get("music_pilot")
		MusicState.COMBAT:
			return _streams.get("music_combat")
		MusicState.HACKING:
			var key := "music_hacking_%d" % clampi(_hack_difficulty, 1, 3)
			return _streams.get(key)
		MusicState.SILENT:
			return null
	return null


# ---------------------------------------------------------------------------
# Crossfade
# ---------------------------------------------------------------------------

func _crossfade(new_stream: AudioStream, duration: float) -> void:
	var next: AudioStreamPlayer = _player_b if _active == _player_a else _player_a
	next.stream = new_stream
	next.volume_db = -80.0
	next.play()
	var tw := create_tween()
	tw.tween_property(_active, "volume_db", -80.0, duration)
	tw.parallel().tween_property(next, "volume_db", 0.0, duration)
	var prev := _active
	_active = next
	tw.tween_callback(func() -> void: prev.stop())


func _fade_out(duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_active, "volume_db", -80.0, duration)
	var prev := _active
	tw.tween_callback(func() -> void: prev.stop())


# ---------------------------------------------------------------------------
# Procedural Stream Generation
# ---------------------------------------------------------------------------

func _build_all_streams() -> void:
	# Check for real .ogg overrides first; fall back to procedural generation.
	var music_dir := "res://assets/audio/music/"
	var keys := {
		"music_tank":      music_dir + "music_tank.ogg",
		"music_pilot":     music_dir + "music_pilot.ogg",
		"music_combat":    music_dir + "music_combat.ogg",
		"music_hacking_1": music_dir + "music_hacking_1.ogg",
		"music_hacking_2": music_dir + "music_hacking_2.ogg",
		"music_hacking_3": music_dir + "music_hacking_3.ogg",
	}
	for key in keys:
		var path: String = keys[key]
		if ResourceLoader.exists(path):
			_streams[key] = load(path)
		else:
			_streams[key] = _generate_track(key)


func _generate_track(key: String) -> AudioStreamWAV:
	match key:
		"music_tank":
			# Low industrial pulse: slow beat (1.3Hz) at 55Hz + 55/110Hz drone
			var pulse := _make_pulse_loop(1.3, 55.0, LOOP_DURATION, 0.55)
			var drone := _make_drone_loop(55.0, 110.0, LOOP_DURATION, 0.35)
			return _mix_streams(pulse, drone, LOOP_DURATION)
		"music_pilot":
			# Sparse eerie: amplitude-modulated 440+523Hz drone at low volume
			return _make_modulated_drone_loop(440.0, 523.0, 0.5, LOOP_DURATION, 0.30)
		"music_combat":
			# Intense: 2Hz pulse at 220Hz + 2Hz noise beats
			var pulse := _make_pulse_loop(2.0, 220.0, LOOP_DURATION, 0.55)
			var noise := _make_noise_beat_loop(2.0, LOOP_DURATION, 0.45)
			return _mix_streams(pulse, noise, LOOP_DURATION)
		"music_hacking_1":
			return _make_pulse_loop(2.0, 880.0, LOOP_DURATION, 0.50)
		"music_hacking_2":
			return _make_pulse_loop(3.0, 880.0, LOOP_DURATION, 0.50)
		"music_hacking_3":
			return _make_pulse_loop(4.0, 880.0, LOOP_DURATION, 0.50)
	return _make_pulse_loop(1.0, 110.0, LOOP_DURATION, 0.4)


# Sine bursts at beat_hz rhythm — sharp attack, quick exponential decay.
# Gives an industrial thump pattern.
func _make_pulse_loop(beat_hz: float, tone_hz: float, duration: float, vol: float) -> AudioStreamWAV:
	var num_samples := int(SAMPLE_RATE * duration)
	var beat_period := SAMPLE_RATE / beat_hz  # samples per beat
	var data := PackedByteArray()
	data.resize(num_samples * 2)  # 16-bit mono

	var phase := 0.0
	var phase_inc := TAU * tone_hz / SAMPLE_RATE

	for i in num_samples:
		var beat_pos := fmod(float(i), beat_period)
		# Envelope: sharp linear attack (10% of period) then exponential decay
		var env_t := beat_pos / beat_period
		var env: float
		if env_t < 0.05:
			env = env_t / 0.05
		else:
			env = exp(-8.0 * (env_t - 0.05))

		var sample := sin(phase) * env * vol
		phase = fmod(phase + phase_inc, TAU)

		var s16 := int(clamp(sample * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF

	return _pack_wav(data, num_samples)


# Two sine waves mixed — sustained drone with harmonic texture.
func _make_drone_loop(freq_a: float, freq_b: float, duration: float, vol: float) -> AudioStreamWAV:
	var num_samples := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	var phase_a := 0.0
	var phase_b := 0.0
	var inc_a := TAU * freq_a / SAMPLE_RATE
	var inc_b := TAU * freq_b / SAMPLE_RATE

	for i in num_samples:
		var sample := (sin(phase_a) + sin(phase_b)) * 0.5 * vol
		phase_a = fmod(phase_a + inc_a, TAU)
		phase_b = fmod(phase_b + inc_b, TAU)

		var s16 := int(clamp(sample * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF

	return _pack_wav(data, num_samples)


# Drone with low-frequency amplitude modulation — eerie pulsing effect.
func _make_modulated_drone_loop(freq_a: float, freq_b: float, mod_hz: float, duration: float, vol: float) -> AudioStreamWAV:
	var num_samples := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	var phase_a := 0.0
	var phase_b := 0.0
	var phase_m := 0.0
	var inc_a := TAU * freq_a / SAMPLE_RATE
	var inc_b := TAU * freq_b / SAMPLE_RATE
	var inc_m := TAU * mod_hz / SAMPLE_RATE

	for i in num_samples:
		var mod_env := (sin(phase_m) * 0.5 + 0.5)  # 0.0–1.0 modulator
		var sample := (sin(phase_a) + sin(phase_b)) * 0.5 * mod_env * vol
		phase_a = fmod(phase_a + inc_a, TAU)
		phase_b = fmod(phase_b + inc_b, TAU)
		phase_m = fmod(phase_m + inc_m, TAU)

		var s16 := int(clamp(sample * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF

	return _pack_wav(data, num_samples)


# White noise bursts at beat_hz — percussive texture for combat.
func _make_noise_beat_loop(beat_hz: float, duration: float, vol: float) -> AudioStreamWAV:
	var num_samples := int(SAMPLE_RATE * duration)
	var beat_period := SAMPLE_RATE / beat_hz
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	var rng := RandomNumberGenerator.new()
	rng.seed = 314159  # deterministic — same sound every run

	for i in num_samples:
		var beat_pos := fmod(float(i), beat_period)
		var env_t := beat_pos / beat_period
		var env: float
		if env_t < 0.05:
			env = env_t / 0.05
		else:
			env = exp(-10.0 * (env_t - 0.05))

		var noise := rng.randf_range(-1.0, 1.0)
		var sample := noise * env * vol

		var s16 := int(clamp(sample * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF

	return _pack_wav(data, num_samples)


# Mix two same-length AudioStreamWAV objects into one by averaging samples.
func _mix_streams(a: AudioStreamWAV, b: AudioStreamWAV, duration: float) -> AudioStreamWAV:
	var num_samples := int(SAMPLE_RATE * duration)
	var data_a := a.data
	var data_b := b.data
	var mixed := PackedByteArray()
	mixed.resize(num_samples * 2)

	for i in num_samples:
		var byte_lo_a := data_a[i * 2]
		var byte_hi_a := data_a[i * 2 + 1]
		var byte_lo_b := data_b[i * 2]
		var byte_hi_b := data_b[i * 2 + 1]

		# Reconstruct signed 16-bit values
		var s16_a: int = byte_lo_a | (byte_hi_a << 8)
		if s16_a >= 32768:
			s16_a -= 65536
		var s16_b: int = byte_lo_b | (byte_hi_b << 8)
		if s16_b >= 32768:
			s16_b -= 65536

		# Average the two channels
		var mixed_val := int(clamp((s16_a + s16_b) * 0.5, -32768.0, 32767.0))
		mixed[i * 2]     = mixed_val & 0xFF
		mixed[i * 2 + 1] = (mixed_val >> 8) & 0xFF

	return _pack_wav(mixed, num_samples)


# Pack raw 16-bit PCM bytes into a looping AudioStreamWAV.
func _pack_wav(pcm_data: PackedByteArray, num_samples: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	stream.mix_rate = SAMPLE_RATE
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = num_samples
	stream.data = pcm_data
	return stream
