extends Node2D
## Title screen: black sky under a living aurora (emerald overtaken by evil red
## in cycles), a stormy castle silhouette with lightning, the Light's Edge
## title + communal-magic emblem, and Start / Playtest / Options / Quit.
## If assets/sprites/backgrounds/menu.png exists it underlays the aurora.

const SCREEN: Vector2 = Vector2(1280, 720)

var _flash: ColorRect
var _bolt: Line2D
var _lightning_timer: Timer
var _menu_box: VBoxContainer
var _playtest_panel: PanelContainer
var _options_panel: PanelContainer


func _ready() -> void:
	_build_sky()
	_build_castle()
	_build_lightning()
	_build_title()
	_build_menu()
	_build_playtest_panel()
	_build_options_panel()
	var music: Node = get_node_or_null("/root/MusicManager")
	if music != null:
		music.play_track("menu")
	var postfx: Node = get_node_or_null("/root/PostFX")
	if postfx != null:
		postfx.mood_menu()


# --- backdrop -----------------------------------------------------------------


func _build_sky() -> void:
	var night: ColorRect = ColorRect.new()
	night.color = Color(0.015, 0.015, 0.035)
	night.size = SCREEN
	add_child(night)

	var art: Texture2D = AssetLibrary.texture("backgrounds", "menu")
	if art != null:
		var image: TextureRect = TextureRect.new()
		image.texture = art
		image.size = SCREEN
		image.stretch_mode = TextureRect.STRETCH_SCALE
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		add_child(image)

	# Sprinkle of stars under the aurora.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in range(70):
		var star: ColorRect = ColorRect.new()
		star.color = Color(1, 1, 1, rng.randf_range(0.15, 0.5))
		star.size = Vector2.ONE * rng.randf_range(1.0, 2.5)
		star.position = Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 420))
		add_child(star)

	var aurora: ColorRect = ColorRect.new()
	aurora.size = SCREEN
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://ui/aurora_sky.gdshader")
	aurora.material = material
	add_child(aurora)


func _build_castle() -> void:
	if AssetLibrary.texture("backgrounds", "menu") != null:
		return  # real art replaces the procedural castle
	var silhouette: Polygon2D = Polygon2D.new()
	silhouette.color = Color(0.028, 0.028, 0.055)
	silhouette.polygon = _castle_points()
	add_child(silhouette)


## Stormy castle skyline: three crenellated towers joined by walls.
func _castle_points() -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var ground: float = 720.0
	points.append(Vector2(340, ground))
	points.append(Vector2(340, 560))
	points.append_array(_tower(360, 560, 90, 470))  # left tower
	points.append(Vector2(470, 560))
	points.append(Vector2(540, 560))
	points.append_array(_tower(560, 560, 120, 380))  # keep (tallest)
	points.append(Vector2(710, 560))
	points.append(Vector2(790, 560))
	points.append_array(_tower(800, 560, 90, 450))  # right tower
	points.append(Vector2(910, 560))
	points.append(Vector2(910, ground))
	return points


func _tower(x: float, base_y: float, width: float, top_y: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2(x, base_y))
	points.append(Vector2(x, top_y))
	var teeth: int = 4
	var tooth_width: float = width / float(teeth * 2 - 1)
	var cursor: float = x
	for i: int in range(teeth):
		points.append(Vector2(cursor, top_y - 16))
		points.append(Vector2(cursor + tooth_width, top_y - 16))
		points.append(Vector2(cursor + tooth_width, top_y))
		cursor += tooth_width * 2.0
		if i < teeth - 1:
			points.append(Vector2(cursor, top_y))
	points.append(Vector2(x + width, top_y))
	points.append(Vector2(x + width, base_y))
	return points


func _build_lightning() -> void:
	_flash = ColorRect.new()
	_flash.color = Color(0.9, 0.93, 1.0, 0.0)
	_flash.size = SCREEN
	add_child(_flash)

	_bolt = Line2D.new()
	_bolt.width = 3.0
	_bolt.default_color = Color(0.95, 0.97, 1.0, 0.0)
	add_child(_bolt)

	_lightning_timer = Timer.new()
	_lightning_timer.one_shot = true
	_lightning_timer.timeout.connect(_strike)
	add_child(_lightning_timer)
	_arm_lightning()


func _arm_lightning() -> void:
	_lightning_timer.start(randf_range(3.5, 9.0))


func _strike() -> void:
	var x: float = randf_range(380.0, 900.0)
	var points: PackedVector2Array = PackedVector2Array()
	var y: float = 0.0
	points.append(Vector2(x, y))
	while y < 520.0:
		y += randf_range(40.0, 90.0)
		x += randf_range(-45.0, 45.0)
		points.append(Vector2(x, minf(y, 540.0)))
	_bolt.points = points
	_bolt.default_color.a = 0.9
	_flash.color.a = 0.4
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_bolt, "default_color:a", 0.0, 0.35)
	tween.tween_property(_flash, "color:a", 0.0, 0.45)
	tween.chain().tween_callback(_arm_lightning)


# --- title & emblem -----------------------------------------------------------


func _build_title() -> void:
	var emblem: Control = Control.new()
	emblem.position = Vector2(640, 118)
	emblem.draw.connect(_draw_emblem.bind(emblem))
	add_child(emblem)

	var title: Label = Label.new()
	title.text = "LIGHT'S  EDGE"
	title.add_theme_font_size_override("font_size", 68)
	title.add_theme_color_override("font_color", Color(0.96, 0.96, 1.0))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title.position = Vector2(0, 168)
	title.size = Vector2(1280, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "—  Part I of the Aurora Series  —"
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.modulate = Color(0.75, 0.85, 0.8)
	subtitle.position = Vector2(0, 246)
	subtitle.size = Vector2(1280, 30)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)


## Communal-magic emblem: a pale sun ringed by twin serpents — one of emerald
## light, one of ember — circling each other (drawn, FF-logo spirit, grey-box).
func _draw_emblem(emblem: Control) -> void:
	emblem.draw_circle(Vector2.ZERO, 44.0, Color(0.95, 0.93, 0.82, 0.16))
	emblem.draw_circle(Vector2.ZERO, 34.0, Color(0.97, 0.95, 0.86, 0.30))
	emblem.draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 48, Color(0.9, 0.88, 0.75, 0.5), 1.5)
	var serpent_green: PackedVector2Array = PackedVector2Array()
	var serpent_red: PackedVector2Array = PackedVector2Array()
	for i: int in range(33):
		var angle: float = TAU * float(i) / 32.0
		var wave: float = sin(angle * 3.0) * 7.0
		var radius_a: float = 52.0 + wave
		var radius_b: float = 52.0 - wave
		serpent_green.append(Vector2(cos(angle), sin(angle)) * radius_a)
		serpent_red.append(Vector2(cos(angle + PI), sin(angle + PI)) * radius_b)
	emblem.draw_polyline(serpent_green, Color(0.2, 0.9, 0.55, 0.85), 3.0)
	emblem.draw_polyline(serpent_red, Color(0.85, 0.2, 0.18, 0.85), 3.0)
	# Serpent heads: small fangs where each coil crests.
	emblem.draw_circle(serpent_green[0], 4.5, Color(0.2, 0.95, 0.6))
	emblem.draw_circle(serpent_red[0], 4.5, Color(0.9, 0.25, 0.2))


# --- menus ----------------------------------------------------------------------


func _build_menu() -> void:
	_menu_box = VBoxContainer.new()
	_menu_box.position = Vector2(540, 380)
	_menu_box.custom_minimum_size = Vector2(200, 0)
	_menu_box.add_theme_constant_override("separation", 12)
	add_child(_menu_box)
	var world: Node = get_node_or_null("/root/WorldState")
	var start: Button = _menu_button("New Pilgrimage")
	start.pressed.connect(func() -> void:
		if world != null:
			world.start_new_run(get_tree())
		else:
			get_tree().change_scene_to_file("res://world/town.tscn"))
	start.grab_focus()
	if world != null and world.has_save():
		var resume: Button = _menu_button("Continue")
		resume.pressed.connect(func() -> void: world.continue_run(get_tree()))
	var playtest: Button = _menu_button("Playtest")
	playtest.pressed.connect(func() -> void: _toggle(_playtest_panel))
	var options: Button = _menu_button("Options")
	options.pressed.connect(func() -> void: _toggle(_options_panel))
	var quit: Button = _menu_button("Quit")
	quit.pressed.connect(func() -> void: get_tree().quit())


func _menu_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 22)
	button.mouse_entered.connect(func() -> void: _sfx("hover"))
	button.focus_entered.connect(func() -> void: _sfx("hover"))
	button.pressed.connect(func() -> void: _sfx("click"))
	_menu_box.add_child(button)
	return button


func _sfx(sfx_name: String) -> void:
	var sfx: Node = get_node_or_null("/root/SfxManager")
	if sfx != null:
		sfx.play(sfx_name)


func _toggle(panel: PanelContainer) -> void:
	var was_visible: bool = panel.visible
	_playtest_panel.visible = false
	_options_panel.visible = false
	panel.visible = not was_visible


## Jump-off points for testing: battles now, world spots as M6 lands.
func _build_playtest_panel() -> void:
	_playtest_panel = PanelContainer.new()
	_playtest_panel.position = Vector2(790, 380)
	_playtest_panel.custom_minimum_size = Vector2(280, 0)
	_playtest_panel.visible = false
	add_child(_playtest_panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_playtest_panel.add_child(box)
	var title: Label = Label.new()
	title.text = "PLAYTEST JUMP-OFFS"
	title.add_theme_font_size_override("font_size", 14)
	box.add_child(title)
	_jump_button(box, "Skirmish — Wolves & Stag", "res://world/battle_test.tscn")
	_jump_button(box, "Boss — The Frozen Shepherd", "res://world/boss_test.tscn")
	var spots: Label = Label.new()
	spots.text = "WORLD SPOTS (fresh run)"
	spots.add_theme_font_size_override("font_size", 12)
	spots.modulate = Color(0.7, 0.7, 0.75)
	box.add_child(spots)
	for spot: Array in [
		["Town — Aethertown", "res://world/town.tscn"],
		["Outside — Crystal Fields", "res://world/outside.tscn"],
		["Dungeon — Crystal Site", "res://world/dungeon.tscn"],
	]:
		var jump: Button = Button.new()
		jump.text = String(spot[0])
		jump.alignment = HORIZONTAL_ALIGNMENT_LEFT
		jump.pressed.connect(func() -> void:
			var world: Node = get_node_or_null("/root/WorldState")
			if world != null:
				world.start_run_at(get_tree(), String(spot[1]))
			else:
				get_tree().change_scene_to_file(String(spot[1])))
		box.add_child(jump)


func _jump_button(box: VBoxContainer, text: String, scene_path: String) -> void:
	var button: Button = Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(func() -> void: get_tree().change_scene_to_file(scene_path))
	box.add_child(button)


func _build_options_panel() -> void:
	_options_panel = PanelContainer.new()
	_options_panel.position = Vector2(790, 380)
	_options_panel.custom_minimum_size = Vector2(280, 0)
	_options_panel.visible = false
	add_child(_options_panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_options_panel.add_child(box)
	var title: Label = Label.new()
	title.text = "OPTIONS"
	title.add_theme_font_size_override("font_size", 14)
	box.add_child(title)

	box.add_child(_slider_row("Master volume", _master_volume_changed, 1.0))
	box.add_child(_slider_row("Music volume", _music_volume_changed, 0.8))
	box.add_child(_slider_row("SFX volume", _sfx_volume_changed, 0.9))

	var fullscreen: CheckButton = CheckButton.new()
	fullscreen.text = "Fullscreen"
	fullscreen.toggled.connect(func(on: bool) -> void:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
		))
	box.add_child(fullscreen)

	var blood: CheckButton = CheckButton.new()
	blood.text = "Blood & violence FX"
	blood.button_pressed = BattleFX.blood_enabled
	blood.toggled.connect(func(on: bool) -> void: BattleFX.blood_enabled = on)
	box.add_child(blood)


func _slider_row(label_text: String, handler: Callable, default_value: float) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 0)
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = default_value
	slider.custom_minimum_size = Vector2(130, 0)
	slider.value_changed.connect(handler)
	row.add_child(slider)
	return row


func _master_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(value, 0.0001, 1.0)))


func _music_volume_changed(value: float) -> void:
	var music: Node = get_node_or_null("/root/MusicManager")
	if music != null:
		music.set_music_volume_linear(value)


func _sfx_volume_changed(value: float) -> void:
	var sfx: Node = get_node_or_null("/root/SfxManager")
	if sfx != null:
		sfx.set_sfx_volume_linear(value)
		sfx.play("click")  # audible preview while sliding
