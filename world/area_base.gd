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


func _ready() -> void:
	_build_common()
	_setup_area()  # scenes override
	if music_track != "":
		var music: Node = get_node_or_null("/root/MusicManager")
		if music != null:
			music.play_track(music_track)
	_arm_encounter()


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
	title.text = area_name
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
	if label_text != "":
		var sign_label: Label = Label.new()
		sign_label.text = label_text
		sign_label.add_theme_font_size_override("font_size", 13)
		sign_label.position = rect.position + Vector2(6, -22)
		sign_label.z_index = 3
		add_child(sign_label)


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
	var art: Texture2D = AssetLibrary.texture("characters", roamer_name)
	if art == null:
		art = AssetLibrary.texture("characters", "Cavene")  # generic villager body
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
