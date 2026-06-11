class_name BattleFX
extends RefCounted
## Procedural battle effects: spawn-and-forget nodes (particles, slashes,
## floating numbers) parented to the battle scene. No art assets required;
## everything is primitives + CPUParticles2D, tuned per element.

const HURT_COLOR: Color = Color(1.0, 0.92, 0.85)
const CRIT_COLOR: Color = Color(1.0, 0.85, 0.25)
const HEAL_COLOR: Color = Color(0.45, 1.0, 0.55)


## Floating combat number (damage = warm white, crit = gold, heal = green).
static func damage_number(parent: Node, pos: Vector2, amount: int, kind: String = "hurt") -> void:
	var label: Label = Label.new()
	label.text = ("+%d" % amount) if kind == "heal" else str(amount)
	label.add_theme_font_size_override("font_size", 26 if kind == "crit" else 20)
	label.modulate = {"hurt": HURT_COLOR, "crit": CRIT_COLOR, "heal": HEAL_COLOR}.get(kind, HURT_COLOR)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.position = pos + Vector2(randf_range(-14.0, 14.0) - 16.0, -54.0)
	label.z_index = 50
	parent.add_child(label)
	var tween: Tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 44.0, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)


## Big floating word: MISS, CRITICAL!, status names, DELAYED...
static func text_pop(parent: Node, pos: Vector2, text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = color
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.position = pos + Vector2(-30.0, -76.0)
	label.z_index = 50
	parent.add_child(label)
	var tween: Tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 26.0, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tween.chain().tween_callback(label.queue_free)


## Physical hit: three quick slash streaks across the target.
static func slash(parent: Node, pos: Vector2) -> void:
	for i: int in range(3):
		var streak: ColorRect = ColorRect.new()
		streak.color = Color(1, 1, 1, 0.9)
		streak.size = Vector2(64.0, 3.0)
		streak.position = pos + Vector2(-32.0, -34.0 + i * 18.0 + randf_range(-4.0, 4.0))
		streak.rotation_degrees = -28.0
		streak.z_index = 40
		parent.add_child(streak)
		var tween: Tween = streak.create_tween()
		tween.tween_interval(0.05 * i)
		tween.tween_property(streak, "position", streak.position + Vector2(26.0, 14.0), 0.16)
		tween.parallel().tween_property(streak, "modulate:a", 0.0, 0.16)
		tween.tween_callback(streak.queue_free)


## Elemental burst at the target. element: "Fire" | "Ice" | "Neutral" | "Dark".
static func elemental_burst(parent: Node, pos: Vector2, element: String) -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.position = pos
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 0.55
	particles.amount = 26
	particles.spread = 180.0
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 150.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.5
	particles.z_index = 45
	match element:
		"Fire":
			particles.color = Color(1.0, 0.45, 0.1)
			particles.gravity = Vector2(0, -160)  # embers rise
		"Ice":
			particles.color = Color(0.55, 0.85, 1.0)
			particles.gravity = Vector2(0, 220)  # shards fall
		"Dark":
			particles.color = Color(0.62, 0.3, 0.9)
			particles.gravity = Vector2(0, -60)
		_:
			particles.color = Color(0.95, 0.95, 0.9)
			particles.gravity = Vector2(0, 80)
	parent.add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


## Rising sparkles for heals / Pray.
static func heal_sparkle(parent: Node, pos: Vector2, color: Color = HEAL_COLOR) -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.position = pos + Vector2(0, 20)
	particles.one_shot = true
	particles.explosiveness = 0.4
	particles.lifetime = 0.8
	particles.amount = 18
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 26.0
	particles.gravity = Vector2(0, -140)
	particles.initial_velocity_min = 10.0
	particles.initial_velocity_max = 40.0
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0
	particles.color = color
	particles.z_index = 45
	parent.add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


## Expanding shield ring for Guard.
static func guard_ring(parent: Node, pos: Vector2) -> void:
	var ring: CPUParticles2D = CPUParticles2D.new()
	ring.position = pos
	ring.one_shot = true
	ring.explosiveness = 1.0
	ring.lifetime = 0.45
	ring.amount = 22
	ring.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	ring.emission_sphere_radius = 30.0
	ring.gravity = Vector2.ZERO
	ring.initial_velocity_min = 35.0
	ring.initial_velocity_max = 45.0
	ring.scale_amount_min = 2.0
	ring.scale_amount_max = 3.0
	ring.color = Color(0.5, 0.75, 1.0)
	ring.z_index = 45
	parent.add_child(ring)
	ring.emitting = true
	ring.finished.connect(ring.queue_free)


## Echo unleash: big two-stage radial burst + flash.
static func echo_burst(parent: Node, pos: Vector2, element: String) -> void:
	elemental_burst(parent, pos, element)
	var flash: CPUParticles2D = CPUParticles2D.new()
	flash.position = pos
	flash.one_shot = true
	flash.explosiveness = 1.0
	flash.lifetime = 0.7
	flash.amount = 40
	flash.spread = 180.0
	flash.gravity = Vector2.ZERO
	flash.initial_velocity_min = 160.0
	flash.initial_velocity_max = 260.0
	flash.scale_amount_min = 3.0
	flash.scale_amount_max = 6.0
	flash.color = Color(1.0, 0.97, 0.8)
	flash.z_index = 46
	parent.add_child(flash)
	flash.emitting = true
	flash.finished.connect(flash.queue_free)


## Quick positional jitter for heavy hits.
static func shake(node: Node2D, strength: float = 7.0) -> void:
	var origin: Vector2 = node.position
	var tween: Tween = node.create_tween()
	for i: int in range(4):
		tween.tween_property(
			node,
			"position",
			origin + Vector2(randf_range(-strength, strength), randf_range(-strength, strength)),
			0.04
		)
	tween.tween_property(node, "position", origin, 0.05)
