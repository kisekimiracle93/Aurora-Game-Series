shader_type canvas_item;
// Pixelated flowing water: chunky UV waves, drifting sparkle, cool sheen.

uniform float pixel_size : hint_range(1.0, 12.0) = 4.0;
uniform float wave_strength : hint_range(0.0, 0.05) = 0.012;
uniform float flow_speed : hint_range(0.0, 3.0) = 0.7;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// Snap UVs so the waves move in pixel steps, not smooth smears.
	vec2 px = vec2(pixel_size) * TEXTURE_PIXEL_SIZE;
	vec2 uv = floor(UV / px) * px;
	uv.x += sin(uv.y * 90.0 + TIME * flow_speed * 2.2) * wave_strength;
	uv.y += TIME * flow_speed * 0.05;
	vec4 col = texture(TEXTURE, fract(uv));
	// Drifting sparkle crests.
	float sparkle = step(0.985, hash(floor(uv * 64.0) + floor(vec2(TIME * 2.0))));
	col.rgb += sparkle * 0.5;
	col.rgb = mix(col.rgb, vec3(0.65, 0.85, 1.0), 0.18);
	COLOR = col;
}
