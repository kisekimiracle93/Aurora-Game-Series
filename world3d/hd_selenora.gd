extends HDBase
## SELENORA, the HD-2D pilot: the 2D town's landmarks rebuilt in true 3D —
## KayKit castle and homes, Quaternius pines, the river, cobbled avenue,
## burning torches — with your pixel pilgrims billboarded on top. Walk out
## the east road (or press Esc) to drop back onto the 2D world.

const COBBLE: String = "res://assets/sprites/props/cobble_fill.png"
const GRASS: String = "res://assets/all files/town_rpg_pack/town_rpg_pack/graphics/grass-tile-2.png"


func _init() -> void:
	area_name = "SELENORA — HD-2D PILOT (3D world, 2D souls)"
	map_px = Vector2(3840, 2400)
	spawn_px = Vector2(1950, 1180)  # on the avenue, plaza ahead, castle north


func _setup_area() -> void:
	ground(GRASS)
	# Edge fences so nobody walks off the diorama.
	for edge: Rect2 in [
		Rect2(-64, 0, 64, map_px.y), Rect2(map_px.x, 0, 64, map_px.y),
		Rect2(0, -64, map_px.x, 64), Rect2(0, map_px.y, map_px.x, 64),
	]:
		wall3d(edge, 4.0)

	# The avenue, plaza, and market lane in real cobble.
	road(Rect2(0, 1100, 3840, 110), COBBLE)
	road(Rect2(1860, 660, 480, 440), COBBLE)
	road(Rect2(620, 1210, 110, 360), COBBLE)

	# The river angles through the west, bridged where the roads cross it.
	water(Rect2(480, 0, 150, 1090))
	water(Rect2(480, 1230, 150, 1170))
	road(Rect2(420, 1090, 270, 140), COBBLE)
	var bridge: Node3D = HDAssets.medieval("building_bridge_A")
	if bridge != null:
		prop(bridge, Vector2(555, 1160), 90.0, 2.2)

	# CASTLE AETHERHOLD — a big landmark to the north, framed not crowded.
	prop(HDAssets.medieval("building_castle_red"), Vector2(2100, 300), 180.0, 7.5, 1000.0)
	prop(HDAssets.medieval("building_tower_A_red"), Vector2(1500, 440), 180.0, 4.5, 220.0)
	prop(HDAssets.medieval("building_tower_B_red"), Vector2(2700, 440), 180.0, 4.5, 220.0)
	prop(HDAssets.medieval("building_tower_A_red"), Vector2(1820, 200), 180.0, 4.0, 200.0)
	prop(HDAssets.medieval("building_tower_B_red"), Vector2(2380, 200), 180.0, 4.0, 200.0)
	wall3d(Rect2(1400, 0, 1400, 500), 7.0)
	# The church and a DENSE working town (eye candy to carry the floor).
	prop(HDAssets.medieval("building_church_red"), Vector2(1620, 760), 160.0, 4.5, 360.0)
	prop(HDAssets.medieval("building_tavern_red"), Vector2(820, 840), 90.0, 4.0, 320.0)
	prop(HDAssets.medieval("building_market_red"), Vector2(760, 1640), 0.0, 4.0, 320.0)
	prop(HDAssets.medieval("building_blacksmith_red"), Vector2(1150, 720), 120.0, 3.6, 300.0)
	prop(HDAssets.medieval("building_windmill_red"), Vector2(3150, 1980), -35.0, 4.5, 340.0)
	prop(HDAssets.medieval("building_watermill_red"), Vector2(700, 1280), 60.0, 4.0, 320.0)
	prop(HDAssets.medieval("building_lumbermill_red"), Vector2(1220, 1960), 25.0, 4.0, 320.0)
	prop(HDAssets.medieval("building_mine_red"), Vector2(3450, 1720), -60.0, 4.0, 320.0)
	prop(HDAssets.medieval("building_archeryrange_red"), Vector2(2800, 760), 200.0, 3.6, 280.0)
	prop(HDAssets.medieval("building_well_red"), Vector2(2120, 980), 0.0, 2.6, 120.0)
	# Homes lining the avenue, set back off the road — density beats bare floor.
	var home_specs: Array = [
		[Vector2(3100, 800), -90.0], [Vector2(3420, 880), -90.0], [Vector2(3580, 1320), -90.0],
		[Vector2(1480, 1520), 0.0], [Vector2(2520, 1500), 10.0], [Vector2(3000, 1520), -10.0],
		[Vector2(1760, 1560), 0.0], [Vector2(3300, 2080), -40.0], [Vector2(1360, 720), 90.0],
		[Vector2(2200, 1560), 0.0], [Vector2(560, 1520), 30.0], [Vector2(3500, 1120), -90.0],
	]
	for i: int in range(home_specs.size()):
		var spec: Array = home_specs[i]
		prop(HDAssets.medieval("building_home_%s_red" % ("A" if i % 2 == 0 else "B")),
			spec[0], float(spec[1]), 3.6, 280.0)

	# Market + yard clutter from the dungeon kit (more = better).
	for clutter: Array in [
		["barrel_small", Vector2(900, 1600)], ["crates_stacked", Vector2(960, 1680)],
		["barrel_large_decorated", Vector2(2460, 1540)], ["barrel_small_stack", Vector2(3040, 850)],
		["crates_stacked", Vector2(840, 1720)], ["barrel_large", Vector2(1240, 2020)],
		["table_medium", Vector2(2060, 1050)], ["barrel_small", Vector2(2180, 1060)],
	]:
		prop(HDAssets.dungeon(String(clutter[0])), clutter[1], randf_range(0, 360), 1.6)

	# The woods ring — real trees with real depth.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in range(46):
		var tree_name: String = ["PineTree_1", "PineTree_2", "PineTree_3", "BirchTree_1", "BirchTree_3"][rng.randi_range(0, 4)]
		var edge_px: Vector2
		match i % 4:
			0: edge_px = Vector2(rng.randf_range(100, 1350), rng.randf_range(60, 260))
			1: edge_px = Vector2(rng.randf_range(2850, 3740), rng.randf_range(60, 260))
			2: edge_px = Vector2(rng.randf_range(100, 3740), rng.randf_range(2180, 2340))
			_: edge_px = Vector2(rng.randf_range(60, 240), rng.randf_range(300, 2100))
		prop(HDAssets.nature(tree_name), edge_px, rng.randf_range(0, 360),
			rng.randf_range(1.6, 2.4), 70.0)
	for i: int in range(14):
		prop(HDAssets.nature(["Bush", "Bush_Large", "Rock_1", "Rock_4"][rng.randi_range(0, 3)]),
			Vector2(rng.randf_range(700, 3400), rng.randf_range(1300, 2100)),
			rng.randf_range(0, 360), rng.randf_range(1.0, 1.8))

	# Light and life.
	for torch_px: Vector2 in [
		Vector2(1100, 1130), Vector2(1700, 1130), Vector2(2500, 1130), Vector2(3200, 1130),
		Vector2(1950, 740), Vector2(2280, 740),
	]:
		torch3(torch_px)
	crystal3(Vector2(2100, 980))
	npc3("villager_a", Vector2(1840, 1180), [
		"A whole NEW Selenora...", "The light falls different here. Softer.",
		"Mind the depth, pilgrim — the world has edges now.",
	] as Array[String], Color(0.85, 0.75, 0.65))
	npc3("villager_b", Vector2(2300, 1000), [
		"The castle has a BACK now. I checked.", "Have you seen a grey cat? In 3D?",
	] as Array[String], Color(0.7, 0.8, 0.9))
	npc3("villager_c", Vector2(950, 1500), [
		"First the crystal sings, now the world grows a third direction.",
		"Selene's light casts real shadows here. Fitting.",
	] as Array[String], Color(0.9, 0.85, 0.7))
	npc3("tarnaie", Vector2(2050, 1240), [
		"It's beautiful, Bas. Phi would have climbed everything.",
	] as Array[String])

	# East: on into the 3D Verdant Pass. (Esc always drops to the 2D town.)
	portal(Rect2(3760, 1040, 80, 220), "res://world3d/hd_forest.tscn", "The Verdant Pass >")
	npc3("villager_d", Vector2(3600, 1150), [
		"The road east is HD now too, they say. Whole world's gone deep.",
	] as Array[String], Color(0.75, 0.85, 0.7))
