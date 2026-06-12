shader_type canvas_item;
// Wind for trees and grass: the crown sways, the roots stay planted.

uniform float sway_strength : hint_range(0.0, 12.0) = 4.0;
uniform float sway_speed : hint_range(0.0, 4.0) = 1.1;

void vertex() {
	float anchor = 1.0 - UV.y;  // 1 at the top of the sprite, 0 at the base
	float phase = VERTEX.x * 0.02 + VERTEX.y * 0.013;
	VERTEX.x += sin(TIME * sway_speed + phase) * sway_strength * anchor * anchor;
}
