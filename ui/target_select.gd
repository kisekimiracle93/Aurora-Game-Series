class_name TargetSelect
extends PanelContainer
## Pick a target for the pending ability (or go back to the action menu).

signal target_chosen(target: BaseCombatant)
signal cancelled

var _box: VBoxContainer


func _ready() -> void:
	custom_minimum_size = Vector2(220, 0)
	_box = VBoxContainer.new()
	add_child(_box)
	visible = false


func open_for(candidates: Array[BaseCombatant]) -> void:
	for child: Node in _box.get_children():
		child.queue_free()
	var title: Label = Label.new()
	title.text = "Choose target"
	title.add_theme_font_size_override("font_size", 14)
	_box.add_child(title)
	var first: Button = null
	for candidate: BaseCombatant in candidates:
		var button: Button = Button.new()
		var hp_tag: String = " (%d/%d)" % [candidate.stats.current_hp, candidate.stats.max_hp()]
		button.text = candidate.display_name + hp_tag
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void: target_chosen.emit(candidate))
		_box.add_child(button)
		if first == null:
			first = button
	var back: Button = Button.new()
	back.text = "< Back"
	back.pressed.connect(func() -> void: cancelled.emit())
	_box.add_child(back)
	visible = true
	if first != null:
		first.grab_focus()


func close() -> void:
	visible = false
