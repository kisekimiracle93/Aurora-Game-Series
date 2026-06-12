extends AreaBase
## THE DEEP SELINORAN WOODS — the moody one. A single winding path (no
## branches) snakes north under a canopy that never quite admits daylight:
## broken signs, one wandering pack, torches long dead. Halfway through, the
## RAIN begins — and it does not stop. The trees finally break against bare
## mountains; a grey stone road climbs through the rocks to a broken
## archway... where the Selinoran Predator has been waiting the whole time.
## Beyond the arch: the Crystal Fields.

const RAIN_LINE_Y: float = 2150.0
const ARCH_GATE_ID: String = "gate_deep_predator"

var _raining: bool = false
var _rain_layer: GPUParticles2D
var _rain_dim: ColorRect
var _thunder_timer: Timer

## The path, as fat walkable rects (south entrance -> north arch).
const PATH_SEGMENTS: Array[Rect2] = [
	Rect2(820, 2950, 160, 650),    # in from the south
	Rect2(380, 2790, 600, 160),    # west bend
	Rect2(380, 2150, 160, 800),    # the long dark climb
	Rect2(380, 1990, 940, 160),    # east bend (the rain line bites here)
	Rect2(1160, 1430, 160, 720),   # north toward the stone
	Rect2(150, 600, 1500, 830),    # the mountain opening (wide and bare)
	Rect2(700, 240, 400, 420),     # the funnel to the arch
]


func _init() -> void:
	area_name = "THE DEEP SELINORAN WOODS — the trees keep their own counsel"
	music_track = "deepwoods"
	ambience_profile = "deepwoods"
	map_size = Vector2(1800, 3600)
	default_spawn = Vector2(900, 3460)
	frost_level = 0.0
	fog_level = 0.34
	firefly_scale = 1.9
	cloud_density = 1.7


func _setup_area() -> void:
	add_rect(Rect2(Vector2.ZERO, map_size), Color(0.16, 0.24, 0.17), -10)  # dim moss
	# The mountain third: bare rock-toned earth, a colder palette.
	add_rect(Rect2(0, 0, map_size.x, 1430), Color(0.34, 0.33, 0.36), -10)
	_build_path()
	_build_woods()
	_build_mountains()
	_build_arch()
	_build_signs()
	add_grass_detail(220, 67)
	for torch_pos: Vector2 in [Vector2(460, 2500), Vector2(1240, 1700)]:
		add_torch(torch_pos)
	add_chest(
		"deepwoods_cart", Vector2(470, 2240),
		{"item_snow_totem": 1, "item_hp_potion": 1}
	)
	_add_broken_cart(Vector2(470, 2290))
	# One pack, half-starved, mid-path. Otherwise: nothing human, nothing kind.
	var world: Node = get_node_or_null("/root/WorldState")
	if world == null or not world.cleared_foes.has("deep_lone_pack"):
		var foe: OverworldFoe = OverworldFoe.new()
		foe.setup("deep_lone_pack", "wolves_2", "Aether Wolf",
			[Vector2(700, 2060), Vector2(1000, 2060)] as Array[Vector2])
		add_child(foe)

	# South: back to the Verdant Pass. North: the arch (and its keeper).
	add_exit(Rect2(820, 3560, 160, 40), "res://world/forest.tscn", Vector2(3060, 700))
	add_exit(Rect2(840, 0, 120, 40), "res://world/outside.tscn", Vector2(110, 700))
	# The rain line: cross it once and the sky stays broken until you leave.
	var rain_zone: Area2D = _make_zone(Rect2(0, RAIN_LINE_Y - 30, map_size.x, 60))
	rain_zone.body_entered.connect(func(body: Node2D) -> void:
		if body == player and not _raining:
			_start_rain())
	# The predator's ground: walking to the arch IS the trigger (no sprite).
	var gate_zone: Area2D = _make_zone(Rect2(700, 300, 400, 90))
	gate_zone.body_entered.connect(func(body: Node2D) -> void:
		if body != player:
			return
		var state: Node = get_node_or_null("/root/WorldState")
		if state == null or not state.in_world_run:
			return
		if state.cleared_foes.has(ARCH_GATE_ID):
			return
		state.pending_foe_id = ARCH_GATE_ID
		state.start_battle(get_tree(), "deep_predator", scene_file_path, Vector2(900, 480)))


func _build_path() -> void:
	for segment: Rect2 in PATH_SEGMENTS:
		var tint: Color = (
			Color(0.45, 0.44, 0.42, 0.9) if segment.position.y < 1430.0
			else Color(0.38, 0.33, 0.26, 0.9)  # mud below, grey stone above
		)
		add_rect(segment, tint, -8)
		add_rect(segment.grow(8.0), Color(0.2, 0.2, 0.16, 0.35), -9)


func _near_path(pos: Vector2, margin: float) -> bool:
	for segment: Rect2 in PATH_SEGMENTS:
		if segment.grow(margin).has_point(pos):
			return true
	return false


## The canopy: solid walls hugging the path, dense passable dark beyond.
func _build_woods() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 91
	# Wall trees: a tight picket just off every path edge (southern woods only).
	for segment: Rect2 in PATH_SEGMENTS:
		if segment.position.y < 1430.0:
			continue  # the mountains keep their own walls
		var x: float = segment.position.x - 70.0
		while x <= segment.end.x + 70.0:
			for y: float in [segment.position.y - 95.0, segment.end.y + 25.0]:
				var pos: Vector2 = Vector2(x + rng.randf_range(-12, 12), y)
				if not _near_path(pos + Vector2(0, 60), 30.0):
					add_prop("pine_cluster", pos, 2.0, true, true)
			x += 104.0
		var y2: float = segment.position.y - 70.0
		while y2 <= segment.end.y + 70.0:
			for x2: float in [segment.position.x - 95.0, segment.end.x + 25.0]:
				var pos2: Vector2 = Vector2(x2, y2 + rng.randf_range(-12, 12))
				if not _near_path(pos2 + Vector2(0, 60), 30.0):
					add_prop("pine_cluster", pos2, 2.0, true, true)
			y2 += 118.0
	# The deep fill: shadowed, passable, endless.
	for i: int in range(240):
		var pos: Vector2 = Vector2(
			rng.randf_range(70, map_size.x - 70), rng.randf_range(1500, map_size.y - 70)
		)
		if _near_path(pos, 110.0):
			continue
		var anchor: Node2D = add_prop(
			"pine_single" if rng.randf() < 0.6 else "pine_cluster", pos, 2.0, false, true
		)
		if anchor != null:
			(anchor.get_child(0) as Sprite2D).modulate = Color(0.62, 0.72, 0.62, 0.95)


## Bare rock and standing stones; the world opens before it narrows.
func _build_mountains() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 17
	# A rampart seals the very top except the arch slot.
	var cliff: Texture2D = AssetLibrary.texture("props", "cliff_tall")
	if cliff != null:
		var x: float = 90.0
		while x < map_size.x - 60.0:
			if absf(x - 900.0) > 200.0:
				var sprite: Sprite2D = Sprite2D.new()
				sprite.texture = cliff
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sprite.scale = Vector2(2.0, 2.0)
				sprite.position = Vector2(x, 150)
				sprite.z_index = 3
				add_child(sprite)
			x += 170.0
	add_wall(Rect2(0, 0, 700, 280))
	add_wall(Rect2(1100, 0, 700, 280))
	# Scattered crags + snow rocks through the opening.
	for i: int in range(14):
		var pos: Vector2 = Vector2(rng.randf_range(160, 1640), rng.randf_range(640, 1380))
		if _near_path(pos, 60.0) and pos.y > 600.0 and absf(pos.x - 900.0) < 220.0:
			continue
		add_prop("snow_rocks" if rng.randf() < 0.5 else "cliff_left", pos, 1.7, true)
	# The funnel walls pinch you toward the arch.
	for funnel: Array in [[660.0, 0.55], [1140.0, 0.55]]:
		for y: float in [340.0, 460.0, 580.0]:
			add_prop("cliff_left", Vector2(float(funnel[0]) + rng.randf_range(-16, 16), y), 1.6, true)


## The broken archway: half a gate, all a threshold.
func _build_arch() -> void:
	var arch: Node2D = Node2D.new()
	arch.position = Vector2(900, 250)
	arch.z_index = SORT_Z
	arch.draw.connect(func() -> void:
		# Two cracked pillars, one leaning; a fallen lintel fragment between.
		arch.draw_rect(Rect2(-120, -110, 38, 120), Color(0.55, 0.55, 0.6))
		arch.draw_rect(Rect2(-116, -110, 30, 8), Color(0.42, 0.42, 0.48))
		arch.draw_set_transform(Vector2(96, -32), 0.18, Vector2.ONE)
		arch.draw_rect(Rect2(-14, -70, 34, 92), Color(0.5, 0.5, 0.56))
		arch.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		arch.draw_rect(Rect2(-44, -6, 96, 16), Color(0.46, 0.46, 0.52))
		for rubble: Vector2 in [Vector2(-70, 16), Vector2(20, 22), Vector2(60, 12)]:
			arch.draw_circle(rubble, 9.0, Color(0.5, 0.5, 0.55))
			arch.draw_circle(rubble + Vector2(3, 3), 5.0, Color(0.38, 0.38, 0.44)))
	add_child(arch)
	add_point_light(Vector2(900, 230), Color(0.7, 0.8, 1.0), 1.3, 0.5)
	var warning: Label = Label.new()
	warning.text = "Old claw-marks score the stone. Recent ones score the old ones."
	warning.add_theme_font_size_override("font_size", 13)
	warning.modulate = Color(0.75, 0.7, 0.7)
	warning.position = Vector2(640, 560)
	add_child(warning)


## Broken signposts: the woods ate the words.
func _build_signs() -> void:
	for sign_config: Array in [
		[Vector2(870, 3160), -8.0, "...ORTH... PASS..."],
		[Vector2(450, 2860), 12.0, "TURN B—"],
		[Vector2(1230, 2080), -15.0, "(clawed through)"],
		[Vector2(1000, 1480), 0.0, "NORTHERN PASSAGE ▲\nICE CAVERNS BEYOND"],
	]:
		var post: Node2D = Node2D.new()
		post.position = sign_config[0]
		post.rotation_degrees = float(sign_config[1])
		post.z_index = SORT_Z
		var intact: bool = absf(float(sign_config[1])) < 1.0
		post.draw.connect(func() -> void:
			post.draw_rect(Rect2(-3, -34, 6, 50), Color(0.32, 0.24, 0.16))
			post.draw_rect(Rect2(-34, -52, 68, 24), Color(0.45, 0.36, 0.24))
			if not intact:
				post.draw_line(Vector2(-30, -48), Vector2(28, -34), Color(0.2, 0.15, 0.1), 2.0))
		add_child(post)
		var text: Label = Label.new()
		text.text = String(sign_config[2])
		text.add_theme_font_size_override("font_size", 10)
		text.modulate = Color(0.85, 0.8, 0.7) if intact else Color(0.6, 0.55, 0.45)
		text.position = sign_config[0] + Vector2(-32, -52)
		text.rotation_degrees = float(sign_config[1])
		text.z_index = 6
		add_child(text)


func _add_broken_cart(pos: Vector2) -> void:
	var cart: Node2D = Node2D.new()
	cart.position = pos
	cart.rotation_degrees = -11.0
	cart.z_index = SORT_Z
	cart.draw.connect(func() -> void:
		cart.draw_rect(Rect2(-30, -20, 58, 16), Color(0.32, 0.24, 0.15))
		cart.draw_circle(Vector2(-12, 0), 9.0, Color(0.24, 0.18, 0.11))
		cart.draw_line(Vector2(16, -4), Vector2(34, 10), Color(0.28, 0.2, 0.12), 4.0)
		cart.draw_circle(Vector2(20, 4), 7.0, Color(0.22, 0.17, 0.1)))
	add_child(cart)


## The sky breaks. It does not mend until you leave these woods.
func _start_rain() -> void:
	_raining = true
	_rain_layer = GPUParticles2D.new()
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(map_size.x / 2.0 + 200.0, 12.0, 1.0)
	material.direction = Vector3(-0.25, 1.0, 0.0)
	material.spread = 4.0
	material.gravity = Vector3(-60.0, 900.0, 0.0)
	material.initial_velocity_min = 320.0
	material.initial_velocity_max = 460.0
	material.scale_min = 0.8
	material.scale_max = 1.6
	material.color = Color(0.72, 0.82, 0.95, 0.55)
	_rain_layer.process_material = material
	_rain_layer.amount = int(900 * map_size.x * map_size.y / (2560.0 * 1600.0))
	_rain_layer.lifetime = map_size.y / 700.0
	_rain_layer.preprocess = 2.0
	_rain_layer.position = Vector2(map_size.x / 2.0, -40.0)
	_rain_layer.visibility_rect = Rect2(
		-map_size.x / 2.0 - 240.0, -60.0, map_size.x + 480.0, map_size.y + 120.0
	)
	_rain_layer.z_index = 47
	add_child(_rain_layer)
	# The light goes out of the day.
	_rain_dim = add_rect(Rect2(Vector2.ZERO, map_size), Color(0.05, 0.07, 0.12, 0.0), 46)
	var dim: Tween = _rain_dim.create_tween()
	dim.tween_property(_rain_dim, "color:a", 0.22, 3.0)
	var soundscape: Node = get_node_or_null("/root/Soundscape")
	if soundscape != null:
		soundscape.set_extra_bed("rain", true)
	_thunder_timer = Timer.new()
	_thunder_timer.wait_time = randf_range(14.0, 30.0)
	_thunder_timer.timeout.connect(func() -> void:
		_thunder_timer.wait_time = randf_range(14.0, 34.0)
		var soundscape_now: Node = get_node_or_null("/root/Soundscape")
		if soundscape_now != null:
			soundscape_now.play_oneshot("thunder")
		var flash: ColorRect = add_rect(Rect2(Vector2.ZERO, map_size), Color(0.9, 0.93, 1.0, 0.0), 48)
		var bolt: Tween = flash.create_tween()
		bolt.tween_property(flash, "color:a", 0.30, 0.06)
		bolt.tween_property(flash, "color:a", 0.0, 0.5)
		bolt.tween_callback(flash.queue_free))
	add_child(_thunder_timer)
	_thunder_timer.start()
