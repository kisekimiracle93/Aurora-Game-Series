extends AreaBase
## Aethertown, third pass: a real castle town. Castle Aetherhold rises in
## layered stone (rear towers behind the curtain wall behind the keep), a
## river runs the west side under two bridges, the avenue is cobbled and
## gated, homes are bigger and walk-behindable (chests hide back there),
## and the streets play out little bubble-talk scenes — shoppers haggling,
## a farmer arguing with his cow, kids playing tag.

var _world: Node


func _init() -> void:
	area_name = "AETHERTOWN — under the walls of Castle Aetherhold"
	music_track = "town"
	ambience_profile = "town"
	map_size = Vector2(2560, 1600)
	frost_level = 0.05
	fog_level = 0.06


func _setup_area() -> void:
	_world = get_node_or_null("/root/WorldState")
	_build_grounds()
	_build_river()
	_build_castle()
	_build_homes()
	add_save_crystal(Vector2(1375, 800))
	_build_npcs_and_quests()
	_build_vignettes()
	_build_life()

	# Night-life: lanterns + torches along the cobbles; gentle snowfall.
	add_point_light(Vector2(420, 330), Color(1.0, 0.8, 0.5), 1.4, 1.0)
	add_point_light(Vector2(1560, 850), Color(1.0, 0.78, 0.48), 1.3, 0.95)
	add_point_light(Vector2(300, 1060), Color(1.0, 0.82, 0.55), 1.1, 0.8)
	for torch_pos: Vector2 in [
		Vector2(520, 640), Vector2(940, 640), Vector2(1640, 640), Vector2(2120, 640),
		Vector2(1300, 720), Vector2(1460, 720), Vector2(960, 1240),
	]:
		add_torch(torch_pos)
	add_road_gate(Vector2(2470, 655))
	add_road_gate(Vector2(950, 1450))
	add_snowfall(170)

	add_chest("town_well", Vector2(1180, 900), {"item_hp_potion": 2})
	add_chest("town_east_garden", Vector2(2300, 950), {"item_aether_draught": 2})
	# Hidden behind buildings — reward for walking where the roofs hide you.
	add_chest("town_widow_back", Vector2(2380, 300), {"item_hp_potion": 2, "item_aether_draught": 1})
	add_chest("town_castle_lee", Vector2(800, 470), {"item_hp_potion": 1})

	# Road out, east edge — into the Verdant Pass.
	add_exit(Rect2(2520, 560, 40, 200), "res://world/forest.tscn", Vector2(130, 980))
	var gate_label: Label = Label.new()
	gate_label.text = "To the Verdant Pass >"
	gate_label.position = Vector2(2290, 530)
	gate_label.add_theme_font_size_override("font_size", 14)
	add_child(gate_label)


## Castle Aetherhold: a full keep in three depth layers (not enterable).
func _build_castle() -> void:
	var stone: Texture2D = (
		load("res://assets/sprites/ui/stone_panel.png")
		if ResourceLoader.exists("res://assets/sprites/ui/stone_panel.png") else null
	)
	# One wrapper anchored at the wall base so the whole keep Y-sorts as a mass.
	var base_y: float = 600.0
	var castle: Node2D = Node2D.new()
	castle.position = Vector2(0, base_y)
	castle.z_index = SORT_Z
	add_child(castle)

	var stone_block: Callable = func(rect: Rect2, tint: Color, z: int) -> void:
		if stone != null:
			var wall: TextureRect = TextureRect.new()
			wall.texture = stone
			wall.stretch_mode = TextureRect.STRETCH_TILE
			wall.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			wall.position = rect.position - Vector2(0, base_y)
			wall.size = rect.size
			wall.modulate = tint
			wall.z_index = z
			castle.add_child(wall)
		else:
			var block: ColorRect = ColorRect.new()
			block.color = Color(0.34, 0.35, 0.42) * tint
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
			), tint * 0.85, z)

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
	var back_tint: Color = Color(0.62, 0.64, 0.74)
	stone_block.call(Rect2(1060, 0, 640, 220), back_tint, 1)
	teeth.call(Rect2(1060, 0, 640, 0), back_tint, 1)
	for tower_x: float in [1010.0, 1700.0]:
		stone_block.call(Rect2(tower_x, -40, 110, 280), back_tint, 1)
		teeth.call(Rect2(tower_x, -40, 110, 0), back_tint, 1)
	# The great keep rises tallest, dead center.
	stone_block.call(Rect2(1280, -80, 200, 360), Color(0.78, 0.80, 0.88), 2)
	teeth.call(Rect2(1280, -80, 200, 0), Color(0.78, 0.80, 0.88), 2)
	banner.call(1380.0, -40.0, 3)

	# LAYER 2 — the front curtain wall, full brightness.
	stone_block.call(Rect2(880, 200, 1000, 400), Color.WHITE, 4)
	teeth.call(Rect2(880, 200, 1000, 0), Color.WHITE, 4)
	# Parapet walk shadow-line.
	var walkline: ColorRect = ColorRect.new()
	walkline.color = Color(0.0, 0.0, 0.05, 0.35)
	walkline.position = Vector2(880, 246 - base_y)
	walkline.size = Vector2(1000, 10)
	walkline.z_index = 4
	castle.add_child(walkline)
	# Buttresses give the wall its rhythm.
	for buttress_x: float in [960.0, 1140.0, 1620.0, 1800.0]:
		stone_block.call(Rect2(buttress_x, 380, 34, 220), Color(0.8, 0.8, 0.86), 5)

	# LAYER 3 — front towers, gatehouse, windows, the gate.
	for tower_x: float in [880.0, 1770.0]:
		stone_block.call(Rect2(tower_x, 110, 130, 490), Color(1.04, 1.04, 1.08), 6)
		teeth.call(Rect2(tower_x, 110, 130, 0), Color.WHITE, 6)
		banner.call(tower_x + 65.0, 160.0, 7)
	for tower_x: float in [1150.0, 1530.0]:
		stone_block.call(Rect2(tower_x, 150, 110, 450), Color(0.96, 0.96, 1.0), 6)
		teeth.call(Rect2(tower_x, 150, 110, 0), Color.WHITE, 6)
	# Gatehouse around the arch.
	stone_block.call(Rect2(1300, 250, 210, 350), Color(1.06, 1.06, 1.1), 7)
	teeth.call(Rect2(1300, 250, 210, 0), Color.WHITE, 7)
	banner.call(1340.0, 300.0, 8)
	banner.call(1470.0, 300.0, 8)
	# Lit windows (they matter at night).
	for window_pos: Vector2 in [
		Vector2(940, 300), Vector2(1080, 380), Vector2(1180, 260), Vector2(1340, -20),
		Vector2(1410, 60), Vector2(1560, 260), Vector2(1700, 380), Vector2(1810, 300),
		Vector2(1240, 440), Vector2(1640, 440),
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
	arch.position = Vector2(1355, 480 - base_y)
	arch.size = Vector2(100, 120)
	arch.z_index = 8
	castle.add_child(arch)
	for bar: int in range(5):
		var iron: ColorRect = ColorRect.new()
		iron.color = Color(0.22, 0.22, 0.26)
		iron.position = Vector2(1361 + bar * 22, 480 - base_y)
		iron.size = Vector2(5, 120)
		iron.z_index = 9
		castle.add_child(iron)
	add_point_light(Vector2(1330, 560), Color(1.0, 0.62, 0.25), 1.0, 1.1)
	add_point_light(Vector2(1480, 560), Color(1.0, 0.62, 0.25), 1.0, 1.1)
	add_interactable(Vector2(1405, 640), "Knock at the castle gate", func() -> void:
		show_dialog([
			"The gatekeeper's slit slides open, then shut.",
			"Gatekeeper: 'Pilgrims to the fields. Petitioners to the chapel. Neither enters Aetherhold.'",
		]))
	# Solid mass + sun shadow + grounding.
	add_wall(Rect2(870, 0, 1020, 600))
	add_occluder(Rect2(880, 200, 1000, 400))
	add_ground_shadow(Vector2(1380, 620), 1150.0)


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
		ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ground.size = map_size
		ground.z_index = -10
		add_child(ground)
	else:
		add_rect(Rect2(Vector2.ZERO, map_size), Color(0.16, 0.20, 0.16), -10)
	# Cobbled avenue, gate plaza, and market lane (real stone underfoot now).
	add_cobble_road(Rect2(210, 600, 2350, 110))
	add_cobble_road(Rect2(880, 710, 120, 890), true)
	add_cobble_road(Rect2(1340, 710, 130, 130), true)
	# The plaza fans out before the gate in packed earth.
	var dirt: Texture2D = AssetLibrary.texture("props", "dirt_patch")
	if dirt != null:
		var plaza: TextureRect = TextureRect.new()
		plaza.texture = dirt
		plaza.stretch_mode = TextureRect.STRETCH_TILE
		plaza.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		plaza.position = Vector2(1180, 700)
		plaza.size = Vector2(230, 110)
		plaza.scale = Vector2(2.0, 2.0)
		plaza.z_index = -9
		plaza.modulate = Color(1.0, 0.98, 0.92, 0.9)
		add_child(plaza)
	# Pine breaks along the north edge + green hedges and single pines about town.
	for x: float in [60.0, 360.0, 660.0, 1980.0, 2280.0, 2500.0]:
		add_prop("pine_cluster", Vector2(x, 150), 2.0, true, true)
	for pos: Vector2 in [
		Vector2(620, 760), Vector2(1700, 770), Vector2(2210, 760), Vector2(330, 1380),
		Vector2(1840, 1180), Vector2(2470, 1100),
	]:
		add_prop("pine_single", pos, 2.0, true, true)
	for pos: Vector2 in [Vector2(760, 900), Vector2(1960, 920), Vector2(1180, 1390)]:
		add_prop("hedge_block", pos, 1.3, true)


## The river: in from the north mists, under two bridges, out the south wall.
func _build_river() -> void:
	var channel: Rect2 = Rect2(110, 0, 100, map_size.y)
	var water: Texture2D = AssetLibrary.texture("props", "water_tile")
	if water != null:
		var river: TextureRect = TextureRect.new()
		river.texture = water
		river.stretch_mode = TextureRect.STRETCH_TILE
		river.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		river.position = channel.position
		river.size = channel.size / 2.0
		river.scale = Vector2(2.0, 2.0)
		river.z_index = -8
		river.material = AssetLibrary.water_material()
		add_child(river)
	else:
		add_rect(channel, Color(0.3, 0.55, 0.65, 0.95), -8)
	# Stony banks.
	var rocks: Texture2D = AssetLibrary.texture("props", "rock_wall")
	for bank_x: float in [channel.position.x - 14.0, channel.end.x - 4.0]:
		if rocks != null:
			var bank: TextureRect = TextureRect.new()
			bank.texture = rocks
			bank.stretch_mode = TextureRect.STRETCH_TILE
			bank.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			bank.position = Vector2(bank_x, 0)
			bank.size = Vector2(9, map_size.y / 2.0)
			bank.scale = Vector2(2.0, 2.0)
			bank.z_index = -7
			add_child(bank)
		else:
			add_rect(Rect2(bank_x, 0, 18, map_size.y), Color(0.45, 0.4, 0.34), -7)
	# Drifting glints sell the current.
	var glints: CPUParticles2D = CPUParticles2D.new()
	glints.position = Vector2(160, 60)
	glints.amount = 30
	glints.lifetime = 9.0
	glints.preprocess = 9.0
	glints.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	glints.emission_rect_extents = Vector2(40, 10)
	glints.direction = Vector2(0, 1)
	glints.spread = 4.0
	glints.gravity = Vector2.ZERO
	glints.initial_velocity_min = 150.0
	glints.initial_velocity_max = 190.0
	glints.scale_amount_min = 1.0
	glints.scale_amount_max = 2.0
	glints.color = Color(0.9, 1.0, 1.0, 0.5)
	glints.z_index = -7
	add_child(glints)
	add_point_light(Vector2(160, 660), Color(0.6, 0.85, 1.0), 1.6, 0.5)
	# Two bridges carry the roads; the rest of the channel is too cold to ford.
	add_wall(Rect2(96, 0, 128, 590))
	add_wall(Rect2(96, 720, 128, 480))
	add_wall(Rect2(96, 1340, 128, 260))
	for bridge_rect: Rect2 in [Rect2(80, 600, 160, 110), Rect2(80, 1210, 160, 120)]:
		add_cobble_road(bridge_rect)
		var rail_top: ColorRect = add_rect(
			Rect2(bridge_rect.position.x, bridge_rect.position.y - 8, bridge_rect.size.x, 8),
			Color(0.35, 0.26, 0.17), 2
		)
		rail_top.z_index = 2
		var rail_bottom: ColorRect = add_rect(
			Rect2(bridge_rect.position.x, bridge_rect.end.y, bridge_rect.size.x, 8),
			Color(0.30, 0.22, 0.14), 2
		)
		rail_bottom.z_index = 2
		for corner_x: float in [bridge_rect.position.x + 8.0, bridge_rect.end.x - 22.0]:
			add_prop("posts", Vector2(corner_x, bridge_rect.position.y - 16.0), 1.2, false)
	# Reeds and riverflowers.
	add_flowers([
		Vector2(238, 380), Vector2(244, 520), Vector2(80, 840), Vector2(238, 980),
		Vector2(86, 1120), Vector2(240, 1420),
	], 29)


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
	# Solid lower body, with the doorway gap open at the bottom-center.
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
	# The inn (landmark, not enterable in the slice) + districts of homes.
	_add_home(Vector2(420, 420), false)  # Pilgrims' Rest
	_add_home(Vector2(2120, 420), true, {
		"prompt": "Enter the fisher's home", "title": "THE FISHER'S HOME",
		"lines": [
			"Fisher: 'The lake froze in a single night, years back. Nobody fishes the deep holes now.'",
			"Fisher: 'You hear it too, don't you? The hum under the ice.'",
		],
	})
	_add_home(Vector2(2380, 460), true, {
		"prompt": "Enter the widow's home", "title": "THE WIDOW'S HOME",
		"lines": [
			"Widow: 'My husband walked the fields one winter and the wolves... well. Mind the road, pilgrim.'",
		],
	})
	_add_home(Vector2(420, 940), true)  # locked home (flavor only)
	_add_home(Vector2(2150, 1040), true)  # east district homes (locked)
	_add_home(Vector2(2400, 1290), true)
	_add_home(Vector2(700, 1330), false)  # the old granary
	_add_home(Vector2(1560, 1000), true, {
		"prompt": "Enter the Mercenary Post", "title": "MERCENARY POST — CHURCH CHARTER",
		"merc": true,
		"lines": [],
	})
	# Shop stall (stub) — barrels, crates, and a cart give it a working yard.
	add_building(Rect2(150, 1080, 220, 120), Color(0.27, 0.3, 0.35))
	add_interactable(Vector2(260, 1150), "Browse the shop", func() -> void:
		show_dialog([
			"Shopkeep: 'Stock's still on the wagon, friend. After the pilgrimage, maybe.'",
			"(The shop is a stub in this slice — full trade arrives later.)",
		]))
	for pos: Vector2 in [Vector2(395, 1105), Vector2(420, 1140)]:
		add_prop("barrel", pos, 2.0)
	add_prop("crate", Vector2(400, 1190), 2.0)
	_add_handcart(Vector2(330, 1255))
	for pos: Vector2 in [Vector2(2060, 480), Vector2(1500, 1090)]:
		add_prop("barrel", pos, 2.0)


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
		Vector2(540, 540), Vector2(580, 560), Vector2(620, 535), Vector2(320, 770),
		Vector2(360, 800), Vector2(1180, 780), Vector2(1240, 800), Vector2(1530, 740),
		Vector2(2050, 780), Vector2(2230, 720), Vector2(820, 1180), Vector2(860, 1210),
		Vector2(1700, 1180), Vector2(2300, 1430), Vector2(480, 1180), Vector2(1960, 540),
	])
	for hen_home: Vector2 in [Vector2(580, 800), Vector2(660, 840), Vector2(2180, 1180)]:
		add_chicken(hen_home)


## The bubble-talk street scenes: lives that don't wait for you.
func _build_vignettes() -> void:
	# 1) The shop crowd, broke and dreaming.
	var buyer_a: Node2D = add_roamer("buyer_a", [Vector2(220, 1190)] as Array[Vector2],
		[] as Array[String], Color(0.8, 0.7, 0.6))
	var buyer_b: Node2D = add_roamer("buyer_b", [Vector2(300, 1210)] as Array[Vector2],
		[] as Array[String], Color(0.65, 0.7, 0.85))
	var buyer_c: Node2D = add_roamer("buyer_c", [
		Vector2(350, 1150), Vector2(310, 1170),
	] as Array[Vector2], [] as Array[String], Color(0.85, 0.8, 0.65))
	add_vignette(Vector2(280, 1160), 330.0, [
		{"node": buyer_a, "lines": ["I'll buy three.", "Why didn't I save more...", "Is THAT new?"]},
		{"node": buyer_b, "lines": [
			"I need more money. Darn.", "This stall always has something fresh.",
			"I should've asked Richard what colors he liked.",
		]},
		{"node": buyer_c, "lines": ["Two coppers? Robbery.", "Fine. FINE. One of each."]},
	])
	# 2) A farmer versus a profoundly stubborn cow.
	var cow: Node2D = Node2D.new()
	cow.position = Vector2(1980, 1290)
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
		Vector2(2030, 1290), Vector2(2014, 1290),
	] as Array[Vector2], [] as Array[String], Color(0.75, 0.65, 0.5))
	add_vignette(Vector2(2000, 1290), 320.0, [
		{"node": farmer, "lines": [
			"Hyah! MOVE, ye great boulder.", "I haven't got all day, Bess.",
			"The grass is the SAME over there!", "Please. I'm begging now. Officially.",
		]},
		{"node": cow, "lines": ["...Mrrh.", "*chews*", "*stares through him*"]},
	])
	# 3) Kids playing tag around the plaza well.
	var kid_a: Node2D = add_roamer("kid_a", [
		Vector2(1130, 880), Vector2(1240, 930), Vector2(1100, 990), Vector2(1010, 910),
	] as Array[Vector2], [] as Array[String], Color(0.95, 0.8, 0.6))
	kid_a.scale = Vector2(0.72, 0.72)
	var kid_b: Node2D = add_roamer("kid_b", [
		Vector2(1240, 930), Vector2(1100, 990), Vector2(1010, 910), Vector2(1130, 880),
	] as Array[Vector2], [] as Array[String], Color(0.7, 0.85, 0.95))
	kid_b.scale = Vector2(0.68, 0.68)
	add_vignette(Vector2(1120, 930), 340.0, [
		{"node": kid_a, "lines": ["Can't catch me!", "You're IT!", "Too slow! Too slow!"]},
		{"node": kid_b, "lines": [
			"No fair, you started early!", "Mum said not past the gate!", "Wait— WAIT—",
		]},
	])


func _build_npcs_and_quests() -> void:
	add_roamer("villager_d", [
		Vector2(1700, 660), Vector2(2300, 660), Vector2(2300, 780),
	] as Array[Vector2], [
		"The castle gate hasn't opened for common folk in nine years.",
		"They light the keep's windows all night. Who for, I wonder.",
		"Mind the chickens. They bite. Don't laugh — they do.",
	] as Array[String], Color(0.75, 0.85, 0.7))
	add_roamer("villager_e", [
		Vector2(960, 1180), Vector2(960, 1420), Vector2(700, 1420),
	] as Array[Vector2], [
		"Fresh bread at dawn, if the granary holds.",
		"You're with the pilgrimage? Selene keep you.",
		"My grandmother remembers when the falls didn't freeze.",
	] as Array[String], Color(0.9, 0.8, 0.75))
	add_roamer("villager_a", [
		Vector2(700, 650), Vector2(1150, 650), Vector2(1150, 760), Vector2(700, 760),
	] as Array[Vector2], [
		"Hello.", "Hi there.", "Move along, kid.", "I don't have time today.",
		"Cold's coming early this year.", "The Lancer drinks for free. Church coin.",
	] as Array[String], Color(0.85, 0.75, 0.65))
	add_roamer("villager_b", [
		Vector2(330, 620), Vector2(330, 1000), Vector2(580, 1000),
	] as Array[Vector2], [
		"I'm looking for my cat. Three days now.", "Have you seen a grey cat?",
		"She answers to 'Ember'. Sometimes.",
	] as Array[String], Color(0.7, 0.8, 0.9))
	add_roamer("villager_c", [
		Vector2(640, 200), Vector2(800, 200), Vector2(800, 330),
	] as Array[Vector2], [
		"The chapel bell cracked last Dimming. Never rang right since.",
		"Don't go past the fields at night.", "Hm? No, nothing. Forget it.",
	] as Array[String], Color(0.9, 0.85, 0.7))

	# --- Choice quests: words that weigh on the meters --------------------------
	_add_quest_npc("quest_letter", Vector2(700, 980), Color(0.75, 0.6, 0.5), "Courier",
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
	_add_quest_npc("quest_smuggler", Vector2(1250, 1100), Color(0.6, 0.65, 0.6), "Nervous man",
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
	_add_quest_npc("quest_festival", Vector2(560, 250), Color(0.8, 0.7, 0.85), "Old acolyte",
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
