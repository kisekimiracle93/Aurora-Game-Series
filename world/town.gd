extends AreaBase
## The small town: save crystal (drain Darkness, restore Resolve, save),
## merc-hire post, shop stub, a couple of NPCs, and the road out.


func _init() -> void:
	area_name = "AETHERTOWN — last light before the crystal fields"
	music_track = "town"


func _setup_area() -> void:
	add_rect(Rect2(0, 0, 1280, 720), Color(0.16, 0.20, 0.16), -10)  # grass
	add_rect(Rect2(0, 320, 1280, 110), Color(0.32, 0.28, 0.22, 0.9), -9)  # main road
	add_rect(Rect2(590, 0, 110, 720), Color(0.32, 0.28, 0.22, 0.9), -9)

	add_building(Rect2(140, 120, 240, 150), Color(0.35, 0.27, 0.2), "Pilgrims' Rest (inn)")
	add_building(Rect2(880, 110, 260, 160), Color(0.3, 0.24, 0.28), "Chapel of Selene")
	add_building(Rect2(150, 480, 220, 140), Color(0.27, 0.3, 0.35), "Shop")
	add_building(Rect2(900, 470, 230, 150), Color(0.3, 0.3, 0.24), "Mercenary Post")

	# Save crystal: pulsing cyan shard by the chapel.
	var crystal: Polygon2D = Polygon2D.new()
	crystal.polygon = PackedVector2Array([
		Vector2(0, -34), Vector2(14, 0), Vector2(0, 34), Vector2(-14, 0)
	])
	crystal.color = Color(0.45, 0.95, 1.0)
	crystal.position = Vector2(800, 330)
	crystal.z_index = 3
	add_child(crystal)
	var pulse: Tween = crystal.create_tween().set_loops()
	pulse.tween_property(crystal, "modulate:a", 0.55, 0.9)
	pulse.tween_property(crystal, "modulate:a", 1.0, 0.9)
	add_interactable(Vector2(800, 330), "Rest at the save crystal", _on_save_crystal)

	add_interactable(Vector2(1015, 545), "Speak with the mercenary", _on_merc_post)
	add_interactable(Vector2(260, 550), "Browse the shop", _on_shop)

	_add_npc(Vector2(480, 380), Color(0.7, 0.6, 0.5), "Pilgrim", [
		"Pilgrim: The wolves grow bolder past the gate. Even the stag-things came down from the ice.",
		"Pilgrim: They say the Shepherd at the crystal site was a guardian, once. Before the stillness took it.",
	])
	_add_npc(Vector2(700, 250), Color(0.6, 0.65, 0.8), "Acolyte", [
		"Acolyte: Rest at the crystal before you go. It eases the... darkness that clings to your friends.",
		"Acolyte: The Church pays the Lancer's wage. Spend his life wisely — he would.",
	])

	# Road out, east edge.
	add_exit(
		Rect2(1240, 300, 40, 150), "res://world/outside.tscn", Vector2(90, 360)
	)
	var gate_label: Label = Label.new()
	gate_label.text = "To the crystal fields >"
	gate_label.position = Vector2(1040, 270)
	gate_label.add_theme_font_size_override("font_size", 14)
	add_child(gate_label)


func _add_npc(pos: Vector2, color: Color, npc_name: String, lines: Array[String]) -> void:
	var body: ColorRect = add_rect(Rect2(pos - Vector2(12, 16), Vector2(24, 32)), color, 4)
	var tag: Label = Label.new()
	tag.text = npc_name
	tag.add_theme_font_size_override("font_size", 12)
	tag.position = pos + Vector2(-24, -38)
	tag.z_index = 4
	add_child(tag)
	add_wall(Rect2(body.position, body.size))
	add_interactable(pos, "Talk to the %s" % npc_name.to_lower(), func() -> void:
		show_dialog(lines))


func _on_save_crystal() -> void:
	var world: Node = get_node_or_null("/root/WorldState")
	if world == null or not world.in_world_run:
		show_dialog(["The crystal hums, but answers no one outside a true journey. (Start a run from the main menu.)"])
		return
	var result: Error = world.rest_and_save(scene_file_path)
	var sfx: Node = get_node_or_null("/root/SfxManager")
	if sfx != null:
		sfx.play("heal")
	if result == OK:
		show_dialog([
			"You rest beneath the crystal's glow. Darkness drains away; Resolve returns.",
			"Game saved.",
		])
	else:
		show_dialog(["The crystal flickers... saving failed (error %d)." % result])


func _on_merc_post() -> void:
	var world: Node = get_node_or_null("/root/WorldState")
	if world == null or not world.in_world_run:
		show_dialog(["The Lancer eyes you. 'Come back when the Church sanctions your road.'"])
		return
	world.merc_hired = not world.merc_hired
	if world.merc_hired:
		show_dialog([
			"Church Lancer: 'Coin's paid, pilgrim. My spear walks with you.'",
			"(The Church Lancer joins the party — slot five.)",
		])
	else:
		show_dialog(["Church Lancer: 'Wise or cruel, your call.' (The Lancer stays in town.)"])


func _on_shop() -> void:
	show_dialog([
		"Shopkeep: 'Stock's still on the wagon, friend. After the pilgrimage, maybe.'",
		"(The shop is a stub in this slice — items arrive with a later milestone.)",
	])
