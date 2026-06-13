class_name HDBase
extends Node3D
## Scaffold for HD-2D areas: a sun-and-sky environment tuned for the
## diorama look (SSAO, glow, volumetric fog, filmic tonemap — full effect
## on Forward+), textured ground, kit props with collision, billboarded
## pixel NPCs with Label3D chatter, torches that burn, and portals back
## to the 2D world. Same 64px = 1 unit mapping everywhere.

var player: PlayerAvatar3D
var area_name: String = "HD-2D PILOT"
var map_px: Vector2 = Vector2(3840, 2400)
## Looping foley bed for the area (a file base in assets/audio/foley/).
var ambience_foley: String = ""
## Where the player drops in (pixel space). Defaults to map center.
var spawn_px: Vector2 = Vector2(-1, -1)


## Subclasses override these to tint the whole scene's mood.
var sky_top: Color = Color(0.30, 0.45, 0.78)
var sky_horizon: Color = Color(0.74, 0.80, 0.92)
var sun_color: Color = Color(1.0, 0.94, 0.84)
var sun_energy: float = 1.4
var fog_density: float = 0.014
var fog_color: Color = Color(0.85, 0.82, 0.78)
var grade_saturation: float = 1.16
var use_physical_sky: bool = true  # interiors set false for a dark void bg
var environment: Environment

var _world_environment: WorldEnvironment


func _ready() -> void:
	_build_environment()
	_setup_area()
	player = PlayerAvatar3D.new()
	add_child(player)
	var drop: Vector2 = spawn_px if spawn_px.x >= 0.0 else map_px / 2.0
	player.position = HDAssets.to3d(drop, 0.5)
	_build_cinematic_layer()
	_build_atmosphere()
	_build_ambience()
	_build_hud()


## A looping atmosphere bed (rain, spooky air) from the foley library.
func _build_ambience() -> void:
	if ambience_foley == "":
		return
	var stream: AudioStream = PlayerAvatar3D._load_foley(ambience_foley)
	if stream == null:
		return
	var player_node: AudioStreamPlayer = AudioStreamPlayer.new()
	player_node.bus = "Ambience" if AudioServer.get_bus_index("Ambience") != -1 else "Master"
	player_node.stream = stream
	player_node.volume_db = -10.0
	add_child(player_node)
	player_node.play()


func _setup_area() -> void:
	pass  # scenes override


func _build_environment() -> void:
	# A physically-shaded sky with a real sun disk: free, gorgeous, and it
	# drives the ambient + reflections for everything below.
	var sky_material: PhysicalSkyMaterial = PhysicalSkyMaterial.new()
	sky_material.rayleigh_coefficient = 2.2
	sky_material.mie_coefficient = 0.008
	sky_material.turbidity = 6.0
	sky_material.sun_disk_scale = 6.0
	sky_material.ground_color = Color(0.32, 0.34, 0.3)
	sky_material.energy_multiplier = 1.0
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128

	environment = Environment.new()
	if use_physical_sky:
		environment.background_mode = Environment.BG_SKY
		environment.sky = sky
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	else:
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = sky_top
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = sky_horizon
	environment.ambient_light_energy = 1.15
	# AgX: the filmic, Hollywood-grade tonemap (Blender's default) — rolls off
	# highlights beautifully and keeps saturated colors from clipping.
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_white = 6.0
	# Real bounced light (Forward+). Soft, free global illumination.
	environment.sdfgi_enabled = true
	environment.sdfgi_cascades = 4
	environment.sdfgi_energy = 1.0
	# Contact shadows + screen-space ambient occlusion + indirect lighting.
	environment.ssao_enabled = true
	environment.ssao_radius = 2.0
	environment.ssao_intensity = 3.0
	environment.ssao_power = 2.0
	environment.ssil_enabled = true
	environment.ssil_intensity = 0.6
	# Generous, soft bloom on anything bright (crystals, torches, sky).
	environment.glow_enabled = true
	environment.glow_intensity = 0.85
	environment.glow_strength = 1.1
	environment.glow_bloom = 0.18
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	environment.glow_hdr_threshold = 0.92
	# Volumetric fog with light shafts pouring through the trees/towers.
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = fog_density
	environment.volumetric_fog_albedo = fog_color
	environment.volumetric_fog_emission = Color(0.02, 0.02, 0.03)
	environment.volumetric_fog_gi_inject = 1.0
	environment.volumetric_fog_length = 96.0
	# Distance fog ties the far edges into the sky (kills any seam/void).
	environment.fog_enabled = true
	environment.fog_light_color = fog_color
	environment.fog_density = 0.0025
	environment.fog_sky_affect = 0.4
	environment.fog_aerial_perspective = 0.5
	environment.adjustment_enabled = true
	environment.adjustment_saturation = grade_saturation
	environment.adjustment_contrast = 1.06
	environment.adjustment_brightness = 1.02
	_world_environment = WorldEnvironment.new()
	_world_environment.environment = environment
	add_child(_world_environment)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48.0, -42.0, 0.0)
	sun.light_color = sun_color
	sun.light_energy = sun_energy
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_blur = 1.5
	sun.light_angular_distance = 1.0  # soft, sun-sized shadow penumbra
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	add_child(sun)


## Full-screen cinematic grade over the 3D viewport (tilt-shift DoF emphasis,
## vignette, split-tone, chromatic aberration, film grain).
func _build_cinematic_layer() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 70
	add_child(layer)
	var rect: ColorRect = ColorRect.new()
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://world3d/shaders/hd_cinematic.gdshader")
	rect.material = material
	layer.add_child(rect)


## Drifting dust motes / pollen caught in the light — the HD-2D shimmer.
func _build_atmosphere() -> void:
	var motes: GPUParticles3D = GPUParticles3D.new()
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(map_px.x / HDAssets.PX / 2.0, 6.0, map_px.y / HDAssets.PX / 2.0)
	material.direction = Vector3(0.2, 1.0, 0.0)
	material.gravity = Vector3(0.1, 0.15, 0.0)
	material.initial_velocity_min = 0.05
	material.initial_velocity_max = 0.25
	material.scale_min = 0.6
	material.scale_max = 1.4
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1.0, 0.97, 0.85, 0.0))
	ramp.add_point(0.3, Color(1.0, 0.97, 0.85, 0.5))
	ramp.set_color(1, Color(1.0, 0.97, 0.85, 0.0))
	var ramp_tex: GradientTexture1D = GradientTexture1D.new()
	ramp_tex.gradient = ramp
	material.color_ramp = ramp_tex
	motes.process_material = material
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var mote_material: StandardMaterial3D = StandardMaterial3D.new()
	mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_material.vertex_color_use_as_albedo = true
	mote_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mote_material.albedo_color = Color(1.0, 0.97, 0.85)
	mote_material.emission_enabled = true
	mote_material.emission = Color(1.0, 0.95, 0.8)
	quad.material = mote_material
	motes.draw_pass_1 = quad
	motes.amount = 260
	motes.lifetime = 14.0
	motes.preprocess = 14.0
	motes.position = HDAssets.to3d(map_px / 2.0, 4.0)
	motes.visibility_aabb = AABB(
		Vector3(-map_px.x / HDAssets.PX, -2, -map_px.y / HDAssets.PX),
		Vector3(map_px.x / HDAssets.PX * 2, 16, map_px.y / HDAssets.PX * 2)
	)
	add_child(motes)


func _build_hud() -> void:
	var hud: CanvasLayer = CanvasLayer.new()
	hud.layer = 80
	add_child(hud)
	var title: Label = Label.new()
	title.text = area_name + "      ·      [Esc] back to the 2D road"
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color(0.9, 0.88, 0.8)
	title.position = Vector2(16, 10)
	hud.add_child(title)
	var hint: Label = Label.new()
	hint.text = "WASD move · G run · T lantern · Tab swap lead · Z lens"
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(0.7, 0.7, 0.75)
	hint.position = Vector2(16, 690)
	hud.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://world/town.tscn")


## --- building blocks --------------------------------------------------------------


func ground(texture_path: String, tile_px: float = 128.0, tint: Color = Color.WHITE) -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(map_px.x / HDAssets.PX, map_px.y / HDAssets.PX)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = plane
	var material: StandardMaterial3D = StandardMaterial3D.new()
	if texture_path != "" and ResourceLoader.exists(texture_path):
		material.albedo_texture = load(texture_path)
		material.uv1_scale = Vector3(map_px.x / tile_px, map_px.y / tile_px, 1.0)
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.albedo_color = tint
	else:
		material.albedo_color = tint if tint != Color.WHITE else Color(0.3, 0.45, 0.28)
	material.roughness = 1.0
	mesh.material_override = material
	mesh.position = HDAssets.to3d(map_px / 2.0)
	add_child(mesh)
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(plane.size.x, 0.2, plane.size.y)
	shape.shape = box
	shape.position.y = -0.1
	body.add_child(shape)
	body.position = mesh.position
	add_child(body)


## A flat textured strip laid on the ground (roads, plazas).
func road(rect_px: Rect2, texture_path: String, tile_px: float = 96.0) -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = rect_px.size / HDAssets.PX
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = plane
	var material: StandardMaterial3D = StandardMaterial3D.new()
	if ResourceLoader.exists(texture_path):
		material.albedo_texture = load(texture_path)
		material.uv1_scale = Vector3(rect_px.size.x / tile_px, rect_px.size.y / tile_px, 1.0)
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 1.0
	mesh.material_override = material
	mesh.position = HDAssets.to3d(rect_px.get_center(), 0.02)
	add_child(mesh)


func water(rect_px: Rect2) -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = rect_px.size / HDAssets.PX
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = plane
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.5, 0.62, 0.9)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.metallic = 0.4
	material.roughness = 0.1
	mesh.material_override = material
	mesh.position = HDAssets.to3d(rect_px.get_center(), -0.06)
	add_child(mesh)
	wall3d(rect_px)


func wall3d(rect_px: Rect2, height: float = 2.0) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(rect_px.size.x / HDAssets.PX, height, rect_px.size.y / HDAssets.PX)
	shape.shape = box
	shape.position.y = height / 2.0
	body.add_child(shape)
	body.position = HDAssets.to3d(rect_px.get_center())
	add_child(body)


## A kit model planted at a 2D-pixel position. `footprint_px` adds collision.
func prop(
	node: Node3D, px: Vector2, rotation_y: float = 0.0, scale_factor: float = 1.0,
	footprint_px: float = 0.0
) -> Node3D:
	if node == null:
		return null
	node.position = HDAssets.to3d(px)
	node.rotation_degrees.y = rotation_y
	node.scale = Vector3.ONE * scale_factor
	add_child(node)
	if footprint_px > 0.0:
		wall3d(Rect2(px - Vector2(footprint_px, footprint_px) / 2.0,
			Vector2(footprint_px, footprint_px)))
	return node


## Your 2D pixel art standing in the 3D world (Y-billboard, casts shadow).
func billboard(texture: Texture2D, px: Vector2, pixel_size: float = 0.03) -> Sprite3D:
	if texture == null:
		return null
	var sprite: Sprite3D = Sprite3D.new()
	sprite.texture = texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = true
	sprite.pixel_size = pixel_size
	sprite.position = HDAssets.to3d(px, texture.get_height() * pixel_size / 2.0)
	add_child(sprite)
	return sprite


## A pixel villager billboard with cycling Label3D chatter overhead.
func npc3(walker_name: String, px: Vector2, lines: Array[String], tint: Color = Color.WHITE) -> void:
	var frames: SpriteFrames = AssetLibrary.walk_frames(walker_name)
	var body: Node3D
	if frames != null:
		var animated: AnimatedSprite3D = AnimatedSprite3D.new()
		animated.sprite_frames = frames
		animated.animation = "idle_down"
		animated.play()
		animated.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		animated.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		animated.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		animated.shaded = true
		animated.pixel_size = 0.024
		animated.modulate = tint
		body = animated
	else:
		body = Node3D.new()
	body.position = HDAssets.to3d(px, 0.62)
	add_child(body)
	if lines.is_empty():
		return
	var bubble: Label3D = Label3D.new()
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.font_size = 36
	bubble.pixel_size = 0.005
	bubble.modulate = Color(1, 1, 1, 0.0)
	bubble.outline_size = 8
	bubble.position.y = 1.0
	body.add_child(bubble)
	var timer: Timer = Timer.new()
	timer.wait_time = randf_range(4.0, 8.0)
	body.add_child(timer)
	timer.timeout.connect(func() -> void:
		timer.wait_time = randf_range(5.0, 9.0)
		if player == null or player.position.distance_to(body.position) > 6.0:
			return
		bubble.text = lines[randi() % lines.size()]
		var fade: Tween = bubble.create_tween()
		fade.tween_property(bubble, "modulate:a", 1.0, 0.25)
		fade.tween_interval(2.4)
		fade.tween_property(bubble, "modulate:a", 0.0, 0.5))
	timer.start()


func torch3(px: Vector2) -> void:
	var model: Node3D = HDAssets.dungeon("torch_lit")
	if model == null:
		model = HDAssets.dungeon("torch")
	if model != null:
		prop(model, px, randf_range(0.0, 360.0), 1.0)
	var flame: OmniLight3D = OmniLight3D.new()
	flame.light_color = Color(1.0, 0.66, 0.27)
	flame.light_energy = 1.4
	flame.omni_range = 4.5
	flame.shadow_enabled = true
	flame.position = HDAssets.to3d(px, 1.0)
	add_child(flame)
	var flicker: Tween = flame.create_tween().set_loops()
	flicker.tween_property(flame, "light_energy", 1.1, randf_range(0.1, 0.2))
	flicker.tween_property(flame, "light_energy", 1.4, randf_range(0.1, 0.2))


func crystal3(px: Vector2) -> void:
	var prism: MeshInstance3D = MeshInstance3D.new()
	var mesh: PrismMesh = PrismMesh.new()
	mesh.size = Vector3(0.5, 1.1, 0.5)
	prism.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.95, 1.0, 0.85)
	material.emission_enabled = true
	material.emission = Color(0.4, 0.9, 1.0)
	material.emission_energy_multiplier = 2.2
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	prism.material_override = material
	prism.position = HDAssets.to3d(px, 0.7)
	add_child(prism)
	var spin: Tween = prism.create_tween().set_loops()
	spin.tween_property(prism, "rotation_degrees:y", 360.0, 6.0)
	spin.tween_callback(func() -> void: prism.rotation_degrees.y = 0.0)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color(0.5, 0.95, 1.0)
	glow.light_energy = 1.6
	glow.omni_range = 5.0
	glow.position = HDAssets.to3d(px, 1.0)
	add_child(glow)


## Scatter trees/rocks/bushes across a pixel rect (decor, with light collision
## on the big trees). `models` is a list of nature model names to pick from.
func scatter_nature(
	rect_px: Rect2, models: Array, count: int, seed_value: int,
	scale_min: float = 1.4, scale_max: float = 2.4, collide_px: float = 0.0
) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for i: int in range(count):
		var px: Vector2 = Vector2(
			rng.randf_range(rect_px.position.x, rect_px.end.x),
			rng.randf_range(rect_px.position.y, rect_px.end.y)
		)
		prop(HDAssets.nature(String(models[rng.randi_range(0, models.size() - 1)])),
			px, rng.randf_range(0, 360), rng.randf_range(scale_min, scale_max), collide_px)


## Tile the KayKit dungeon floor across a pixel rect (these read GREAT in 3D).
func dungeon_floor(rect_px: Rect2, tile_name: String = "floor_tile_large") -> void:
	var step: float = 256.0  # one tile spans ~4 world units
	var y: float = rect_px.position.y
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(rect_px.position.x + rect_px.position.y)
	while y < rect_px.end.y:
		var x: float = rect_px.position.x
		while x < rect_px.end.x:
			var variant: String = tile_name
			if tile_name == "floor_tile_large" and rng.randf() < 0.22:
				variant = ["floor_tile_large_rocks", "floor_dirt_large", "floor_dirt_large_rocky"][rng.randi_range(0, 2)]
			var tile: Node3D = HDAssets.dungeon(variant)
			if tile != null:
				prop(tile, Vector2(x + step / 2.0, y + step / 2.0), 90.0 * rng.randi_range(0, 3), 1.0)
			x += step
		y += step


## A straight dungeon wall run between two pixel points (auto-tiled + collided).
func dungeon_wall(from_px: Vector2, to_px: Vector2, wall_name: String = "wall") -> void:
	var span: float = from_px.distance_to(to_px)
	var step: float = 256.0
	var count: int = maxi(1, int(span / step))
	var angle: float = rad_to_deg(atan2(to_px.y - from_px.y, to_px.x - from_px.x))
	for i: int in range(count + 1):
		var px: Vector2 = from_px.lerp(to_px, float(i) / float(maxi(count, 1)))
		prop(HDAssets.dungeon(wall_name), px, angle + 90.0, 1.0)
	wall3d(Rect2(from_px.lerp(to_px, 0.5) - Vector2(span, 64) / 2.0, Vector2(span, 128)), 2.5)


## Walk into it, return to the 2D road (or any scene).
func portal(rect_px: Rect2, target_scene: String, label_text: String) -> void:
	var zone: Area3D = Area3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(rect_px.size.x / HDAssets.PX, 3.0, rect_px.size.y / HDAssets.PX)
	shape.shape = box
	shape.position.y = 1.0
	zone.add_child(shape)
	zone.position = HDAssets.to3d(rect_px.get_center())
	add_child(zone)
	zone.body_entered.connect(func(body: Node3D) -> void:
		if body == player:
			get_tree().change_scene_to_file.call_deferred(target_scene))
	var sign_label: Label3D = Label3D.new()
	sign_label.text = label_text
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.font_size = 40
	sign_label.pixel_size = 0.006
	sign_label.modulate = Color(1.0, 0.9, 0.5)
	sign_label.outline_size = 10
	sign_label.position = HDAssets.to3d(rect_px.get_center(), 1.6)
	add_child(sign_label)
