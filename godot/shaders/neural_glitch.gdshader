// neural_glitch.gdshader
// Neural Link feedback shader — driven by on_tether_strained signal.
// Attach as ShaderMaterial on a full-viewport ColorRect (CanvasLayer Z=100).
// interference_strength: 0.0 = clear, 1.0 = fully severed/chaotic.
shader_type canvas_item;

uniform float interference_strength : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;

	// Pixel Displacement — horizontal scanline shifting at high interference
	float shift_strength = interference_strength * 0.007;
	float line = floor(uv.y * 180.0);
	float rand = fract(sin(line * 127.1 + TIME * 3.7) * 43758.5);
	if (rand > (1.0 - interference_strength * 0.45)) {
		uv.x += (rand - 0.5) * shift_strength * 5.0;
	}
	uv = clamp(uv, vec2(0.0), vec2(1.0));

	// Chromatic Aberration — R/B channel separation toward screen edges
	float aberration = interference_strength * 0.009;
	float r = texture(SCREEN_TEXTURE, uv + vec2(aberration, 0.0)).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv - vec2(aberration, 0.0)).b;

	// Vignette — darkens corners, intensifies with interference
	vec2 center = uv - 0.5;
	float vignette = 1.0 - dot(center, center) * interference_strength * 4.0;

	vec4 color = vec4(r, g, b, 1.0);
	color.rgb *= clamp(vignette, 0.0, 1.0);

	COLOR = color;
}
