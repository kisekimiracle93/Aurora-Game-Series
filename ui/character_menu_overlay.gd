class_name CharacterMenuOverlay
extends CanvasLayer
## The party ledger (C / gamepad Y in any world area): one stone card per
## member — class, element, full stat block, and every meter with its band
## and a plain-words description. Reads WorldState (world meters) + the
## character .tres files. Closes with the same key, B, or Esc.

const SHEETS: Array[Dictionary] = [
	{"path": "res://data/characters/bastil.tres", "blurb": "Firebound Warden — the shield that swears."},
	{"path": "res://data/characters/cavene.tres", "blurb": "Firebrand Inquisitor — truth, by flame."},
	{"path": "res://data/characters/jecht.tres", "blurb": "Icebound Heir — power that eats its bearer."},
	{"path": "res://data/characters/mati.tres", "blurb": "Icebound Heir — grace under the long snow."},
	{"path": "res://data/characters/merc_lancer.tres", "blurb": "Church Lancer — paid spear, honest work."},
]

## The known world, west to east (scene path -> label).
const MAP_CHAIN: Array[Dictionary] = [
	{"scene": "res://world/town.tscn", "label": "AETHERTOWN", "note": "castle · save"},
	{"scene": "res://world/forest.tscn", "label": "VERDANT PASS", "note": "forest · save"},
	{"scene": "res://world/outside.tscn", "label": "CRYSTAL FIELDS", "note": "ice · save"},
	{"scene": "res://world/dungeon.tscn", "label": "CRYSTAL SITE II", "note": "boss"},
]

var _cards_root: Control
var _map_root: Control
var _on_map_page: bool = false


func _ready() -> void:
	layer = 90
	var dimmer: ColorRect = ColorRect.new()
	dimmer.color = Color(0.02, 0.02, 0.04, 0.82)
	dimmer.size = Vector2(1280, 720)
	add_child(dimmer)

	var title: Label = Label.new()
	title.text = "T H E   P I L G R I M S"
	title.add_theme_font_size_override("font_size", 26)
	title.position = Vector2(0, 24)
	title.size = Vector2(1280, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var hint: Label = Label.new()
	hint.text = "[C / Y / Esc]  close      ·      [M]  world map"
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(0.7, 0.7, 0.75)
	hint.position = Vector2(0, 678)
	hint.size = Vector2(1280, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	_cards_root = Control.new()
	add_child(_cards_root)
	var row: HBoxContainer = HBoxContainer.new()
	row.position = Vector2(20, 80)
	row.add_theme_constant_override("separation", 8)
	_cards_root.add_child(row)

	var world: Node = get_node_or_null("/root/WorldState")
	for sheet: Dictionary in SHEETS:
		var data: CharacterData = load(String(sheet["path"]))
		if data.is_merc and (world == null or not world.merc_hired):
			continue
		row.add_child(_member_card(data, String(sheet["blurb"]), world))

	_map_root = Control.new()
	_map_root.visible = false
	add_child(_map_root)
	_build_map_page(world)


## --- the WIP world map (rough by design) ---------------------------------------


func _build_map_page(world: Node) -> void:
	var frame: PanelContainer = PanelContainer.new()
	frame.position = Vector2(140, 160)
	frame.custom_minimum_size = Vector2(1000, 360)
	_map_root.add_child(frame)
	var title: Label = Label.new()
	title.text = "THE PILGRIM ROAD  (surveyor's draft)"
	title.add_theme_font_size_override("font_size", 15)
	title.position = Vector2(150, 130)
	_map_root.add_child(title)

	var current: String = String(world.current_area) if world != null else ""
	var previous: String = String(world.previous_area) if world != null else ""
	for i: int in range(MAP_CHAIN.size()):
		var stop: Dictionary = MAP_CHAIN[i]
		var box: PanelContainer = PanelContainer.new()
		box.position = Vector2(190 + i * 240, 240)
		box.custom_minimum_size = Vector2(190, 130)
		_map_root.add_child(box)
		var stack: VBoxContainer = VBoxContainer.new()
		box.add_child(stack)
		var name_label: Label = Label.new()
		name_label.text = String(stop["label"])
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(name_label)
		var note: Label = Label.new()
		note.text = String(stop["note"])
		note.add_theme_font_size_override("font_size", 11)
		note.modulate = Color(0.7, 0.7, 0.65)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(note)
		var marker: Label = Label.new()
		marker.add_theme_font_size_override("font_size", 12)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(marker)
		if String(stop["scene"]) == current:
			marker.text = "✦ YOU ARE HERE"
			marker.modulate = Color(1.0, 0.85, 0.3)
			box.self_modulate = Color(1.35, 1.25, 0.9)
			var pulse: Tween = box.create_tween().set_loops()
			pulse.tween_property(box, "self_modulate", Color(1.15, 1.1, 0.85), 0.7)
			pulse.tween_property(box, "self_modulate", Color(1.35, 1.25, 0.9), 0.7)
		elif String(stop["scene"]) == previous:
			marker.text = "(came from)"
			marker.modulate = Color(0.65, 0.7, 0.8)
		# Road connector to the next stop.
		if i < MAP_CHAIN.size() - 1:
			var road: ColorRect = ColorRect.new()
			road.color = Color(0.7, 0.62, 0.5, 0.8)
			road.position = Vector2(190 + i * 240 + 190, 300)
			road.size = Vector2(50, 8)
			_map_root.add_child(road)
	# Branch scribbles: the parts a surveyor would pencil in.
	var scribble: Label = Label.new()
	scribble.text = "· pass branches: alpha clearing (N), smuggler's hollow (S)\n· two routes cross into the fields\n· the castle does not open"
	scribble.add_theme_font_size_override("font_size", 12)
	scribble.modulate = Color(0.66, 0.66, 0.6)
	scribble.position = Vector2(190, 400)
	_map_root.add_child(scribble)


func _toggle_map() -> void:
	_on_map_page = not _on_map_page
	_map_root.visible = _on_map_page
	_cards_root.visible = not _on_map_page


func _member_card(data: CharacterData, blurb: String, world: Node) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(242, 560)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)

	var portrait: TextureRect = TextureRect.new()
	var art: Texture2D = AssetLibrary.texture("characters", data.name)
	if art != null:
		portrait.texture = art
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.custom_minimum_size = Vector2(0, 72)
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(portrait)

	var name_label: Label = Label.new()
	name_label.text = data.name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	_small(box, "%s — %s" % [data.class_type, data.element], Color(0.8, 0.78, 0.7))
	_small(box, blurb, Color(0.65, 0.65, 0.7))
	box.add_child(HSeparator.new())

	for stat_name: String in [
		"hp", "aether", "power", "focus", "guard", "ward", "speed",
		"accuracy", "evasion", "crit",
	]:
		_stat_row(box, stat_name.to_upper(), str(int(data.base_stats.get(stat_name, 0))))
	box.add_child(HSeparator.new())

	if world != null and world.party_meters.has(data.name):
		var meters: Dictionary = world.party_meters[data.name]
		var resolve: float = float(meters.get("resolve", 60.0))
		var band: String = MeterMath.band_name(MeterMath.resolve_band(resolve))
		_stat_row(box, "RESOLVE", "%d  (%s)" % [int(resolve), band])
		_small(box, "Courage: speed, damage, defense.", Color(0.6, 0.6, 0.65))
		_stat_row(box, "DUTY", str(int(float(meters.get("duty", 50.0)))))
		_small(box, "Conviction: hits harder, echoes cheaper.", Color(0.6, 0.6, 0.65))
		var burden: float = float(meters.get("burden", 0.0))
		_stat_row(box, "BURDEN", str(int(burden)))
		_small(
			box,
			"Grief: drags speed%s." % (", LOCKS ECHO" if burden >= 80.0 else ""),
			Color(0.85, 0.4, 0.35) if burden >= 50.0 else Color(0.6, 0.6, 0.65)
		)
		if data.is_heir:
			_stat_row(box, "DARKNESS", str(int(float(meters.get("darkness", 0.0)))))
			_small(box, "Power's price: max HP, accuracy.", Color(0.7, 0.5, 0.85))
	return card


func _stat_row(parent: VBoxContainer, label_text: String, value: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var tag: Label = Label.new()
	tag.text = label_text
	tag.custom_minimum_size = Vector2(96, 0)
	tag.add_theme_font_size_override("font_size", 12)
	row.add_child(tag)
	var value_label: Label = Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.modulate = Color(0.95, 0.92, 0.85)
	row.add_child(value_label)


func _small(parent: VBoxContainer, text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = color
	parent.add_child(label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_M:
		get_viewport().set_input_as_handled()
		_toggle_map()
		return
	if event.is_action_pressed("char_menu") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _on_map_page:
			_toggle_map()  # the map closes back to the character menu, not out
			return
		queue_free()
