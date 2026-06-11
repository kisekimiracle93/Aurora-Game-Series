shader_type canvas_item;
// Aurora curtain for the title sky: emerald light overtaken by a moody,
// evil red in slow cycles. Pure math — no textures required.

uniform float cycle_seconds = 16.0;
uniform float intensity = 0.9;

void fragment() {
	float t = TIME;
	// Drifting curtains: two interfering band frequencies + a slow sway.
	float sway = sin(t * 0.18) * 0.35;
	float band1 = sin((UV.x + sway) * 12.6 + t * 0.45) * 0.5 + 0.5;
	float band2 = sin((UV.x - sway * 0.6) * 31.4 - t * 0.27 + UV.y * 4.0) * 0.5 + 0.5;
	float band3 = sin(UV.x * 7.0 + t * 0.12) * 0.5 + 0.5;
	// Curtains hang from the top of the sky and fade downward.
	float hang = pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.7);
	float curtain = hang * (0.25 + 0.75 * band1 * mix(band2, band3, 0.5));

	// The cycle: shimmering emerald -> dark evil red, and back.
	float phase = sin(t * 6.28318 / cycle_seconds) * 0.5 + 0.5;
	phase = smoothstep(0.15, 0.85, phase);
	vec3 emerald = vec3(0.08, 0.95, 0.52);
	vec3 blood = vec3(0.72, 0.05, 0.10);
	vec3 col = mix(emerald, blood, phase);
	// Red phase reads angrier: slightly dimmer, higher contrast.
	col *= mix(1.0, 0.85, phase);

	COLOR = vec4(col * curtain * intensity, curtain * 0.85 * intensity);
}
