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

	# CASTLE AETHERHOLD — the real thing this time, towers and all.
	prop(HDAssets.medieval("building_castle_red"), Vector2(2100, 360), 180.0, 9.0, 900.0)
	prop(HDAssets.medieval("building_tower_A_red"), Vector2(1560, 480), 180.0, 6.0, 200.0)
	prop(HDAssets.medieval("building_tower_A_red"), Vector2(2640, 480), 180.0, 6.0, 200.0)
	wall3d(Rect2(1450, 0, 1300, 560), 6.0)
	# The church and the working town around the plaza.
	prop(HDAssets.medieval("building_church_red"), Vector2(1650, 780), 160.0, 4.5, 320.0)
	prop(HDAssets.medieval("building_tavern_red"), Vector2(920, 880), 90.0, 4.0, 300.0)
	prop(HDAssets.medieval("building_home_A_red"), Vector2(3050, 820), -90.0, 4.0, 280.0)
	prop(HDAssets.medieval("building_home_B_red"), Vector2(3350, 900), -90.0, 4.0, 280.0)
	prop(HDAssets.medieval("building_home_A_red"), Vector2(1500, 1450), 0.0, 4.0, 280.0)
	prop(HDAssets.medieval("building_home_B_red"), Vector2(2480, 1430), 0.0, 4.0, 280.0)
	prop(HDAssets.medieval("building_market_red"), Vector2(820, 1620), 0.0, 4.0, 300.0)
	prop(HDAssets.medieval("building_windmill_red"), Vector2(3100, 1950), -35.0, 4.5, 320.0)
	prop(HDAssets.medieval("building_well_red"), Vector2(2120, 920), 0.0, 3.0, 120.0)
	prop(HDAssets.medieval("building_lumbermill_red"), Vector2(1250, 1880), 25.0, 4.0, 320.0)

	# Market clutter from the dungeon kit.
	for clutter: Array in [
		["barrel_small", Vector2(950, 1580)], ["crate_large", Vector2(975, 1655)],
		["barrel_large_decorated", Vector2(2420, 1520)], ["box_stacked", Vector2(2990, 870)],
	]:
		prop(HDAssets.dungeon(String(clutter[0])), clutter[1], randf_range(0, 360), 1.4)

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

	portal(Rect2(3760, 1040, 80, 220), "res://world/town.tscn", "To the 2D road >")
