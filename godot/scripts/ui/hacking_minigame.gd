# hacking_minigame.gd
# Synaptic Bypass waveform mini-game. Rendered as a Node2D in world space
# positioned above Jason — fully diegetic, world keeps running.
#
# Player tunes Amplitude (W/S), Frequency (A/D), Phase (Q/E) to match the
# target sine wave. Success = average waveform error < MATCH_TOLERANCE for
# SUCCESS_DURATION consecutive seconds.
extends Node2D

const DISPLAY_W: float = 140.0
const DISPLAY_H: float = 60.0
const WAVE_SAMPLES: int = 60

const AMP_SPEED: float = 0.55
const FREQ_SPEED: float = 1.8
const PHASE_SPEED: float = 2.0

const MATCH_TOLERANCE: float = 0.13  # Average normalised error threshold
const SUCCESS_DURATION: float = 1.5

# Colors
const C_BG        := Color(0.04, 0.04, 0.09, 0.92)
const C_BORDER    := Color(0.38, 0.15, 0.75, 0.85)
const C_TARGET    := Color(0.961, 0.620, 0.043, 0.55)
const C_PLAYER    := Color(0.20, 0.88, 1.00, 1.00)
const C_MATCH_OK  := Color(0.20, 1.00, 0.40, 0.90)
const C_MATCH_BAD := Color(0.75, 0.15, 0.15, 0.70)
const C_TEXT      := Color(0.961, 0.620, 0.043, 0.80)

var target_amplitude: float = 0.70
var target_frequency: float = 2.50
var target_phase: float = 1.00

var player_amplitude: float = 0.30
var player_frequency: float = 1.00
var player_phase: float = 0.00

var match_timer: float = 0.00
var is_active: bool = false

signal hack_succeeded
signal hack_cancelled


func setup(t_amp: float, t_freq: float, t_phase: float) -> void:
	target_amplitude = t_amp
	target_frequency = t_freq
	target_phase = t_phase
	is_active = true


func cancel() -> void:
	is_active = false
	hack_cancelled.emit()
	queue_free()


func _process(delta: float) -> void:
	if not is_active:
		return
	_handle_input(delta)
	_check_match(delta)
	queue_redraw()


func _handle_input(delta: float) -> void:
	# Amplitude — W up, S down
	if Input.is_action_pressed("p_jump"):
		player_amplitude = clampf(player_amplitude + AMP_SPEED * delta, 0.10, 1.00)
	if Input.is_action_pressed("h_amp_down"):
		player_amplitude = clampf(player_amplitude - AMP_SPEED * delta, 0.10, 1.00)

	# Frequency — D up, A down
	var freq_dir := Input.get_axis("p_move_left", "p_move_right")
	player_frequency = clampf(player_frequency + freq_dir * FREQ_SPEED * delta, 0.50, 5.00)

	# Phase shift — Q left, E right
	if Input.is_action_pressed("p_utility"):
		player_phase -= PHASE_SPEED * delta
	if Input.is_action_pressed("h_phase_right"):
		player_phase += PHASE_SPEED * delta


func _check_match(delta: float) -> void:
	var error := _compute_wave_error()
	if error <= MATCH_TOLERANCE:
		match_timer += delta
		if match_timer >= SUCCESS_DURATION:
			is_active = false
			hack_succeeded.emit()
			queue_free()
	else:
		match_timer = maxf(match_timer - delta * 0.5, 0.0)  # Decay slowly on mismatch


func _compute_wave_error() -> float:
	var total: float = 0.0
	for i in WAVE_SAMPLES:
		var t := float(i) / WAVE_SAMPLES
		var ty := target_amplitude * sin(target_frequency * t * TAU + target_phase)
		var py := player_amplitude * sin(player_frequency * t * TAU + player_phase)
		total += absf(ty - py)
	# Normalise: max possible error per sample is 2.0 (amps cancel perfectly wrong)
	return (total / WAVE_SAMPLES) / 2.0


func _draw() -> void:
	var hw := DISPLAY_W * 0.5
	var hh := DISPLAY_H * 0.5

	# Background
	draw_rect(Rect2(-hw, -hh, DISPLAY_W, DISPLAY_H), C_BG)
	draw_rect(Rect2(-hw, -hh, DISPLAY_W, DISPLAY_H), C_BORDER, false, 1.0)

	# Centre line
	draw_line(Vector2(-hw, 0), Vector2(hw, 0), Color(0.3, 0.3, 0.4, 0.4), 0.5)

	# Waves
	_draw_sine_wave(target_amplitude, target_frequency, target_phase, C_TARGET, 1.2)
	_draw_sine_wave(player_amplitude, player_frequency, player_phase, C_PLAYER, 1.8)

	# Match progress bar
	var error := _compute_wave_error()
	var bar_color := C_MATCH_OK if error <= MATCH_TOLERANCE else C_MATCH_BAD
	var bar_w := DISPLAY_W * clampf(match_timer / SUCCESS_DURATION, 0.0, 1.0)
	draw_rect(Rect2(-hw, hh - 5, DISPLAY_W, 5), Color(0.1, 0.1, 0.15, 0.8))
	if bar_w > 0.0:
		draw_rect(Rect2(-hw, hh - 5, bar_w, 5), bar_color)

	# Control hint (below panel)
	draw_string(ThemeDB.fallback_font,
		Vector2(-hw, hh + 12),
		"Spc/S:AMP  A/D:FREQ  Q/R:PHASE",
		HORIZONTAL_ALIGNMENT_LEFT, DISPLAY_W, 8, C_TEXT)


func _draw_sine_wave(amp: float, freq: float, phase: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	var hw := DISPLAY_W * 0.5
	var wave_scale := DISPLAY_H * 0.38
	for i in WAVE_SAMPLES + 1:
		var t := float(i) / WAVE_SAMPLES
		var x := (t - 0.5) * DISPLAY_W
		var y := -amp * wave_scale * sin(freq * t * TAU + phase)
		pts.append(Vector2(x, y))
	draw_polyline(pts, color, width, true)
