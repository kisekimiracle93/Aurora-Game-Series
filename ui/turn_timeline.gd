class_name TurnTimeline
extends PanelContainer
## Turn-order preview: the next N actors, color-coded by side.

var _list: VBoxContainer


func _ready() -> void:
	custom_minimum_size = Vector2(170, 0)
	var root: VBoxContainer = VBoxContainer.new()
	add_child(root)
	var title: Label = Label.new()
	title.text = "NEXT TURNS"
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(0.8, 0.8, 0.9)
	root.add_child(title)
	_list = VBoxContainer.new()
	root.add_child(_list)


func show_preview(preview: Array[BaseCombatant]) -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	for i: int in range(preview.size()):
		var combatant: BaseCombatant = preview[i]
		var entry: Label = Label.new()
		entry.text = "%d. %s" % [i + 1, combatant.display_name]
		entry.add_theme_font_size_override("font_size", 13)
		if combatant.is_player_controlled:
			entry.modulate = Color(0.75, 0.9, 1.0)
		else:
			entry.modulate = Color(1.0, 0.6, 0.55)
		if i == 0:
			entry.modulate = Color(1.0, 0.95, 0.4)
		_list.add_child(entry)
