// phase_shift.gdshader
// Lerps between two texture sets when a Quantum Core shifts world phase.
// Apply to TileMapLayer or environment sprites.
// blend: 0.0 = Phase A, 1.0 = Phase B.
shader_type canvas_item;

uniform sampler2D phase_b_texture : hint_default_black;
uniform float blend : hint_range(0.0, 1.0) = 0.0;
uniform vec4 shift_tint : source_color = vec4(0.6, 0.4, 1.0, 1.0);  // Violet quantum flash

void fragment() {
	vec4 phase_a = texture(TEXTURE, UV);
	vec4 phase_b = texture(phase_b_texture, UV);

	// Brief violet tint flash at midpoint of transition
	float flash = smoothstep(0.3, 0.5, blend) * smoothstep(0.7, 0.5, blend);
	vec4 result = mix(phase_a, phase_b, blend);
	result.rgb = mix(result.rgb, shift_tint.rgb, flash * 0.4);

	COLOR = result;
}
