shader_type canvas_item;
// Octopath-style post stack: tilt-shift depth of field (sharp focus band,
// blurred top/bottom), lens vignette, faint film grain, frost creeping in
// from the screen edges, and a slow volumetric-ish fog drift.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float dof_amount : hint_range(0.0, 1.0) = 0.45;
uniform float focus_y : hint_range(0.0, 1.0) = 0.55;
uniform float focus_height : hint_range(0.05, 0.6) = 0.26;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.32;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.035;
uniform float frost_amount : hint_range(0.0, 1.0) = 0.0;
uniform float fog_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 fog_color = vec3(0.82, 0.88, 0.95);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// Tilt-shift: blur scales with distance from the focus band.
	float band = smoothstep(0.0, focus_height, abs(uv.y - focus_y));
	float blur = band * dof_amount * 4.5;
	vec3 col = textureLod(screen_tex, uv, blur).rgb;

	// Volumetric-ish fog: two drifting noise octaves, denser toward the top.
	if (fog_amount > 0.001) {
		float drift = noise(uv * 6.0 + vec2(TIME * 0.04, TIME * 0.013));
		drift += 0.5 * noise(uv * 14.0 - vec2(TIME * 0.022, 0.0));
		float density = fog_amount * drift * (0.25 + 0.75 * (1.0 - uv.y));
		col = mix(col, fog_color, clamp(density * 0.5, 0.0, 0.6));
	}

	// Frost: crystalline brightening that climbs in from the borders.
	if (frost_amount > 0.001) {
		float edge = 1.0 - smoothstep(0.0, 0.42, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
		float crystals = noise(uv * 38.0) * 0.6 + noise(uv * 90.0) * 0.4;
		float frost = edge * frost_amount * smoothstep(0.45, 0.95, crystals + edge * 0.35);
		col = mix(col, vec3(0.87, 0.94, 1.0), clamp(frost, 0.0, 0.75));
	}

	// Lens vignette + breathing grain.
	float vig = distance(uv, vec2(0.5)) * 1.35;
	col *= 1.0 - vignette_strength * vig * vig;
	col += (hash(uv * vec2(1280.0, 720.0) + vec2(TIME * 60.0)) - 0.5) * grain_strength;

	COLOR = vec4(col, 1.0);
}
