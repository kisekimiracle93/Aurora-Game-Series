extends Node2D
## Grey-box fight picker: the M4 wolfpack skirmish or the M5 Frozen Shepherd.


func _ready() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.08, 0.09, 0.12)
	background.size = Vector2(1280, 720)
	add_child(background)

	var title: Label = Label.new()
	title.text = "GAME AURORA — VERTICAL SLICE"
	title.add_theme_font_size_override("font_size", 30)
	title.position = Vector2(0, 160)
	title.size = Vector2(1280, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var box: VBoxContainer = VBoxContainer.new()
	box.position = Vector2(490, 280)
	box.custom_minimum_size = Vector2(300, 0)
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	var wolves: Button = Button.new()
	wolves.text = "Skirmish — Wolves & Stag"
	wolves.pressed.connect(func() -> void: _start("wolfpack"))
	box.add_child(wolves)
	wolves.grab_focus()

	var boss: Button = Button.new()
	boss.text = "Boss — The Frozen Shepherd"
	boss.pressed.connect(func() -> void: _start("boss"))
	box.add_child(boss)

	var back: Button = Button.new()
	back.text = "< Main menu"
	back.pressed.connect(
		func() -> void: get_tree().change_scene_to_file("res://world/main_menu.tscn")
	)
	box.add_child(back)

	var hint: Label = Label.new()
	hint.text = "Pray passes a turn with no defense — handy for damage testing."
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(0.7, 0.7, 0.75)
	hint.position = Vector2(0, 430)
	hint.size = Vector2(1280, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)


func _start(roster: String) -> void:
	var scene_path: String = (
		"res://world/boss_test.tscn" if roster == "boss" else "res://world/battle_test.tscn"
	)
	get_tree().change_scene_to_file(scene_path)
