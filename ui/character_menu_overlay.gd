class_name CharacterMenuOverlay
extends CanvasLayer
## The in-game menu (C / gamepad Y in any world area). Opens on a front page:
## the real entries (Party, World Map, Game Guide, Quit) beside the greyed
## promises (Equipment, Sphere Grid, Options) — plus the party condition
## tracker reading everyone's heart off the meters. Esc/C from any sub-page
## returns HERE; Esc/C from here closes. [M] hops straight to the map.

const SHEETS: Array[Dictionary] = [
	{"path": "res://data/characters/bastil.tres", "blurb": "Firebound Warden — the shield that swears."},
	{"path": "res://data/characters/cavene.tres", "blurb": "Firebrand Inquisitor — truth, by flame."},
	{"path": "res://data/characters/jecht.tres", "blurb": "Icebound Heir — power that eats its bearer."},
	{"path": "res://data/characters/mati.tres", "blurb": "Icebound Heir — grace under the long snow."},
	{"path": "res://data/characters/tarnaie.tres", "blurb": "Priestess of Selene — a borrowed name, a chosen gentleness."},
	{"path": "res://data/characters/merc_lancer.tres", "blurb": "Church Lancer — paid spear, honest work."},
]

## The known world, west to east (scene path -> label).
const MAP_CHAIN: Array[Dictionary] = [
	{"scene": "res://world/town.tscn", "label": "SELENORA", "note": "castle · save"},
	{"scene": "res://world/forest.tscn", "label": "VERDANT PASS", "note": "forest · save"},
	{"scene": "res://world/deep_woods.tscn", "label": "SELINORAN DEEP", "note": "rain · predator"},
	{"scene": "res://world/outside.tscn", "label": "CRYSTAL FIELDS", "note": "ice · save"},
	{"scene": "res://world/dungeon.tscn", "label": "CRYSTAL SITE II", "note": "boss"},
]

var _menu_root: Control
var _cards_root: Control
var _map_root: Control
var _guide_root: Control
var _page: String = "menu"
## Back-compat for the map toggle shortcut/tests.
var _on_map_page: bool = false

var _world: Node


func _ready() -> void:
	layer = 90
	_world = get_node_or_null("/root/WorldState")
	var dimmer: ColorRect = ColorRect.new()
	dimmer.color = Color(0.02, 0.02, 0.04, 0.85)
	dimmer.size = Vector2(1280, 720)
	add_child(dimmer)

	var title: Label = Label.new()
	title.text = "T H E   P I L G R I M A G E"
	title.add_theme_font_size_override("font_size", 26)
	title.position = Vector2(0, 22)
	title.size = Vector2(1280, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var hint: Label = Label.new()
	hint.text = "[C / Y / Esc]  back · close      ·      [M]  world map"
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(0.7, 0.7, 0.75)
	hint.position = Vector2(0, 684)
	hint.size = Vector2(1280, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	_menu_root = Control.new()
	add_child(_menu_root)
	_build_menu_page()

	_cards_root = Control.new()
	_cards_root.visible = false
	add_child(_cards_root)
	var row: HBoxContainer = HBoxContainer.new()
	row.position = Vector2(20, 80)
	row.add_theme_constant_override("separation", 8)
	_cards_root.add_child(row)
	for sheet: Dictionary in SHEETS:
		var data: CharacterData = load(String(sheet["path"]))
		if data.is_merc and (_world == null or not _world.merc_hired):
			continue
		row.add_child(_member_card(data, String(sheet["blurb"]), _world))

	_map_root = Control.new()
	_map_root.visible = false
	add_child(_map_root)
	_build_map_page(_world)

	_guide_root = Control.new()
	_guide_root.visible = false
	add_child(_guide_root)
	_build_guide_page()


## --- the front page: entries + the condition tracker ---------------------------


func _build_menu_page() -> void:
	var entries: VBoxContainer = VBoxContainer.new()
	entries.position = Vector2(120, 110)
	entries.custom_minimum_size = Vector2(330, 0)
	entries.add_theme_constant_override("separation", 8)
	_menu_root.add_child(entries)
	var first: Button = null
	for entry: Array in [
		["PARTY", true, func() -> void: _show_page("party")],
		["WORLD MAP", true, func() -> void: _show_page("map")],
		["GAME GUIDE — how to play", true, func() -> void: _show_page("guide")],
		["EQUIPMENT", false, Callable()],
		["SPHERE GRID", false, Callable()],
		["OPTIONS", false, Callable()],
		["QUIT TO TITLE", true, func() -> void:
			get_tree().change_scene_to_file("res://world/main_menu.tscn")],
	]:
		var button: Button = Button.new()
		button.text = String(entry[0])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 17)
		if bool(entry[1]):
			button.pressed.connect(entry[2])
			if first == null:
				first = button
		else:
			button.disabled = true
			button.text += "   (not yet built)"
			button.modulate = Color(1, 1, 1, 0.45)
		entries.add_child(button)
	if first != null:
		first.grab_focus()

	# The condition tracker: the meters, read back as hearts.
	var tracker: PanelContainer = PanelContainer.new()
	tracker.position = Vector2(540, 110)
	tracker.custom_minimum_size = Vector2(620, 0)
	_menu_root.add_child(tracker)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	tracker.add_child(stack)
	var header: Label = Label.new()
	header.text = "THE PARTY'S CONDITION"
	header.add_theme_font_size_override("font_size", 15)
	header.modulate = Color(0.85, 0.8, 0.68)
	stack.add_child(header)
	var meters_by_name: Dictionary = _world.party_meters if _world != null else {}
	var party_line: Label = Label.new()
	party_line.text = PartyMood.party_state(meters_by_name)
	party_line.add_theme_font_size_override("font_size", 19)
	party_line.modulate = Color(0.95, 0.93, 0.85)
	stack.add_child(party_line)
	stack.add_child(HSeparator.new())
	for sheet: Dictionary in SHEETS:
		var data: CharacterData = load(String(sheet["path"]))
		if data.is_merc and (_world == null or not _world.merc_hired):
			continue
		if not meters_by_name.has(data.name):
			continue
		var meters: Dictionary = meters_by_name[data.name]
		var state: String = PartyMood.member_state(
			float(meters.get("resolve", 60.0)), float(meters.get("duty", 50.0)),
			float(meters.get("burden", 0.0)), float(meters.get("darkness", 0.0)),
			data.is_heir
		)
		var line: HBoxContainer = HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		stack.add_child(line)
		var dot: Label = Label.new()
		dot.text = "●"
		dot.modulate = PartyMood.state_color(state)
		line.add_child(dot)
		var who: Label = Label.new()
		who.text = "%s is %s." % [data.name, state]
		who.add_theme_font_size_override("font_size", 14)
		line.add_child(who)
		var numbers: Label = Label.new()
		numbers.text = "   RES %d · DUTY %d · BUR %d%s" % [
			int(float(meters.get("resolve", 60.0))), int(float(meters.get("duty", 50.0))),
			int(float(meters.get("burden", 0.0))),
			(" · DRK %d" % int(float(meters.get("darkness", 0.0)))) if data.is_heir else "",
		]
		numbers.add_theme_font_size_override("font_size", 11)
		numbers.modulate = Color(0.6, 0.6, 0.62)
		line.add_child(numbers)
		# Who they ARE, in one breath (the owner asked the menu to say it).
		var who_blurb: Label = Label.new()
		who_blurb.text = "      " + String(sheet["blurb"])
		who_blurb.add_theme_font_size_override("font_size", 10)
		who_blurb.modulate = Color(0.52, 0.52, 0.56)
		stack.add_child(who_blurb)
	stack.add_child(HSeparator.new())
	var footnote: Label = Label.new()
	footnote.text = "(WIP reading: courage carries, conviction steadies, grief and the dark drag.)"
	footnote.add_theme_font_size_override("font_size", 10)
	footnote.modulate = Color(0.55, 0.55, 0.58)
	stack.add_child(footnote)


func _show_page(page: String) -> void:
	_page = page
	_on_map_page = page == "map"
	_menu_root.visible = page == "menu"
	_cards_root.visible = page == "party"
	_map_root.visible = page == "map"
	_guide_root.visible = page == "guide"


## [M] shortcut: hop to the map, or from the map back to the menu.
func _toggle_map() -> void:
	_show_page("menu" if _on_map_page else "map")


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
		box.position = Vector2(165 + i * 196, 240)
		box.custom_minimum_size = Vector2(160, 130)
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
			road.position = Vector2(165 + i * 196 + 160, 300)
			road.size = Vector2(36, 8)
			_map_root.add_child(road)
	# Branch scribbles: the parts a surveyor would pencil in.
	var scribble: Label = Label.new()
	scribble.text = "· pass branches: alpha clearing (N), smuggler's hollow (S)\n· two routes cross into the fields\n· the castle does not open"
	scribble.add_theme_font_size_override("font_size", 12)
	scribble.modulate = Color(0.66, 0.66, 0.6)
	scribble.position = Vector2(190, 400)
	_map_root.add_child(scribble)


## --- the game guide ---------------------------------------------------------------


const GUIDE_TEXT: String = """THE METERS — what the bars mean
RESOLVE (white) — courage. High Resolve quickens the heart: better speed,
  damage, and defense. It rises with victories and brave choices, falls with
  defeats and retreats. Bands: Shaken · Wavering · Neutral · Bold · Valiant.
DUTY (gold) — conviction. High Duty lands harder blows and makes Echoes
  cheaper to call. Earned by keeping faith with the Church's charge.
BURDEN (red) — grief carried. At 50+ it drags your turns (slower CT);
  at 80+ it LOCKS the Echo entirely. Resting at a save crystal eases it.
DARKNESS (violet, Heirs only) — power's price. Heir magic feeds it; it eats
  max HP and accuracy, and at the brink it can force a collapse. Drains to
  zero when you rest.
ECHO (cyan) — the gauge fills as a fighter deals and takes blows. Full gauge
  = one Echo: a memory made weapon.
AETHER (blue) — spell fuel. Draughts and rest restore it.

HOW TO PLAY — the world
Move: WASD / arrows / left stick.    Interact: E / Enter / gamepad A.
Menu: C / gamepad Y.    World map: M (inside the menu).
Run: G toggles a sprint.    Lantern: T raises a warm light for the night.
Lead: Tab cycles who walks point (any of the five pilgrims).
Save crystals: rest to drain Darkness, lift Resolve, ease Burden — and save.
Foes patrol in the open: they chase only so far before returning. Pick your
fights — or run past them.
Selenora's gate opens only after FIVE farewells — talk to the town before
the road. And at Crystal Site II, the memory crystal holds a lost Echo.

HOW TO PLAY — battle
Turn order runs on speed (the timeline shows who's next). Arrows / stick
navigate any menu; Enter / A confirms; Esc / B backs out.
Magic, Skills, and Items live in folders; Attack, Guard, and Pray sit on top.
Guard halves the hurt until your next turn. Pray does nothing — loudly.
Debug hatches: ✓ win fight [Y] · ✕ end fight (no rewards, no penalty).

THE ROAD
Aethertown (castle · save) → the Verdant Pass (forest · save · branches) →
the Crystal Fields (ice · save) → Aether Crystal Site II (the Shepherd).
"""


func _build_guide_page() -> void:
	var frame: PanelContainer = PanelContainer.new()
	frame.position = Vector2(140, 80)
	frame.custom_minimum_size = Vector2(1000, 560)
	_guide_root.add_child(frame)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1000, 560)
	frame.add_child(scroll)
	var body: Label = Label.new()
	body.text = GUIDE_TEXT
	body.add_theme_font_size_override("font_size", 13)
	body.custom_minimum_size = Vector2(960, 0)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(body)


## --- the party cards ---------------------------------------------------------------


func _member_card(data: CharacterData, blurb: String, world: Node) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(242, 560)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	card.add_child(box)

	# Portrait row: the face (front-on now) beside name + class.
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	var portrait: TextureRect = TextureRect.new()
	var art: Texture2D = AssetLibrary.texture("characters", data.name)
	if art != null:
		portrait.texture = art
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.custom_minimum_size = Vector2(64, 84)
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(portrait)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(titles)
	var name_label: Label = Label.new()
	name_label.text = data.name
	name_label.add_theme_font_size_override("font_size", 19)
	titles.add_child(name_label)
	var class_label: Label = Label.new()
	class_label.text = "%s — %s" % [data.class_type, data.element]
	class_label.add_theme_font_size_override("font_size", 11)
	class_label.modulate = Color(0.8, 0.78, 0.7)
	titles.add_child(class_label)
	_small(box, blurb, Color(0.65, 0.65, 0.7))
	box.add_child(HSeparator.new())

	# Stats in a tight two-column grid — half the scanning.
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 3)
	box.add_child(grid)
	for stat_name: String in [
		"hp", "aether", "power", "focus", "guard", "ward", "speed",
		"accuracy", "evasion", "crit",
	]:
		var tag: Label = Label.new()
		tag.text = stat_name.to_upper()
		tag.add_theme_font_size_override("font_size", 11)
		tag.modulate = Color(0.7, 0.7, 0.72)
		grid.add_child(tag)
		var value_label: Label = Label.new()
		value_label.text = str(int(data.base_stats.get(stat_name, 0)))
		value_label.add_theme_font_size_override("font_size", 11)
		value_label.modulate = Color(0.95, 0.92, 0.85)
		grid.add_child(value_label)
	box.add_child(HSeparator.new())

	if world != null and world.party_meters.has(data.name):
		var meters: Dictionary = world.party_meters[data.name]
		var resolve: float = float(meters.get("resolve", 60.0))
		var band: String = MeterMath.band_name(MeterMath.resolve_band(resolve))
		_meter_bar(box, "RESOLVE  %d (%s)" % [int(resolve), band], resolve / 120.0,
			Color(0.92, 0.93, 0.97))
		_meter_bar(box, "DUTY  %d" % int(float(meters.get("duty", 50.0))),
			float(meters.get("duty", 50.0)) / 120.0, Color(0.95, 0.8, 0.3))
		var burden: float = float(meters.get("burden", 0.0))
		_meter_bar(box, "BURDEN  %d%s" % [int(burden), "  · LOCKS ECHO" if burden >= 80.0 else ""],
			burden / 100.0, Color(0.9, 0.4, 0.35))
		if data.is_heir:
			_meter_bar(box, "DARKNESS  %d" % int(float(meters.get("darkness", 0.0))),
				float(meters.get("darkness", 0.0)) / 100.0, Color(0.7, 0.5, 0.9))
		var state: String = PartyMood.member_state(
			resolve, float(meters.get("duty", 50.0)), burden,
			float(meters.get("darkness", 0.0)), data.is_heir
		)
		var mood: Label = Label.new()
		mood.text = "— %s —" % state
		mood.add_theme_font_size_override("font_size", 12)
		mood.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mood.modulate = PartyMood.state_color(state)
		box.add_child(mood)
	return card


## A labeled meter with a slim color bar under it — read at a glance.
func _meter_bar(parent: VBoxContainer, label_text: String, fraction: float, color: Color) -> void:
	var tag: Label = Label.new()
	tag.text = label_text
	tag.add_theme_font_size_override("font_size", 11)
	parent.add_child(tag)
	var track: ColorRect = ColorRect.new()
	track.color = Color(0.1, 0.1, 0.12, 0.9)
	track.custom_minimum_size = Vector2(0, 7)
	parent.add_child(track)
	var fill: ColorRect = ColorRect.new()
	fill.color = color
	fill.position = Vector2(1, 1)
	fill.size = Vector2(maxf(218.0 * clampf(fraction, 0.0, 1.0), 2.0), 5)
	track.add_child(fill)


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
		if _page != "menu":
			_show_page("menu")  # sub-pages fall back to the menu, not out of it
			return
		queue_free()
