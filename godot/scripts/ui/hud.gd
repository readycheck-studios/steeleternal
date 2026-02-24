# hud.gd
# HUD controller. Listens to Events signals and updates all UI elements.
# Also drives the neural glitch overlay via on_tether_strained.
# All styling is applied in _apply_styles() to keep the .tscn clean.
extends Node

const AMBER      := Color(0.961, 0.620, 0.043, 1.0)
const BLUE_PILOT := Color(0.251, 0.647, 0.961, 1.0)
const BAR_BG     := Color(0.067, 0.067, 0.098, 0.90)

const DANGER_THRESHOLD: float = 0.80   # Glitch starts at 80% tether distance
const GLITCH_LERP_SPEED: float = 8.0   # How fast the shader value tracks the target

var _glitch_target: float = 0.0
var _glitch_current: float = 0.0

@onready var nova_label:      Label       = $StaticHUD/HUDRoot/NOVAPanel/NOVALabel
@onready var stability_bar:   ProgressBar = $StaticHUD/HUDRoot/NOVAPanel/StabilityRow/StabilityBar
@onready var stability_value: Label       = $StaticHUD/HUDRoot/NOVAPanel/StabilityRow/StabilityValue
@onready var dust_icon:       Label       = $StaticHUD/HUDRoot/PhaseDustPanel/DustIcon
@onready var dust_count:      Label       = $StaticHUD/HUDRoot/PhaseDustPanel/DustCount
@onready var jason_panel:     Control     = $StaticHUD/HUDRoot/JasonPanel
@onready var pilot_label:     Label       = $StaticHUD/HUDRoot/JasonPanel/PilotLabel
@onready var hp_bar:          ProgressBar = $StaticHUD/HUDRoot/JasonPanel/HPRow/HPBar
@onready var hp_value:        Label       = $StaticHUD/HUDRoot/JasonPanel/HPRow/HPValue
@onready var mode_label:      Label       = $StaticHUD/HUDRoot/ModeLabel
@onready var stalled_alert:    Label       = $StaticHUD/HUDRoot/StalledAlert
@onready var run_failed_label: Label       = $StaticHUD/HUDRoot/RunFailedLabel
@onready var glitch_rect:      ColorRect   = $GlitchOverlay/GlitchRect


func _ready() -> void:
	_apply_styles()
	_connect_signals()
	dust_count.text = str(GameData.phase_dust)
	# Explicitly zero the shader on every scene load — prevents stale GPU value after reload.
	_reset_glitch()


func _connect_signals() -> void:
	Events.on_tank_stability_changed.connect(_on_stability_changed)
	Events.on_jason_health_changed.connect(_on_hp_changed)
	Events.on_pawn_swapped.connect(_on_pawn_swapped)
	Events.on_tank_stalled.connect(_on_tank_stalled)
	Events.on_tether_strained.connect(_on_tether_strained)
	Events.on_run_ended.connect(_on_run_ended)


func _apply_styles() -> void:
	# Label colors
	for lbl: Label in [nova_label, stability_value, dust_icon, dust_count, mode_label]:
		lbl.add_theme_color_override("font_color", AMBER)
	pilot_label.add_theme_color_override("font_color", BLUE_PILOT)
	hp_value.add_theme_color_override("font_color", BLUE_PILOT)

	# Stability bar — amber fill on dark background
	var amber_fill := StyleBoxFlat.new()
	amber_fill.bg_color = AMBER
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = BAR_BG
	stability_bar.add_theme_stylebox_override("fill", amber_fill)
	stability_bar.add_theme_stylebox_override("background", bar_bg)

	# HP bar — blue fill
	var blue_fill := StyleBoxFlat.new()
	blue_fill.bg_color = BLUE_PILOT
	hp_bar.add_theme_stylebox_override("fill", blue_fill)
	hp_bar.add_theme_stylebox_override("background", bar_bg.duplicate())


# --- Signal Handlers ---

func _on_stability_changed(value: float) -> void:
	stability_bar.value = value
	stability_value.text = str(int(value))
	if value > 0.0 and stalled_alert.visible:
		stalled_alert.visible = false


func _on_hp_changed(value: float) -> void:
	hp_bar.value = value
	hp_value.text = str(int(value))


func _on_pawn_swapped(active_node: Node2D) -> void:
	var is_jason := active_node.name == "Jason_Pilot"
	jason_panel.visible = is_jason
	mode_label.text = "◉  PILOT MODE" if is_jason else "◉  TANK MODE"


func _on_tank_stalled() -> void:
	stalled_alert.visible = true


func _on_run_ended(cause: String) -> void:
	stalled_alert.visible = false
	var reason := "JASON LOST" if cause == "jason_died" else "N·O·V·A DESTROYED"
	run_failed_label.text = "✖  RUN FAILED  —  " + reason
	run_failed_label.visible = true


func _on_tether_strained(severity: float) -> void:
	# Remap: no effect below DANGER_THRESHOLD, ramps 0→1 over the remaining 20%
	_glitch_target = clampf(
		(severity - DANGER_THRESHOLD) / (1.0 - DANGER_THRESHOLD), 0.0, 1.0)


func _reset_glitch() -> void:
	_glitch_target = 0.0
	_glitch_current = 0.0
	var mat := glitch_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("interference_strength", 0.0)


func _process(delta: float) -> void:
	if _glitch_current == 0.0 and _glitch_target == 0.0:
		return  # Skip shader write entirely when fully clear
	_glitch_current = lerpf(_glitch_current, _glitch_target, GLITCH_LERP_SPEED * delta)
	# Sine pulse: 0.8s cycle, ±15% swing at full intensity — visible breathing in Danger Zone
	var pulse := sin(Time.get_ticks_msec() * 0.008) * 0.15 * _glitch_current
	var mat := glitch_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("interference_strength",
			clampf(_glitch_current + pulse, 0.0, 1.0))
