class_name AreaBase
extends Node2D
## Shared scaffold for walkable areas (town / outside / dungeon): screen
## bounds, a player avatar, exits to other scenes, interactables with an
## E/A prompt, sequential dialog, and optional step-based random encounters.

const SCREEN: Vector2 = Vector2(1280, 720)

var player: PlayerAvatar
var area_name: String = ""
var music_track: String = ""

## Random encounters (outside area): rolls a battle every N walked pixels.
var encounters_enabled: bool = false
var encounter_rosters: Array[String] = []
var _steps_until_encounter: float = 0.0

var _prompt: Label
var _dialog: PanelContainer
var _dialog_label: Label
var _dialog_lines: Array[String] = []
var _active_interactable: Dictionary = {}
var _interactables: Array[Dictionary] = []  # {"area": Area2D, "prompt": String, "callback": Callable}


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

	# Screen-edge walls.
	for bounds: Rect2 in [
		Rect2(-40, 0, 40, SCREEN.y), Rect2(SCREEN.x, 0, 40, SCREEN.y),
		Rect2(0, -40, SCREEN.x, 40), Rect2(0, SCREEN.y, SCREEN.x, 40),
	]:
		add_wall(bounds)

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 16)
	_prompt.position = Vector2(0, 612)
	_prompt.size = Vector2(SCREEN.x, 24)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	_prompt.z_index = 90
	add_child(_prompt)

	_dialog = PanelContainer.new()
	_dialog.position = Vector2(240, 560)
	_dialog.custom_minimum_size = Vector2(800, 0)
	_dialog.visible = false
	_dialog.z_index = 95
	add_child(_dialog)
	_dialog_label = Label.new()
	_dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_label.add_theme_font_size_override("font_size", 16)
	_dialog.add_child(_dialog_label)

	var title: Label = Label.new()
	title.text = area_name
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color(0.85, 0.85, 0.9)
	title.position = Vector2(16, 10)
	title.z_index = 90
	add_child(title)


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
	_advance_dialog()


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
