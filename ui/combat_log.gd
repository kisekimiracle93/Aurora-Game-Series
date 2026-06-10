class_name CombatLog
extends PanelContainer
## Scrolling battle text (last MAX_LINES lines).

const MAX_LINES: int = 8

var _label: RichTextLabel
var _lines: Array[String] = []


func _ready() -> void:
	custom_minimum_size = Vector2(540, 130)
	_label = RichTextLabel.new()
	_label.fit_content = false
	_label.scroll_active = false
	_label.add_theme_font_size_override("normal_font_size", 13)
	add_child(_label)


func append_line(text: String) -> void:
	_lines.append(text)
	while _lines.size() > MAX_LINES:
		_lines.pop_front()
	_label.text = "\n".join(_lines)
