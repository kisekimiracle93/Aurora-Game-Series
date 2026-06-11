class_name DeclarationBanner
extends PanelContainer
## The stone narrator: a weathered slab that loudly declares each action —
## "B A S T I L — OATHFIRE STRIKE" — then crumbles away. Letterspaced caps on
## dark stone with chiseled edge lines for the old-monument feel.

var _actor_label: Label
var _deed_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(460, 0)
	position = Vector2(410, 150)
	z_index = 70
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0

	var stone: StyleBoxFlat = StyleBoxFlat.new()
	stone.bg_color = Color(0.10, 0.095, 0.085, 0.92)
	stone.border_color = Color(0.55, 0.5, 0.42, 0.9)
	stone.border_width_top = 2
	stone.border_width_bottom = 4
	stone.border_width_left = 1
	stone.border_width_right = 1
	stone.content_margin_left = 22.0
	stone.content_margin_right = 22.0
	stone.content_margin_top = 8.0
	stone.content_margin_bottom = 10.0
	add_theme_stylebox_override("panel", stone)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	add_child(box)

	_actor_label = Label.new()
	_actor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_actor_label.add_theme_font_size_override("font_size", 15)
	box.add_child(_actor_label)

	_deed_label = Label.new()
	_deed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deed_label.add_theme_font_size_override("font_size", 26)
	_deed_label.add_theme_constant_override("shadow_offset_x", 2)
	_deed_label.add_theme_constant_override("shadow_offset_y", 3)
	_deed_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	box.add_child(_deed_label)


## "Carve every letter": A T T A C K reads like an inscription.
static func _letterspace(text: String) -> String:
	var glyphs: PackedStringArray = PackedStringArray()
	for character: String in text.to_upper():
		glyphs.append(character)
	return " ".join(glyphs)


func declare(actor: BaseCombatant, ability: AbilityData) -> void:
	_actor_label.text = _letterspace(actor.display_name)
	_actor_label.modulate = (
		Color(0.95, 0.85, 0.55) if actor.is_player_controlled else Color(1.0, 0.5, 0.45)
	)
	var deed: String = ability.display_name.replace("Echo: ", "")
	_deed_label.text = _letterspace(deed)
	_deed_label.modulate = Color(0.93, 0.91, 0.85)
	reset_size()
	position.x = 640.0 - size.x / 2.0

	scale = Vector2(0.92, 0.92)
	pivot_offset = size / 2.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.18)
	tween.tween_property(self, "scale", Vector2.ONE, 0.22)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func dismiss() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
