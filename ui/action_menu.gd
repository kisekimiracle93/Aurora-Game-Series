class_name ActionMenu
extends PanelContainer
## FF-style command menu: a compact root (Attack / Magic / Skills / Items /
## Echo / Guard / Pray) where Magic, Skills, and Items open as sub-folders
## with a Back entry. Fully keyboard/controller drivable (focus + ui_up/down,
## which also answer to WASD). Unaffordable entries grey out.

signal ability_chosen(ability: AbilityData)
signal button_hovered
signal page_changed  # folders open/close: the scene re-anchors the panel

var _on_root: bool = true

const ITEM_IDS: Array[String] = ["item_hp_potion", "item_aether_draught"]

var _box: VBoxContainer
var _title: Label
var _actor: BaseCombatant


func _ready() -> void:
	custom_minimum_size = Vector2(230, 0)
	_box = VBoxContainer.new()
	add_child(_box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 14)
	_box.add_child(_title)
	visible = false


func open_for(actor: BaseCombatant) -> void:
	_actor = actor
	_show_root()
	visible = true
	pivot_offset = Vector2(0, size.y)
	scale = Vector2(0.94, 0.94)
	var pop: Tween = create_tween()
	pop.tween_property(self, "scale", Vector2.ONE, 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and not _on_root and event.is_action_pressed("ui_cancel"):
		_show_root()
		get_viewport().set_input_as_handled()


## --- menu pages ----------------------------------------------------------------


func _show_root() -> void:
	_on_root = true
	_clear()
	_title.text = "%s — choose action" % _actor.display_name

	var attack: AbilityData = _actor.abilities.find_by_id("attack_basic")
	if attack != null:
		_ability_button(attack)
	if not _magic_list().is_empty():
		_folder_button("Magic  ▸", _show_magic)
	if not _skill_list().is_empty():
		_folder_button("Skills  ▸", _show_skills)
	if _has_items():
		_folder_button("Items  ▸", _show_items)
	for echo: AbilityData in _actor.abilities.get_echoes():
		var locked: bool = (
			not _actor.meters.echo_ready()
			or MeterMath.is_echo_locked_by_burden(_actor.burden_for_math())
		)
		_ability_button(echo, locked)
	var guard: AbilityData = _actor.abilities.find_by_id("guard")
	if guard != null:
		_ability_button(guard)
	var pray: AbilityData = _actor.abilities.find_by_id("pray")
	if pray != null:
		_ability_button(pray)
	_focus_first()
	page_changed.emit()


func _show_magic() -> void:
	_on_root = false
	_clear()
	_title.text = "%s — magic" % _actor.display_name
	for spell: AbilityData in _magic_list():
		_ability_button(spell)
	_back_button()
	_focus_first()
	page_changed.emit()


func _show_skills() -> void:
	_on_root = false
	_clear()
	_title.text = "%s — skills" % _actor.display_name
	for skill: AbilityData in _skill_list():
		_ability_button(skill)
	_back_button()
	_focus_first()
	page_changed.emit()


func _show_items() -> void:
	_on_root = false
	_clear()
	_title.text = "%s — items" % _actor.display_name
	var world: Node = get_node_or_null("/root/WorldState")
	for item_id: String in ITEM_IDS:
		var count: int = world.item_count(item_id) if world != null else 0
		if count <= 0:
			continue
		var item: AbilityData = AbilityLibrary.load_ability(item_id)
		if item == null:
			continue
		var button: Button = _make_button("%s  ×%d" % [item.display_name, count])
		button.pressed.connect(func() -> void: ability_chosen.emit(item))
	_back_button()
	_focus_first()
	page_changed.emit()


## --- categorization --------------------------------------------------------------


## Spells and battle-supports (heals, rallies) live under Magic, FF-style.
func _magic_list() -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	for ability: AbilityData in _actor.abilities.get_all():
		if ability.is_item or ability.id in ["guard", "pray"]:
			continue
		if ability.ability_type == "spell" or ability.ability_type == "support":
			result.append(ability)
	return result


## Weapon arts: physical techniques beyond the basic swing.
func _skill_list() -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	for ability: AbilityData in _actor.abilities.get_all():
		if ability.ability_type == "attack" and ability.id != "attack_basic":
			result.append(ability)
	return result


func _has_items() -> bool:
	var world: Node = get_node_or_null("/root/WorldState")
	if world == null or not world.in_world_run:
		return false
	for item_id: String in ITEM_IDS:
		if world.item_count(item_id) > 0:
			return true
	return false


## --- widgets ----------------------------------------------------------------------


func _clear() -> void:
	for child: Node in _box.get_children():
		if child != _title:
			child.queue_free()


func _make_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_entered.connect(func() -> void: button_hovered.emit())
	button.focus_entered.connect(func() -> void: button_hovered.emit())
	_box.add_child(button)
	return button


var _description_label: Label


func _ability_button(ability: AbilityData, force_disabled: bool = false) -> void:
	var cost_tag: String = "  (%d AE)" % ability.aether_cost if ability.aether_cost > 0 else ""
	var button: Button = _make_button(ability.display_name + cost_tag)
	button.disabled = force_disabled or not _actor.stats.can_spend_aether(ability.aether_cost)
	if _actor.status.is_spell_blocked() and ability.ability_type == "spell":
		button.disabled = true
		button.text += "  [Silenced]"
	# What it IS: clue-bearing item text and ability flavor surface here.
	if ability.description != "":
		button.tooltip_text = ability.description
		button.mouse_entered.connect(func() -> void: _show_description(ability.description))
		button.focus_entered.connect(func() -> void: _show_description(ability.description))
	button.pressed.connect(func() -> void: ability_chosen.emit(ability))


## A parchment strip floating above the menu: the hovered entry, explained.
func _show_description(text: String) -> void:
	if _description_label == null or not is_instance_valid(_description_label):
		_description_label = Label.new()
		_description_label.add_theme_font_size_override("font_size", 11)
		_description_label.modulate = Color(0.85, 0.83, 0.72)
		_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_description_label.custom_minimum_size = Vector2(260, 0)
		add_child(_description_label)
	_description_label.position = Vector2(6, -54)
	_description_label.text = text


func _folder_button(text: String, opener: Callable) -> void:
	var button: Button = _make_button(text)
	button.pressed.connect(func() -> void:
		button_hovered.emit()  # audible page-turn
		opener.call())


func _back_button() -> void:
	var button: Button = _make_button("<  Back")
	button.pressed.connect(_show_root)


func _focus_first() -> void:
	await get_tree().process_frame  # let queued frees settle before focusing
	for child: Node in _box.get_children():
		if child is Button and not (child as Button).disabled:
			(child as Button).grab_focus()
			return
