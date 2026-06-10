class_name CombatantToken
extends Node2D
## Grey-box battlefield visual for one combatant: colored rect + name + HP sliver.

const BODY_SIZE: Vector2 = Vector2(48, 64)

var combatant: BaseCombatant

var _body: ColorRect
var _ring: ColorRect
var _hp_fill: ColorRect
var _guard_label: Label


func setup(combatant_in: BaseCombatant, body_color: Color) -> void:
	combatant = combatant_in

	_ring = ColorRect.new()
	_ring.color = Color(1.0, 0.9, 0.2, 0.9)
	_ring.size = BODY_SIZE + Vector2(10, 10)
	_ring.position = -(_ring.size / 2.0)
	_ring.visible = false
	add_child(_ring)

	_body = ColorRect.new()
	_body.color = body_color
	_body.size = BODY_SIZE
	_body.position = -(BODY_SIZE / 2.0)
	add_child(_body)

	var name_label: Label = Label.new()
	name_label.text = combatant.display_name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.position = Vector2(-BODY_SIZE.x, -BODY_SIZE.y / 2.0 - 24.0)
	name_label.size = Vector2(BODY_SIZE.x * 2.0, 18.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_label)

	var hp_bg: ColorRect = ColorRect.new()
	hp_bg.color = Color(0.15, 0.15, 0.15)
	hp_bg.size = Vector2(BODY_SIZE.x + 4.0, 6.0)
	hp_bg.position = Vector2(-(BODY_SIZE.x + 4.0) / 2.0, BODY_SIZE.y / 2.0 + 6.0)
	add_child(hp_bg)

	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.3, 0.85, 0.35)
	_hp_fill.size = Vector2(BODY_SIZE.x + 4.0, 6.0)
	_hp_fill.position = hp_bg.position
	add_child(_hp_fill)

	_guard_label = Label.new()
	_guard_label.text = "GUARD"
	_guard_label.add_theme_font_size_override("font_size", 11)
	_guard_label.modulate = Color(1.0, 0.9, 0.2)
	_guard_label.position = Vector2(-22.0, BODY_SIZE.y / 2.0 + 14.0)
	_guard_label.visible = false
	add_child(_guard_label)

	combatant.stats.hp_changed.connect(_on_hp_changed)
	combatant.stats.died.connect(_on_died)


func _process(_delta: float) -> void:
	if combatant != null:
		_guard_label.visible = combatant.is_guarding and combatant.is_alive()


func set_highlighted(on: bool) -> void:
	_ring.visible = on


func _on_hp_changed(old_value: int, new_value: int) -> void:
	var ratio: float = clampf(float(new_value) / float(combatant.stats.max_hp()), 0.0, 1.0)
	_hp_fill.size.x = (BODY_SIZE.x + 4.0) * ratio
	_hp_fill.color = Color(0.85, 0.25, 0.2) if ratio < 0.3 else Color(0.3, 0.85, 0.35)
	if new_value < old_value:
		var tween: Tween = create_tween()
		_body.modulate = Color(3.0, 3.0, 3.0)
		tween.tween_property(_body, "modulate", Color.WHITE, 0.25)


func _on_died() -> void:
	rotation_degrees = 90.0
	modulate = Color(0.45, 0.45, 0.45, 0.8)
	_ring.visible = false
