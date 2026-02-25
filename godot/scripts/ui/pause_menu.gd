# pause_menu.gd
# Pause menu overlay. Escape toggles open/close.
# process_mode = ALWAYS so it stays responsive while the tree is paused.
# Sits on CanvasLayer 90 — above HUD (80), below glitch overlay (100).
#
# Two sub-panels live inside the shared panel container:
#   _main_btns     — Resume / Aegis Hub / Settings / Quit
#   _settings_panel — Volume slider, Fullscreen toggle, Window Scale
# Pressing Settings swaps visibility between them.
extends CanvasLayer

const AMBER   := Color(0.961, 0.620, 0.043, 1.0)
const GREY    := Color(0.40,  0.40,  0.40,  1.0)
const RED_DIM := Color(0.85,  0.22,  0.16,  1.0)

var _overlay: Control

# Main menu
var _main_btns: VBoxContainer

# Settings sub-panel widgets (kept for live updates)
var _settings_panel: VBoxContainer
var _vol_slider:     HSlider
var _fs_check:       CheckButton
var _scale_row:      HBoxContainer


func _ready() -> void:
	process_mode     = Node.PROCESS_MODE_ALWAYS
	layer            = 90
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
	if not opening:
		# Always return to main buttons on close
		_main_btns.visible      = true
		_settings_panel.visible = false


# ---------------------------------------------------------------------------
# UI Construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# Root control — blocks all game input while visible
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# Semi-transparent dimmer
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color        = Color(0.0, 0.0, 0.0, 0.60)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(dim)

	# Centred panel
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.09, 0.97)
	sb.border_color = AMBER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(root_vbox)

	# Title — always visible
	var title := Label.new()
	title.text                   = "— PAUSED —"
	title.horizontal_alignment   = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", AMBER)
	root_vbox.add_child(title)
	root_vbox.add_child(HSeparator.new())

	# Main button list
	_main_btns = VBoxContainer.new()
	_main_btns.add_theme_constant_override("separation", 8)
	root_vbox.add_child(_main_btns)

	_add_btn(_main_btns, "RESUME",          AMBER,   _on_resume_pressed)
	_add_btn(_main_btns, "AEGIS HUB",       AMBER,   _on_hub_pressed)
	_add_btn(_main_btns, "SETTINGS",        GREY,    _on_settings_pressed)
	_add_btn(_main_btns, "QUIT TO DESKTOP", RED_DIM, _on_quit_pressed)

	# Settings sub-panel (hidden by default)
	_settings_panel         = _build_settings_panel()
	_settings_panel.visible = false
	root_vbox.add_child(_settings_panel)


func _build_settings_panel() -> VBoxContainer:
	var s := VBoxContainer.new()
	s.add_theme_constant_override("separation", 10)

	_add_btn(s, "< BACK", AMBER, _on_back_pressed)
	s.add_child(HSeparator.new())

	# --- Master Volume ---
	var vol_label := _make_label("MASTER VOLUME")
	s.add_child(vol_label)

	_vol_slider                   = HSlider.new()
	_vol_slider.min_value         = -40.0
	_vol_slider.max_value         = 0.0
	_vol_slider.step              = 1.0
	_vol_slider.value             = SettingsManager.master_volume_db
	_vol_slider.custom_minimum_size = Vector2(160, 20)
	_vol_slider.value_changed.connect(_on_vol_changed)
	s.add_child(_vol_slider)

	# --- Fullscreen ---
	var fs_row := HBoxContainer.new()
	s.add_child(fs_row)

	var fs_label := _make_label("FULLSCREEN")
	fs_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_row.add_child(fs_label)

	_fs_check                = CheckButton.new()
	_fs_check.button_pressed = SettingsManager.fullscreen
	_fs_check.toggled.connect(_on_fs_toggled)
	fs_row.add_child(_fs_check)

	# --- Window Scale (hidden while fullscreen) ---
	_scale_row         = HBoxContainer.new()
	_scale_row.visible = not SettingsManager.fullscreen
	s.add_child(_scale_row)

	var scale_label := _make_label("WINDOW SCALE")
	scale_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale_row.add_child(scale_label)

	var scale_opt := OptionButton.new()
	scale_opt.add_item("2×", 2)
	scale_opt.add_item("3×", 3)
	scale_opt.selected = 0 if SettingsManager.window_scale == 2 else 1
	scale_opt.add_theme_font_size_override("font_size", 9)
	scale_opt.item_selected.connect(_on_scale_selected)
	_scale_row.add_child(scale_opt)

	return s


func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", AMBER)
	return lbl


func _add_btn(parent: Control, label: String, col: Color, cb: Callable) -> void:
	var btn := Button.new()
	btn.text = label
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", col)
	for state in ["normal", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color     = Color(col.r, col.g, col.b, 0.12)
		s.border_color = Color(col.r, col.g, col.b, 0.50)
		s.set_border_width_all(1)
		s.set_corner_radius_all(2)
		s.set_content_margin_all(6)
		btn.add_theme_stylebox_override(state, s)
	for state in ["hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color     = Color(col.r, col.g, col.b, 0.30)
		s.border_color = col
		s.set_border_width_all(1)
		s.set_corner_radius_all(2)
		s.set_content_margin_all(6)
		btn.add_theme_stylebox_override(state, s)
	btn.pressed.connect(cb)
	parent.add_child(btn)


# ---------------------------------------------------------------------------
# Button / Control Handlers
# ---------------------------------------------------------------------------

func _on_resume_pressed() -> void:
	_toggle()


func _on_hub_pressed() -> void:
	get_tree().paused    = false
	_overlay.visible     = false
	GameData.clear_run_state()
	GameData.save_run_state()
	RunManager.go_to_hub()


func _on_settings_pressed() -> void:
	_main_btns.visible      = false
	_settings_panel.visible = true
	# Sync slider in case volume was changed externally
	_vol_slider.value = SettingsManager.master_volume_db


func _on_back_pressed() -> void:
	_settings_panel.visible = false
	_main_btns.visible      = true


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_vol_changed(value: float) -> void:
	SettingsManager.master_volume_db = value
	SettingsManager.apply()
	SettingsManager.save_settings()


func _on_fs_toggled(pressed: bool) -> void:
	SettingsManager.fullscreen = pressed
	_scale_row.visible         = not pressed
	SettingsManager.apply()
	SettingsManager.save_settings()


func _on_scale_selected(index: int) -> void:
	SettingsManager.window_scale = 2 if index == 0 else 3
	SettingsManager.apply()
	SettingsManager.save_settings()
