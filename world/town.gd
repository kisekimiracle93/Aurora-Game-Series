extends AreaBase
## Aethertown, rebuilt with the toolbox art: a real multi-home town on a
## scrolling map — enterable homes and merc post, save crystal, shop stub,
## roaming villagers with one-liners, choice-quests that move the meters,
## and treasure to find.

var _world: Node


func _init() -> void:
	area_name = "AETHERTOWN — under the walls of Castle Aetherhold"
	music_track = "town"
	map_size = Vector2(2560, 1600)
	frost_level = 0.05
	fog_level = 0.06


func _setup_area() -> void:
	_world = get_node_or_null("/root/WorldState")
	_build_grounds()
	_build_castle()
	_build_homes()
	add_save_crystal(Vector2(1375, 740))
	_build_npcs_and_quests()
	_build_life()

	# Night-life: lanterns + gate torches; gentle snowfall.
	add_point_light(Vector2(420, 330), Color(1.0, 0.8, 0.5), 1.4, 1.0)
	add_point_light(Vector2(1500, 850), Color(1.0, 0.78, 0.48), 1.3, 0.95)
	add_point_light(Vector2(260, 1060), Color(1.0, 0.82, 0.55), 1.1, 0.8)
	for torch_pos: Vector2 in [
		Vector2(1290, 600), Vector2(1460, 600), Vector2(700, 640),
		Vector2(2050, 640), Vector2(960, 1240),
	]:
		add_torch(torch_pos)
	add_snowfall(170)

	add_chest("town_well", Vector2(1180, 880), {"item_hp_potion": 2})
	add_chest("town_east_garden", Vector2(2300, 950), {"item_aether_draught": 2})

	# Road out, east edge — into the Verdant Pass.
	add_exit(Rect2(2520, 560, 40, 200), "res://world/forest.tscn", Vector2(130, 980))
	var gate_label: Label = Label.new()
	gate_label.text = "To the Verdant Pass >"
	gate_label.position = Vector2(2300, 530)
	gate_label.add_theme_font_size_override("font_size", 14)
	add_child(gate_label)


## Castle Aetherhold: a massive landmark keep (not enterable in the slice).
func _build_castle() -> void:
	var stone: Texture2D = (
		load("res://assets/sprites/ui/stone_panel.png")
		if ResourceLoader.exists("res://assets/sprites/ui/stone_panel.png") else null
	)
	var body: Rect2 = Rect2(980, 120, 760, 420)
	if stone != null:
		var wall: TextureRect = TextureRect.new()
		wall.texture = stone
		wall.stretch_mode = TextureRect.STRETCH_TILE
		wall.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		wall.position = body.position
		wall.size = body.size
		wall.z_index = 4
		add_child(wall)
	else:
		add_rect(body, Color(0.32, 0.33, 0.4), 4)
	# Towers: two flanks and the great keep, all crenellated.
	for tower: Rect2 in [
		Rect2(930, 40, 130, 520), Rect2(1660, 40, 130, 520), Rect2(1270, 0, 200, 560),
	]:
		if stone != null:
			var tower_wall: TextureRect = TextureRect.new()
			tower_wall.texture = stone
			tower_wall.stretch_mode = TextureRect.STRETCH_TILE
			tower_wall.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tower_wall.position = tower.position
			tower_wall.size = tower.size
			tower_wall.z_index = 5
			add_child(tower_wall)
		else:
			add_rect(tower, Color(0.36, 0.37, 0.44), 5)
		var teeth: int = 5
		var tooth_w: float = tower.size.x / float(teeth * 2 - 1)
		for tooth: int in range(teeth):
			add_rect(Rect2(
				tower.position.x + tooth * tooth_w * 2.0, tower.position.y - 16.0,
				tooth_w, 16.0
			), Color(0.30, 0.31, 0.38), 5)
		# Banner: church crimson with a pale sun disc.
		add_rect(Rect2(tower.position.x + tower.size.x / 2.0 - 14, tower.position.y + 40, 28, 64),
			Color(0.62, 0.12, 0.14), 6)
	# Lit windows (they matter at night).
	for window_pos: Vector2 in [
		Vector2(1080, 240), Vector2(1180, 320), Vector2(1560, 240), Vector2(1480, 360),
		Vector2(1340, 160), Vector2(1390, 300),
	]:
		add_rect(Rect2(window_pos, Vector2(20, 30)), Color(1.0, 0.85, 0.45, 0.9), 6)
		add_point_light(window_pos + Vector2(10, 15), Color(1.0, 0.8, 0.45), 0.5, 0.5)
	# The gate: a dark arch flanked by torches, opening onto the plaza.
	add_rect(Rect2(1330, 460, 90, 100), Color(0.08, 0.07, 0.1), 6)
	var gate_sign: Label = Label.new()
	gate_sign.text = "CASTLE AETHERHOLD — the Church keeps its own counsel"
	gate_sign.position = Vector2(1130, 580)
	gate_sign.add_theme_font_size_override("font_size", 13)
	gate_sign.modulate = Color(0.8, 0.78, 0.7)
	add_child(gate_sign)
	add_interactable(Vector2(1375, 580), "Knock at the castle gate", func() -> void:
		show_dialog([
			"The gatekeeper's slit slides open, then shut.",
			"Gatekeeper: 'Pilgrims to the fields. Petitioners to the chapel. Neither enters Aetherhold.'",
		]))
	# Solid mass + shadows + occluder.
	add_wall(Rect2(930, 0, 860, 540))
	add_occluder(Rect2(930, 0, 860, 540))
	add_ground_shadow(Vector2(1360, 560), 900.0)


func _build_grounds() -> void:
	var grass: Texture2D = load(
		"res://assets/all files/town_rpg_pack/town_rpg_pack/graphics/grass-tile-2.png"
	) if ResourceLoader.exists(
		"res://assets/all files/town_rpg_pack/town_rpg_pack/graphics/grass-tile-2.png"
	) else null
	if grass != null:
		var ground: TextureRect = TextureRect.new()
		ground.texture = grass
		ground.stretch_mode = TextureRect.STRETCH_TILE
		ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ground.size = map_size
		ground.z_index = -10
		add_child(ground)
	else:
		add_rect(Rect2(Vector2.ZERO, map_size), Color(0.16, 0.20, 0.16), -10)
	# Dirt roads: the main avenue, the gate road, and a market lane.
	add_rect(Rect2(0, 600, map_size.x, 110), Color(0.42, 0.34, 0.24, 0.95), -9)
	add_rect(Rect2(1330, 560, 90, 200), Color(0.42, 0.34, 0.24, 0.95), -9)
	add_rect(Rect2(880, 600, 120, map_size.y - 600.0), Color(0.42, 0.34, 0.24, 0.95), -9)
	# Pine breaks along the north edge.
	var pines: Texture2D = AssetLibrary.texture("props", "pine_cluster")
	if pines != null:
		for x: float in [60.0, 360.0, 660.0, 1900.0, 2200.0, 2470.0]:
			var cluster: Sprite2D = Sprite2D.new()
			cluster.texture = pines
			cluster.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			cluster.scale = Vector2(2.0, 2.0)
			cluster.position = Vector2(x, 140)
			cluster.z_index = 3
			cluster.material = AssetLibrary.foliage_material()
			add_child(cluster)
			add_wall(Rect2(x - 50, 90, 100, 110))


## A home: sprite house, solid walls, and (optionally) a door you can enter.
func _add_home(
	pos: Vector2, tall: bool, door_config: Dictionary = {}
) -> void:
	var art: Texture2D = AssetLibrary.texture("props", "house_tall" if tall else "house_inn")
	var footprint: Vector2 = (Vector2(90, 118) if tall else Vector2(168, 104)) * 2.0
	if art != null:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = art
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(2.0, 2.0)
		sprite.position = pos
		sprite.z_index = 4
		add_child(sprite)
	else:
		add_rect(Rect2(pos - footprint / 2.0, footprint), Color(0.35, 0.27, 0.2), 4)
	# Solid body, but leave the doorway gap open at the bottom-center.
	var top_left: Vector2 = pos - footprint / 2.0
	add_wall(Rect2(top_left, Vector2(footprint.x, footprint.y - 26)))
	add_wall(Rect2(top_left + Vector2(0, footprint.y - 26), Vector2(footprint.x / 2.0 - 28, 26)))
	add_wall(Rect2(
		top_left + Vector2(footprint.x / 2.0 + 28, footprint.y - 26),
		Vector2(footprint.x / 2.0 - 28, 26)
	))
	add_ground_shadow(pos + Vector2(0, footprint.y / 2.0 - 6.0), footprint.x * 1.15)
	if door_config.is_empty():
		return
	var door_pos: Vector2 = pos + Vector2(0, footprint.y / 2.0 + 14)
	add_interactable(door_pos, String(door_config.get("prompt", "Enter")), func() -> void:
		if _world == null:
			show_dialog(["The door is barred to drifters."])
			return
		_world.next_interior = {
			"title": door_config.get("title", "A quiet home"),
			"lines": door_config.get("lines", []),
			"merc": door_config.get("merc", false),
			"exit_scene": scene_file_path,
			"exit_pos": door_pos + Vector2(0, 30),
		}
		get_tree().change_scene_to_file.call_deferred("res://world/interior.tscn"))


func _build_homes() -> void:
	# The inn (landmark, not enterable in the slice) + a row of homes.
	_add_home(Vector2(420, 420), false)  # Pilgrims' Rest
	var inn_sign: Label = Label.new()
	inn_sign.text = "Pilgrims' Rest (inn)"
	inn_sign.position = Vector2(330, 290)
	inn_sign.add_theme_font_size_override("font_size", 13)
	add_child(inn_sign)

	_add_home(Vector2(2120, 420), true, {
		"prompt": "Enter the fisher's home", "title": "THE FISHER'S HOME",
		"lines": [
			"Fisher: 'The lake froze in a single night, years back. Nobody fishes the deep holes now.'",
			"Fisher: 'You hear it too, don't you? The hum under the ice.'",
		],
	})
	_add_home(Vector2(2380, 460), true, {
		"prompt": "Enter the widow's home", "title": "THE WIDOW'S HOME",
		"lines": [
			"Widow: 'My husband walked the fields one winter and the wolves... well. Mind the road, pilgrim.'",
		],
	})
	_add_home(Vector2(420, 900), true)  # locked home (flavor only)
	_add_home(Vector2(2150, 1000), true)  # east district homes (locked)
	_add_home(Vector2(2400, 1250), true)
	_add_home(Vector2(700, 1300), false)  # the old granary
	_add_home(Vector2(1500, 950), true, {
		"prompt": "Enter the Mercenary Post", "title": "MERCENARY POST — CHURCH CHARTER",
		"merc": true,
		"lines": [],
	})
	var merc_sign: Label = Label.new()
	merc_sign.text = "Mercenary Post"
	merc_sign.position = Vector2(1430, 800)
	merc_sign.add_theme_font_size_override("font_size", 13)
	add_child(merc_sign)

	# Shop stall (stub).
	add_building(Rect2(150, 1080, 220, 120), Color(0.27, 0.3, 0.35), "Shop")
	add_interactable(Vector2(260, 1150), "Browse the shop", func() -> void:
		show_dialog([
			"Shopkeep: 'Stock's still on the wagon, friend. After the pilgrimage, maybe.'",
			"(The shop is a stub in this slice — full trade arrives later.)",
		]))


## Flowers, hens, and idle townsfolk — the small life of a living town.
func _build_life() -> void:
	add_flowers([
		Vector2(540, 540), Vector2(580, 560), Vector2(620, 535), Vector2(300, 760),
		Vector2(340, 790), Vector2(1180, 760), Vector2(1240, 790), Vector2(1530, 700),
		Vector2(2050, 760), Vector2(2230, 700), Vector2(820, 1180), Vector2(860, 1210),
		Vector2(1700, 1180), Vector2(2300, 1420), Vector2(480, 1180), Vector2(1960, 540),
	])
	for hen_home: Vector2 in [Vector2(560, 760), Vector2(640, 800), Vector2(2180, 1180)]:
		add_chicken(hen_home)


func _build_npcs_and_quests() -> void:
	add_roamer("villager_d", [
		Vector2(1700, 660), Vector2(2300, 660), Vector2(2300, 780),
	] as Array[Vector2], [
		"The castle gate hasn't opened for common folk in nine years.",
		"They light the keep's windows all night. Who for, I wonder.",
		"Mind the chickens. They bite. Don't laugh — they do.",
	] as Array[String], Color(0.75, 0.85, 0.7))
	add_roamer("villager_e", [
		Vector2(960, 1180), Vector2(960, 1420), Vector2(700, 1420),
	] as Array[Vector2], [
		"Fresh bread at dawn, if the granary holds.",
		"You're with the pilgrimage? Selene keep you.",
		"My grandmother remembers when the falls didn't freeze.",
	] as Array[String], Color(0.9, 0.8, 0.75))
	# Roaming villagers with one-liners.
	add_roamer("villager_a", [
		Vector2(700, 650), Vector2(1150, 650), Vector2(1150, 760), Vector2(700, 760),
	] as Array[Vector2], [
		"Hello.", "Hi there.", "Move along, kid.", "I don't have time today.",
		"Cold's coming early this year.", "The Lancer drinks for free. Church coin.",
	] as Array[String], Color(0.85, 0.75, 0.65))
	add_roamer("villager_b", [
		Vector2(300, 620), Vector2(300, 1000), Vector2(560, 1000),
	] as Array[Vector2], [
		"I'm looking for my cat. Three days now.", "Have you seen a grey cat?",
		"She answers to 'Ember'. Sometimes.",
	] as Array[String], Color(0.7, 0.8, 0.9))
	add_roamer("villager_c", [
		Vector2(1100, 200), Vector2(1500, 200), Vector2(1500, 330),
	] as Array[Vector2], [
		"The chapel bell cracked last Dimming. Never rang right since.",
		"Don't go past the fields at night.", "Hm? No, nothing. Forget it.",
	] as Array[String], Color(0.9, 0.85, 0.7))

	# --- Choice quests: words that weigh on the meters --------------------------
	_add_quest_npc("quest_letter", Vector2(700, 980), Color(0.75, 0.6, 0.5), "Courier",
		"Courier: 'This letter proves the miller's husband cheats at dice — and worse. Deliver the truth to her, or burn it and spare the house the shame?'", [
		{"label": "Deliver the truth (Duty +14, Resolve +8)", "callback": func() -> void:
			_world.adjust_party_meter("duty", 14.0)
			_world.adjust_party_meter("resolve", 8.0)
			show_dialog(["The miller's wife reads it twice, thanks you once, and bars her door.",
				"Truth is a cold gift, but a gift."])},
		{"label": "Burn it (Burden +15, Heirs Darkness +8)", "callback": func() -> void:
			_world.adjust_party_meter("burden", 15.0)
			_world.adjust_party_meter("darkness", 8.0)
			show_dialog(["The letter curls to ash. The lie keeps a roof warm tonight.",
				"Something of it clings to your hands anyway."])},
	])
	_add_quest_npc("quest_smuggler", Vector2(1250, 1100), Color(0.6, 0.65, 0.6), "Nervous man",
		"Nervous man: 'The guards are coming for the grain smuggler tonight. He feeds half the poor quarter. Warn him — or let the law have him?'", [
		{"label": "Warn the smuggler (Resolve +10, Burden +12)", "callback": func() -> void:
			_world.adjust_party_meter("resolve", 10.0)
			_world.adjust_party_meter("burden", 12.0)
			show_dialog(["He's gone before the lanterns turn the corner. The poor quarter eats.",
				"The law remembers faces, though. Yours included."])},
		{"label": "Alert the guards (Duty +15, Resolve -6)", "callback": func() -> void:
			_world.adjust_party_meter("duty", 15.0)
			_world.adjust_party_meter("resolve", -6.0)
			show_dialog(["They take him quietly. The captain nods at you like a colleague.",
				"It was the lawful thing. The street is very quiet."])},
	])
	_add_quest_npc("quest_festival", Vector2(560, 250), Color(0.8, 0.7, 0.85), "Old acolyte",
		"Old acolyte: 'The Festival of First Light... the \"miracle\" was lamp-oil and mirrors. I rigged it myself, forty years past. Should the town know?'", [
		{"label": "Tell the town the truth (Duty +12, Resolve -8)", "callback": func() -> void:
			_world.adjust_party_meter("duty", 12.0)
			_world.adjust_party_meter("resolve", -8.0)
			show_dialog(["Some thank you. Most don't. The festival lanterns look dimmer now to everyone.",
				"Truth costs what it costs."])},
		{"label": "Let the town keep its miracle (Burden +12)", "callback": func() -> void:
			_world.adjust_party_meter("burden", 12.0)
			show_dialog(["The old man nods, relieved and ashamed in the same breath.",
				"You carry the secret out the door with you."])},
	])


func _add_quest_npc(
	quest_id: String, pos: Vector2, tint: Color, npc_name: String,
	prompt_text: String, options: Array
) -> void:
	var art: Texture2D = AssetLibrary.texture("characters", "Cavene")
	if art != null:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = art
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(2.0, 2.0)
		sprite.modulate = tint
		sprite.position = pos
		sprite.z_index = 5
		add_child(sprite)
	var marker: Label = Label.new()
	marker.text = "?"
	marker.add_theme_font_size_override("font_size", 22)
	marker.modulate = Color(1.0, 0.9, 0.3)
	marker.position = pos + Vector2(-6, -56)
	marker.z_index = 5
	add_child(marker)
	add_interactable(pos, "Speak with the %s" % npc_name.to_lower(), func() -> void:
		if _world == null or not _world.in_world_run:
			show_dialog(["They wave you off. (Start a run from the main menu.)"])
			return
		if _world.quests_done.has(quest_id):
			show_dialog(["%s: 'It's done. No taking it back now.'" % npc_name])
			return
		_world.quests_done.append(quest_id)  # committed the moment the choice opens
		marker.visible = false
		show_choice(prompt_text, options))
