class_name TurnTimeline
extends PanelContainer
## Turn-order bar, old-Final-Fantasy style: a soft blue panel with a clean
## white border running horizontally across the top of the screen. Each
## upcoming turn is a chip — face, name, side-colored underline — with the
## current actor's chip lit gold and a touch larger.

const CHIP_FACE: float = 30.0


func _ready() -> void:
	# The FF blue: deep, soft, white-bordered, gently rounded.
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.14, 0.40, 0.92)
	style.border_color = Color(0.92, 0.94, 1.0, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", style)


func show_preview(preview: Array[BaseCombatant]) -> void:
	for child: Node in get_children():
		child.queue_free()
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	var lead: Label = Label.new()
	lead.text = "NEXT"
	lead.add_theme_font_size_override("font_size", 11)
	lead.modulate = Color(0.75, 0.82, 1.0)
	lead.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lead)
	for i: int in range(mini(preview.size(), 7)):
		var combatant: BaseCombatant = preview[i]
		row.add_child(_chip(combatant, i == 0))
	# Keep the bar centered across the top however many chips it holds.
	await get_tree().process_frame
	if is_inside_tree():
		reset_size()
		position.x = (1280.0 - size.x) / 2.0


func _chip(combatant: BaseCombatant, current: bool) -> VBoxContainer:
	var chip: VBoxContainer = VBoxContainer.new()
	chip.add_theme_constant_override("separation", 1)
	var face_size: float = CHIP_FACE * (1.25 if current else 1.0)
	var art: Texture2D = AssetLibrary.texture(
		"characters", combatant.display_name.rstrip("0123456789 ")
	)
	if art != null:
		var face: TextureRect = TextureRect.new()
		face.texture = art
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.custom_minimum_size = Vector2(face_size, face_size)
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if not current:
			face.modulate = Color(0.85, 0.85, 0.9)
		chip.add_child(face)
	var name_label: Label = Label.new()
	name_label.text = combatant.display_name
	name_label.add_theme_font_size_override("font_size", 10 if not current else 11)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.modulate = (
		Color(1.0, 0.92, 0.45) if current
		else (Color(0.78, 0.88, 1.0) if combatant.is_player_controlled else Color(1.0, 0.66, 0.6))
	)
	chip.add_child(name_label)
	var underline: ColorRect = ColorRect.new()
	underline.custom_minimum_size = Vector2(0, 2)
	underline.color = (
		Color(1.0, 0.85, 0.25) if current
		else (Color(0.45, 0.65, 1.0, 0.8) if combatant.is_player_controlled else Color(0.9, 0.4, 0.35, 0.8))
	)
	chip.add_child(underline)
	return chip
