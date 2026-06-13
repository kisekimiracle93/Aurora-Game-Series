extends HDBase
## AETHER CRYSTAL SITE II in HD-2D: the showcase for the KayKit dungeon kit —
## tiled stone floors, walls and pillars, banners and coffins, torch-lit dark,
## the memory crystal, and the Shepherd's arena door. This is where the 3D
## really sings.


func _init() -> void:
	area_name = "AETHER CRYSTAL SITE II — HD-2D"
	map_px = Vector2(2400, 1400)
	sky_top = Color(0.05, 0.07, 0.12)
	sky_horizon = Color(0.10, 0.13, 0.20)
	sun_color = Color(0.5, 0.6, 0.85)
	sun_energy = 0.35
	fog_density = 0.06
	fog_color = Color(0.18, 0.22, 0.32)
	grade_saturation = 1.05
	use_physical_sky = false  # a dark cavern, not an open sky
	ambience_foley = "Spooky Ambience"


func _setup_area() -> void:
	# A hewn-stone floor, wall to wall, from the kit (looks GREAT tiled).
	dungeon_floor(Rect2(0, 0, map_px.x, map_px.y), "floor_tile_large")
	# Floor collision (a thin invisible slab; the tiles are decor).
	var floor_body: StaticBody3D = StaticBody3D.new()
	var fshape: CollisionShape3D = CollisionShape3D.new()
	var fbox: BoxShape3D = BoxShape3D.new()
	fbox.size = Vector3(map_px.x / HDAssets.PX, 0.4, map_px.y / HDAssets.PX)
	fshape.shape = fbox
	fshape.position.y = -0.2
	floor_body.add_child(fshape)
	floor_body.position = HDAssets.to3d(map_px / 2.0)
	add_child(floor_body)

	# Outer walls + three chambers divided by walls with doorway gaps.
	dungeon_wall(Vector2(0, 0), Vector2(map_px.x, 0))
	dungeon_wall(Vector2(0, map_px.y), Vector2(map_px.x, map_px.y))
	dungeon_wall(Vector2(0, 0), Vector2(0, map_px.y))
	dungeon_wall(Vector2(map_px.x, 0), Vector2(map_px.x, map_px.y))
	dungeon_wall(Vector2(800, 0), Vector2(800, 520))
	dungeon_wall(Vector2(800, 880), Vector2(800, map_px.y))
	dungeon_wall(Vector2(1600, 0), Vector2(1600, 520))
	dungeon_wall(Vector2(1600, 880), Vector2(1600, map_px.y))

	# Pillars line the approach; banners and decay dress the stone.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12
	for px: Vector2 in [Vector2(300, 360), Vector2(300, 1040), Vector2(560, 700)]:
		prop(HDAssets.dungeon("pillar_decorated"), px, 0.0, 2.0, 80.0)
	for banner_px: Vector2 in [Vector2(120, 500), Vector2(120, 900)]:
		prop(HDAssets.dungeon("banner_patternC_blue"), banner_px, 90.0, 2.2)
	for decay: Array in [
		["coffin", Vector2(420, 300)], ["coffin_decorated", Vector2(420, 1100)],
		["rubble_large", Vector2(650, 450)], ["barrel_large", Vector2(250, 700)],
		["crates_stacked", Vector2(600, 950)], ["bones", Vector2(500, 600)],
	]:
		var node: Node3D = HDAssets.dungeon(String(decay[0]))
		if node != null:
			prop(node, decay[1], rng.randf_range(0, 360), 2.0)

	# Torches throw real shadows down the corridors.
	for torch_px: Vector2 in [
		Vector2(200, 300), Vector2(200, 1100), Vector2(620, 700),
		Vector2(1000, 300), Vector2(1000, 1100), Vector2(1400, 700),
		Vector2(1800, 400), Vector2(2200, 700), Vector2(1800, 1000),
	]:
		torch3(torch_px)

	# Zone 2: the memory crystal (M7) — violet, blazing.
	var memory: MeshInstance3D = MeshInstance3D.new()
	var prism: PrismMesh = PrismMesh.new()
	prism.size = Vector3(0.7, 1.6, 0.7)
	memory.mesh = prism
	var crystal_mat: StandardMaterial3D = StandardMaterial3D.new()
	crystal_mat.albedo_color = Color(0.75, 0.55, 1.0, 0.85)
	crystal_mat.emission_enabled = true
	crystal_mat.emission = Color(0.7, 0.45, 1.0)
	crystal_mat.emission_energy_multiplier = 3.5
	crystal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	memory.material_override = crystal_mat
	memory.position = HDAssets.to3d(Vector2(1200, 700), 1.0)
	add_child(memory)
	var spin: Tween = memory.create_tween().set_loops()
	spin.tween_property(memory, "rotation_degrees:y", 360.0, 8.0)
	spin.tween_callback(func() -> void: memory.rotation_degrees.y = 0.0)
	var memory_glow: OmniLight3D = OmniLight3D.new()
	memory_glow.light_color = Color(0.7, 0.5, 1.0)
	memory_glow.light_energy = 2.5
	memory_glow.omni_range = 7.0
	memory_glow.position = HDAssets.to3d(Vector2(1200, 700), 1.2)
	add_child(memory_glow)

	# Zone 3: the boss door, pulsing cold blue.
	prop(HDAssets.dungeon("wall_gated"), Vector2(2150, 700), 90.0, 2.5, 0.0)
	var door_glow: OmniLight3D = OmniLight3D.new()
	door_glow.light_color = Color(0.55, 0.85, 1.0)
	door_glow.light_energy = 2.0
	door_glow.omni_range = 6.0
	door_glow.position = HDAssets.to3d(Vector2(2120, 700), 1.4)
	add_child(door_glow)

	npc3("villager_c", Vector2(400, 700), [
		"The crystal sings, even down here. Especially down here.",
		"Voices older than the ice. They know the new Aetherion's name.",
	] as Array[String], Color(0.7, 0.75, 0.9))

	portal(Rect2(0, 600, 80, 200), "res://world3d/hd_fields.tscn", "< The Crystal Fields")
	# The boss is fought in the 2D combat system; the door drops you there.
	portal(Rect2(2320, 600, 80, 200), "res://world/dungeon.tscn", "The Shepherd's Arena (2D) >")
