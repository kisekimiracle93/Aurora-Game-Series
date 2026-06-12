extends AreaBase
## THE VERDANT PASS — the grassland forest between Aethertown and the frozen
## fields. A wide, clear main road walled by dense treelines; branch paths
## peel off to a mini-boss clearing and treasure caches; two gated routes
## break east into the ice. The deep woods beyond the walls are dense but
## passable scatter — wander the trunks all you like, only the road is fenced.


func _init() -> void:
	area_name = "THE VERDANT PASS — green, for now"
	music_track = "forest"
	ambience_profile = "forest"
	map_size = Vector2(3200, 2000)
	frost_level = 0.0
	fog_level = 0.10


func _setup_area() -> void:
	add_rect(Rect2(Vector2.ZERO, map_size), Color(0.30, 0.44, 0.28), -10)  # grassland
	_build_ground()
	_build_treelines()
	_build_deep_woods()
	_build_branches()
	_build_foes()
	add_save_crystal(Vector2(1600, 1000))
	for torch_pos: Vector2 in [
		Vector2(420, 950), Vector2(900, 950), Vector2(1380, 950),
		Vector2(1860, 950), Vector2(2340, 950), Vector2(2820, 950),
	]:
		add_torch(torch_pos)
	add_road_gate(Vector2(200, 1000))
	add_road_gate(Vector2(3000, 705))
	add_road_gate(Vector2(3000, 1425))
	add_flowers([
		Vector2(500, 1050), Vector2(700, 905), Vector2(1100, 1060), Vector2(1500, 910),
		Vector2(1900, 1050), Vector2(2300, 905), Vector2(2700, 1050), Vector2(900, 1080),
		Vector2(2000, 900), Vector2(2600, 905), Vector2(1300, 1070), Vector2(1700, 1080),
	], 13)

	# West: home to Aethertown. East: two routes into the Crystal Fields.
	add_exit(Rect2(0, 880, 40, 220), "res://world/town.tscn", Vector2(3700, 1150))
	add_exit(Rect2(3160, 600, 40, 200), "res://world/outside.tscn", Vector2(110, 700))
	add_exit(Rect2(3160, 1320, 40, 200), "res://world/outside.tscn", Vector2(110, 1200))
	var west: Label = Label.new()
	west.text = "< Aethertown"
	west.position = Vector2(50, 850)
	west.add_theme_font_size_override("font_size", 14)
	add_child(west)
	for east_label: Array in [["North pass — the fields >", Vector2(2860, 600)], ["South pass — the fields >", Vector2(2860, 1320)]]:
		var sign_label: Label = Label.new()
		sign_label.text = String(east_label[0])
		sign_label.position = east_label[1]
		sign_label.add_theme_font_size_override("font_size", 14)
		add_child(sign_label)


func _build_ground() -> void:
	# Mottled grass + the wide main road (clear, direct, west to east).
	var mottle: Node2D = Node2D.new()
	mottle.z_index = -9
	mottle.draw.connect(func() -> void:
		for i: int in range(220):
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = 300 + i
			mottle.draw_circle(
				Vector2(rng.randf_range(0, map_size.x), rng.randf_range(0, map_size.y)),
				rng.randf_range(16.0, 80.0),
				Color(0.2, 0.35, 0.2, 0.12) if rng.randf() < 0.5 else Color(0.5, 0.65, 0.4, 0.10)
			))
	add_child(mottle)
	# The main road: broad and unmissable, broken by old cobble patches.
	add_rect(Rect2(0, 940, map_size.x, 120), Color(0.52, 0.44, 0.32, 0.9), -8)
	for patch_x: float in [300.0, 1150.0, 2050.0, 2900.0]:
		add_cobble_road(Rect2(patch_x, 955, 180, 90))
	# Branch paths: north to the alpha clearing, south to the cache hollow,
	# and the two eastern passes.
	add_rect(Rect2(1080, 420, 110, 520), Color(0.5, 0.43, 0.32, 0.85), -8)
	add_rect(Rect2(2050, 1060, 110, 520), Color(0.5, 0.43, 0.32, 0.85), -8)
	add_rect(Rect2(2700, 660, 500, 90), Color(0.52, 0.44, 0.32, 0.9), -8)
	add_rect(Rect2(2700, 1380, 500, 90), Color(0.52, 0.44, 0.32, 0.9), -8)
	add_rect(Rect2(2700, 700, 90, 740), Color(0.5, 0.43, 0.32, 0.85), -8)


## A pine on the walkable plane. Solid trees collide at the trunk and you can
## slip behind their crowns; scatter trees are pure atmosphere.
func _tree(pos: Vector2, solid: bool, single: bool = false) -> void:
	var anchor: Node2D = add_prop(
		"pine_single" if single else "pine_cluster", pos, 2.0, solid, true
	)
	if anchor != null and not solid:
		(anchor.get_child(0) as Sprite2D).modulate = Color(0.85, 0.95, 0.85, 0.92)


## Tree WALLS shepherd the road; gaps open only where paths branch.
func _build_treelines() -> void:
	var x: float = 60.0
	while x < map_size.x - 60.0:
		# North wall of the main road (gap at the north branch + east passes).
		if not (absf(x - 1135.0) < 130.0 or x > 2640.0):
			_tree(Vector2(x, 830), true)
		# South wall (gap at the south branch + east passes).
		if not (absf(x - 2105.0) < 130.0 or x > 2640.0):
			_tree(Vector2(x, 1185), true)
		x += 96.0
	# Walls along the branch paths.
	for y: float in [420.0, 560.0, 700.0, 840.0]:
		_tree(Vector2(1010, y), true)
		_tree(Vector2(1260, y), true)
	for y: float in [1185.0, 1320.0, 1455.0, 1590.0]:
		_tree(Vector2(1980, y), true)
		_tree(Vector2(2230, y), true)
	# Pass walls funneling to the two eastern exits.
	for x2: float in [2700.0, 2850.0, 3000.0]:
		_tree(Vector2(x2, 540), true)
		_tree(Vector2(x2, 880), true)
		_tree(Vector2(x2, 1255), true)
		_tree(Vector2(x2, 1600), true)


## The deep woods: dense, atmospheric, and passable — wander freely.
func _build_deep_woods() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	for i: int in range(160):
		var pos: Vector2 = Vector2(
			rng.randf_range(80.0, map_size.x - 80.0), rng.randf_range(80.0, map_size.y - 80.0)
		)
		# Keep the road and clearings breathable.
		if absf(pos.y - 1000.0) < 250.0:
			continue
		if Rect2(950, 80, 380, 380).has_point(pos):  # alpha clearing
			continue
		if Rect2(1900, 1540, 420, 380).has_point(pos):  # cache hollow
			continue
		_tree(pos, false, rng.randf() < 0.55)


func _build_branches() -> void:
	# North branch: the Alpha's clearing — a mini-boss pack guards real loot.
	var clearing_label: Label = Label.new()
	clearing_label.text = "Something large beds down here."
	clearing_label.position = Vector2(1010, 250)
	clearing_label.add_theme_font_size_override("font_size", 13)
	clearing_label.modulate = Color(0.75, 0.7, 0.6)
	add_child(clearing_label)
	add_chest("forest_alpha_cache", Vector2(1135, 200), {"item_hp_potion": 3, "item_aether_draught": 2})

	# South branch: the smuggler's hollow — a lighter "cheat" cache.
	add_chest("forest_hollow_cache", Vector2(2105, 1700), {"item_hp_potion": 2})
	var hollow_label: Label = Label.new()
	hollow_label.text = "A smuggler's drop, half-buried."
	hollow_label.position = Vector2(1980, 1760)
	hollow_label.add_theme_font_size_override("font_size", 13)
	hollow_label.modulate = Color(0.75, 0.7, 0.6)
	add_child(hollow_label)
	add_prop("barrel", Vector2(2160, 1730), 1.8)
	add_prop("crate", Vector2(2055, 1735), 1.8)


func _build_foes() -> void:
	var world: Node = get_node_or_null("/root/WorldState")
	var foes: Array = [
		["pass_alpha", "dungeon_gauntlet", "Icebound Stag",
			[Vector2(1135, 330), Vector2(1050, 260), Vector2(1220, 260)]],
		["pass_bandits", "bandit_ambush", "Bandit Cutthroat",
			[Vector2(2105, 1600), Vector2(2160, 1700)]],
		["pass_wolves", "wolves_2", "Aether Wolf",
			[Vector2(700, 1400), Vector2(950, 1480), Vector2(760, 1580)]],
		["pass_road_bandit", "bandit_pair", "Roadside Bandit",
			[Vector2(2400, 990), Vector2(2550, 990)]],
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
