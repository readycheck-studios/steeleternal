# aegis_hub.gd
# Between-runs meta-progression screen. Player spends Phase Dust on permanent
# Neural Imprints across three upgrade branches (Titan / Ghost / Flux).
# Entire UI is built in code to keep the .tscn minimal.
extends Control

# ---------------------------------------------------------------------------
# Upgrade catalog — 3 branches × 3 tiers
# ---------------------------------------------------------------------------
const UPGRADES: Array = [
	{
		"id": "titan_1", "branch": "Titan", "name": "Reactive Armour",
		"desc": "N.O.V.A. takes 20% less stability damage per hit.",
		"cost": 3, "requires": ""
	},
	{
		"id": "titan_2", "branch": "Titan", "name": "High-Yield Rounds",
		"desc": "Cannon damage +10 per projectile.",
		"cost": 6, "requires": "titan_1"
	},
	{
		"id": "titan_3", "branch": "Titan", "name": "Overdrive Chassis",
		"desc": "N.O.V.A. move speed +50 units.",
		"cost": 12, "requires": "titan_2"
	},
	{
		"id": "ghost_1", "branch": "Ghost", "name": "Pilot Conditioning",
		"desc": "Jason takes 20% less damage per hit.",
		"cost": 3, "requires": ""
	},
	{
		"id": "ghost_2", "branch": "Ghost", "name": "Neural Boost",
		"desc": "Tether max range +100 px.",
		"cost": 6, "requires": "ghost_1"
	},
	{
		"id": "ghost_3", "branch": "Ghost", "name": "Rapid Reroute",
		"desc": "Data-Spike cooldown 0.8s → 0.3s.",
		"cost": 12, "requires": "ghost_2"
	},
	{
		"id": "flux_1", "branch": "Flux", "name": "Phase Resonance",
		"desc": "+2 Phase Dust per Core activation (total 5).",
		"cost": 3, "requires": ""
	},
	{
		"id": "flux_2", "branch": "Flux", "name": "Quantum Attunement",
		"desc": "Core hack difficulty −1 (min 1).",
		"cost": 6, "requires": "flux_1"
	},
	{
		"id": "flux_3", "branch": "Flux", "name": "Distant Uplink",
		"desc": "Core activation range +100 px.",
		"cost": 12, "requires": "flux_2"
	},
]

const BRANCH_ORDER: Array = ["Titan", "Ghost", "Flux"]

# Colours
const AMBER      := Color(0.961, 0.620, 0.043, 1.0)
const AMBER_DIM  := Color(0.961, 0.620, 0.043, 0.40)
const DARK_BG    := Color(0.055, 0.055, 0.075, 1.0)
const PANEL_BG   := Color(0.075, 0.075, 0.110, 1.0)
const GREY       := Color(0.35, 0.35, 0.35, 1.0)
const GREEN      := Color(0.30, 0.90, 0.45, 1.0)
const WHITE      := Color(1.0, 1.0, 1.0, 1.0)

var _dust_label: Label
var _status_label: Label
# Map upgrade id → the slot's inner VBoxContainer (stable reference, never freed)
var _slot_vboxes: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	Events.on_phase_dust_changed.connect(_on_dust_changed)


# ---------------------------------------------------------------------------
# UI Construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# Full-screen dark backdrop
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = DARK_BG
	add_child(bg)

	# Root VBox fills the screen; header + deploy pin top/bottom, scroll takes the rest
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	# ---- Header ----
	var title := Label.new()
	title.text = "▸  AEGIS HUB"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", AMBER)
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "NEURAL IMPRINT TERMINAL  —  PERMANENT UPGRADES"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 7)
	subtitle.add_theme_color_override("font_color", GREY)
	root.add_child(subtitle)

	# Dust counter
	var dust_row := HBoxContainer.new()
	dust_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dust_row.add_theme_constant_override("separation", 4)
	root.add_child(dust_row)

	var dust_icon := Label.new()
	dust_icon.text = "◈  PHASE DUST:"
	dust_icon.add_theme_color_override("font_color", AMBER)
	dust_icon.add_theme_font_size_override("font_size", 9)
	dust_row.add_child(dust_icon)

	_dust_label = Label.new()
	_dust_label.text = str(GameData.phase_dust)
	_dust_label.add_theme_color_override("font_color", WHITE)
	_dust_label.add_theme_font_size_override("font_size", 9)
	dust_row.add_child(_dust_label)

	root.add_child(HSeparator.new())

	# ---- Scrollable columns (takes all remaining vertical space) ----
	var scroll := ScrollContainer.new()
	scroll.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	scroll.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var columns := HBoxContainer.new()
	columns.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	columns.add_theme_constant_override("separation", 6)
	scroll.add_child(columns)

	for branch in BRANCH_ORDER:
		columns.add_child(_build_branch_column(branch))

	# ---- Footer (always visible below scroll) ----
	root.add_child(HSeparator.new())

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", AMBER)
	_status_label.add_theme_font_size_override("font_size", 8)
	_status_label.custom_minimum_size = Vector2(0, 14)
	root.add_child(_status_label)

	var deploy := Button.new()
	deploy.text = "[ DEPLOY RUN ]"
	deploy.add_theme_font_size_override("font_size", 11)
	_style_button(deploy, AMBER)
	deploy.pressed.connect(_on_deploy_pressed)

	var deploy_center := CenterContainer.new()
	deploy_center.add_child(deploy)
	root.add_child(deploy_center)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	root.add_child(spacer)


func _build_branch_column(branch: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	_style_panel(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var header := Label.new()
	header.text = "— " + branch.to_upper() + " —"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", AMBER)
	header.add_theme_font_size_override("font_size", 9)
	vbox.add_child(header)

	for upg in UPGRADES:
		if upg["branch"] == branch:
			vbox.add_child(_build_upgrade_slot(upg))

	return panel


func _build_upgrade_slot(upg: Dictionary) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	_style_slot(slot)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	slot.add_child(vbox)

	# Store VBoxContainer reference — used by _refresh_all_slots to swap the action widget
	_slot_vboxes[upg["id"]] = vbox

	var name_lbl := Label.new()
	name_lbl.text = upg["name"]
	name_lbl.add_theme_font_size_override("font_size", 8)
	name_lbl.add_theme_color_override("font_color", WHITE)
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = upg["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 7)
	desc_lbl.add_theme_color_override("font_color", GREY)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "Cost: %d ◈" % upg["cost"]
	cost_lbl.add_theme_font_size_override("font_size", 7)
	cost_lbl.add_theme_color_override("font_color", AMBER_DIM)
	vbox.add_child(cost_lbl)

	# Action widget is always the last child — swapped by _refresh_all_slots
	vbox.add_child(_make_slot_action(upg))

	return slot


func _make_slot_action(upg: Dictionary) -> Control:
	var id: String = upg["id"]
	var lvl: Dictionary = GameData.upgrade_levels
	var purchased: bool  = lvl.get(id, 0) >= 1
	var prereq_ok: bool  = upg["requires"] == "" or lvl.get(upg["requires"], 0) >= 1
	var can_afford: bool = GameData.phase_dust >= upg["cost"]

	if purchased:
		var lbl := Label.new()
		lbl.text = "✓  IMPRINT ACTIVE"
		lbl.add_theme_font_size_override("font_size", 7)
		lbl.add_theme_color_override("font_color", GREEN)
		return lbl

	var btn := Button.new()
	btn.add_theme_font_size_override("font_size", 8)

	if not prereq_ok:
		btn.text = "LOCKED"
		btn.disabled = true
		_style_button(btn, GREY)
	elif not can_afford:
		btn.text = "BUY  (%d ◈)" % upg["cost"]
		btn.disabled = true
		_style_button(btn, AMBER_DIM)
	else:
		btn.text = "BUY  (%d ◈)" % upg["cost"]
		btn.disabled = false
		_style_button(btn, AMBER)
		btn.pressed.connect(_on_buy_pressed.bind(upg))

	return btn


# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

func _on_buy_pressed(upg: Dictionary) -> void:
	var id: String = upg["id"]
	if GameData.phase_dust < upg["cost"]:
		_status_label.text = "✖  Not enough Phase Dust."
		return

	GameData.phase_dust -= upg["cost"]
	GameData.upgrade_levels[id] = 1
	GameData.save_run_state()

	_status_label.text = "✔  %s imprinted." % upg["name"]

	# Emit after save; _on_dust_changed handles the full slot refresh
	Events.on_phase_dust_changed.emit(GameData.phase_dust)


func _on_deploy_pressed() -> void:
	RunManager.restart_run()


func _on_dust_changed(value: int) -> void:
	_dust_label.text = str(value)
	_refresh_all_slots()


# ---------------------------------------------------------------------------
# Slot Refresh — replaces only the action widget (last child) of each slot
# ---------------------------------------------------------------------------

func _refresh_all_slots() -> void:
	for upg in UPGRADES:
		var vbox: VBoxContainer = _slot_vboxes.get(upg["id"])
		if vbox == null:
			continue
		var last_idx: int = vbox.get_child_count() - 1
		if last_idx < 0:
			continue
		var old_action: Control = vbox.get_child(last_idx)
		# Only replace if the state could have changed (skip confirmed-purchased labels)
		if old_action is Label and old_action.text.begins_with("✓"):
			continue
		vbox.remove_child(old_action)
		old_action.queue_free()
		vbox.add_child(_make_slot_action(upg))


# ---------------------------------------------------------------------------
# Styling Helpers
# ---------------------------------------------------------------------------

func _style_panel(panel: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = AMBER_DIM
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", sb)


func _style_slot(slot: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.13, 1.0)
	sb.border_color = Color(0.15, 0.15, 0.22, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(5)
	slot.add_theme_stylebox_override("panel", sb)


func _style_button(btn: Button, col: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col if state != "disabled" else Color(col.r, col.g, col.b, 0.3)
		sb.set_corner_radius_all(2)
		sb.set_content_margin_all(3)
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", DARK_BG)
	btn.add_theme_color_override("font_disabled_color", Color(0.2, 0.2, 0.2, 0.6))
