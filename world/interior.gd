extends AreaBase
## A generic enterable interior (homes, the merc post). WorldState.next_interior
## tells it whose roof this is: {"title", "lines", "merc": bool, "exit_scene",
## "exit_pos"}.

var _config: Dictionary = {}


func _init() -> void:
	area_name = "INSIDE"
	map_size = Vector2(1280, 720)


func _setup_area() -> void:
	var world: Node = get_node_or_null("/root/WorldState")
	if world != null:
		_config = world.get("next_interior")
		area_name = String(_config.get("title", "A quiet home"))
	add_rect(Rect2(0, 0, 1280, 720), Color(0.12, 0.09, 0.07), -10)  # timber dark
	add_rect(Rect2(160, 120, 960, 480), Color(0.24, 0.18, 0.13), -9)  # floorboards
	add_rect(Rect2(200, 160, 220, 90), Color(0.45, 0.30, 0.25), 1)  # bed
	add_wall(Rect2(200, 160, 220, 90))
	add_rect(Rect2(860, 170, 160, 80), Color(0.30, 0.24, 0.18), 1)  # table
	add_wall(Rect2(860, 170, 160, 80))
	add_rect(Rect2(560, 150, 90, 40), Color(0.55, 0.35, 0.2), 1)  # hearth
	var title: Label = Label.new()
	title.text = area_name
	title.position = Vector2(540, 300)
	title.modulate = Color(0.6, 0.55, 0.5)
	add_child(title)

	var occupant_lines: Array[String] = []
	for line: Variant in _config.get("lines", []):
		occupant_lines.append(String(line))
	if not occupant_lines.is_empty():
		_add_occupant(Vector2(700, 360), occupant_lines, bool(_config.get("merc", false)))

	# Door back out, bottom-center.
	add_exit(
		Rect2(600, 680, 110, 40),
		String(_config.get("exit_scene", "res://world/town.tscn")),
		_config.get("exit_pos", Vector2(640, 400))
	)
	var door_label: Label = Label.new()
	door_label.text = "v  leave"
	door_label.position = Vector2(615, 645)
	door_label.add_theme_font_size_override("font_size", 13)
	add_child(door_label)


func _add_occupant(pos: Vector2, lines: Array[String], is_merc_post: bool) -> void:
	var art: Texture2D = AssetLibrary.texture(
		"characters", "Church Lancer" if is_merc_post else "Mati"
	)
	if art != null:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = art
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(2.4, 2.4)
		sprite.position = pos
		if not is_merc_post:
			sprite.modulate = Color(0.9, 0.85, 0.8)  # de-hero the body double
		add_child(sprite)
	if is_merc_post:
		add_interactable(pos, "Speak with the Lancer", _merc_talk)
	else:
		add_interactable(pos, "Talk", func() -> void: show_dialog(lines))


func _merc_talk() -> void:
	var world: Node = get_node_or_null("/root/WorldState")
	if world == null or not world.in_world_run:
		show_dialog(["The Lancer eyes you. 'Come back with the Church's writ.'"])
		return
	if world.merc_hired:
		show_choice("Church Lancer: 'My spear is yours, pilgrim. Changing your mind?'", [
			{"label": "Keep him in the party", "callback": func() -> void:
				show_dialog(["Lancer: 'Good. The roads are bad company alone.'"])},
			{"label": "Dismiss him", "callback": func() -> void:
				world.merc_hired = false
				show_dialog(["Lancer: 'Wise or cruel — your call.' (He stays behind.)"])},
		])
	else:
		show_choice("Church Lancer: 'Coin's paid by the Church. Want my spear on the road?'", [
			{"label": "Hire the Lancer (joins slot five)", "callback": func() -> void:
				world.merc_hired = true
				show_dialog(["Lancer: 'Then we march. Try not to spend me cheap.'"])},
			{"label": "Not yet", "callback": func() -> void:
				show_dialog(["Lancer: 'Suit yourself.'"])},
		])
