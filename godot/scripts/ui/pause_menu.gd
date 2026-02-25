# pause_menu.gd
# Pause menu overlay. Escape toggles open/close.
# process_mode = ALWAYS so it stays responsive while the tree is paused.
# Sits on CanvasLayer 90 — above HUD (80), below glitch overlay (100).
extends CanvasLayer

const AMBER   := Color(0.961, 0.620, 0.043, 1.0)
const GREY    := Color(0.40, 0.40, 0.40, 1.0)
const RED_DIM := Color(0.85, 0.22, 0.16, 1.0)
const DARK_BG := Color(0.055, 0.055, 0.075, 1.0)

var _overlay: Control        # Root toggled to show/hide everything
var _settings_label: Label   # Placeholder shown when Settings pressed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	_build_ui()
	_overlay.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	var opening := not _overlay.visible
	_overlay.visible = opening
	get_tree().paused = opening
	if not opening and _settings_label:
		_settings_label.visible = false  # Reset settings placeholder on close


# ---------------------------------------------------------------------------
# UI Construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# Root control — toggled as one unit; blocks all game input while visible
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# Dimmer behind the panel
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.60)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(dim)

	# Centred panel container
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.09, 0.97)
	sb.border_color = AMBER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "— PAUSED —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", AMBER)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_add_btn(vbox, "RESUME",          AMBER,   _on_resume_pressed)
	_add_btn(vbox, "AEGIS HUB",       AMBER,   _on_hub_pressed)
	_add_btn(vbox, "SETTINGS",        GREY,    _on_settings_pressed)
	_add_btn(vbox, "QUIT TO DESKTOP", RED_DIM, _on_quit_pressed)

	# Settings placeholder — shown when Settings is pressed
	_settings_label = Label.new()
	_settings_label.text = "SETTINGS — COMING SOON"
	_settings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_label.add_theme_font_size_override("font_size", 8)
	_settings_label.add_theme_color_override("font_color", GREY)
	_settings_label.visible = false
	vbox.add_child(_settings_label)


func _add_btn(parent: VBoxContainer, label: String, col: Color, cb: Callable) -> void:
	var btn := Button.new()
	btn.text = label
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", col)
	# Normal: subtle border only; Hover/Pressed: filled
	for state in ["normal", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(col.r, col.g, col.b, 0.12)
		s.border_color = Color(col.r, col.g, col.b, 0.50)
		s.set_border_width_all(1)
		s.set_corner_radius_all(2)
		s.set_content_margin_all(6)
		btn.add_theme_stylebox_override(state, s)
	for state in ["hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(col.r, col.g, col.b, 0.30)
		s.border_color = col
		s.set_border_width_all(1)
		s.set_corner_radius_all(2)
		s.set_content_margin_all(6)
		btn.add_theme_stylebox_override(state, s)
	btn.pressed.connect(cb)
	parent.add_child(btn)


# ---------------------------------------------------------------------------
# Button Handlers
# ---------------------------------------------------------------------------

func _on_resume_pressed() -> void:
	_toggle()


func _on_hub_pressed() -> void:
	get_tree().paused = false
	_overlay.visible = false
	# Clear run state (voluntary exit — treated like a run end, no death penalty)
	GameData.clear_run_state()
	GameData.save_run_state()
	RunManager.go_to_hub()


func _on_settings_pressed() -> void:
	_settings_label.visible = not _settings_label.visible


func _on_quit_pressed() -> void:
	get_tree().quit()
