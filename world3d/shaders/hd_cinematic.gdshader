shader_type canvas_item;
// Cinematic post for the HD-2D world: tilt-shift depth blur (the Octopath
// "miniature diorama" signature), filmic vignette, subtle chromatic
// aberration at the edges, warm/cool split-tone grade, and animated film
// grain. Runs full-screen over the 3D viewport.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float focus_band : hint_range(0.0, 1.0) = 0.58;   // screen-y in sharp focus
uniform float focus_width : hint_range(0.05, 1.0) = 0.62; // how tall the sharp band is
uniform float blur_strength : hint_range(0.0, 4.0) = 0.7;
uniform float vignette : hint_range(0.0, 1.5) = 0.28;
uniform float aberration : hint_range(0.0, 4.0) = 0.5;
uniform float grain : hint_range(0.0, 0.2) = 0.022;
uniform vec3 lift_warm : source_color = vec3(1.03, 1.0, 0.95);
uniform vec3 gamma_cool : source_color = vec3(0.97, 1.0, 1.04);
uniform float saturation : hint_range(0.0, 2.0) = 1.12;

float blur_amount(vec2 uv) {
	float d = abs(uv.y - focus_band);
	return clamp((d - focus_width * 0.5) / focus_width, 0.0, 1.0);
}

vec3 sample_blurred(vec2 uv, float amt, vec2 texel) {
	if (amt < 0.01) {
		return texture(screen_texture, uv).rgb;
	}
	vec2 px = texel * amt * blur_strength * 2.4;
	vec3 sum = texture(screen_texture, uv).rgb * 0.227;
	sum += texture(screen_texture, uv + vec2(px.x, 0.0)).rgb * 0.19;
	sum += texture(screen_texture, uv - vec2(px.x, 0.0)).rgb * 0.19;
	sum += texture(screen_texture, uv + vec2(0.0, px.y)).rgb * 0.19;
	sum += texture(screen_texture, uv - vec2(0.0, px.y)).rgb * 0.19;
	sum += texture(screen_texture, uv + px * 1.5).rgb * 0.012;
	sum += texture(screen_texture, uv - px * 1.5).rgb * 0.012;
	return sum;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 texel = vec2(1.0) / vec2(textureSize(screen_texture, 0));
	float amt = blur_amount(uv);

	// Chromatic aberration grows toward the edges, on top of the blur.
	vec2 dir = uv - vec2(0.5);
	float edge = dot(dir, dir);
	vec2 ca = dir * edge * aberration * texel * 6.0 * (0.4 + amt);
	vec3 col;
	col.r = sample_blurred(uv + ca, amt, texel).r;
	col.g = sample_blurred(uv, amt, texel).g;
	col.b = sample_blurred(uv - ca, amt, texel).b;

	// Split-tone grade: warm lift in shadows, cool in highlights.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col *= mix(lift_warm, gamma_cool, smoothstep(0.2, 0.8, luma));
	col = mix(vec3(luma), col, saturation);

	// Filmic vignette.
	float vig = smoothstep(0.8, 0.2, length(dir) * (1.0 + vignette));
	col *= mix(1.0 - vignette, 1.0, vig);

	// Animated film grain.
	float n = fract(sin(dot(uv * vec2(1.0 + TIME), vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * grain;

	COLOR = vec4(col, 1.0);
}
