class_name AreaBase
extends Node2D
## Shared scaffold for walkable areas (town / outside / dungeon): screen
## bounds, a player avatar, exits to other scenes, interactables with an
## E/A prompt, sequential dialog, and optional step-based random encounters.

const SCREEN: Vector2 = Vector2(1280, 720)

var player: PlayerAvatar
var area_name: String = ""
var music_track: String = ""
## Maps larger than the screen get a follow camera clamped to these bounds.
var map_size: Vector2 = Vector2(1280, 720)
## Interiors opt out so popping into a house doesn't smudge the travel trail.
var tracks_on_map: bool = true

## Random encounters (outside area): rolls a battle every N walked pixels.
var encounters_enabled: bool = false
var encounter_rosters: Array[String] = []
var _steps_until_encounter: float = 0.0

var _prompt: Label
var _dialog: PanelContainer
var _dialog_label: Label
var _dialog_lines: Array[String] = []
var _choice_box: VBoxContainer
var _active_interactable: Dictionary = {}
var _interactables: Array[Dictionary] = []  # {"area": Area2D, "prompt": String, "callback": Callable}
var _hud_layer: CanvasLayer  # prompts/dialog ride above the scrolling map
## Lens mood for this area (PostFX): frost at the screen edges, fog drift.
var frost_level: float = 0.0
var fog_level: float = 0.0


func _ready() -> void:
	_build_common()
	_setup_area()  # scenes override
	var world: Node = get_node_or_null("/root/WorldState")
	if world != null and tracks_on_map:
		world.note_area_visit(scene_file_path)
	var atmosphere: Node = get_node_or_null("/root/Atmosphere")
	if atmosphere != null:
		atmosphere.apply_to_area(self)
		atmosphere.night_changed.connect(_on_night_changed)
	_play_area_music()
	var postfx: Node = get_node_or_null("/root/PostFX")
	if postfx != null:
		postfx.mood_world(frost_level, fog_level)
	_set_torches_lit(atmosphere != null and atmosphere.is_night())
	_arm_encounter()


## Each area carries a day theme and an optional night variant (<track>_night).
func _play_area_music() -> void:
	if music_track == "":
		return
	var music: Node = get_node_or_null("/root/MusicManager")
	if music == null:
		return
	var atmosphere: Node = get_node_or_null("/root/Atmosphere")
	var pick: String = music_track
	if atmosphere != null and atmosphere.is_night():
		if AssetLibrary.music_stream(music_track + "_night") != null:
			pick = music_track + "_night"
	music.play_track(pick)


func _on_night_changed(now_night: bool) -> void:
	_play_area_music()
	_set_torches_lit(now_night)


func _set_torches_lit(lit: bool) -> void:
	for torch_light: Node in get_tree().get_nodes_in_group("torch_light"):
		if not torch_light is PointLight2D:
			continue
		var tween: Tween = (torch_light as PointLight2D).create_tween()
		tween.tween_property(torch_light, "energy", 1.15 if lit else 0.0, 1.4)


## Scenes override this to build their geometry and content.
func _setup_area() -> void:
	pass


func _build_common() -> void:
	player = PlayerAvatar.new()
	player.z_index = 10
	add_child(player)
	player.position = _spawn_position()
	player.stepped.connect(_on_player_stepped)

	# Map-edge walls + follow camera for maps bigger than the screen.
	for bounds: Rect2 in [
		Rect2(-40, 0, 40, map_size.y), Rect2(map_size.x, 0, 40, map_size.y),
		Rect2(0, -40, map_size.x, 40), Rect2(0, map_size.y, map_size.x, 40),
	]:
		add_wall(bounds)
	var camera: Camera2D = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map_size.x)
	camera.limit_bottom = int(map_size.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	player.add_child(camera)
	camera.make_current()

	# UI rides a CanvasLayer so it stays put while the camera roams.
	_hud_layer = CanvasLayer.new()
	add_child(_hud_layer)

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 16)
	_prompt.position = Vector2(0, 612)
	_prompt.size = Vector2(SCREEN.x, 24)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	_hud_layer.add_child(_prompt)

	_dialog = PanelContainer.new()
	_dialog.position = Vector2(240, 540)
	_dialog.custom_minimum_size = Vector2(800, 0)
	_dialog.visible = false
	_hud_layer.add_child(_dialog)
	var dialog_stack: VBoxContainer = VBoxContainer.new()
	dialog_stack.add_theme_constant_override("separation", 8)
	_dialog.add_child(dialog_stack)
	_dialog_label = Label.new()
	_dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_label.add_theme_font_size_override("font_size", 16)
	dialog_stack.add_child(_dialog_label)
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 6)
	dialog_stack.add_child(_choice_box)

	var title: Label = Label.new()
	title.text = area_name + "      ·      [C] party"
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color(0.85, 0.85, 0.9)
	title.position = Vector2(16, 10)
	_hud_layer.add_child(title)


func _spawn_position() -> Vector2:
	var world: Node = get_node_or_null("/root/WorldState")
	if world != null and world.has_return_position:
		world.has_return_position = false
		return world.return_position
	return SCREEN / 2.0


## --- building blocks for scenes ----------------------------------------------


func add_rect(rect: Rect2, color: Color, z: int = 0) -> ColorRect:
	var block: ColorRect = ColorRect.new()
	block.color = color
	block.position = rect.position
	block.size = rect.size
	block.z_index = z
	add_child(block)
	return block


func add_wall(rect: Rect2) -> void:
	var wall: StaticBody2D = StaticBody2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	wall.position = rect.position + rect.size / 2.0
	wall.add_child(shape)
	add_child(wall)


## Solid scenery: a colored block the player collides with.
func add_building(rect: Rect2, color: Color, label_text: String = "") -> void:
	add_rect(rect, color, 2)
	add_wall(rect)
	add_occluder(rect)
	if label_text != "":
		var sign_label: Label = Label.new()
		sign_label.text = label_text
		sign_label.add_theme_font_size_override("font_size", 13)
		sign_label.position = rect.position + Vector2(6, -22)
		sign_label.z_index = 3
		add_child(sign_label)


## Sun-shadow caster matching a solid's footprint.
func add_occluder(rect: Rect2) -> void:
	var occluder: LightOccluder2D = LightOccluder2D.new()
	var poly: OccluderPolygon2D = OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2.ZERO, Vector2(rect.size.x, 0), rect.size, Vector2(0, rect.size.y)
	])
	occluder.occluder = poly
	occluder.position = rect.position
	add_child(occluder)


## A warm (or cold) glow that bites at night: lanterns, crystals, fires.
func add_point_light(
	pos: Vector2, color: Color, light_scale: float = 1.6, energy: float = 0.9
) -> PointLight2D:
	var light: PointLight2D = PointLight2D.new()
	light.texture = load("res://assets/sprites/ui/light_radial.png")
	light.position = pos
	light.color = color
	light.energy = energy
	light.texture_scale = light_scale
	light.shadow_enabled = true
	light.shadow_color = Color(0, 0, 0.05, 0.4)
	add_child(light)
	var flicker: Tween = light.create_tween().set_loops()
	flicker.tween_property(light, "energy", energy * 0.82, randf_range(0.7, 1.3))
	flicker.tween_property(light, "energy", energy, randf_range(0.7, 1.3))
	return light


## Soft contact-darkening under big shapes (the cheap seat's SSAO).
func add_ground_shadow(pos: Vector2, width: float) -> void:
	var shadow: Sprite2D = Sprite2D.new()
	shadow.texture = load("res://assets/sprites/ui/light_radial.png")
	shadow.modulate = Color(0, 0, 0, 0.30)
	shadow.scale = Vector2(width / 256.0, width / 256.0 * 0.34)
	shadow.position = pos
	shadow.z_index = 1
	add_child(shadow)


## GPU snowfall across the whole map.
func add_snowfall(amount: int = 300) -> void:
	var snow: GPUParticles2D = GPUParticles2D.new()
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(map_size.x / 2.0, 12.0, 1.0)
	material.direction = Vector3(0.18, 1.0, 0.0)
	material.spread = 12.0
	material.gravity = Vector3(6.0, 38.0, 0.0)
	material.initial_velocity_min = 18.0
	material.initial_velocity_max = 46.0
	material.scale_min = 1.2
	material.scale_max = 2.6
	material.color = Color(0.96, 0.98, 1.0, 0.85)
	snow.process_material = material
	snow.amount = amount
	snow.lifetime = map_size.y / 40.0
	snow.preprocess = snow.lifetime
	snow.position = Vector2(map_size.x / 2.0, -20.0)
	snow.visibility_rect = Rect2(-map_size.x / 2.0, -40.0, map_size.x, map_size.y + 80.0)
	snow.z_index = 50
	add_child(snow)


## A standing torch that lights itself when night falls (group: torch_light).
func add_torch(pos: Vector2) -> void:
	var torch: Node2D = Node2D.new()
	torch.position = pos
	torch.z_index = 4
	torch.draw.connect(func() -> void:
		torch.draw_rect(Rect2(-3, -8, 6, 30), Color(0.32, 0.22, 0.14))
		torch.draw_circle(Vector2(0, -14), 7.0, Color(1.0, 0.62, 0.18))
		torch.draw_circle(Vector2(0, -18), 4.0, Color(1.0, 0.85, 0.4)))
	add_child(torch)
	var embers: CPUParticles2D = CPUParticles2D.new()
	embers.position = Vector2(0, -16)
	embers.amount = 6
	embers.lifetime = 0.9
	embers.gravity = Vector2(0, -70)
	embers.initial_velocity_min = 4.0
	embers.initial_velocity_max = 14.0
	embers.scale_amount_min = 1.0
	embers.scale_amount_max = 2.0
	embers.color = Color(1.0, 0.7, 0.25, 0.8)
	torch.add_child(embers)
	var light: PointLight2D = PointLight2D.new()
	light.texture = load("res://assets/sprites/ui/light_radial.png")
	light.position = Vector2(0, -14)
	light.color = Color(1.0, 0.68, 0.3)
	light.energy = 0.0  # dawn state; night ignites it
	light.texture_scale = 1.2
	light.shadow_enabled = true
	light.add_to_group("torch_light")
	torch.add_child(light)


## Shared save crystal: drain Darkness, restore Resolve, ease Burden, save.
func add_save_crystal(pos: Vector2) -> void:
	var crystal: Polygon2D = Polygon2D.new()
	crystal.polygon = PackedVector2Array([
		Vector2(0, -34), Vector2(14, 0), Vector2(0, 34), Vector2(-14, 0)
	])
	crystal.color = Color(0.45, 0.95, 1.0)
	crystal.position = pos
	crystal.z_index = 3
	add_child(crystal)
	var pulse: Tween = crystal.create_tween().set_loops()
	pulse.tween_property(crystal, "modulate:a", 0.55, 0.9)
	pulse.tween_property(crystal, "modulate:a", 1.0, 0.9)
	add_point_light(pos, Color(0.5, 0.95, 1.0), 1.6, 1.2)
	add_interactable(pos, "Rest at the save crystal", func() -> void:
		var world: Node = get_node_or_null("/root/WorldState")
		if world == null or not world.in_world_run:
			show_dialog(["The crystal hums, but answers no one outside a true journey."])
			return
		var result: Error = world.rest_and_save(scene_file_path)
		var sfx: Node = get_node_or_null("/root/SfxManager")
		if sfx != null:
			sfx.play("heal")
		if result == OK:
			show_dialog([
				"You rest beneath the crystal's glow. Darkness drains; Resolve returns; the weight eases.",
				"Game saved.",
			])
		else:
			show_dialog(["The crystal flickers... saving failed (error %d)." % result]))


## A scatter of little drawn wildflowers (life, cheap and cheerful).
func add_flowers(positions: Array, seed_value: int = 11) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for pos: Vector2 in positions:
		var petal_color: Color = [
			Color(0.95, 0.55, 0.65), Color(0.95, 0.85, 0.4),
			Color(0.7, 0.6, 0.95), Color(0.95, 0.95, 0.95),
		][rng.randi_range(0, 3)]
		var flower: Node2D = Node2D.new()
		flower.position = pos
		flower.z_index = 1
		flower.draw.connect(func() -> void:
			for angle_index: int in range(4):
				var angle: float = TAU * float(angle_index) / 4.0
				flower.draw_circle(Vector2(cos(angle), sin(angle)) * 3.0, 2.6, petal_color)
			flower.draw_circle(Vector2.ZERO, 2.0, Color(0.95, 0.8, 0.3))
			flower.draw_rect(Rect2(-0.8, 3.0, 1.6, 6.0), Color(0.25, 0.5, 0.25)))
		add_child(flower)


## A pecking chicken on a little waddle loop. Pure charm, zero mechanics.
func add_chicken(home: Vector2) -> void:
	var hen: Node2D = Node2D.new()
	hen.position = home
	hen.z_index = 5
	hen.draw.connect(func() -> void:
		hen.draw_circle(Vector2.ZERO, 7.0, Color(0.96, 0.95, 0.9))
		hen.draw_circle(Vector2(5, -5), 4.0, Color(0.96, 0.95, 0.9))
		hen.draw_circle(Vector2(5.5, -6.5), 1.6, Color(0.85, 0.2, 0.15))
		hen.draw_rect(Rect2(8.0, -5.5, 3.0, 2.0), Color(0.95, 0.7, 0.2))
		hen.draw_rect(Rect2(-2.0, 6.0, 1.5, 4.0), Color(0.9, 0.65, 0.2))
		hen.draw_rect(Rect2(1.5, 6.0, 1.5, 4.0), Color(0.9, 0.65, 0.2)))
	add_child(hen)
	var waddle: Tween = hen.create_tween().set_loops()
	for hop: int in range(3):
		var target: Vector2 = home + Vector2(randf_range(-70, 70), randf_range(-40, 40))
		waddle.tween_property(hen, "position", target, randf_range(1.2, 2.4))
		waddle.tween_property(hen, "rotation_degrees", 8.0, 0.12)
		waddle.tween_property(hen, "rotation_degrees", 0.0, 0.12)
		waddle.tween_interval(randf_range(0.5, 1.6))
	waddle.tween_property(hen, "position", home, 1.5)


func add_exit(rect: Rect2, target_scene: String, spawn_in_target: Vector2) -> void:
	var zone: Area2D = _make_zone(rect)
	zone.body_entered.connect(func(body: Node2D) -> void:
		if body == player:
			var world: Node = get_node_or_null("/root/WorldState")
			if world != null:
				world.return_position = spawn_in_target
				world.has_return_position = true
			get_tree().change_scene_to_file.call_deferred(target_scene))
	add_rect(rect, Color(0.9, 0.9, 0.5, 0.25), 1)


func add_interactable(pos: Vector2, prompt_text: String, callback: Callable) -> void:
	var zone: Area2D = _make_zone(Rect2(pos - Vector2(40, 40), Vector2(80, 80)))
	var entry: Dictionary = {"area": zone, "prompt": prompt_text, "callback": callback}
	_interactables.append(entry)
	zone.body_entered.connect(func(body: Node2D) -> void:
		if body == player:
			_active_interactable = entry
			_prompt.text = "[E / A]  %s" % prompt_text
			_prompt.visible = true)
	zone.body_exited.connect(func(body: Node2D) -> void:
		if body == player and _active_interactable.get("area") == zone:
			_active_interactable = {}
			_prompt.visible = false)


func _make_zone(rect: Rect2) -> Area2D:
	var zone: Area2D = Area2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	zone.position = rect.position + rect.size / 2.0
	zone.add_child(shape)
	add_child(zone)
	return zone


func show_dialog(lines: Array[String]) -> void:
	_dialog_lines = lines.duplicate()
	_clear_choices()
	_advance_dialog()


## A spoken line plus 2-3 weighty options; each runs its callback when picked.
## options: [{"label": String, "callback": Callable}, ...]
func show_choice(prompt_text: String, options: Array) -> void:
	_dialog_lines = []
	_clear_choices()
	_dialog_label.text = prompt_text
	_dialog.visible = true
	var first: Button = null
	for option: Dictionary in options:
		var button: Button = Button.new()
		button.text = String(option["label"])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var callback: Callable = option["callback"]
		button.pressed.connect(func() -> void:
			_clear_choices()
			_dialog.visible = false
			callback.call())
		_choice_box.add_child(button)
		if first == null:
			first = button
	if first != null:
		first.grab_focus()


func _clear_choices() -> void:
	for child: Node in _choice_box.get_children():
		child.queue_free()


## Loot chest: opens once per run (tracked in WorldState), pays out items.
func add_chest(chest_id: String, pos: Vector2, loot: Dictionary) -> void:
	var world: Node = get_node_or_null("/root/WorldState")
	if world != null and world.opened_chests.has(chest_id):
		return
	var art: Texture2D = AssetLibrary.texture("props", "crate")
	var chest: Node2D = Node2D.new()
	chest.position = pos
	if art != null:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = art
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(2.0, 2.0)
		chest.add_child(sprite)
	else:
		var box: ColorRect = ColorRect.new()
		box.color = Color(0.6, 0.45, 0.2)
		box.size = Vector2(30, 24)
		box.position = Vector2(-15, -12)
		chest.add_child(box)
	add_child(chest)
	add_interactable(pos, "Open the chest", func() -> void:
		if world == null:
			show_dialog(["The chest is sealed to drifters. (Start a run.)"])
			return
		if world.opened_chests.has(chest_id):
			show_dialog(["Empty. Someone was here first — you, probably."])
			return
		world.opened_chests.append(chest_id)
		var lines: Array[String] = []
		for item_id: String in loot:
			world.add_item(item_id, int(loot[item_id]))
			var item: AbilityData = AbilityLibrary.load_ability(item_id)
			var item_name: String = item.display_name if item != null else item_id
			lines.append("Found %s ×%d!" % [item_name, int(loot[item_id])])
		var sfx: Node = get_node_or_null("/root/SfxManager")
		if sfx != null:
			sfx.play("heal")
		chest.modulate = Color(0.5, 0.5, 0.5)
		show_dialog(lines))


## A villager who wanders between waypoints and tosses a one-liner when bumped.
func add_roamer(
	roamer_name: String, waypoints: Array[Vector2], lines: Array[String], tint: Color = Color.WHITE
) -> void:
	var roamer: Node2D = Node2D.new()
	roamer.position = waypoints[0]
	roamer.z_index = 9
	# Directional walker body (tinted villager); static sprite as fallback.
	var walker_name: String = (
		roamer_name if AssetLibrary.walk_frames(roamer_name) != null else "Cavene"
	)
	if WalkerSprite.attach(roamer, walker_name, 2.0):
		(roamer.get_child(0) as WalkerSprite).modulate = tint
	else:
		var art: Texture2D = AssetLibrary.texture("characters", "Cavene")
		if art != null:
			var sprite: Sprite2D = Sprite2D.new()
			sprite.texture = art
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.scale = Vector2(2.0, 2.0)
			sprite.modulate = tint
			roamer.add_child(sprite)
	add_child(roamer)
	# Drift between waypoints forever.
	var tween: Tween = roamer.create_tween().set_loops()
	for i: int in range(waypoints.size()):
		var next: Vector2 = waypoints[(i + 1) % waypoints.size()]
		var hop: Vector2 = waypoints[i]
		tween.tween_property(roamer, "position", next, maxf(hop.distance_to(next) / 60.0, 0.5))
		tween.tween_interval(randf_range(0.8, 2.2))
	# Talking zone follows the roamer.
	var zone: Area2D = Area2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 46.0
	shape.shape = circle
	zone.add_child(shape)
	roamer.add_child(zone)
	var entry: Dictionary = {
		"area": zone, "prompt": "Talk", "callback": func() -> void:
			show_dialog([lines[randi() % lines.size()]] as Array[String]),
	}
	_interactables.append(entry)
	zone.body_entered.connect(func(body: Node2D) -> void:
		if body == player:
			_active_interactable = entry
			_prompt.text = "[E / A]  Talk"
			_prompt.visible = true)
	zone.body_exited.connect(func(body: Node2D) -> void:
		if body == player and _active_interactable.get("area") == zone:
			_active_interactable = {}
			_prompt.visible = false)


func _advance_dialog() -> void:
	if _dialog_lines.is_empty():
		_dialog.visible = false
		return
	_dialog_label.text = _dialog_lines.pop_front() + "\n\n[E / A] ..."
	_dialog.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("char_menu") and not _dialog.visible:
		get_viewport().set_input_as_handled()
		var sfx_menu: Node = get_node_or_null("/root/SfxManager")
		if sfx_menu != null:
			sfx_menu.play("click")
		add_child(CharacterMenuOverlay.new())
		return
	if not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	var sfx: Node = get_node_or_null("/root/SfxManager")
	if sfx != null:
		sfx.play("click")
	if _dialog.visible:
		_advance_dialog()
		return
	if not _active_interactable.is_empty():
		var callback: Callable = _active_interactable["callback"]
		callback.call()


## --- random encounters ---------------------------------------------------------


func _arm_encounter() -> void:
	_steps_until_encounter = randf_range(260.0, 430.0)


func _on_player_stepped(distance: float) -> void:
	if not encounters_enabled or encounter_rosters.is_empty() or _dialog.visible:
		return
	_steps_until_encounter -= distance
	if _steps_until_encounter > 0.0:
		return
	var world: Node = get_node_or_null("/root/WorldState")
	if world == null or not world.in_world_run:
		_arm_encounter()
		return
	var roster: String = encounter_rosters[randi() % encounter_rosters.size()]
	var sfx: Node = get_node_or_null("/root/SfxManager")
	if sfx != null:
		sfx.play("shock")
	world.start_battle(get_tree(), roster, scene_file_path, player.position)
