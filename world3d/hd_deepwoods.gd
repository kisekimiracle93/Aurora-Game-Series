extends HDBase
## THE DEEP SELINORAN WOODS in HD-2D: a dark, dense, winding single path —
## moody fog, scarce torches, a broken arch at the north into the mountains.

const DIRT: String = "res://assets/kits3d/nature/forest_texture.png"
const COBBLE: String = "res://assets/sprites/props/cobble_fill.png"


func _init() -> void:
	area_name = "THE DEEP SELINORAN WOODS — HD-2D"
	map_px = Vector2(1800, 3000)
	# Always near-dusk under the canopy: low cold sun, heavy blue fog.
	sky_top = Color(0.10, 0.14, 0.22)
	sky_horizon = Color(0.22, 0.28, 0.36)
	sun_color = Color(0.65, 0.74, 0.95)
	sun_energy = 0.5
	fog_density = 0.06
	fog_color = Color(0.34, 0.40, 0.48)
	grade_saturation = 0.92
	ambience_foley = "Rain_Heavy"


func _setup_area() -> void:
	ground("res://assets/all files/town_rpg_pack/town_rpg_pack/graphics/grass-tile-2.png")
	environment.adjustment_brightness = 0.82
	for edge: Rect2 in [
		Rect2(-64, 0, 64, map_px.y), Rect2(map_px.x, 0, 64, map_px.y),
		Rect2(0, -64, map_px.x, 64), Rect2(0, map_px.y, map_px.x, 64),
	]:
		wall3d(edge, 5.0)

	# The winding path: a few cobbled segments snaking north.
	road(Rect2(820, 2400, 180, 600), COBBLE)
	road(Rect2(400, 2240, 600, 180), COBBLE)
	road(Rect2(400, 1400, 180, 840), COBBLE)
	road(Rect2(400, 1240, 940, 180), COBBLE)
	road(Rect2(1160, 600, 180, 820), COBBLE)
	road(Rect2(700, 440, 660, 180), COBBLE)

	# Dense dark trees in the SIDE bands only — the winding path down the
	# middle stays walkable and visible (collision walls fence the verges).
	scatter_nature(Rect2(60, 60, 320, 2880), ["PineTree_1", "PineTree_2", "PineTree_3", "PineTree_4", "PineTree_5"], 90, 91, 1.8, 2.8)
	scatter_nature(Rect2(1420, 60, 320, 2880), ["PineTree_1", "PineTree_2", "PineTree_3", "PineTree_4", "PineTree_5"], 90, 93, 1.8, 2.8)
	scatter_nature(Rect2(380, 60, 1040, 360), ["PineTree_2", "PineTree_4"], 22, 94, 1.8, 2.6)
	scatter_nature(Rect2(120, 120, 1560, 2760), ["Bush", "Bush_Large", "Rock_1", "Rock_4"], 30, 92, 0.9, 1.6)
	wall3d(Rect2(0, 0, 360, map_px.y), 4.0)
	wall3d(Rect2(1440, 0, 360, map_px.y), 4.0)

	# Two lonely torches and the broken arch at the north mouth.
	torch3(Vector2(500, 2100))
	torch3(Vector2(1240, 1000))
	prop(HDAssets.dungeon("wall_broken"), Vector2(900, 360), 0.0, 2.5, 0.0)
	prop(HDAssets.dungeon("pillar"), Vector2(780, 380), 0.0, 2.5, 60.0)
	prop(HDAssets.dungeon("pillar_decorated"), Vector2(1020, 380), 0.0, 2.5, 60.0)
	prop(HDAssets.dungeon("rubble_large"), Vector2(900, 420), 0.0, 2.0, 0.0)

	npc3("deep_hermit", Vector2(560, 2000), [
		"The rain knows my name. The fog knows my face now too.",
		"The thing at the arch lets me be. We have an understanding.",
	] as Array[String], Color(0.55, 0.6, 0.55))

	portal(Rect2(820, 2920, 240, 80), "res://world3d/hd_forest.tscn", "< The Verdant Pass")
	portal(Rect2(760, 0, 280, 80), "res://world3d/hd_fields.tscn", "Northern Passage ^")
