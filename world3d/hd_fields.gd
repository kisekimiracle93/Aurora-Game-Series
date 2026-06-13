extends HDBase
## THE CRYSTAL FIELDS in HD-2D: a cold snowfield under a pale sun, framed by
## rock cliffs and pines, a frozen river, drifting snow, and ice crystals.
## North/east → the crystal site.


func _init() -> void:
	area_name = "THE CRYSTAL FIELDS — HD-2D"
	map_px = Vector2(2560, 1600)
	spawn_px = Vector2(700, 700)  # on the trail, clear of rocks
	sky_top = Color(0.42, 0.52, 0.74)
	sky_horizon = Color(0.86, 0.90, 0.98)
	sun_color = Color(0.92, 0.95, 1.0)
	sun_energy = 1.15
	fog_density = 0.03
	fog_color = Color(0.86, 0.90, 0.97)
	grade_saturation = 0.96


func _setup_area() -> void:
	# Packed-snow ground: a clean blue-white plane (no green grass here).
	ground("", 128.0, Color(0.88, 0.93, 1.0))
	for edge: Rect2 in [
		Rect2(-64, 0, 64, map_px.y), Rect2(map_px.x, 0, 64, map_px.y),
		Rect2(0, -64, map_px.x, 64), Rect2(0, map_px.y, map_px.x, 64),
	]:
		wall3d(edge, 4.0)

	# The trodden trail across the snow.
	road(Rect2(0, 660, 1400, 90), "res://assets/sprites/props/cobble_fill.png")
	road(Rect2(1330, 470, 90, 260), "res://assets/sprites/props/cobble_fill.png")
	road(Rect2(1330, 640, 1230, 90), "res://assets/sprites/props/cobble_fill.png")

	# The frozen river + a rock-cliff rampart sealing the north.
	water(Rect2(1310, 260, 96, 1340))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20
	var x: float = 120.0
	while x < map_px.x - 80.0:
		prop(HDAssets.nature(["Rock_3", "Rock_5"][rng.randi_range(0, 1)]),
			Vector2(x, 150 + rng.randf_range(-20, 20)), rng.randf_range(0, 360),
			rng.randf_range(1.8, 2.6), 120.0)
		x += 200.0
	wall3d(Rect2(0, 0, map_px.x, 280), 5.0)
	# Pine stands + boulders, frosted (kept well clear of the trail/spawn).
	scatter_nature(Rect2(140, 900, 420, 560), ["PineTree_1", "PineTree_3"], 14, 21, 1.8, 2.6, 90.0)
	scatter_nature(Rect2(1700, 1050, 660, 480), ["PineTree_2", "PineTree_4"], 14, 22, 1.8, 2.6, 90.0)
	scatter_nature(Rect2(1500, 900, 900, 640), ["Rock_1", "Rock_2", "Rock_4"], 16, 23, 0.9, 1.6)

	# Ice crystals catching the pale light, and the save crystal.
	for ice_px: Vector2 in [Vector2(900, 980), Vector2(2050, 900), Vector2(560, 480), Vector2(2200, 540)]:
		crystal3(ice_px)
	# The optional hoard nook in the north.
	for clutter: String in ["chest_gold", "coin_stack_large", "barrel_large"]:
		prop(HDAssets.dungeon(clutter), Vector2(2100, 380) + Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40)), rng.randf_range(0, 360), 2.0)

	# Heavy drifting snow across the whole field.
	_snow()

	npc3("shrine_keeper", Vector2(2330, 700), [
		"The crystal site hums at night now. Like a hymn with the words worn off.",
		"A woman in purple passed at dusk once. Didn't pray. COUNTED the candles.",
	] as Array[String], Color(0.8, 0.82, 0.88))

	portal(Rect2(0, 600, 80, 220), "res://world3d/hd_deepwoods.tscn", "< The Selinoran Deep")
	portal(Rect2(2480, 600, 80, 220), "res://world3d/hd_dungeon.tscn", "Crystal Site II >")


func _snow() -> void:
	var snow: GPUParticles3D = GPUParticles3D.new()
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(map_px.x / HDAssets.PX / 2.0, 1.0, map_px.y / HDAssets.PX / 2.0)
	material.direction = Vector3(0.3, -1.0, 0.1)
	material.gravity = Vector3(0.4, -2.2, 0.2)
	material.initial_velocity_min = 0.8
	material.initial_velocity_max = 1.6
	material.scale_min = 0.5
	material.scale_max = 1.3
	material.turbulence_enabled = true
	material.turbulence_noise_strength = 0.6
	snow.process_material = material
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var flake: StandardMaterial3D = StandardMaterial3D.new()
	flake.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flake.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flake.albedo_color = Color(0.98, 0.99, 1.0, 0.85)
	quad.material = flake
	snow.draw_pass_1 = quad
	snow.amount = 500
	snow.lifetime = 8.0
	snow.preprocess = 8.0
	snow.position = HDAssets.to3d(map_px / 2.0, 10.0)
	snow.visibility_aabb = AABB(
		Vector3(-map_px.x / HDAssets.PX, -4, -map_px.y / HDAssets.PX),
		Vector3(map_px.x / HDAssets.PX * 2, 24, map_px.y / HDAssets.PX * 2)
	)
	add_child(snow)
