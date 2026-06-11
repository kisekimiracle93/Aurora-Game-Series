class_name SelectionArrow
extends Node2D
## Classic JRPG bouncing pointer: a downward chevron hovering over a combatant.
## Gold = whose turn it is; crimson = who you're about to target.

var _chevron: Polygon2D
var _elapsed: float = 0.0
var _anchor_y: float = 0.0


func _init(color: Color) -> void:
	z_index = 60
	_chevron = Polygon2D.new()
	_chevron.polygon = PackedVector2Array([
		Vector2(0, 12), Vector2(-11, -8), Vector2(-4, -8),
		Vector2(0, -1), Vector2(4, -8), Vector2(11, -8),
	])
	_chevron.color = color
	add_child(_chevron)
	var outline: Line2D = Line2D.new()
	outline.points = PackedVector2Array([
		Vector2(0, 12), Vector2(-11, -8), Vector2(-4, -8),
		Vector2(0, -1), Vector2(4, -8), Vector2(11, -8), Vector2(0, 12),
	])
	outline.width = 1.5
	outline.default_color = Color(0, 0, 0, 0.7)
	add_child(outline)
	visible = false


func _process(delta: float) -> void:
	_elapsed += delta
	position.y = _anchor_y + sin(_elapsed * 7.0) * 4.0


func point_at(global_pos: Vector2) -> void:
	position.x = global_pos.x
	_anchor_y = global_pos.y - 86.0
	position.y = _anchor_y
	visible = true


func hide_arrow() -> void:
	visible = false
