extends AreaBase
## The crystal-site dungeon, three zones west to east:
## combat approach (scripted gauntlet) -> memory-echo chamber (M7 stub) ->
## the boss arena door (Frozen Shepherd).


func _init() -> void:
	area_name = "AETHER CRYSTAL SITE II — the glacial deep"
	music_track = "dungeon"


func _setup_area() -> void:
	add_rect(Rect2(0, 0, 1280, 720), Color(0.08, 0.12, 0.16), -10)  # cavern dark
	add_rect(Rect2(0, 280, 1280, 180), Color(0.13, 0.18, 0.23), -9)  # carved path

	# Zone dividers: narrow doorways in two rock walls.
	for wall_x: float in [420.0, 840.0]:
		add_building(Rect2(wall_x, 0, 36, 280), Color(0.16, 0.2, 0.26))
		add_building(Rect2(wall_x, 460, 36, 260), Color(0.16, 0.2, 0.26))

	var zone1: Label = Label.new()
	zone1.text = "I. THE APPROACH"
	zone1.position = Vector2(120, 60)
	zone1.modulate = Color(0.6, 0.7, 0.8)
	add_child(zone1)
	var zone2: Label = Label.new()
	zone2.text = "II. MEMORY CHAMBER"
	zone2.position = Vector2(540, 60)
	zone2.modulate = Color(0.6, 0.7, 0.8)
	add_child(zone2)
	var zone3: Label = Label.new()
	zone3.text = "III. THE SHEPHERD'S ARENA"
	zone3.position = Vector2(940, 60)
	zone3.modulate = Color(0.8, 0.6, 0.6)
	add_child(zone3)

	# Zone 1: a frozen sentinel pack blocks the path (fights once per visit).
	var world: Node = get_node_or_null("/root/WorldState")
	var gauntlet_done: bool = world != null and world.get("dungeon_gauntlet_cleared")
	if not gauntlet_done:
		var pack: Polygon2D = Polygon2D.new()
		pack.polygon = PackedVector2Array([
			Vector2(-20, -16), Vector2(20, -16), Vector2(28, 16), Vector2(-28, 16)
		])
		pack.color = Color(0.5, 0.55, 0.65)
		pack.position = Vector2(300, 360)
		add_child(pack)
		add_interactable(Vector2(300, 360), "Face the frozen pack", func() -> void:
			if world != null and world.in_world_run:
				world.set("dungeon_gauntlet_cleared", true)
				world.start_battle(get_tree(), "dungeon_gauntlet", scene_file_path, Vector2(360, 360))
			else:
				show_dialog(["The pack ignores ghosts. (Start a run from the main menu.)"]))

	# Zone 2: the memory crystal (M7 unlocks the Echo here).
	var crystal: Polygon2D = Polygon2D.new()
	crystal.polygon = PackedVector2Array([
		Vector2(0, -40), Vector2(18, 0), Vector2(0, 40), Vector2(-18, 0)
	])
	crystal.color = Color(0.75, 0.6, 1.0)
	crystal.position = Vector2(640, 360)
	crystal.z_index = 3
	add_child(crystal)
	var pulse: Tween = crystal.create_tween().set_loops()
	pulse.tween_property(crystal, "modulate:a", 0.5, 1.2)
	pulse.tween_property(crystal, "modulate:a", 1.0, 1.2)
	add_interactable(Vector2(640, 360), "Touch the memory crystal", func() -> void:
		show_dialog([
			"The crystal stirs. Voices older than the ice press against your mind...",
			"...but the memory will not open. Not yet. (Memory Echo arrives with M7.)",
		]))

	# Zone 3: the boss door.
	var door: ColorRect = add_rect(Rect2(1150, 300, 60, 140), Color(0.55, 0.8, 0.95, 0.9), 3)
	var door_pulse: Tween = door.create_tween().set_loops()
	door_pulse.tween_property(door, "modulate:a", 0.6, 1.0)
	door_pulse.tween_property(door, "modulate:a", 1.0, 1.0)
	add_interactable(Vector2(1180, 370), "Enter the Shepherd's arena", _on_boss_door)

	# Back west to the fields.
	add_exit(Rect2(0, 300, 40, 150), "res://world/outside.tscn", Vector2(1180, 370))

	if world != null and world.get("boss_cleared"):
		show_dialog([
			"The arena lies silent. The Shepherd's stillness is broken.",
			"THE SLICE IS COMPLETE — thank you for playing this far. (M7 polish remains.)",
		])


func _on_boss_door() -> void:
	var world: Node = get_node_or_null("/root/WorldState")
	if world == null or not world.in_world_run:
		show_dialog(["The door answers only true pilgrims. (Start a run from the main menu.)"])
		return
	if world.get("boss_cleared"):
		show_dialog(["Only cold wind remains beyond the door."])
		return
	world.start_battle(get_tree(), "boss", scene_file_path, Vector2(1100, 370))
