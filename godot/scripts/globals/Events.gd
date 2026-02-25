# Events.gd
# Global signal bus for all cross-system communication.
# Systems emit and listen here exclusively — never use get_parent().get_node() for cross-system events.
# Emit:   Events.signal_name.emit(args)
# Listen: Events.signal_name.connect(_handler) in _ready()
extends Node

# --- Pawn / Player ---
signal on_pawn_swapped(active_node: Node2D)

# --- Neural Tether ---
signal on_tether_strained(severity: float)  # 0.0 (safe) to 1.0 (severed)

# --- World Shifting ---
signal on_world_shifted(new_phase: int)

# --- Hacking ---
signal on_hack_started(difficulty: int)
signal on_hack_completed
signal on_hack_failed

# --- N.O.V.A. ---
signal on_tank_stalled                             # Stability reached zero
signal on_tank_stability_changed(new_value: float) # 0.0 to 100.0

# --- Jason ---
signal on_jason_health_changed(new_value: float)   # 0.0 to 30.0
signal on_data_spike_hit                           # Jason's melee stun connected with an enemy

# --- Enemies ---
signal on_enemy_died(position: Vector2)

# --- Phase Dust ---
signal on_phase_dust_changed(new_value: int)

# --- Run ---
signal on_run_ended(cause: String)  # e.g. "jason_died", "nova_destroyed", "tether_severed"

# --- Camera ---
signal on_screen_shake(intensity: float)  # 0.0 to 1.0 normalised

# --- Audio ---
signal on_sfx_play_at(sfx_key: String, world_position: Vector2)  # Positional one-shot SFX
