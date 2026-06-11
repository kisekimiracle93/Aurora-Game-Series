extends AreaBase
## The Crystal Fields, rebuilt: a big scrolling snowfield framed by cliffs,
## pine woods, a frozen river fed by a waterfall, scattered rocks and ice —
## and the wild made visible: foes patrol the land with limited chase leashes,
## so you choose your fights (random encounters are gone).


func _init() -> void:
	area_name = "THE CRYSTAL FIELDS — the wild watches"
	music_track = "world"
	encounters_enabled = false  # superseded by visible map foes
	map_size = Vector2(2560, 1600)


func _setup_area() -> void:
	add_rect(Rect2(Vector2.ZERO, map_size), Color(0.62, 0.67, 0.73), -10)  # deep snow
	_build_terrain()
	_build_river_and_falls()
	_build_foes()

	add_chest("fields_riverbank", Vector2(1620, 1180), {"item_hp_potion": 1, "item_aether_draught": 1})
	add_chest("fields_cliffbase", Vector2(2300, 320), {"item_hp_potion": 2})

	# West back to town; far east into the crystal site.
	add_exit(Rect2(0, 620, 40, 200), "res://world/town.tscn", Vector2(1800, 660))
	add_exit(Rect2(2520, 620, 40, 200), "res://world/dungeon.tscn", Vector2(100, 360))
	var west: Label = Label.new()
	west.text = "< Aethertown"
	west.position = Vector2(50, 590)
	west.add_theme_font_size_override("font_size", 14)
	add_child(west)
	var east: Label = Label.new()
	east.text = "Crystal site >"
	east.position = Vector2(2360, 590)
	east.add_theme_font_size_override("font_size", 14)
	add_child(east)


func _prop(prop_name: String, pos: Vector2, prop_scale: float = 2.0, solid: bool = true) -> void:
	var art: Texture2D = AssetLibrary.texture("props", prop_name)
	if art == null:
		return
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


func _build_terrain() -> void:
	# Cliff walls crown the north and shoulder the south-east.
	for x: float in [180.0, 420.0, 660.0, 1500.0, 1740.0, 1980.0]:
		_prop("cliff_tall", Vector2(x, 170), 2.2)
	for pos: Vector2 in [Vector2(2280, 1380), Vector2(2050, 1450)]:
		_prop("cliff_left", pos, 2.0)
	# Pine woods, west and center.
	for pos: Vector2 in [
		Vector2(330, 760), Vector2(450, 900), Vector2(260, 1060), Vector2(560, 1180),
		Vector2(1120, 420), Vector2(1240, 520), Vector2(1010, 540),
	]:
		_prop("pine_cluster", pos, 2.0)
	# Rocks and ice teeth scattered across the open snow.
	for pos: Vector2 in [
		Vector2(880, 980), Vector2(1480, 760), Vector2(1960, 1040), Vector2(760, 1380),
	]:
		_prop("snow_rocks", pos, 2.0)
	for pos: Vector2 in [Vector2(1820, 380), Vector2(640, 520), Vector2(2120, 800)]:
		_prop("icicles", pos, 1.8)
	var hint: Label = Label.new()
	hint.text = "The beasts keep to their grounds. Step into theirs, and they will not stay there."
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(0.32, 0.34, 0.4)
	hint.position = Vector2(820, 1540)
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
		add_child(river)
	else:
		add_rect(river_rect, Color(0.45, 0.7, 0.9, 0.9), -8)
	add_wall(Rect2(1310, 420, 96, 1180))  # too cold to ford (crossing at the falls pool)

	# The waterfall: white water sheeting off the cliff into a mist pool.
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
