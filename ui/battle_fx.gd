class_name BattleFX
extends RefCounted
## Procedural battle effects: spawn-and-forget nodes (particles, slashes,
## floating numbers) parented to the battle scene. No art assets required;
## everything is primitives + CPUParticles2D, tuned per element.

const HURT_COLOR: Color = Color(1.0, 0.92, 0.85)
const CRIT_COLOR: Color = Color(1.0, 0.85, 0.25)
const HEAL_COLOR: Color = Color(0.45, 1.0, 0.55)

## Adult-violence toggle (Options menu). Off = no blood, everything else stays.
static var blood_enabled: bool = true


## Crimson spray on physical wounds; big version for crits and kills.
static func blood_spray(parent: Node, pos: Vector2, big: bool = false) -> void:
	if not blood_enabled:
		return
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.position = pos + Vector2(0, -10)
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.6
	particles.amount = 34 if big else 18
	particles.spread = 70.0
	particles.direction = Vector2(0, -1)
	particles.gravity = Vector2(0, 540)
	particles.initial_velocity_min = 90.0 if big else 50.0
	particles.initial_velocity_max = 220.0 if big else 130.0
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.5 if big else 2.5
	particles.color = Color(0.62, 0.04, 0.04)
	particles.z_index = 44
	parent.add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


## A dark stain that lingers on the ground, then soaks away.
static func blood_pool(parent: Node, pos: Vector2) -> void:
	if not blood_enabled:
		return
	var pool: Node2D = Node2D.new()
	pool.position = pos + Vector2(randf_range(-8.0, 8.0), 36.0)
	pool.z_index = 5
	pool.draw.connect(func() -> void:
		pool.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.30))
		pool.draw_circle(Vector2.ZERO, 30.0, Color(0.40, 0.02, 0.02, 0.75))
		pool.draw_circle(Vector2(14, 6), 12.0, Color(0.40, 0.02, 0.02, 0.7)))
	parent.add_child(pool)
	var tween: Tween = pool.create_tween()
	tween.tween_interval(6.0)
	tween.tween_property(pool, "modulate:a", 0.0, 3.0)
	tween.tween_callback(pool.queue_free)


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


## --- anime-scale spell staging: light layered on light ------------------------

const ELEMENT_GLOW: Dictionary = {
	"Fire": Color(1.0, 0.45, 0.12),
	"Ice": Color(0.45, 0.8, 1.0),
	"Dark": Color(0.66, 0.3, 0.95),
	"Neutral": Color(0.95, 0.92, 0.8),
}


static func _additive() -> CanvasItemMaterial:
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


## The full spectacle: light gathers on the caster, a pillar of the element
## crashes down from above the target, rings of light race across the ground
## beneath them, and a storm of motes erupts. `big` = Echo scale.
static func spell_cinematic(
	parent: Node, caster_pos: Vector2, target_pos: Vector2, element: String, big: bool = false
) -> void:
	caster_aura(parent, caster_pos, element)
	sky_pillar(parent, target_pos, element, big)
	ground_rings(parent, target_pos, element, big)
	elemental_storm(parent, target_pos, element, big)


static func caster_aura(parent: Node, pos: Vector2, element: String) -> void:
	var glow: Color = ELEMENT_GLOW.get(element, ELEMENT_GLOW["Neutral"])
	var aura: CPUParticles2D = CPUParticles2D.new()
	aura.position = pos
	aura.material = _additive()
	aura.one_shot = true
	aura.explosiveness = 0.25
	aura.lifetime = 0.7
	aura.amount = 30
	aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 36.0
	aura.gravity = Vector2(0, -220)
	aura.initial_velocity_min = 15.0
	aura.initial_velocity_max = 55.0
	aura.scale_amount_min = 2.5
	aura.scale_amount_max = 5.0
	aura.color = glow
	aura.z_index = 46
	parent.add_child(aura)
	aura.emitting = true
	aura.finished.connect(aura.queue_free)


static func sky_pillar(parent: Node, target_pos: Vector2, element: String, big: bool) -> void:
	var glow: Color = ELEMENT_GLOW.get(element, ELEMENT_GLOW["Neutral"])
	var width: float = 150.0 if big else 100.0
	var pillar: ColorRect = ColorRect.new()
	pillar.material = _additive()
	pillar.color = Color(glow, 0.0)
	pillar.size = Vector2(width, 470.0)
	pillar.position = target_pos + Vector2(-width / 2.0, -470.0)
	pillar.pivot_offset = Vector2(width / 2.0, 470.0)
	pillar.scale = Vector2(0.12, 1.0)
	pillar.z_index = 43
	parent.add_child(pillar)
	var tween: Tween = pillar.create_tween()
	tween.set_parallel(true)
	tween.tween_property(pillar, "color:a", 0.75 if big else 0.55, 0.12)
	tween.tween_property(pillar, "scale:x", 1.0, 0.22)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(0.28 if big else 0.16)
	tween.chain().tween_property(pillar, "color:a", 0.0, 0.4)
	tween.chain().tween_callback(pillar.queue_free)


static func ground_rings(parent: Node, target_pos: Vector2, element: String, big: bool) -> void:
	var glow: Color = ELEMENT_GLOW.get(element, ELEMENT_GLOW["Neutral"])
	var ring_count: int = 3 if big else 2
	for i: int in range(ring_count):
		var ring: Node2D = Node2D.new()
		ring.position = target_pos + Vector2(0, 30)
		ring.z_index = 42
		var radius: Array[float] = [12.0]
		ring.draw.connect(func() -> void:
			ring.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.34))
			ring.draw_arc(Vector2.ZERO, radius[0], 0.0, TAU, 40, Color(glow, 0.9), 5.0))
		parent.add_child(ring)
		ring.material = _additive()
		var max_radius: float = (190.0 if big else 130.0) + i * 26.0
		var tween: Tween = ring.create_tween()
		tween.tween_interval(0.12 * i)
		tween.tween_method(func(value: float) -> void:
			radius[0] = value
			ring.queue_redraw(), 12.0, max_radius, 0.5)
		tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.62).set_delay(0.12 * i)
		tween.tween_callback(ring.queue_free)


static func elemental_storm(
	parent: Node, target_pos: Vector2, element: String, big: bool
) -> void:
	var glow: Color = ELEMENT_GLOW.get(element, ELEMENT_GLOW["Neutral"])
	var storm: CPUParticles2D = CPUParticles2D.new()
	storm.position = target_pos
	storm.material = _additive()
	storm.one_shot = true
	storm.explosiveness = 0.85
	storm.lifetime = 0.95
	storm.amount = 110 if big else 70
	storm.spread = 180.0
	storm.gravity = Vector2(0, -170) if element == "Fire" else Vector2(0, 260)
	storm.initial_velocity_min = 120.0
	storm.initial_velocity_max = 300.0 if big else 240.0
	storm.scale_amount_min = 2.5
	storm.scale_amount_max = 7.0 if big else 5.5
	storm.color = glow
	storm.z_index = 45
	parent.add_child(storm)
	storm.emitting = true
	storm.finished.connect(storm.queue_free)


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
