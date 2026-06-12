class_name AreaBase
extends Node2D
## Shared scaffold for walkable areas (town / forest / fields / dungeon):
## bounds + follow camera, the player avatar, exits, interactables with an
## E/A prompt, dialog/choices, chests, roamers, save crystals, torches that
## ignite at night, ambient life (dust, butterflies, fireflies, god rays,
## cloud shadows), bubble-talk vignettes, and a corner minimap. The whole
## walkable plane Y-sorts, so everyone can pass BEHIND houses, trees, and
## the castle.

const SCREEN: Vector2 = Vector2(1280, 720)
## The z plane everything walkable/standable shares; Y position decides draw
## order inside it (feet-anchored), so sprites overlap like a real street.
const SORT_Z: int = 5

var player: PlayerAvatar
var area_name: String = ""
var music_track: String = ""
## Soundscape profile ("town"/"forest"/"fields"/"dungeon"/"interior"/"").
var ambience_profile: String = ""
## Maps larger than the screen get a follow camera clamped to these bounds.
var map_size: Vector2 = Vector2(1280, 720)
## Where a fresh visit drops the player when no return position is queued.
var default_spawn: Vector2 = Vector2.INF
## Interiors opt out so popping into a house doesn't smudge the travel trail.
var tracks_on_map: bool = true

## Random encounters (legacy): rolls a battle every N walked pixels.
var encounters_enabled: bool = false
var encounter_rosters: Array[String] = []
var _steps_until_encounter: float = 0.0

var _prompt: Label
var _dialog: PanelContainer
var _dialog_label: Label
var _dialog_lines: Array[String] = []
var _choice_box: VBoxContainer
var _active_interactable: Dictionary = {}
var _interactables: Array[Dictionary] = []  # {"area": Area2D, "prompt": String, "callback": Callable}
var _hud_layer: CanvasLayer  # prompts/dialog/minimap ride above the postfx lens
## Lens mood for this area (PostFX): frost at the screen edges, fog drift.
var frost_level: float = 0.0
var fog_level: float = 0.0
## Ambient-life dials (the deep woods turns these up).
var firefly_scale: float = 1.0
var cloud_density: float = 1.0

## Minimap bookkeeping (filled by the add_* helpers).
var _exit_rects: Array[Rect2] = []
var _save_points: Array[Vector2] = []
var _chest_points: Array[Vector2] = []
var _minimap: Control

## Day/night-reactive decor.
var _fireflies: GPUParticles2D
var _butterflies: Array[Node2D] = []
var _rays: Array[Polygon2D] = []
var _clouds: Node2D


func _ready() -> void:
	y_sort_enabled = true
	_build_common()
	_setup_area()  # scenes override
	var world: Node = get_node_or_null("/root/WorldState")
	if world != null and tracks_on_map:
		world.note_area_visit(scene_file_path)
	var atmosphere: Node = get_node_or_null("/root/Atmosphere")
	if atmosphere != null:
		atmosphere.apply_to_area(self)
		atmosphere.night_changed.connect(_on_night_changed)
	_play_area_music()
	var soundscape: Node = get_node_or_null("/root/Soundscape")
	if soundscape != null:
		soundscape.set_scene_profile(ambience_profile)
	var postfx: Node = get_node_or_null("/root/PostFX")
	if postfx != null:
		postfx.mood_world(frost_level, fog_level)
	_build_sky_layer()
	_build_ambient_life()
	var night_now: bool = atmosphere != null and atmosphere.is_night()
	_set_torches_lit(night_now)
	_apply_night_decor(night_now)
	_build_minimap()
	_arm_encounter()


## Each area carries a day theme and an optional night variant (<track>_night).
func _play_area_music() -> void:
	if music_track == "":
		return
	var music: Node = get_node_or_null("/root/MusicManager")
	if music == null:
		return
	var atmosphere: Node = get_node_or_null("/root/Atmosphere")
	var pick: String = music_track
	if atmosphere != null and atmosphere.is_night():
		if AssetLibrary.music_stream(music_track + "_night") != null:
			pick = music_track + "_night"
	music.play_track(pick)


func _on_night_changed(now_night: bool) -> void:
	_play_area_music()
	_set_torches_lit(now_night)
	_apply_night_decor(now_night)


func _set_torches_lit(lit: bool) -> void:
	for torch_light: Node in get_tree().get_nodes_in_group("torch_light"):
		if not torch_light is PointLight2D:
			continue
		var light: PointLight2D = torch_light as PointLight2D
		if light.has_meta("flicker"):
			var old: Tween = light.get_meta("flicker")
			if old != null and old.is_valid():
				old.kill()
			light.remove_meta("flicker")
		var tween: Tween = light.create_tween()
		tween.tween_property(light, "energy", 1.65 if lit else 0.0, 1.4)
		if lit:
			tween.tween_callback(func() -> void:
				var flicker: Tween = light.create_tween().set_loops()
				flicker.tween_property(light, "energy", 1.35, randf_range(0.10, 0.22))
				flicker.tween_property(light, "energy", 1.65, randf_range(0.10, 0.22))
				light.set_meta("flicker", flicker))
	for glow: Node in get_tree().get_nodes_in_group("torch_glow"):
		if glow is CanvasItem:
			var tween: Tween = (glow as CanvasItem).create_tween()
			tween.tween_property(glow, "modulate:a", 0.85 if lit else 0.0, 1.4)


func _apply_night_decor(night: bool) -> void:
	if _fireflies != null:
		_fireflies.emitting = night
	for butterfly: Node2D in _butterflies:
		if is_instance_valid(butterfly):
			var tween: Tween = butterfly.create_tween()
			tween.tween_property(butterfly, "modulate:a", 0.0 if night else 1.0, 2.0)
	for ray: Polygon2D in _rays:
		if is_instance_valid(ray):
			ray.color = (
				Color(0.72, 0.80, 1.0, 0.085) if night else Color(1.0, 0.95, 0.72, 0.115)
			)
	if _clouds != null:
		_clouds.modulate.a = 1.35 if night else 1.0


## Scenes override this to build their geometry and content.
func _setup_area() -> void:
	pass


func _build_common() -> void:
	player = PlayerAvatar.new()
	player.z_index = SORT_Z
	add_child(player)
	player.position = _spawn_position()
	player.stepped.connect(_on_player_stepped)

	# Map-edge walls + follow camera for maps bigger than the screen.
	for bounds: Rect2 in [
		Rect2(-40, 0, 40, map_size.y), Rect2(map_size.x, 0, 40, map_size.y),
		Rect2(0, -40, map_size.x, 40), Rect2(0, map_size.y, map_size.x, 40),
	]:
		add_wall(bounds)
	var camera: Camera2D = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map_size.x)
	camera.limit_bottom = int(map_size.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	player.add_child(camera)
	camera.make_current()

	# UI rides a CanvasLayer ABOVE the postfx lens so it stays crisp.
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 80
	add_child(_hud_layer)

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 16)
	_prompt.position = Vector2(0, 612)
	_prompt.size = Vector2(SCREEN.x, 24)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	_hud_layer.add_child(_prompt)

	_dialog = PanelContainer.new()
	_dialog.position = Vector2(240, 540)
	_dialog.custom_minimum_size = Vector2(800, 0)
	_dialog.visible = false
	_hud_layer.add_child(_dialog)
	var dialog_stack: VBoxContainer = VBoxContainer.new()
	dialog_stack.add_theme_constant_override("separation", 8)
	_dialog.add_child(dialog_stack)
	_dialog_label = Label.new()
	_dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_label.add_theme_font_size_override("font_size", 16)
	dialog_stack.add_child(_dialog_label)
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 6)
	dialog_stack.add_child(_choice_box)

	var title: Label = Label.new()
	title.text = area_name + "      ·      [C] menu"
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color(0.85, 0.85, 0.9)
	title.position = Vector2(16, 10)
	_hud_layer.add_child(title)


func _spawn_position() -> Vector2:
	var world: Node = get_node_or_null("/root/WorldState")
	if world != null and world.has_return_position:
		world.has_return_position = false
		return world.return_position
	return default_spawn if default_spawn != Vector2.INF else SCREEN / 2.0


## --- building blocks for scenes ----------------------------------------------


func add_rect(rect: Rect2, color: Color, z: int = 0) -> ColorRect:
	var block: ColorRect = ColorRect.new()
	block.color = color
	block.position = rect.position
	block.size = rect.size
	block.z_index = z
	add_child(block)
	return block


func add_wall(rect: Rect2) -> void:
	var wall: StaticBody2D = StaticBody2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	wall.position = rect.position + rect.size / 2.0
	wall.add_child(shape)
	add_child(wall)


## A sprite prop on the walkable plane, anchored at its FEET so Y-sorting
## reads true: stand above it -> you vanish behind it; below -> you're in front.
## `pos` stays the visual CENTER (back-compatible with the old call sites).
func add_prop(
	prop_name: String, pos: Vector2, prop_scale: float = 2.0,
	solid: bool = true, sway: bool = false
) -> Node2D:
	var art: Texture2D = AssetLibrary.texture("props", prop_name)
	if art == null:
		return null
	var half_height: float = art.get_size().y * prop_scale / 2.0
	var anchor: Node2D = Node2D.new()
	anchor.position = pos + Vector2(0.0, half_height - 8.0)
	anchor.z_index = SORT_Z
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = art
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(prop_scale, prop_scale)
	sprite.position = Vector2(0.0, -(half_height - 8.0))
	if sway:
		sprite.material = AssetLibrary.foliage_material()
	anchor.add_child(sprite)
	add_child(anchor)
	if solid:
		var size: Vector2 = art.get_size() * prop_scale
		# Collide with the trunk/base band, not the crown — you can walk behind.
		var body: Vector2 = Vector2(size.x * 0.62, size.y * 0.30)
		add_wall(Rect2(pos + Vector2(-body.x / 2.0, size.y / 2.0 - body.y), body))
	return anchor


## Solid scenery: a colored block the player collides with.
func add_building(rect: Rect2, color: Color, _label_text: String = "") -> void:
	# (Building names live on the minimap now, not floating in the world.)
	add_rect(rect, color, 2)
	add_wall(rect)
	add_occluder(rect)


## Sun-shadow caster matching a solid's footprint.
func add_occluder(rect: Rect2) -> void:
	var occluder: LightOccluder2D = LightOccluder2D.new()
	var poly: OccluderPolygon2D = OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2.ZERO, Vector2(rect.size.x, 0), rect.size, Vector2(0, rect.size.y)
	])
	occluder.occluder = poly
	occluder.position = rect.position
	add_child(occluder)


## A warm (or cold) glow that bites at night: lanterns, crystals, fires.
func add_point_light(
	pos: Vector2, color: Color, light_scale: float = 1.6, energy: float = 0.9
) -> PointLight2D:
	var light: PointLight2D = PointLight2D.new()
	light.texture = load("res://assets/sprites/ui/light_radial.png")
	light.position = pos
	light.color = color
	light.energy = energy
	light.texture_scale = light_scale
	light.shadow_enabled = true
	light.shadow_color = Color(0, 0, 0.05, 0.4)
	add_child(light)
	var flicker: Tween = light.create_tween().set_loops()
	flicker.tween_property(light, "energy", energy * 0.82, randf_range(0.7, 1.3))
	flicker.tween_property(light, "energy", energy, randf_range(0.7, 1.3))
	return light


## Soft contact-darkening under big shapes (the cheap seat's SSAO).
func add_ground_shadow(pos: Vector2, width: float) -> void:
	var shadow: Sprite2D = Sprite2D.new()
	shadow.texture = load("res://assets/sprites/ui/light_radial.png")
	shadow.modulate = Color(0, 0, 0, 0.30)
	shadow.scale = Vector2(width / 256.0, width / 256.0 * 0.34)
	shadow.position = pos
	shadow.z_index = 1
	add_child(shadow)


## GPU snowfall across the whole map.
func add_snowfall(amount: int = 300) -> void:
	var snow: GPUParticles2D = GPUParticles2D.new()
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(map_size.x / 2.0, 12.0, 1.0)
	material.direction = Vector3(0.18, 1.0, 0.0)
	material.spread = 12.0
	material.gravity = Vector3(6.0, 38.0, 0.0)
	material.initial_velocity_min = 18.0
	material.initial_velocity_max = 46.0
	material.scale_min = 1.2
	material.scale_max = 2.6
	material.color = Color(0.96, 0.98, 1.0, 0.85)
	snow.process_material = material
	snow.amount = amount
	snow.lifetime = map_size.y / 40.0
	snow.preprocess = snow.lifetime
	snow.position = Vector2(map_size.x / 2.0, -20.0)
	snow.visibility_rect = Rect2(-map_size.x / 2.0, -40.0, map_size.x, map_size.y + 80.0)
	snow.z_index = 50
	add_child(snow)


## A standing torch on a stone base; ignites itself when night falls.
func add_torch(pos: Vector2) -> void:
	var torch: Node2D = Node2D.new()
	torch.position = pos + Vector2(0, 14)  # foot anchor for the y-sort
	torch.z_index = SORT_Z
	torch.draw.connect(func() -> void:
		# Stone footing, iron-banded pole, head basket.
		torch.draw_circle(Vector2(-7, 12), 6.0, Color(0.42, 0.43, 0.47))
		torch.draw_circle(Vector2(7, 12), 6.0, Color(0.38, 0.39, 0.43))
		torch.draw_circle(Vector2(0, 14), 7.0, Color(0.46, 0.47, 0.51))
		torch.draw_rect(Rect2(-3, -26, 6, 40), Color(0.30, 0.21, 0.13))
		torch.draw_rect(Rect2(-4, -6, 8, 3), Color(0.2, 0.2, 0.24))
		torch.draw_rect(Rect2(-6, -30, 12, 6), Color(0.25, 0.25, 0.3))
		torch.draw_circle(Vector2(0, -32), 7.5, Color(1.0, 0.58, 0.14))
		torch.draw_circle(Vector2(0, -36), 4.5, Color(1.0, 0.86, 0.42)))
	add_child(torch)
	var embers: CPUParticles2D = CPUParticles2D.new()
	embers.position = Vector2(0, -34)
	embers.amount = 14
	embers.lifetime = 1.1
	embers.spread = 16.0
	embers.direction = Vector2(0, -1)
	embers.gravity = Vector2(0, -85)
	embers.initial_velocity_min = 6.0
	embers.initial_velocity_max = 22.0
	embers.scale_amount_min = 1.0
	embers.scale_amount_max = 2.4
	embers.color = Color(1.0, 0.7, 0.25, 0.85)
	torch.add_child(embers)
	# Warm halo sprite (additive) that breathes in when lit.
	var halo: Sprite2D = Sprite2D.new()
	halo.texture = load("res://assets/sprites/ui/light_radial.png")
	halo.position = Vector2(0, -33)
	halo.scale = Vector2(0.30, 0.30)
	halo.modulate = Color(1.0, 0.62, 0.22, 0.0)
	var halo_material: CanvasItemMaterial = CanvasItemMaterial.new()
	halo_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = halo_material
	halo.add_to_group("torch_glow")
	torch.add_child(halo)
	var light: PointLight2D = PointLight2D.new()
	light.texture = load("res://assets/sprites/ui/light_radial.png")
	light.position = Vector2(0, -32)
	light.color = Color(1.0, 0.66, 0.27)
	light.energy = 0.0  # dawn state; night ignites it
	light.texture_scale = 1.55
	light.shadow_enabled = true
	light.add_to_group("torch_light")
	torch.add_child(light)


## A long wooden waypost gate spanning the road (cosmetic, walk straight
## through): pillars at the ends and middles, a full crossbeam, hanging
## pennants, and a lantern glow at each post after dark.
func add_road_gate(center: Vector2, width: float = 260.0) -> void:
	var art: Texture2D = AssetLibrary.texture("props", "posts")
	var pillar_count: int = maxi(2, int(width / 130.0) + 1)
	for i: int in range(pillar_count):
		var x: float = center.x - width / 2.0 + width * float(i) / float(pillar_count - 1)
		if art != null:
			add_prop("posts", Vector2(x, center.y), 2.1, false)
		else:
			add_rect(Rect2(x - 6, center.y - 48, 12, 96), Color(0.4, 0.3, 0.2), SORT_Z)
	# The crossbeam sits ON the post tops (posts are ~84px tall at 2.1 scale).
	var beam: Node2D = Node2D.new()
	beam.position = center + Vector2(0, 40)
	beam.z_index = SORT_Z
	beam.draw.connect(func() -> void:
		beam.draw_rect(Rect2(-width / 2.0 - 14.0, -86.0, width + 28.0, 10.0), Color(0.36, 0.26, 0.16))
		beam.draw_rect(Rect2(-width / 2.0 - 14.0, -77.0, width + 28.0, 4.0), Color(0.22, 0.16, 0.10))
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = int(absf(center.x + center.y))
		var pennant: int = int(width / 64.0)
		for i: int in range(pennant):
			var x: float = -width / 2.0 + 24.0 + (width - 48.0) * float(i) / maxf(float(pennant - 1), 1.0)
			beam.draw_colored_polygon(PackedVector2Array([
				Vector2(x - 7, -76), Vector2(x + 7, -76), Vector2(x, -58),
			]), Color(0.62, 0.12, 0.14) if rng.randf() < 0.6 else Color(0.85, 0.78, 0.6)))
	add_child(beam)
	for side: float in [-1.0, 1.0]:
		add_point_light(
			center + Vector2(side * width / 2.0, -52.0), Color(1.0, 0.75, 0.4), 0.9, 0.55
		)


## A tiled sandstone-cobble road strip (falls back to a flat color band).
## A soft worn-earth fringe under it blends the stone into the grass — the
## eye finishes the edge instead of hitting a hard line.
func add_cobble_road(rect: Rect2, _vertical: bool = false) -> void:
	add_rect(rect.grow(7.0), Color(0.40, 0.33, 0.24, 0.45), -9)
	add_rect(rect.grow(14.0), Color(0.36, 0.34, 0.22, 0.18), -9)
	var art: Texture2D = AssetLibrary.texture("props", "cobble_fill")
	if art == null:
		add_rect(rect, Color(0.52, 0.44, 0.32, 0.9), -8)
		return
	var road: TextureRect = TextureRect.new()
	road.texture = art
	road.stretch_mode = TextureRect.STRETCH_TILE
	road.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	road.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	road.position = rect.position
	road.size = rect.size / 2.0
	road.scale = Vector2(2.0, 2.0)
	road.z_index = -8
	road.modulate = Color(1.0, 0.97, 0.92)
	add_child(road)


## Grass that earns its acreage: drawn tufts, clover shadows, tiny stones.
func add_grass_detail(count: int, seed_value: int = 23) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var detail: Node2D = Node2D.new()
	detail.z_index = -9
	var spots: Array = []
	for i: int in range(count):
		spots.append([
			Vector2(rng.randf_range(40, map_size.x - 40), rng.randf_range(40, map_size.y - 40)),
			rng.randi_range(0, 2), rng.randf_range(0.8, 1.5),
			Color(0.22, 0.38, 0.2, rng.randf_range(0.5, 0.9)),
		])
	detail.draw.connect(func() -> void:
		for spot: Array in spots:
			var pos: Vector2 = spot[0]
			var kind: int = spot[1]
			var spot_scale: float = spot[2]
			var tint: Color = spot[3]
			if kind == 0:  # a tuft of three blades
				for blade: int in range(3):
					var bx: float = (blade - 1) * 3.0 * spot_scale
					detail.draw_line(
						pos + Vector2(bx, 0),
						pos + Vector2(bx + (blade - 1) * 1.5, -7.0 * spot_scale),
						tint, 1.4
					)
			elif kind == 1:  # clover shadow patch
				detail.draw_circle(pos, 7.0 * spot_scale, Color(0.16, 0.3, 0.16, 0.35))
				detail.draw_circle(pos + Vector2(5, 3) * spot_scale, 5.0 * spot_scale, Color(0.18, 0.33, 0.17, 0.3))
			else:  # a pale pebble
				detail.draw_circle(pos, 2.2 * spot_scale, Color(0.7, 0.7, 0.64, 0.7))
				detail.draw_circle(pos + Vector2(0.8, 0.8), 1.4 * spot_scale, Color(0.5, 0.5, 0.46, 0.6)))
	add_child(detail)


## Shared save crystal: drain Darkness, restore Resolve, ease Burden, save.
func add_save_crystal(pos: Vector2) -> void:
	_save_points.append(pos)
	var crystal: Polygon2D = Polygon2D.new()
	crystal.polygon = PackedVector2Array([
		Vector2(0, -34), Vector2(14, 0), Vector2(0, 34), Vector2(-14, 0)
	])
	crystal.color = Color(0.45, 0.95, 1.0)
	crystal.position = pos
	crystal.z_index = SORT_Z
	add_child(crystal)
	var pulse: Tween = crystal.create_tween().set_loops()
	pulse.tween_property(crystal, "modulate:a", 0.55, 0.9)
	pulse.tween_property(crystal, "modulate:a", 1.0, 0.9)
	# A reaching beam of pale light + drifting motes: you can find it across the map.
	var beam: Sprite2D = Sprite2D.new()
	beam.texture = load("res://assets/sprites/ui/light_radial.png")
	beam.position = pos + Vector2(0, -130)
	beam.scale = Vector2(0.22, 1.6)
	beam.modulate = Color(0.55, 0.95, 1.0, 0.20)
	var beam_material: CanvasItemMaterial = CanvasItemMaterial.new()
	beam_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	beam.material = beam_material
	beam.z_index = SORT_Z
	add_child(beam)
	var beam_pulse: Tween = beam.create_tween().set_loops()
	beam_pulse.tween_property(beam, "modulate:a", 0.10, 1.6)
	beam_pulse.tween_property(beam, "modulate:a", 0.24, 1.6)
	var motes: CPUParticles2D = CPUParticles2D.new()
	motes.position = pos
	motes.amount = 14
	motes.lifetime = 2.4
	motes.preprocess = 2.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = 26.0
	motes.direction = Vector2(0, -1)
	motes.gravity = Vector2(0, -42)
	motes.initial_velocity_min = 4.0
	motes.initial_velocity_max = 16.0
	motes.scale_amount_min = 1.2
	motes.scale_amount_max = 2.2
	motes.color = Color(0.6, 0.97, 1.0, 0.8)
	motes.z_index = SORT_Z
	add_child(motes)
	add_point_light(pos, Color(0.5, 0.95, 1.0), 2.1, 1.55)
	add_interactable(pos, "Rest at the save crystal", func() -> void:
		var world: Node = get_node_or_null("/root/WorldState")
		if world == null or not world.in_world_run:
			show_dialog(["The crystal hums, but answers no one outside a true journey."])
			return
		var result: Error = world.rest_and_save(scene_file_path)
		var sfx: Node = get_node_or_null("/root/SfxManager")
		if sfx != null:
			sfx.play("heal")
		if result == OK:
			show_dialog([
				"You rest beneath the crystal's glow. Darkness drains; Resolve returns; the weight eases.",
				"Game saved.",
			])
		else:
			show_dialog(["The crystal flickers... saving failed (error %d)." % result]))


## A scatter of little drawn wildflowers (life, cheap and cheerful).
func add_flowers(positions: Array, seed_value: int = 11) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for pos: Vector2 in positions:
		var petal_color: Color = [
			Color(0.95, 0.55, 0.65), Color(0.95, 0.85, 0.4),
			Color(0.7, 0.6, 0.95), Color(0.95, 0.95, 0.95),
		][rng.randi_range(0, 3)]
		var flower: Node2D = Node2D.new()
		flower.position = pos
		flower.z_index = 1
		flower.draw.connect(func() -> void:
			for angle_index: int in range(4):
				var angle: float = TAU * float(angle_index) / 4.0
				flower.draw_circle(Vector2(cos(angle), sin(angle)) * 3.0, 2.6, petal_color)
			flower.draw_circle(Vector2.ZERO, 2.0, Color(0.95, 0.8, 0.3))
			flower.draw_rect(Rect2(-0.8, 3.0, 1.6, 6.0), Color(0.25, 0.5, 0.25)))
		add_child(flower)


## A pecking chicken on a little waddle loop. Pure charm, zero mechanics.
func add_chicken(home: Vector2) -> void:
	var hen: Node2D = Node2D.new()
	hen.position = home
	hen.z_index = SORT_Z
	hen.draw.connect(func() -> void:
		hen.draw_circle(Vector2.ZERO, 7.0, Color(0.96, 0.95, 0.9))
		hen.draw_circle(Vector2(5, -5), 4.0, Color(0.96, 0.95, 0.9))
		hen.draw_circle(Vector2(5.5, -6.5), 1.6, Color(0.85, 0.2, 0.15))
		hen.draw_rect(Rect2(8.0, -5.5, 3.0, 2.0), Color(0.95, 0.7, 0.2))
		hen.draw_rect(Rect2(-2.0, 6.0, 1.5, 4.0), Color(0.9, 0.65, 0.2))
		hen.draw_rect(Rect2(1.5, 6.0, 1.5, 4.0), Color(0.9, 0.65, 0.2)))
	add_child(hen)
	var waddle: Tween = hen.create_tween().set_loops()
	for hop: int in range(3):
		var target: Vector2 = home + Vector2(randf_range(-70, 70), randf_range(-40, 40))
		waddle.tween_property(hen, "position", target, randf_range(1.2, 2.4))
		waddle.tween_property(hen, "rotation_degrees", 8.0, 0.12)
		waddle.tween_property(hen, "rotation_degrees", 0.0, 0.12)
		waddle.tween_interval(randf_range(0.5, 1.6))
	waddle.tween_property(hen, "position", home, 1.5)


func add_exit(rect: Rect2, target_scene: String, spawn_in_target: Vector2) -> void:
	_exit_rects.append(rect)
	var zone: Area2D = _make_zone(rect)
	zone.body_entered.connect(func(body: Node2D) -> void:
		if body == player:
			var world: Node = get_node_or_null("/root/WorldState")
			if world != null:
				world.return_position = spawn_in_target
				world.has_return_position = true
			get_tree().change_scene_to_file.call_deferred(target_scene))
	add_rect(rect, Color(0.9, 0.9, 0.5, 0.25), 1)


func add_interactable(pos: Vector2, prompt_text: String, callback: Callable) -> void:
	var zone: Area2D = _make_zone(Rect2(pos - Vector2(40, 40), Vector2(80, 80)))
	var entry: Dictionary = {"area": zone, "prompt": prompt_text, "callback": callback}
	_interactables.append(entry)
	zone.body_entered.connect(func(body: Node2D) -> void:
		if body == player:
			_active_interactable = entry
			_prompt.text = "[E / A]  %s" % prompt_text
			_prompt.visible = true)
	zone.body_exited.connect(func(body: Node2D) -> void:
		if body == player and _active_interactable.get("area") == zone:
			_active_interactable = {}
			_prompt.visible = false)


func _make_zone(rect: Rect2) -> Area2D:
	var zone: Area2D = Area2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	zone.position = rect.position + rect.size / 2.0
	zone.add_child(shape)
	add_child(zone)
	return zone


func show_dialog(lines: Array[String]) -> void:
	_dialog_lines = lines.duplicate()
	_clear_choices()
	_advance_dialog()


## A spoken line plus 2-3 weighty options; each runs its callback when picked.
## options: [{"label": String, "callback": Callable}, ...]
func show_choice(prompt_text: String, options: Array) -> void:
	_dialog_lines = []
	_clear_choices()
	_dialog_label.text = prompt_text
	_dialog.visible = true
	var first: Button = null
	for option: Dictionary in options:
		var button: Button = Button.new()
		button.text = String(option["label"])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var callback: Callable = option["callback"]
		button.pressed.connect(func() -> void:
			_clear_choices()
			_dialog.visible = false
			callback.call())
		_choice_box.add_child(button)
		if first == null:
			first = button
	if first != null:
		first.grab_focus()


func _clear_choices() -> void:
	for child: Node in _choice_box.get_children():
		child.queue_free()


## Loot chest: opens once per run (tracked in WorldState), pays out items.
func add_chest(chest_id: String, pos: Vector2, loot: Dictionary) -> void:
	var world: Node = get_node_or_null("/root/WorldState")
	if world != null and world.opened_chests.has(chest_id):
		return
	_chest_points.append(pos)
	var art: Texture2D = AssetLibrary.texture("props", "chest")
	if art == null:
		art = AssetLibrary.texture("props", "crate")
	var chest: Node2D = Node2D.new()
	chest.position = pos
	chest.z_index = SORT_Z
	if art != null:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = art
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(2.0, 2.0)
		chest.add_child(sprite)
	else:
		var box: ColorRect = ColorRect.new()
		box.color = Color(0.6, 0.45, 0.2)
		box.size = Vector2(30, 24)
		box.position = Vector2(-15, -12)
		chest.add_child(box)
	add_child(chest)
	add_interactable(pos, "Open the chest", func() -> void:
		if world == null:
			show_dialog(["The chest is sealed to drifters. (Start a run.)"])
			return
		if world.opened_chests.has(chest_id):
			show_dialog(["Empty. Someone was here first — you, probably."])
			return
		world.opened_chests.append(chest_id)
		var lines: Array[String] = []
		for item_id: String in loot:
			world.add_item(item_id, int(loot[item_id]))
			var item: AbilityData = AbilityLibrary.load_ability(item_id)
			var item_name: String = item.display_name if item != null else item_id
			lines.append("Found %s ×%d!" % [item_name, int(loot[item_id])])
		var sfx: Node = get_node_or_null("/root/SfxManager")
		if sfx != null:
			sfx.play("heal")
		chest.modulate = Color(0.5, 0.5, 0.5)
		show_dialog(lines))


## A villager who wanders between waypoints and tosses a one-liner when bumped.
## `quips`: optional [[party_speaker, line], ...] — the party sometimes answers.
func add_roamer(
	roamer_name: String, waypoints: Array[Vector2], lines: Array[String],
	tint: Color = Color.WHITE, quips: Array = []
) -> Node2D:
	var roamer: Node2D = Node2D.new()
	roamer.position = waypoints[0]
	roamer.z_index = SORT_Z
	# Directional walker body (tinted villager); static sprite as fallback.
	var walker_name: String = (
		roamer_name if AssetLibrary.walk_frames(roamer_name) != null else "Cavene"
	)
	if WalkerSprite.attach(roamer, walker_name, 2.0):
		(roamer.get_child(0) as WalkerSprite).modulate = tint
	else:
		var art: Texture2D = AssetLibrary.texture("characters", "Cavene")
		if art != null:
			var sprite: Sprite2D = Sprite2D.new()
			sprite.texture = art
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.scale = Vector2(2.0, 2.0)
			sprite.modulate = tint
			roamer.add_child(sprite)
	add_child(roamer)
	# Drift between waypoints forever.
	if waypoints.size() > 1:
		var tween: Tween = roamer.create_tween().set_loops()
		for i: int in range(waypoints.size()):
			var next: Vector2 = waypoints[(i + 1) % waypoints.size()]
			var hop: Vector2 = waypoints[i]
			tween.tween_property(roamer, "position", next, maxf(hop.distance_to(next) / 60.0, 0.5))
			tween.tween_interval(randf_range(0.8, 2.2))
	if lines.is_empty():
		return roamer
	# Talking zone follows the roamer.
	var zone: Area2D = Area2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 46.0
	shape.shape = circle
	zone.add_child(shape)
	roamer.add_child(zone)
	var entry: Dictionary = {
		"area": zone, "prompt": "Talk", "callback": func() -> void:
			show_dialog([lines[randi() % lines.size()]] as Array[String])
			maybe_quip(quips),
	}
	_interactables.append(entry)
	zone.body_entered.connect(func(body: Node2D) -> void:
		if body == player:
			_active_interactable = entry
			_prompt.text = "[E / A]  Talk"
			_prompt.visible = true)
	zone.body_exited.connect(func(body: Node2D) -> void:
		if body == player and _active_interactable.get("area") == zone:
			_active_interactable = {}
			_prompt.visible = false)
	return roamer


## --- the party's voice: quips that cross the bottom of the screen ----------------


var _quip_label: Label
var _quip_tween: Tween

## Owner spec: party members "flash their opinions across the bottom, with
## enough time to read." One line at a time; later quips replace earlier.
func party_quip(speaker: String, line: String) -> void:
	if _quip_label == null or not is_instance_valid(_quip_label):
		_quip_label = Label.new()
		_quip_label.add_theme_font_size_override("font_size", 15)
		_quip_label.position = Vector2(0, 648)
		_quip_label.size = Vector2(1280, 26)
		_quip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hud_layer.add_child(_quip_label)
	if _quip_tween != null and _quip_tween.is_valid():
		_quip_tween.kill()
	_quip_label.text = "%s — “%s”" % [speaker, line]
	_quip_label.modulate = Color(0.95, 0.92, 0.8, 0.0)
	_quip_tween = create_tween()
	_quip_tween.tween_property(_quip_label, "modulate:a", 1.0, 0.3)
	_quip_tween.tween_interval(maxf(2.6, float(line.length()) * 0.055))
	_quip_tween.tween_property(_quip_label, "modulate:a", 0.0, 0.6)


## Sometimes the party answers the street. pool: [[speaker, line], ...]
func maybe_quip(pool: Array, chance: float = 0.4) -> void:
	if pool.is_empty() or randf() > chance:
		return
	var pick: Array = pool[randi() % pool.size()]
	party_quip(String(pick[0]), String(pick[1]))


## --- street souls: thinkers and callers ------------------------------------------


## A thinker: approach and "watch quietly" — you read what they will not say.
## Their thoughts arrive parenthesized, a window not a conversation.
func add_thinker(
	walker_name: String, pos: Vector2, tint: Color, thoughts: Array[String],
	quips: Array = []
) -> void:
	var soul: Node2D = add_roamer(walker_name, [pos] as Array[Vector2],
		[] as Array[String], tint)
	var mark: Label = Label.new()
	mark.text = "…"
	mark.add_theme_font_size_override("font_size", 18)
	mark.modulate = Color(0.7, 0.75, 0.85, 0.8)
	mark.position = Vector2(-7, -58)
	soul.add_child(mark)
	var blink: Tween = mark.create_tween().set_loops()
	blink.tween_property(mark, "modulate:a", 0.25, 1.1)
	blink.tween_property(mark, "modulate:a", 0.8, 1.1)
	add_interactable(pos, "Watch quietly", func() -> void:
		var inner: Array[String] = []
		inner.append("( " + thoughts[randi() % thoughts.size()] + " )")
		show_dialog(inner)
		maybe_quip(quips))


## A caller: shouts/murmurs AT you, unprompted, when you pass close.
func add_caller(
	walker_name: String, pos: Vector2, tint: Color, calls: Array,
	radius: float = 230.0
) -> void:
	var soul: Node2D = add_roamer(walker_name, [pos] as Array[Vector2],
		[] as Array[String], tint)
	add_vignette(pos, radius, [{"node": soul, "lines": calls}])


## speakers: [{"node": Node2D, "lines": Array}], cycling random mini-bubbles
## whenever the player is within `radius` of `center`. No interaction needed —
## the street just talks around you.
func add_vignette(center: Vector2, radius: float, speakers: Array) -> void:
	var timer: Timer = Timer.new()
	timer.wait_time = randf_range(2.2, 3.6)
	timer.one_shot = false
	add_child(timer)
	timer.timeout.connect(func() -> void:
		timer.wait_time = randf_range(2.6, 5.0)
		if player == null or player.position.distance_to(center) > radius:
			return
		var speaker: Dictionary = speakers[randi() % speakers.size()]
		var node: Node2D = speaker["node"]
		if not is_instance_valid(node):
			return
		var lines: Array = speaker["lines"]
		_pop_bubble(node, String(lines[randi() % lines.size()])))
	timer.start()


func _pop_bubble(above: Node2D, text: String) -> void:
	var bubble: PanelContainer = PanelContainer.new()
	bubble.modulate = Color(1, 1, 1, 0.0)
	bubble.z_index = 30
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	bubble.add_child(label)
	above.add_child(bubble)
	await get_tree().process_frame  # size settles after layout
	if not is_instance_valid(bubble):
		return
	bubble.position = Vector2(-bubble.size.x / 2.0, -64.0 - bubble.size.y)
	var tween: Tween = bubble.create_tween()
	tween.tween_property(bubble, "modulate:a", 1.0, 0.22)
	tween.tween_interval(1.9)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.45)
	tween.tween_callback(bubble.queue_free)


## --- sky + ambient life ----------------------------------------------------------


## God rays by day, pale moonbeams by night, and cloud shadows crossing the land.
func _build_sky_layer() -> void:
	var ray_material: CanvasItemMaterial = CanvasItemMaterial.new()
	ray_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 31
	for i: int in range(7):
		var ray: Polygon2D = Polygon2D.new()
		var width: float = rng.randf_range(90.0, 200.0)
		var length: float = map_size.length() * 0.8
		ray.polygon = PackedVector2Array([
			Vector2(0, 0), Vector2(width, 0),
			Vector2(width + 180.0, length), Vector2(180.0, length),
		])
		ray.color = Color(1.0, 0.95, 0.72, 0.115)
		ray.material = ray_material
		ray.rotation_degrees = -28.0
		ray.position = Vector2(rng.randf_range(0.0, map_size.x), -80.0)
		ray.z_index = 45
		add_child(ray)
		_rays.append(ray)
		var drift: Tween = ray.create_tween().set_loops()
		var span: float = rng.randf_range(120.0, 260.0)
		drift.tween_property(ray, "position:x", ray.position.x + span, rng.randf_range(14.0, 26.0))\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.parallel().tween_property(ray, "modulate:a", 0.35, rng.randf_range(7.0, 12.0))\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.tween_property(ray, "position:x", ray.position.x, rng.randf_range(14.0, 26.0))\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.parallel().tween_property(ray, "modulate:a", 1.0, rng.randf_range(7.0, 12.0))\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Slow cloud shadows: big soft blots sliding over everything below z45.
	_clouds = Node2D.new()
	_clouds.z_index = 44
	add_child(_clouds)
	for i: int in range(int(7 * cloud_density)):
		var cloud: Node2D = Node2D.new()
		var seed_value: int = 50 + i * 7
		cloud.draw.connect(func() -> void:
			var cloud_rng: RandomNumberGenerator = RandomNumberGenerator.new()
			cloud_rng.seed = seed_value
			for blob: int in range(5):
				cloud.draw_circle(
					Vector2(cloud_rng.randf_range(-90, 90), cloud_rng.randf_range(-40, 40)),
					cloud_rng.randf_range(55.0, 110.0),
					Color(0.05, 0.06, 0.12, 0.075)
				))
		cloud.position = Vector2(rng.randf_range(0, map_size.x), rng.randf_range(60, map_size.y - 60))
		cloud.scale = Vector2(2.2, 1.6)
		_clouds.add_child(cloud)
		var cross: Tween = cloud.create_tween().set_loops()
		var trip: float = rng.randf_range(55.0, 100.0)
		cross.tween_property(cloud, "position:x", map_size.x + 320.0, trip * (map_size.x - cloud.position.x) / map_size.x)
		cross.tween_callback(func() -> void: cloud.position.x = -320.0)
		cross.tween_property(cloud, "position:x", map_size.x + 320.0, trip)
		cross.tween_callback(func() -> void: cloud.position.x = -320.0)


## Dust motes always, butterflies by day, fireflies after dark.
func _build_ambient_life() -> void:
	var area_factor: float = map_size.x * map_size.y / (1280.0 * 720.0)
	# Pollen / dust drifting up through the light (the "pretty stuff" layer).
	var dust: GPUParticles2D = GPUParticles2D.new()
	var dust_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	dust_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dust_material.emission_box_extents = Vector3(map_size.x / 2.0, map_size.y / 2.0, 1.0)
	dust_material.direction = Vector3(0.1, -1.0, 0.0)
	dust_material.spread = 30.0
	dust_material.gravity = Vector3(2.0, -7.0, 0.0)
	dust_material.initial_velocity_min = 2.0
	dust_material.initial_velocity_max = 9.0
	dust_material.scale_min = 0.8
	dust_material.scale_max = 1.7
	dust_material.color = Color(1.0, 0.97, 0.85, 0.30)
	dust.process_material = dust_material
	dust.amount = int(130 * area_factor)
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.position = map_size / 2.0
	dust.visibility_rect = Rect2(-map_size.x / 2.0, -map_size.y / 2.0, map_size.x, map_size.y)
	dust.z_index = 40
	add_child(dust)
	# Fireflies: blinking embers of green-gold, night only, collision-free.
	_fireflies = GPUParticles2D.new()
	var fly_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	fly_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	fly_material.emission_box_extents = Vector3(map_size.x / 2.0, map_size.y / 2.0, 1.0)
	fly_material.gravity = Vector3.ZERO
	fly_material.initial_velocity_min = 6.0
	fly_material.initial_velocity_max = 18.0
	fly_material.spread = 180.0
	fly_material.direction = Vector3(1, 0, 0)
	fly_material.scale_min = 1.2 * firefly_scale
	fly_material.scale_max = 2.0 * firefly_scale
	var blink: Gradient = Gradient.new()
	blink.set_color(0, Color(0.78, 1.0, 0.42, 0.0))
	blink.add_point(0.25, Color(0.78, 1.0, 0.42, 0.9))
	blink.add_point(0.5, Color(0.65, 0.9, 0.3, 0.05))
	blink.add_point(0.75, Color(0.8, 1.0, 0.5, 0.8))
	blink.set_color(1, Color(0.78, 1.0, 0.42, 0.0))
	var blink_texture: GradientTexture1D = GradientTexture1D.new()
	blink_texture.gradient = blink
	fly_material.color_ramp = blink_texture
	_fireflies.process_material = fly_material
	_fireflies.amount = int(90 * area_factor)
	_fireflies.lifetime = 5.0
	_fireflies.preprocess = 5.0
	_fireflies.position = map_size / 2.0
	_fireflies.visibility_rect = Rect2(
		-map_size.x / 2.0, -map_size.y / 2.0, map_size.x, map_size.y
	)
	_fireflies.z_index = 42
	_fireflies.emitting = false
	add_child(_fireflies)
	# A handful of butterflies on lazy wanders (day only).
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 8
	for i: int in range(clampi(int(4 * area_factor), 3, 10)):
		var butterfly: Node2D = Node2D.new()
		var tint: Color = [
			Color(0.95, 0.75, 0.3), Color(0.85, 0.85, 0.95), Color(0.9, 0.6, 0.75),
		][i % 3]
		var wing: Node2D = Node2D.new()
		wing.draw.connect(func() -> void:
			wing.draw_colored_polygon(
				PackedVector2Array([Vector2(0, 0), Vector2(-6, -5), Vector2(-5, 2)]), tint
			)
			wing.draw_colored_polygon(
				PackedVector2Array([Vector2(0, 0), Vector2(6, -5), Vector2(5, 2)]), tint
			)
			wing.draw_rect(Rect2(-0.7, -2.5, 1.4, 5.0), Color(0.25, 0.2, 0.2)))
		butterfly.add_child(wing)
		var flap: Tween = wing.create_tween().set_loops()
		flap.tween_property(wing, "scale:x", 0.35, 0.09)
		flap.tween_property(wing, "scale:x", 1.0, 0.09)
		butterfly.position = Vector2(
			rng.randf_range(100, map_size.x - 100), rng.randf_range(100, map_size.y - 100)
		)
		butterfly.z_index = 41
		add_child(butterfly)
		_butterflies.append(butterfly)
		var wander: Tween = butterfly.create_tween().set_loops()
		for hop: int in range(4):
			wander.tween_property(
				butterfly, "position",
				butterfly.position + Vector2(rng.randf_range(-160, 160), rng.randf_range(-110, 110)),
				rng.randf_range(2.0, 4.0)
			).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			wander.tween_interval(rng.randf_range(0.4, 1.4))
		wander.tween_property(butterfly, "position", butterfly.position, 3.0)\
			.set_trans(Tween.TRANS_SINE)


## --- the corner minimap -----------------------------------------------------------


func _build_minimap() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(1052, 8)
	_hud_layer.add_child(panel)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	panel.add_child(stack)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	stack.add_child(head)
	var face: TextureRect = TextureRect.new()
	var lead: String = player.lead_name if player != null else "Bastil"
	var art: Texture2D = AssetLibrary.texture("characters", lead)
	if art != null:
		face.texture = art
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.custom_minimum_size = Vector2(34, 46)
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(face)
	var names: VBoxContainer = VBoxContainer.new()
	head.add_child(names)
	var who: Label = Label.new()
	who.text = lead.to_upper()
	who.add_theme_font_size_override("font_size", 13)
	names.add_child(who)
	if player != null:
		player.lead_changed.connect(func(new_lead: String) -> void:
			who.text = new_lead.to_upper()
			var new_art: Texture2D = AssetLibrary.texture("characters", new_lead)
			if new_art != null:
				face.texture = new_art)
	var where: Label = Label.new()
	where.text = area_name.split("—")[0].strip_edges()
	where.add_theme_font_size_override("font_size", 10)
	where.modulate = Color(0.75, 0.73, 0.65)
	names.add_child(where)
	_minimap = Control.new()
	_minimap.custom_minimum_size = Vector2(176, 176.0 * map_size.y / map_size.x)
	stack.add_child(_minimap)
	_minimap.draw.connect(_draw_minimap)


func _draw_minimap() -> void:
	var size: Vector2 = _minimap.size
	var scale_factor: float = size.x / map_size.x
	_minimap.draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.08, 0.10, 0.85))
	_minimap.draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.5, 0.4, 0.8), false, 1.5)
	for exit_rect: Rect2 in _exit_rects:
		_minimap.draw_rect(
			Rect2(exit_rect.position * scale_factor, (exit_rect.size * scale_factor).max(Vector2(3, 3))),
			Color(0.95, 0.9, 0.4, 0.9)
		)
	for save_pos: Vector2 in _save_points:
		_minimap.draw_circle(save_pos * scale_factor, 3.0, Color(0.45, 0.95, 1.0))
	for chest_pos: Vector2 in _chest_points:
		_minimap.draw_circle(chest_pos * scale_factor, 2.0, Color(0.85, 0.65, 0.3))
	for foe: Node in get_tree().get_nodes_in_group("overworld_foe"):
		if foe is Node2D:
			_minimap.draw_circle((foe as Node2D).position * scale_factor, 2.4, Color(0.9, 0.3, 0.25))
	if player != null:
		_minimap.draw_circle(player.position * scale_factor, 3.2, Color(1.0, 0.85, 0.25))
		_minimap.draw_circle(player.position * scale_factor, 5.0, Color(1.0, 0.85, 0.25, 0.35))


func _process(_delta: float) -> void:
	if _minimap != null:
		_minimap.queue_redraw()


func _advance_dialog() -> void:
	if _dialog_lines.is_empty():
		_dialog.visible = false
		return
	_dialog_label.text = _dialog_lines.pop_front() + "\n\n[E / A] ..."
	_dialog.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("lens_zoom") and player != null:
		# The cameraman racks in tight, then slowly relaxes back out.
		var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
		if camera == null:
			for child: Node in player.get_children():
				if child is Camera2D:
					camera = child
		if camera != null:
			var snap: Tween = create_tween()
			snap.tween_property(camera, "zoom", Vector2(1.5, 1.5), 0.15)\
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			snap.tween_property(camera, "zoom", Vector2.ONE, 6.5)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return
	if event.is_action_pressed("char_menu") and not _dialog.visible:
		get_viewport().set_input_as_handled()
		var sfx_menu: Node = get_node_or_null("/root/SfxManager")
		if sfx_menu != null:
			sfx_menu.play("click")
		add_child(CharacterMenuOverlay.new())
		return
	if not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	var sfx: Node = get_node_or_null("/root/SfxManager")
	if sfx != null:
		sfx.play("click")
	if _dialog.visible:
		_advance_dialog()
		return
	if not _active_interactable.is_empty():
		var callback: Callable = _active_interactable["callback"]
		callback.call()


## --- random encounters ---------------------------------------------------------


func _arm_encounter() -> void:
	_steps_until_encounter = randf_range(260.0, 430.0)


func _on_player_stepped(distance: float) -> void:
	if not encounters_enabled or encounter_rosters.is_empty() or _dialog.visible:
		return
	_steps_until_encounter -= distance
	if _steps_until_encounter > 0.0:
		return
	var world: Node = get_node_or_null("/root/WorldState")
	if world == null or not world.in_world_run:
		_arm_encounter()
		return
	var roster: String = encounter_rosters[randi() % encounter_rosters.size()]
	var sfx: Node = get_node_or_null("/root/SfxManager")
	if sfx != null:
		sfx.play("shock")
	world.start_battle(get_tree(), roster, scene_file_path, player.position)
