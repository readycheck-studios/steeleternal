// crt_scanline.gdshader
// Global CRT/scanline filter reinforcing the Neural Link aesthetic.
// Apply to a full-viewport ColorRect on a CanvasLayer (Z=80 or below glitch shader).
shader_type canvas_item;

uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float scanline_count : hint_range(60.0, 360.0) = 180.0;
uniform float barrel_strength : hint_range(0.0, 0.1) = 0.02;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;

	// Barrel distortion (subtle CRT curvature)
	vec2 curved = uv * 2.0 - 1.0;
	curved *= 1.0 + dot(curved, curved) * barrel_strength;
	vec2 crt_uv = (curved + 1.0) * 0.5;

	// Kill pixels outside the barrel
	if (crt_uv.x < 0.0 || crt_uv.x > 1.0 || crt_uv.y < 0.0 || crt_uv.y > 1.0) {
		COLOR = vec4(0.0);
		return;
	}

	vec4 color = texture(SCREEN_TEXTURE, crt_uv);

	// Horizontal scanlines
	float scanline = sin(crt_uv.y * scanline_count * PI) * 0.5 + 0.5;
	scanline = pow(scanline, 0.4);
	color.rgb *= mix(1.0, scanline, scanline_intensity);

	COLOR = color;
}
