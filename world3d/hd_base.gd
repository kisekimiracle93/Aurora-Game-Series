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


func _ready() -> void:
	_build_environment()
	_setup_area()
	player = PlayerAvatar3D.new()
	add_child(player)
	player.position = HDAssets.to3d(map_px / 2.0, 0.5)
	_build_hud()


func _setup_area() -> void:
	pass  # scenes override


func _build_environment() -> void:
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.36, 0.46, 0.72)
	sky_material.sky_horizon_color = Color(0.92, 0.78, 0.62)
	sky_material.ground_bottom_color = Color(0.22, 0.2, 0.18)
	sky_material.ground_horizon_color = Color(0.82, 0.72, 0.58)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 1.0
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	environment.ssao_radius = 1.4
	environment.ssao_intensity = 2.2
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_hdr_threshold = 1.05
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.012
	environment.volumetric_fog_albedo = Color(0.9, 0.85, 0.75)
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.12
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)


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


func ground(texture_path: String, tile_px: float = 128.0) -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(map_px.x / HDAssets.PX, map_px.y / HDAssets.PX)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = plane
	var material: StandardMaterial3D = StandardMaterial3D.new()
	if ResourceLoader.exists(texture_path):
		material.albedo_texture = load(texture_path)
		material.uv1_scale = Vector3(map_px.x / tile_px, map_px.y / tile_px, 1.0)
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	else:
		material.albedo_color = Color(0.3, 0.45, 0.28)
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


## Walk into it, return to the 2D road.
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
