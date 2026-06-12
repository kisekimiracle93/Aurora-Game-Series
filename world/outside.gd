extends AreaBase
## The Crystal Fields, rebuilt: a big scrolling snowfield framed by cliffs,
## pine woods, a frozen river fed by a waterfall, scattered rocks and ice —
## and the wild made visible: foes patrol the land with limited chase leashes,
## so you choose your fights (random encounters are gone).


func _init() -> void:
	area_name = "THE CRYSTAL FIELDS — the wild watches"
	music_track = "world"
	ambience_profile = "fields"
	encounters_enabled = false  # superseded by visible map foes
	map_size = Vector2(2560, 1600)
	frost_level = 0.22
	fog_level = 0.16


func _setup_area() -> void:
	add_rect(Rect2(Vector2.ZERO, map_size), Color(0.78, 0.82, 0.88), -10)  # deep snow
	_build_ground_detail()
	_build_terrain()
	_build_river_and_falls()
	_build_foes()
	add_snowfall(430)

	add_chest("fields_riverbank", Vector2(1620, 1180), {"item_hp_potion": 1, "item_aether_draught": 1})
	add_chest("fields_cliffbase", Vector2(2300, 320), {"item_hp_potion": 2})

	# West: the two Verdant Pass routes home. Far east: the crystal site.
	add_exit(Rect2(0, 620, 40, 200), "res://world/forest.tscn", Vector2(3060, 700))
	add_exit(Rect2(0, 1120, 40, 200), "res://world/forest.tscn", Vector2(3060, 1420))
	add_exit(Rect2(2520, 620, 40, 200), "res://world/dungeon.tscn", Vector2(100, 360))
	add_road_gate(Vector2(2400, 705))
	add_save_crystal(Vector2(2380, 900))
	for torch_pos: Vector2 in [Vector2(700, 620), Vector2(1500, 620), Vector2(2200, 620)]:
		add_torch(torch_pos)
	var west: Label = Label.new()
	west.text = "< The Verdant Pass"
	west.position = Vector2(50, 590)
	west.add_theme_font_size_override("font_size", 14)
	add_child(west)
	var west2: Label = Label.new()
	west2.text = "< The Verdant Pass (south)"
	west2.position = Vector2(50, 1090)
	west2.add_theme_font_size_override("font_size", 14)
	add_child(west2)
	var east: Label = Label.new()
	east.text = "Crystal site >"
	east.position = Vector2(2360, 590)
	east.add_theme_font_size_override("font_size", 14)
	add_child(east)


func _prop(prop_name: String, pos: Vector2, prop_scale: float = 2.0, solid: bool = true) -> void:
	var art: Texture2D = AssetLibrary.texture("props", prop_name)
	if art == null:
		return
	if prop_name.begins_with("cliff"):
		# Edge scenery: stays behind the walkable plane, casts real shadows.
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = art
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(prop_scale, prop_scale)
		sprite.position = pos
		sprite.z_index = 3
		add_child(sprite)
		if solid:
			var size: Vector2 = art.get_size() * prop_scale * 0.7
			add_wall(Rect2(pos - size / 2.0, size))
			add_occluder(Rect2(pos - size / 2.0, size))
			add_ground_shadow(pos + Vector2(0, size.y / 2.0 - 8.0), size.x * 1.3)
		return
	add_prop(prop_name, pos, prop_scale, solid, prop_name.begins_with("pine"))


## Soft tonal mottling + the trodden trail: kills the flat-color blandness.
func _build_ground_detail() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20
	var mottle: Node2D = Node2D.new()
	mottle.z_index = -9
	mottle.draw.connect(func() -> void:
		for i: int in range(160):
			var spot_rng: RandomNumberGenerator = RandomNumberGenerator.new()
			spot_rng.seed = 100 + i
			var pos: Vector2 = Vector2(
				spot_rng.randf_range(0, map_size.x), spot_rng.randf_range(0, map_size.y)
			)
			var dark: bool = spot_rng.randf() < 0.5
			mottle.draw_circle(
				pos,
				spot_rng.randf_range(18.0, 70.0),
				Color(0.55, 0.6, 0.7, 0.10) if dark else Color(1.0, 1.0, 1.0, 0.14)
			))
	add_child(mottle)
	# The pilgrim trail: a worn dirt path west gate -> falls crossing -> east gate.
	for segment: Rect2 in [
		Rect2(0, 660, 760, 84), Rect2(700, 540, 84, 200), Rect2(700, 470, 700, 84),
		Rect2(1330, 470, 84, 250), Rect2(1330, 640, 1230, 84),
	]:
		add_rect(segment, Color(0.52, 0.44, 0.34, 0.85), -8)


func _build_terrain() -> void:
	# A contiguous cliff rampart seals the whole northern edge.
	var cliff: Texture2D = AssetLibrary.texture("props", "cliff_tall")
	if cliff != null:
		var step: float = cliff.get_width() * 2.2
		var x: float = step / 2.0
		while x < map_size.x - 40.0:
			_prop("cliff_tall", Vector2(x, 170), 2.2, false)
			x += step - 8.0
		add_wall(Rect2(0, 0, map_size.x, 320))
	# Southern ridge of low cliffs with a forest skirt.
	for x: float in [260.0, 460.0, 1700.0, 1900.0, 2100.0, 2300.0]:
		_prop("cliff_left", Vector2(x, 1480), 2.0)
	# Forests: a western wood and a mid-field grove (tree WALLS, not confetti).
	for pos: Vector2 in [
		Vector2(180, 800), Vector2(290, 860), Vector2(400, 920), Vector2(510, 980),
		Vector2(180, 980), Vector2(290, 1040), Vector2(180, 1160), Vector2(400, 1100),
		Vector2(1060, 380), Vector2(1170, 420), Vector2(1010, 480),
		Vector2(1640, 1060), Vector2(1750, 1120), Vector2(1860, 1180), Vector2(1640, 1220),
	]:
		_prop("pine_cluster", pos, 2.0)
	# Rocks + ice teeth in deliberate clusters near landmarks.
	for pos: Vector2 in [
		Vector2(900, 980), Vector2(960, 1020), Vector2(2050, 900), Vector2(2110, 950),
	]:
		_prop("snow_rocks", pos, 2.0)
	for pos: Vector2 in [Vector2(1500, 360), Vector2(560, 480), Vector2(2200, 540)]:
		_prop("icicles", pos, 1.8)
	# Fence posts shepherd the trail out of town.
	var fence: Texture2D = AssetLibrary.texture("props", "fence")
	if fence != null:
		for x: float in [120.0, 260.0, 400.0, 540.0]:
			for y: float in [620.0, 770.0]:
				var post: Sprite2D = Sprite2D.new()
				post.texture = fence
				post.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				post.scale = Vector2(1.6, 1.6)
				post.position = Vector2(x, y)
				post.z_index = 2
				add_child(post)
	var hint: Label = Label.new()
	hint.text = "The beasts keep to their grounds. Step into theirs, and they will not stay there."
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(0.32, 0.34, 0.4)
	hint.position = Vector2(820, 1545)
	add_child(hint)


func _build_river_and_falls() -> void:
	# A frozen river runs south from the falls at the north cliffs.
	var water: Texture2D = AssetLibrary.texture("props", "water_tile")
	var river: TextureRect
	if water != null:
		river = TextureRect.new()
		river.texture = water
		river.stretch_mode = TextureRect.STRETCH_TILE
		river.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		river = null
	var river_rect: Rect2 = Rect2(1310, 260, 96, 1340)
	if river != null:
		river.position = river_rect.position
		river.size = river_rect.size
		river.z_index = -8
		river.modulate = Color(0.75, 0.9, 1.0)
		river.material = AssetLibrary.water_material()
		add_child(river)
	else:
		add_rect(river_rect, Color(0.45, 0.7, 0.9, 0.9), -8)
	add_wall(Rect2(1310, 420, 96, 1180))  # too cold to ford (crossing at the falls pool)

	# The painted falls themselves (toolbox art), doubled for the long drop.
	var falls_art: Texture2D = AssetLibrary.texture("props", "waterfall")
	if falls_art != null:
		for stack: int in range(2):
			var sheet: Sprite2D = Sprite2D.new()
			sheet.texture = falls_art
			sheet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sheet.scale = Vector2(2.6, 2.0)
			sheet.position = Vector2(1358, 180 + stack * 142)
			sheet.z_index = -7
			sheet.material = AssetLibrary.water_material()
			add_child(sheet)

	# The waterfall spray: white water sheeting off the cliff into a mist pool.
	var falls: CPUParticles2D = CPUParticles2D.new()
	falls.position = Vector2(1358, 240)
	falls.amount = 90
	falls.lifetime = 1.1
	falls.preprocess = 1.0
	falls.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	falls.emission_rect_extents = Vector2(44, 4)
	falls.direction = Vector2(0, 1)
	falls.spread = 6.0
	falls.gravity = Vector2(0, 420)
	falls.initial_velocity_min = 60.0
	falls.initial_velocity_max = 110.0
	falls.scale_amount_min = 2.0
	falls.scale_amount_max = 4.0
	falls.color = Color(0.85, 0.95, 1.0, 0.8)
	falls.z_index = 2
	add_child(falls)
	var mist: CPUParticles2D = CPUParticles2D.new()
	mist.position = Vector2(1358, 420)
	mist.amount = 26
	mist.lifetime = 1.6
	mist.preprocess = 1.5
	mist.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	mist.emission_sphere_radius = 50.0
	mist.gravity = Vector2(0, -30)
	mist.scale_amount_min = 4.0
	mist.scale_amount_max = 8.0
	mist.color = Color(0.9, 0.97, 1.0, 0.25)
	mist.z_index = 2
	add_child(mist)
	add_point_light(Vector2(1358, 380), Color(0.7, 0.9, 1.0), 1.8, 0.9)


func _build_foes() -> void:
	var world: Node = get_node_or_null("/root/WorldState")
	var foes: Array = [
		# [id, roster, sprite, waypoints]
		["fields_wolves_a", "wolves_2", "Aether Wolf",
			[Vector2(760, 700), Vector2(1040, 700), Vector2(1040, 880)]],
		["fields_wolves_b", "wolves_3", "Aether Wolf",
			[Vector2(1680, 480), Vector2(1980, 480), Vector2(1830, 640)]],
		["fields_stag", "stag_hunt", "Icebound Stag",
			[Vector2(2100, 1150), Vector2(1840, 1260)]],
		["fields_bandits_a", "bandit_pair", "Roadside Bandit",
			[Vector2(620, 660), Vector2(620, 560)]],
		["fields_bandits_b", "bandit_ambush", "Bandit Cutthroat",
			[Vector2(2280, 660), Vector2(2420, 760), Vector2(2280, 860)]],
		["fields_wisps", "wisp_pack", "Frost Wisp",
			[Vector2(1450, 360), Vector2(1560, 470), Vector2(1430, 540)]],
		["fields_pack_south", "wolfpack", "Aether Wolf",
			[Vector2(1100, 1320), Vector2(1380, 1440), Vector2(900, 1460)]],
	]
	for config: Array in foes:
		if world != null and world.cleared_foes.has(String(config[0])):
			continue
		var foe: OverworldFoe = OverworldFoe.new()
		var points: Array[Vector2] = []
		for point: Vector2 in config[3]:
			points.append(point)
		foe.setup(String(config[0]), String(config[1]), String(config[2]), points)
		add_child(foe)
