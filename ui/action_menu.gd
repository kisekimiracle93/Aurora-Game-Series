class_name ActionMenu
extends PanelContainer
## The current actor's command menu. Emits the chosen AbilityData; the battle
## scene handles targeting. Unaffordable abilities are greyed out.

signal ability_chosen(ability: AbilityData)

var _box: VBoxContainer
var _title: Label


func _ready() -> void:
	custom_minimum_size = Vector2(220, 0)
	_box = VBoxContainer.new()
	add_child(_box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 14)
	_box.add_child(_title)
	visible = false


func open_for(actor: BaseCombatant) -> void:
	for child: Node in _box.get_children():
		if child != _title:
			child.queue_free()
	_title.text = "%s — choose action" % actor.display_name

	var attack: AbilityData = actor.abilities.find_by_id("attack_basic")
	if attack != null:
		_add_button(actor, attack)
	for skill: AbilityData in actor.abilities.get_skills():
		if skill.id != "guard":
			_add_button(actor, skill)
	for echo: AbilityData in actor.abilities.get_echoes():
		_add_button(actor, echo, not actor.meters.echo_ready())
	var guard: AbilityData = actor.abilities.find_by_id("guard")
	if guard != null:
		_add_button(actor, guard)

	visible = true
	var first_button: Button = _first_button()
	if first_button != null:
		first_button.grab_focus()


func close() -> void:
	visible = false


func _add_button(actor: BaseCombatant, ability: AbilityData, force_disabled: bool = false) -> void:
	var button: Button = Button.new()
	var cost_tag: String = "  (%d AE)" % ability.aether_cost if ability.aether_cost > 0 else ""
	button.text = ability.display_name + cost_tag
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.disabled = force_disabled or not actor.stats.can_spend_aether(ability.aether_cost)
	if actor.status.is_spell_blocked() and ability.ability_type == "spell":
		button.disabled = true
		button.text += "  [Silenced]"
	button.pressed.connect(func() -> void: ability_chosen.emit(ability))
	_box.add_child(button)


func _first_button() -> Button:
	for child: Node in _box.get_children():
		if child is Button and not (child as Button).disabled:
			return child as Button
	return null
