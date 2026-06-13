extends HDBase
## THE VERDANT PASS in HD-2D: a broad cobbled road through deep 3D pine and
## birch woods, walled by treelines, with branch clearings. East → the Deep.

const COBBLE: String = "res://assets/sprites/props/cobble_fill.png"
const GRASS: String = "res://assets/all files/town_rpg_pack/town_rpg_pack/graphics/grass-tile-2.png"


func _init() -> void:
	area_name = "THE VERDANT PASS — HD-2D"
	map_px = Vector2(3200, 2000)


func _setup_area() -> void:
	ground(GRASS)
	for edge: Rect2 in [
		Rect2(-64, 0, 64, map_px.y), Rect2(map_px.x, 0, 64, map_px.y),
		Rect2(0, -64, map_px.x, 64), Rect2(0, map_px.y, map_px.x, 64),
	]:
		wall3d(edge, 4.0)

	# The main road, BROAD and clear (a wide diorama corridor), branch north.
	road(Rect2(0, 860, 3200, 300), COBBLE)
	road(Rect2(1060, 440, 170, 540), COBBLE)

	# INVISIBLE collision walls keep you on the road; the woods stay visually
	# OPEN so the diorama camera looks down the path, not into a tree-wall.
	wall3d(Rect2(0, 760, 3200, 40), 3.0)    # north verge (gap at the branch)
	wall3d(Rect2(0, 1220, 3200, 40), 3.0)   # south verge
	# Spaced tree CLUMPS set well back, low enough to see the sky over them.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 31
	var x: float = 140.0
	while x < map_px.x - 80.0:
		if absf(x - 1140.0) > 180.0:
			for off: Vector2 in [Vector2(0, 0), Vector2(60, -90), Vector2(-50, -160)]:
				prop(HDAssets.nature(["PineTree_1", "PineTree_4", "BirchTree_2", "PineTree_3"][rng.randi_range(0, 3)]),
					Vector2(x, 650) + off + Vector2(rng.randf_range(-20, 20), 0), rng.randf_range(0, 360),
					rng.randf_range(1.5, 2.0))
		for off2: Vector2 in [Vector2(0, 0), Vector2(70, 90), Vector2(-40, 170)]:
			prop(HDAssets.nature(["PineTree_2", "PineTree_5", "BirchTree_4", "PineTree_1"][rng.randi_range(0, 3)]),
				Vector2(x, 1380) + off2 + Vector2(rng.randf_range(-20, 20), 0), rng.randf_range(0, 360),
				rng.randf_range(1.5, 2.0))
		x += 360.0
	# Sparse deep scatter far from the road (depth, no clutter at the path).
	scatter_nature(Rect2(80, 80, 3040, 380), ["PineTree_1", "PineTree_3", "BirchTree_1"], 28, 77, 1.4, 2.0)
	scatter_nature(Rect2(80, 1620, 3040, 320), ["PineTree_2", "PineTree_4", "BirchTree_3"], 28, 78, 1.4, 2.0)
	# A few bushes and rocks soften the road shoulders.
	scatter_nature(Rect2(200, 820, 2800, 30), ["Bush", "Bush_Large"], 12, 79, 0.8, 1.2)
	scatter_nature(Rect2(200, 1180, 2800, 30), ["Bush", "Rock_2"], 12, 80, 0.8, 1.2)

	# The north clearing: a mini-boss's ground (loot in the 2D layer).
	scatter_nature(Rect2(960, 120, 360, 320), ["Rock_3", "Rock_5", "Bush_Large"], 8, 80, 1.4, 2.2)
	crystal3(Vector2(1600, 1010))
	for torch_px: Vector2 in [Vector2(500, 1010), Vector2(1100, 1010), Vector2(1900, 1010), Vector2(2600, 1010)]:
		torch3(torch_px)

	npc3("wandering_friar", Vector2(900, 1010), [
		"The Kimahri missions, friend — even the road there has gained a third dimension.",
		"Walk the cobbles. The woods are deeper than they look now. Literally.",
	] as Array[String], Color(0.78, 0.72, 0.6))
	npc3("refugee_mother", Vector2(2400, 1010), [
		"Is the pass safe? The trees have SHADOWS that move now.",
	] as Array[String], Color(0.66, 0.6, 0.55))

	portal(Rect2(0, 880, 80, 240), "res://world3d/hd_selenora.tscn", "< Selenora")
	portal(Rect2(3120, 880, 80, 240), "res://world3d/hd_deepwoods.tscn", "The Selinoran Deep >")
