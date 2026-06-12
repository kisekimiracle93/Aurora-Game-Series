extends AreaBase
## Aethertown, fourth pass: twice the town again (3840x2400), ringed by deep
## woods. A winding river angles NW->S under three cobbled bridges (water
## first, stone second — splashes, glints, fishermen, a stone-skipping kid).
## Castle Aetherhold fills the north behind guarded gates and flanking
## thickets (that's why you can't walk around it). Cobbled avenue and plaza,
## bigger walk-behind homes with chests hidden in their shadows, a working
## farm, the shop yard, guards, gates, and the same quest-bearing souls.

var _world: Node


func _init() -> void:
	area_name = "AETHERTOWN — under the walls of Castle Aetherhold"
	music_track = "town"
	ambience_profile = "town"
	map_size = Vector2(3840, 2400)
	default_spawn = Vector2(2100, 1260)
	frost_level = 0.05
	fog_level = 0.06


func _setup_area() -> void:
	_world = get_node_or_null("/root/WorldState")
	_build_grounds()
	_build_woods_ring()
	_build_river()
	_build_castle()
	_build_homes()
	_build_farm()
	add_save_crystal(Vector2(2100, 980))
	_build_npcs_and_quests()
	_build_vignettes()
	_build_life()

	# Night-life: lanterns + torches along the cobbles; gentle snowfall.
	add_point_light(Vector2(920, 880), Color(1.0, 0.8, 0.5), 1.4, 1.0)
	add_point_light(Vector2(2480, 1270), Color(1.0, 0.78, 0.48), 1.3, 0.95)
	add_point_light(Vector2(820, 1500), Color(1.0, 0.82, 0.55), 1.1, 0.8)
	for torch_pos: Vector2 in [
		Vector2(1100, 1130), Vector2(1600, 1130), Vector2(2700, 1130), Vector2(3200, 1130),
		Vector2(1900, 770), Vector2(2300, 770), Vector2(860, 1480), Vector2(3060, 1900),
	]:
		add_torch(torch_pos)
	add_road_gate(Vector2(3640, 1155), 300.0)
	add_road_gate(Vector2(680, 1155), 260.0)
	add_snowfall(220)

	add_chest("town_well", Vector2(2280, 1180), {"item_hp_potion": 2})
	add_chest("town_east_garden", Vector2(3480, 1310), {"item_aether_draught": 2})
	# Hidden behind buildings — reward for walking where the roofs hide you.
	add_chest("town_widow_back", Vector2(3350, 700), {"item_hp_potion": 2, "item_aether_draught": 1})
	add_chest("town_castle_lee", Vector2(1340, 880), {"item_hp_potion": 1})

	# Road out, east edge — into the Verdant Pass.
	add_exit(Rect2(3800, 1040, 40, 220), "res://world/forest.tscn", Vector2(130, 980))
	var gate_label: Label = Label.new()
	gate_label.text = "To the Verdant Pass >"
	gate_label.position = Vector2(3560, 1000)
	gate_label.add_theme_font_size_override("font_size", 14)
	add_child(gate_label)


func _build_grounds() -> void:
	var grass: Texture2D = load(
		"res://assets/all files/town_rpg_pack/town_rpg_pack/graphics/grass-tile-2.png"
	) if ResourceLoader.exists(
		"res://assets/all files/town_rpg_pack/town_rpg_pack/graphics/grass-tile-2.png"
	) else null
	if grass != null:
		var ground: TextureRect = TextureRect.new()
		ground.texture = grass
		ground.stretch_mode = TextureRect.STRETCH_TILE
		ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ground.size = map_size
		ground.z_index = -10
		add_child(ground)
	else:
		add_rect(Rect2(Vector2.ZERO, map_size), Color(0.16, 0.20, 0.16), -10)
	# Cobbled avenue west bridge -> east gate, the plaza apron, market lane
	# (the lane hugs the river's WEST side down to the shop yard).
	add_cobble_road(Rect2(240, 1100, 3600, 110))
	add_cobble_road(Rect2(1860, 660, 480, 440))
	add_cobble_road(Rect2(620, 1210, 110, 360), true)


## The deep woods ring: the town sits in a forest clearing. Only the east
## road breaks the treeline.
func _build_woods_ring() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 41
	var step: float = 116.0
	var x: float = 70.0
	while x < map_size.x - 60.0:
		# North edge (the castle owns the middle of it).
		if x < 1180.0 or x > 3020.0:
			add_prop("pine_cluster", Vector2(x, 130 + rng.randf_range(-16, 16)), 2.0, true, true)
		# South edge.
		add_prop("pine_cluster", Vector2(x, 2300 + rng.randf_range(-14, 14)), 2.0, true, true)
		x += step
	var y: float = 220.0
	while y < map_size.y - 140.0:
		add_prop("pine_cluster", Vector2(90, y), 2.0, true, true)
		# East edge parts only for the exit road.
		if y < 980.0 or y > 1330.0:
			add_prop("pine_cluster", Vector2(3760, y), 2.0, true, true)
		y += step
	# Castle flank thickets: the reason nobody strolls around the walls.
	for flank_x: float in [1180.0, 1300.0, 1420.0]:
		for flank_y: float in [180.0, 380.0, 560.0]:
			add_prop("pine_cluster", Vector2(flank_x + randf_range(-18, 18), flank_y), 2.0, true, true)
	for flank_x: float in [3040.0, 3160.0, 3280.0]:
		for flank_y: float in [180.0, 380.0, 560.0]:
			add_prop("pine_cluster", Vector2(flank_x + randf_range(-18, 18), flank_y), 2.0, true, true)


## The river: in from the north woods, angling SE in broad steps, out the
## south — WATER first (wide channel, thin banks), three cobbled bridges.
func _build_river() -> void:
	var water: Texture2D = AssetLibrary.texture("props", "water_tile")
	var rocks: Texture2D = AssetLibrary.texture("props", "rock_wall")
	# Channel segments: straight runs + stair-step diagonals.
	var segments: Array[Rect2] = [Rect2(480, 0, 150, 700)]
	var sx: float = 480.0
	var sy: float = 700.0
	for step: int in range(6):  # first diagonal: drift east while flowing south
		segments.append(Rect2(sx + step * 62.0, sy + step * 92.0, 150, 110))
	sx += 5 * 62.0
	sy += 6 * 92.0
	segments.append(Rect2(sx, sy, 150, 480))  # mid straight (x ~790)
	sy += 480.0
	for step: int in range(6):  # second diagonal
		segments.append(Rect2(sx + step * 74.0, sy + step * 90.0, 150, 108))
	sx += 5 * 74.0
	sy += 6 * 90.0
	segments.append(Rect2(sx, sy, 150, map_size.y - sy))  # out the south (x ~1160)

	for segment: Rect2 in segments:
		if water != null:
			var flow: TextureRect = TextureRect.new()
			flow.texture = water
			flow.stretch_mode = TextureRect.STRETCH_TILE
			flow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			flow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			flow.position = segment.position
			flow.size = segment.size / 2.0
			flow.scale = Vector2(2.0, 2.0)
			flow.z_index = -8
			flow.material = AssetLibrary.water_material()
			add_child(flow)
		else:
			add_rect(segment, Color(0.30, 0.55, 0.65, 0.95), -8)
	# Thin stone lips only on the long straights (water > stone).
	if rocks != null:
		for lip_config: Array in [
			[Vector2(470, 0), 690.0], [Vector2(622, 0), 690.0],
			[Vector2(780, 1260), 470.0], [Vector2(932, 1260), 470.0],
		]:
			var lip: TextureRect = TextureRect.new()
			lip.texture = rocks
			lip.stretch_mode = TextureRect.STRETCH_TILE
			lip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			lip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			lip.position = lip_config[0]
			lip.size = Vector2(5.0, float(lip_config[1]) / 2.0)
			lip.scale = Vector2(2.0, 2.0)
			lip.z_index = -7
			lip.modulate = Color(0.85, 0.82, 0.8, 0.9)
			add_child(lip)
	# Current glints + joint splashes: the water is ALIVE.
	for glint_config: Array in [
		[Vector2(555, 60), Vector2(0, 1)], [Vector2(865, 1300), Vector2(0, 1)],
		[Vector2(1235, 2300), Vector2(0, 1)],
	]:
		var glints: CPUParticles2D = CPUParticles2D.new()
		glints.position = glint_config[0]
		glints.amount = 26
		glints.lifetime = 7.0
		glints.preprocess = 7.0
		glints.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		glints.emission_rect_extents = Vector2(54, 10)
		glints.direction = glint_config[1]
		glints.spread = 5.0
		glints.gravity = Vector2.ZERO
		glints.initial_velocity_min = 130.0
		glints.initial_velocity_max = 180.0
		glints.scale_amount_min = 1.0
		glints.scale_amount_max = 2.2
		glints.color = Color(0.92, 1.0, 1.0, 0.55)
		glints.z_index = -7
		add_child(glints)
	for splash_pos: Vector2 in [
		Vector2(540, 690), Vector2(700, 1050), Vector2(870, 1270),
		Vector2(1050, 1980), Vector2(940, 1830),
	]:
		var splash: CPUParticles2D = CPUParticles2D.new()
		splash.position = splash_pos
		splash.amount = 9
		splash.lifetime = 0.7
		splash.preprocess = 0.7
		splash.spread = 60.0
		splash.direction = Vector2(0, -1)
		splash.gravity = Vector2(0, 240)
		splash.initial_velocity_min = 40.0
		splash.initial_velocity_max = 90.0
		splash.scale_amount_min = 1.0
		splash.scale_amount_max = 2.0
		splash.color = Color(0.95, 1.0, 1.0, 0.8)
		splash.z_index = -7
		add_child(splash)
	add_point_light(Vector2(560, 500), Color(0.6, 0.85, 1.0), 1.5, 0.5)
	add_point_light(Vector2(1235, 2330), Color(0.6, 0.85, 1.0), 1.5, 0.5)

	# Walls along the channel, except where the bridges carry you over.
	var bridges: Array[Rect2] = [
		Rect2(440, 470, 230, 130),   # north foot bridge
		Rect2(740, 1090, 250, 130),  # the avenue crossing
		Rect2(960, 1930, 250, 130),  # the south lane
	]
	for segment: Rect2 in segments:
		var blocked: Rect2 = segment.grow_individual(0, 0, 0, 0)
		var crossed: bool = false
		for bridge: Rect2 in bridges:
			if bridge.intersects(blocked.grow(8.0)):
				crossed = true
				# Wall above and below the bridge deck only.
				if bridge.position.y - blocked.position.y > 24.0:
					add_wall(Rect2(
						blocked.position,
						Vector2(blocked.size.x, bridge.position.y - blocked.position.y)
					))
				if blocked.end.y - bridge.end.y > 24.0:
					add_wall(Rect2(
						Vector2(blocked.position.x, bridge.end.y),
						Vector2(blocked.size.x, blocked.end.y - bridge.end.y)
					))
		if not crossed:
			add_wall(blocked)
	for bridge: Rect2 in bridges:
		add_cobble_road(bridge)
		add_rect(Rect2(bridge.position.x, bridge.position.y - 8, bridge.size.x, 8), Color(0.35, 0.26, 0.17), 2)
		add_rect(Rect2(bridge.position.x, bridge.end.y, bridge.size.x, 8), Color(0.30, 0.22, 0.14), 2)
		for corner_x: float in [bridge.position.x + 10.0, bridge.end.x - 24.0]:
			add_prop("posts", Vector2(corner_x, bridge.position.y - 14.0), 1.2, false)
	add_flowers([
		Vector2(660, 320), Vector2(450, 760), Vector2(700, 900), Vector2(960, 1340),
		Vector2(700, 1280), Vector2(1080, 1700), Vector2(1380, 2050), Vector2(1100, 2200),
	], 29)


## Castle Aetherhold: a full keep in three depth layers (not enterable).
func _build_castle() -> void:
	var stone: Texture2D = (
		load("res://assets/sprites/ui/stone_panel.png")
		if ResourceLoader.exists("res://assets/sprites/ui/stone_panel.png") else null
	)
	var base_y: float = 640.0
	var castle: Node2D = Node2D.new()
	castle.position = Vector2(0, base_y)
	castle.z_index = SORT_Z
	add_child(castle)

	var stone_block: Callable = func(rect: Rect2, tint: Color, z: int) -> void:
		if stone != null:
			var wall: TextureRect = TextureRect.new()
			wall.texture = stone
			wall.stretch_mode = TextureRect.STRETCH_TILE
			wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			wall.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			wall.position = rect.position - Vector2(0, base_y)
			wall.size = rect.size
			wall.modulate = tint
			wall.z_index = z
			castle.add_child(wall)
		else:
			var block: ColorRect = ColorRect.new()
			block.color = Color(0.40, 0.41, 0.48) * tint
			block.position = rect.position - Vector2(0, base_y)
			block.size = rect.size
			block.z_index = z
			castle.add_child(block)

	var teeth: Callable = func(rect: Rect2, tint: Color, z: int) -> void:
		var tooth_count: int = int(rect.size.x / 26.0)
		var tooth_w: float = rect.size.x / float(tooth_count * 2 - 1)
		for tooth: int in range(tooth_count):
			stone_block.call(Rect2(
				rect.position.x + tooth * tooth_w * 2.0, rect.position.y - 14.0,
				tooth_w, 14.0
			), tint * 0.8, z)

	var banner: Callable = func(x: float, y: float, z: int) -> void:
		var flag: ColorRect = ColorRect.new()
		flag.color = Color(0.62, 0.12, 0.14)
		flag.position = Vector2(x - 13, y - base_y)
		flag.size = Vector2(26, 60)
		flag.z_index = z
		castle.add_child(flag)
		var disc: ColorRect = ColorRect.new()
		disc.color = Color(0.92, 0.86, 0.65)
		disc.position = Vector2(x - 6, y + 16 - base_y)
		disc.size = Vector2(12, 12)
		disc.z_index = z
		castle.add_child(disc)

	# LAYER 1 — the rear keep, dimmer: towers seen over the front wall.
	var back_tint: Color = Color(0.74, 0.76, 0.86)
	stone_block.call(Rect2(1680, 0, 840, 240), back_tint, 1)
	teeth.call(Rect2(1680, 0, 840, 0), back_tint, 1)
	for tower_x: float in [1630.0, 2420.0]:
		stone_block.call(Rect2(tower_x, -40, 110, 300), back_tint, 1)
		teeth.call(Rect2(tower_x, -40, 110, 0), back_tint, 1)
	# The great keep rises tallest, dead center.
	stone_block.call(Rect2(1990, -90, 220, 380), Color(1.05, 1.06, 1.12), 2)
	teeth.call(Rect2(1990, -90, 220, 0), Color.WHITE, 2)
	banner.call(2100.0, -48.0, 3)

	# LAYER 2 — the front curtain wall, full brightness.
	stone_block.call(Rect2(1500, 240, 1200, 400), Color(1.18, 1.18, 1.22), 4)
	teeth.call(Rect2(1500, 240, 1200, 0), Color(1.1, 1.1, 1.15), 4)
	var walkline: ColorRect = ColorRect.new()
	walkline.color = Color(0.0, 0.0, 0.05, 0.30)
	walkline.position = Vector2(1500, 288 - base_y)
	walkline.size = Vector2(1200, 10)
	walkline.z_index = 4
	castle.add_child(walkline)
	for buttress_x: float in [1600.0, 1800.0, 2360.0, 2560.0]:
		stone_block.call(Rect2(buttress_x, 430, 36, 210), Color(1.0, 1.0, 1.05), 5)

	# LAYER 3 — front towers, gatehouse, windows, the gate.
	for tower_x: float in [1500.0, 2570.0]:
		stone_block.call(Rect2(tower_x, 140, 130, 500), Color(1.24, 1.24, 1.3), 6)
		teeth.call(Rect2(tower_x, 140, 130, 0), Color(1.15, 1.15, 1.2), 6)
		banner.call(tower_x + 65.0, 190.0, 7)
	for tower_x: float in [1790.0, 2300.0]:
		stone_block.call(Rect2(tower_x, 180, 110, 460), Color(1.14, 1.14, 1.2), 6)
		teeth.call(Rect2(tower_x, 180, 110, 0), Color(1.08, 1.08, 1.14), 6)
	stone_block.call(Rect2(1990, 300, 220, 340), Color(1.28, 1.28, 1.34), 7)
	teeth.call(Rect2(1990, 300, 220, 0), Color(1.18, 1.18, 1.24), 7)
	banner.call(2030.0, 350.0, 8)
	banner.call(2170.0, 350.0, 8)
	for window_pos: Vector2 in [
		Vector2(1560, 340), Vector2(1700, 420), Vector2(1840, 300), Vector2(2050, -30),
		Vector2(2130, 60), Vector2(2350, 300), Vector2(2480, 420), Vector2(2620, 340),
		Vector2(1940, 480), Vector2(2260, 480),
	]:
		var window: ColorRect = ColorRect.new()
		window.color = Color(1.0, 0.85, 0.45, 0.9)
		window.position = window_pos + Vector2(0, -base_y)
		window.size = Vector2(18, 28)
		window.z_index = 8
		castle.add_child(window)
		add_point_light(window_pos + Vector2(9, 14), Color(1.0, 0.8, 0.45), 0.5, 0.5)
	# The gate: dark arch, portcullis bars, brazier pair.
	var arch: ColorRect = ColorRect.new()
	arch.color = Color(0.07, 0.06, 0.09)
	arch.position = Vector2(2045, 520 - base_y)
	arch.size = Vector2(110, 120)
	arch.z_index = 8
	castle.add_child(arch)
	for bar: int in range(5):
		var iron: ColorRect = ColorRect.new()
		iron.color = Color(0.22, 0.22, 0.26)
		iron.position = Vector2(2052 + bar * 24, 520 - base_y)
		iron.size = Vector2(5, 120)
		iron.z_index = 9
		castle.add_child(iron)
	add_point_light(Vector2(2020, 610), Color(1.0, 0.62, 0.25), 1.0, 1.1)
	add_point_light(Vector2(2180, 610), Color(1.0, 0.62, 0.25), 1.0, 1.1)
	add_interactable(Vector2(2100, 690), "Knock at the castle gate", func() -> void:
		show_dialog([
			"The gatekeeper's slit slides open, then shut.",
			"Gatekeeper: 'Pilgrims to the fields. Petitioners to the chapel. Neither enters Aetherhold.'",
		]))
	add_wall(Rect2(1490, 0, 1220, 640))
	add_occluder(Rect2(1500, 240, 1200, 400))
	add_ground_shadow(Vector2(2100, 660), 1350.0)
	# The gate guard pair: spears, crimson tabards, no nonsense.
	for guard_config: Array in [
		[Vector2(1960, 700), "Halt. State your— ah. Pilgrims. Walk on."],
		[Vector2(2240, 700), "The Shepherd's woken something out east. Keep to the road."],
	]:
		var guard: Node2D = add_roamer("castle_guard", [guard_config[0]] as Array[Vector2],
			[String(guard_config[1]), "Eyes forward, citizen.", "No entry. Chapel's south."] as Array[String],
			Color(0.85, 0.55, 0.5))
		guard.scale = Vector2(1.1, 1.1)


## A home: sprite house anchored at its base (walk behind it!), solid below
## the roofline, and (optionally) a door you can enter.
func _add_home(pos: Vector2, tall: bool, door_config: Dictionary = {}) -> void:
	var art: Texture2D = AssetLibrary.texture("props", "house_tall" if tall else "house_inn")
	var home_scale: float = 2.4
	var footprint: Vector2
	if art != null:
		add_prop("house_tall" if tall else "house_inn", pos, home_scale, false)
		var size: Vector2 = art.get_size() * home_scale
		footprint = Vector2(size.x, size.y * 0.45)
	else:
		footprint = (Vector2(90, 118) if tall else Vector2(168, 104)) * 2.0
		add_rect(Rect2(pos - footprint / 2.0, footprint), Color(0.35, 0.27, 0.2), 4)
	var size_full: Vector2 = art.get_size() * home_scale if art != null else footprint
	var base_bottom: Vector2 = Vector2(pos.x - footprint.x / 2.0, pos.y + size_full.y / 2.0 - footprint.y)
	add_wall(Rect2(base_bottom, Vector2(footprint.x, footprint.y - 26)))
	add_wall(Rect2(
		base_bottom + Vector2(0, footprint.y - 26), Vector2(footprint.x / 2.0 - 28, 26)
	))
	add_wall(Rect2(
		base_bottom + Vector2(footprint.x / 2.0 + 28, footprint.y - 26),
		Vector2(footprint.x / 2.0 - 28, 26)
	))
	add_occluder(Rect2(base_bottom, footprint))
	add_ground_shadow(pos + Vector2(0, size_full.y / 2.0 - 6.0), footprint.x * 1.15)
	if door_config.is_empty():
		return
	var door_pos: Vector2 = pos + Vector2(0, size_full.y / 2.0 + 14)
	add_interactable(door_pos, String(door_config.get("prompt", "Enter")), func() -> void:
		if _world == null:
			show_dialog(["The door is barred to drifters."])
			return
		_world.next_interior = {
			"title": door_config.get("title", "A quiet home"),
			"lines": door_config.get("lines", []),
			"merc": door_config.get("merc", false),
			"exit_scene": scene_file_path,
			"exit_pos": door_pos + Vector2(0, 30),
		}
		get_tree().change_scene_to_file.call_deferred("res://world/interior.tscn"))


func _build_homes() -> void:
	_add_home(Vector2(920, 850), false)  # Pilgrims' Rest (inn), on the avenue
	_add_home(Vector2(3050, 800), true, {
		"prompt": "Enter the fisher's home", "title": "THE FISHER'S HOME",
		"lines": [
			"Fisher: 'The lake froze in a single night, years back. Nobody fishes the deep holes now.'",
			"Fisher: 'You hear it too, don't you? The hum under the ice.'",
		],
	})
	_add_home(Vector2(3350, 860), true, {
		"prompt": "Enter the widow's home", "title": "THE WIDOW'S HOME",
		"lines": [
			"Widow: 'My husband walked the fields one winter and the wolves... well. Mind the road, pilgrim.'",
		],
	})
	_add_home(Vector2(1500, 1450), true)  # locked homes (flavor only)
	_add_home(Vector2(3000, 1500), true)
	_add_home(Vector2(3380, 1760), true)
	_add_home(Vector2(1480, 1900), false)  # the old granary
	_add_home(Vector2(2480, 1430), true, {
		"prompt": "Enter the Mercenary Post", "title": "MERCENARY POST — CHURCH CHARTER",
		"merc": true,
		"lines": [],
	})
	# Shop stall (stub) — barrels, crates, and a cart give it a working yard.
	add_building(Rect2(700, 1560, 220, 120), Color(0.27, 0.3, 0.35))
	add_interactable(Vector2(810, 1630), "Browse the shop", func() -> void:
		show_dialog([
			"Shopkeep: 'Stock's still on the wagon, friend. After the pilgrimage, maybe.'",
			"(The shop is a stub in this slice — full trade arrives later.)",
		]))
	for pos: Vector2 in [Vector2(950, 1585), Vector2(975, 1620)]:
		add_prop("barrel", pos, 2.0)
	add_prop("crate", Vector2(955, 1670), 2.0)
	_add_handcart(Vector2(880, 1730))
	for pos: Vector2 in [Vector2(2990, 860), Vector2(2420, 1520)]:
		add_prop("barrel", pos, 2.0)
	for pos: Vector2 in [
		Vector2(1700, 1300), Vector2(2700, 950), Vector2(3550, 1550), Vector2(1050, 2050),
	]:
		add_prop("pine_single", pos, 2.0, true, true)
	for pos: Vector2 in [Vector2(1620, 1700), Vector2(2900, 1280), Vector2(2200, 1800)]:
		add_prop("hedge_block", pos, 1.3, true)


## The southeast farm: tilled plots, wheat-gold flowers, hens — and Bess.
func _build_farm() -> void:
	var dirt: Texture2D = AssetLibrary.texture("props", "dirt_patch")
	for plot_pos: Vector2 in [
		Vector2(2900, 1980), Vector2(3120, 1980), Vector2(2900, 2120), Vector2(3120, 2120),
	]:
		if dirt != null:
			var plot: Sprite2D = Sprite2D.new()
			plot.texture = dirt
			plot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			plot.scale = Vector2(2.0, 2.0)
			plot.position = plot_pos
			plot.z_index = -9
			add_child(plot)
		else:
			add_rect(Rect2(plot_pos - Vector2(48, 40), Vector2(96, 80)), Color(0.42, 0.3, 0.2), -9)
	add_flowers([
		Vector2(2860, 1940), Vector2(2960, 2050), Vector2(3080, 1940), Vector2(3180, 2060),
		Vector2(3000, 2160), Vector2(3220, 2160),
	], 53)
	var fence: Texture2D = AssetLibrary.texture("props", "fence")
	if fence != null:
		for fence_x: float in [2820.0, 2920.0, 3020.0, 3120.0, 3220.0]:
			var post: Sprite2D = Sprite2D.new()
			post.texture = fence
			post.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			post.scale = Vector2(1.6, 1.6)
			post.position = Vector2(fence_x, 1890)
			post.z_index = 2
			add_child(post)


## A little drawn handcart (village clutter the sheet didn't carry).
func _add_handcart(pos: Vector2) -> void:
	var cart: Node2D = Node2D.new()
	cart.position = pos
	cart.z_index = SORT_Z
	cart.draw.connect(func() -> void:
		cart.draw_rect(Rect2(-30, -22, 60, 18), Color(0.45, 0.33, 0.2))
		cart.draw_rect(Rect2(-30, -24, 60, 4), Color(0.55, 0.42, 0.26))
		cart.draw_rect(Rect2(28, -20, 26, 4), Color(0.4, 0.3, 0.18))
		cart.draw_circle(Vector2(-14, 0), 9.0, Color(0.3, 0.22, 0.13))
		cart.draw_circle(Vector2(-14, 0), 4.0, Color(0.5, 0.4, 0.25))
		cart.draw_circle(Vector2(14, 0), 9.0, Color(0.3, 0.22, 0.13))
		cart.draw_circle(Vector2(14, 0), 4.0, Color(0.5, 0.4, 0.25))
		cart.draw_rect(Rect2(-24, -34, 14, 12), Color(0.7, 0.6, 0.35))
		cart.draw_rect(Rect2(-6, -32, 12, 10), Color(0.6, 0.65, 0.4)))
	add_child(cart)
	add_wall(Rect2(pos + Vector2(-30, -12), Vector2(60, 22)))


## Flowers, hens, and the small life of a living town.
func _build_life() -> void:
	add_flowers([
		Vector2(1040, 950), Vector2(1080, 980), Vector2(1700, 1000), Vector2(1760, 1030),
		Vector2(2450, 980), Vector2(2520, 1010), Vector2(2900, 1180), Vector2(3300, 1100),
		Vector2(1300, 1550), Vector2(1360, 1580), Vector2(2050, 1600), Vector2(2750, 1700),
		Vector2(3470, 2050), Vector2(1900, 2100), Vector2(2350, 2000), Vector2(1450, 2150),
	])
	for hen_home: Vector2 in [Vector2(1300, 1980), Vector2(1380, 2030), Vector2(3240, 1930)]:
		add_chicken(hen_home)


## The bubble-talk street scenes: lives that don't wait for you.
func _build_vignettes() -> void:
	# 1) The shop crowd, broke and dreaming.
	var buyer_a: Node2D = add_roamer("buyer_a", [Vector2(760, 1690)] as Array[Vector2],
		[] as Array[String], Color(0.8, 0.7, 0.6))
	var buyer_b: Node2D = add_roamer("buyer_b", [Vector2(850, 1700)] as Array[Vector2],
		[] as Array[String], Color(0.65, 0.7, 0.85))
	var buyer_c: Node2D = add_roamer("buyer_c", [
		Vector2(900, 1640), Vector2(860, 1660),
	] as Array[Vector2], [] as Array[String], Color(0.85, 0.8, 0.65))
	add_vignette(Vector2(820, 1650), 330.0, [
		{"node": buyer_a, "lines": ["I'll buy three.", "Why didn't I save more...", "Is THAT new?"]},
		{"node": buyer_b, "lines": [
			"I need more money. Darn.", "This stall always has something fresh.",
			"I should've asked Richard what colors he liked.",
		]},
		{"node": buyer_c, "lines": ["Two coppers? Robbery.", "Fine. FINE. One of each."]},
	])
	# 2) A farmer versus a profoundly stubborn cow.
	var cow: Node2D = Node2D.new()
	cow.position = Vector2(3020, 2050)
	cow.z_index = SORT_Z
	cow.draw.connect(func() -> void:
		cow.draw_circle(Vector2.ZERO, 16.0, Color(0.92, 0.9, 0.86))
		cow.draw_circle(Vector2(-6, -2), 6.0, Color(0.25, 0.2, 0.18))
		cow.draw_circle(Vector2(8, 5), 5.0, Color(0.25, 0.2, 0.18))
		cow.draw_circle(Vector2(-17, -7), 7.0, Color(0.92, 0.9, 0.86))
		cow.draw_rect(Rect2(-24, -12, 5, 4), Color(0.85, 0.8, 0.7))
		cow.draw_rect(Rect2(-26, -9, 4, 3), Color(0.4, 0.33, 0.3))
		cow.draw_rect(Rect2(-9, 13, 4, 8), Color(0.8, 0.78, 0.72))
		cow.draw_rect(Rect2(5, 13, 4, 8), Color(0.8, 0.78, 0.72)))
	add_child(cow)
	var sway: Tween = cow.create_tween().set_loops()
	sway.tween_property(cow, "rotation_degrees", 2.0, 1.4)
	sway.tween_property(cow, "rotation_degrees", -1.0, 1.4)
	var farmer: Node2D = add_roamer("farmer", [
		Vector2(3070, 2050), Vector2(3054, 2050),
	] as Array[Vector2], [] as Array[String], Color(0.75, 0.65, 0.5))
	add_vignette(Vector2(3040, 2050), 340.0, [
		{"node": farmer, "lines": [
			"Hyah! MOVE, ye great boulder.", "I haven't got all day, Bess.",
			"The grass is the SAME over there!", "Please. I'm begging now. Officially.",
		]},
		{"node": cow, "lines": ["...Mrrh.", "*chews*", "*stares through him*"]},
	])
	# 3) Kids playing tag on the plaza.
	var kid_a: Node2D = add_roamer("kid_a", [
		Vector2(1980, 880), Vector2(2120, 930), Vector2(1960, 1000), Vector2(1880, 910),
	] as Array[Vector2], [] as Array[String], Color(0.95, 0.8, 0.6))
	kid_a.scale = Vector2(0.72, 0.72)
	var kid_b: Node2D = add_roamer("kid_b", [
		Vector2(2120, 930), Vector2(1960, 1000), Vector2(1880, 910), Vector2(1980, 880),
	] as Array[Vector2], [] as Array[String], Color(0.7, 0.85, 0.95))
	kid_b.scale = Vector2(0.68, 0.68)
	add_vignette(Vector2(2000, 930), 340.0, [
		{"node": kid_a, "lines": ["Can't catch me!", "You're IT!", "Too slow! Too slow!"]},
		{"node": kid_b, "lines": [
			"No fair, you started early!", "Mum said not past the gate!", "Wait— WAIT—",
		]},
	])
	# 4) The riverbank: two patient fishermen and a stone-skipping kid.
	var fisher_a: Node2D = add_roamer("fisher_a", [Vector2(420, 540)] as Array[Vector2],
		[] as Array[String], Color(0.6, 0.7, 0.75))
	var fisher_b: Node2D = add_roamer("fisher_b", [Vector2(680, 620)] as Array[Vector2],
		[] as Array[String], Color(0.75, 0.72, 0.6))
	var skipper: Node2D = add_roamer("skipper", [
		Vector2(600, 1000), Vector2(640, 1020),
	] as Array[Vector2], [] as Array[String], Color(0.9, 0.75, 0.6))
	skipper.scale = Vector2(0.7, 0.7)
	add_vignette(Vector2(600, 760), 420.0, [
		{"node": fisher_a, "lines": ["Anything?", "...", "The river's louder than it was."]},
		{"node": fisher_b, "lines": ["Quiet today.", "Had one. Lost one.", "Mind the current, lad."]},
		{"node": skipper, "lines": ["Four skips! FOUR!", "That one LOOKED at me.", "Watch THIS one."]},
	])
	# His stones actually hit the water.
	var skip_timer: Timer = Timer.new()
	skip_timer.wait_time = 5.0
	add_child(skip_timer)
	skip_timer.timeout.connect(func() -> void:
		if player == null or player.position.distance_to(Vector2(600, 1000)) > 500.0:
			return
		var plink: CPUParticles2D = CPUParticles2D.new()
		plink.position = Vector2(720, 1040)
		plink.one_shot = true
		plink.emitting = true
		plink.amount = 8
		plink.lifetime = 0.5
		plink.spread = 70.0
		plink.direction = Vector2(0, -1)
		plink.gravity = Vector2(0, 260)
		plink.initial_velocity_min = 50.0
		plink.initial_velocity_max = 100.0
		plink.color = Color(0.95, 1.0, 1.0, 0.85)
		plink.z_index = -7
		add_child(plink)
		var cleanup: Tween = plink.create_tween()
		cleanup.tween_interval(1.0)
		cleanup.tween_callback(plink.queue_free))
	skip_timer.start()


func _build_npcs_and_quests() -> void:
	add_roamer("villager_d", [
		Vector2(2450, 1140), Vector2(3050, 1140), Vector2(3050, 1280),
	] as Array[Vector2], [
		"The castle gate hasn't opened for common folk in nine years.",
		"They light the keep's windows all night. Who for, I wonder.",
		"Mind the chickens. They bite. Don't laugh — they do.",
	] as Array[String], Color(0.75, 0.85, 0.7))
	add_roamer("villager_e", [
		Vector2(1550, 1700), Vector2(1550, 1980), Vector2(1300, 2020),
	] as Array[Vector2], [
		"Fresh bread at dawn, if the granary holds.",
		"You're with the pilgrimage? Selene keep you.",
		"My grandmother remembers when the falls didn't freeze.",
	] as Array[String], Color(0.9, 0.8, 0.75))
	add_roamer("villager_a", [
		Vector2(1300, 1140), Vector2(1800, 1140), Vector2(1800, 1260), Vector2(1300, 1260),
	] as Array[Vector2], [
		"Hello.", "Hi there.", "Move along, kid.", "I don't have time today.",
		"Cold's coming early this year.", "The Lancer drinks for free. Church coin.",
	] as Array[String], Color(0.85, 0.75, 0.65))
	add_roamer("villager_b", [
		Vector2(990, 1300), Vector2(990, 1560), Vector2(1240, 1560),
	] as Array[Vector2], [
		"I'm looking for my cat. Three days now.", "Have you seen a grey cat?",
		"She answers to 'Ember'. Sometimes.",
	] as Array[String], Color(0.7, 0.8, 0.9))
	add_roamer("villager_c", [
		Vector2(2900, 1450), Vector2(3260, 1450), Vector2(3260, 1600),
	] as Array[Vector2], [
		"The chapel bell cracked last Dimming. Never rang right since.",
		"Don't go past the fields at night.", "Hm? No, nothing. Forget it.",
	] as Array[String], Color(0.9, 0.85, 0.7))

	# --- Choice quests: words that weigh on the meters --------------------------
	_add_quest_npc("quest_letter", Vector2(1180, 1330), Color(0.75, 0.6, 0.5), "Courier",
		"Courier: 'This letter proves the miller's husband cheats at dice — and worse. Deliver the truth to her, or burn it and spare the house the shame?'", [
		{"label": "Deliver the truth (Duty +14, Resolve +8)", "callback": func() -> void:
			_world.adjust_party_meter("duty", 14.0)
			_world.adjust_party_meter("resolve", 8.0)
			show_dialog(["The miller's wife reads it twice, thanks you once, and bars her door.",
				"Truth is a cold gift, but a gift."])},
		{"label": "Burn it (Burden +15, Heirs Darkness +8)", "callback": func() -> void:
			_world.adjust_party_meter("burden", 15.0)
			_world.adjust_party_meter("darkness", 8.0)
			show_dialog(["The letter curls to ash. The lie keeps a roof warm tonight.",
				"Something of it clings to your hands anyway."])},
	])
	_add_quest_npc("quest_smuggler", Vector2(2700, 1450), Color(0.6, 0.65, 0.6), "Nervous man",
		"Nervous man: 'The guards are coming for the grain smuggler tonight. He feeds half the poor quarter. Warn him — or let the law have him?'", [
		{"label": "Warn the smuggler (Resolve +10, Burden +12)", "callback": func() -> void:
			_world.adjust_party_meter("resolve", 10.0)
			_world.adjust_party_meter("burden", 12.0)
			show_dialog(["He's gone before the lanterns turn the corner. The poor quarter eats.",
				"The law remembers faces, though. Yours included."])},
		{"label": "Alert the guards (Duty +15, Resolve -6)", "callback": func() -> void:
			_world.adjust_party_meter("duty", 15.0)
			_world.adjust_party_meter("resolve", -6.0)
			show_dialog(["They take him quietly. The captain nods at you like a colleague.",
				"It was the lawful thing. The street is very quiet."])},
	])
	_add_quest_npc("quest_festival", Vector2(1650, 880), Color(0.8, 0.7, 0.85), "Old acolyte",
		"Old acolyte: 'The Festival of First Light... the \"miracle\" was lamp-oil and mirrors. I rigged it myself, forty years past. Should the town know?'", [
		{"label": "Tell the town the truth (Duty +12, Resolve -8)", "callback": func() -> void:
			_world.adjust_party_meter("duty", 12.0)
			_world.adjust_party_meter("resolve", -8.0)
			show_dialog(["Some thank you. Most don't. The festival lanterns look dimmer now to everyone.",
				"Truth costs what it costs."])},
		{"label": "Let the town keep its miracle (Burden +12)", "callback": func() -> void:
			_world.adjust_party_meter("burden", 12.0)
			show_dialog(["The old man nods, relieved and ashamed in the same breath.",
				"You carry the secret out the door with you."])},
	])


func _add_quest_npc(
	quest_id: String, pos: Vector2, tint: Color, npc_name: String,
	prompt_text: String, options: Array
) -> void:
	var art: Texture2D = AssetLibrary.texture("characters", "Cavene")
	if art != null:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = art
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(2.0, 2.0)
		sprite.modulate = tint
		sprite.position = pos
		sprite.z_index = SORT_Z
		add_child(sprite)
	var marker: Label = Label.new()
	marker.text = "?"
	marker.add_theme_font_size_override("font_size", 22)
	marker.modulate = Color(1.0, 0.9, 0.3)
	marker.position = pos + Vector2(-6, -56)
	marker.z_index = 6
	add_child(marker)
	add_interactable(pos, "Speak with the %s" % npc_name.to_lower(), func() -> void:
		if _world == null or not _world.in_world_run:
			show_dialog(["They wave you off. (Start a run from the main menu.)"])
			return
		if _world.quests_done.has(quest_id):
			show_dialog(["%s: 'It's done. No taking it back now.'" % npc_name])
			return
		_world.quests_done.append(quest_id)  # committed the moment the choice opens
		marker.visible = false
		show_choice(prompt_text, options))
