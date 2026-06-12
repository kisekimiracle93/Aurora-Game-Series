class_name PartyHUD
extends PanelContainer
## Bottom strip: one panel per party member with HP/Aether bars, Resolve
## (value + band), Darkness (heirs only), and the Echo gauge.

const BAND_COLORS: Dictionary = {
	MeterMath.ResolveBand.BROKEN: Color(0.9, 0.25, 0.2),
	MeterMath.ResolveBand.SHAKEN: Color(0.95, 0.6, 0.2),
	MeterMath.ResolveBand.NEUTRAL: Color(0.85, 0.85, 0.85),
	MeterMath.ResolveBand.STEADY: Color(0.55, 0.85, 1.0),
	MeterMath.ResolveBand.UNYIELDING: Color(0.55, 1.0, 0.6),
}

var _row: HBoxContainer
var _panels: Dictionary = {}  # BaseCombatant -> Dictionary of controls


func _ready() -> void:
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 10)
	add_child(_row)


func setup(party: Array[BaseCombatant]) -> void:
	for member: BaseCombatant in party:
		_panels[member] = _build_panel(member)
		member.stats.hp_changed.connect(func(_o: int, _n: int) -> void: _refresh(member))
		member.stats.aether_changed.connect(func(_o: int, _n: int) -> void: _refresh(member))
		member.meters.meter_changed.connect(
			func(_id: StringName, _o: float, _n: float) -> void: _refresh(member)
		)
		member.stats.died.connect(func() -> void: _refresh(member))
		_refresh(member)


func set_active(actor: BaseCombatant) -> void:
	for member: BaseCombatant in _panels:
		var controls: Dictionary = _panels[member]
		var panel: PanelContainer = controls["panel"]
		var is_active: bool = member == actor
		panel.self_modulate = Color(1.6, 1.5, 0.9) if is_active else Color.WHITE
		if is_active:
			panel.pivot_offset = panel.size / 2.0
			panel.scale = Vector2(1.05, 1.05)
			var pulse: Tween = panel.create_tween()
			pulse.tween_property(panel, "scale", Vector2.ONE, 0.22)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_panel(member: BaseCombatant) -> Dictionary:
	var controls: Dictionary = {}
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(242, 0)
	_row.add_child(panel)
	controls["panel"] = panel

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var name_label: Label = Label.new()
	name_label.add_theme_font_size_override("font_size", 15)
	box.add_child(name_label)
	controls["name"] = name_label

	controls["hp"] = _add_bar(box, "HP", Color(0.3, 0.85, 0.35))
	controls["aether"] = _add_bar(box, "AE", Color(0.35, 0.55, 1.0))
	controls["resolve"] = _add_bar(box, "RES", Color(0.85, 0.85, 0.85))
	controls["duty"] = _add_bar(box, "DUTY", Color(0.95, 0.78, 0.3))
	controls["burden"] = _add_bar(box, "BUR", Color(0.6, 0.45, 0.4))
	if member.is_heir():
		controls["darkness"] = _add_bar(box, "DRK", Color(0.65, 0.3, 0.9))
	controls["echo"] = _add_bar(box, "ECHO", Color(0.3, 0.9, 0.95))
	return controls


func _add_bar(parent: VBoxContainer, label_text: String, fill: Color) -> Dictionary:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var tag: Label = Label.new()
	tag.text = label_text
	tag.custom_minimum_size = Vector2(40, 0)
	tag.add_theme_font_size_override("font_size", 12)
	row.add_child(tag)
	var bar: ProgressBar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(105, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	bar.add_theme_stylebox_override("fill", style)
	row.add_child(bar)
	var value_label: Label = Label.new()
	value_label.add_theme_font_size_override("font_size", 12)
	row.add_child(value_label)
	return {"bar": bar, "value": value_label, "tag": tag}


func _refresh(member: BaseCombatant) -> void:
	var controls: Dictionary = _panels[member]
	var name_label: Label = controls["name"]
	var band: MeterMath.ResolveBand = member.meters.resolve_band()
	name_label.text = "%s  —  %s" % [member.display_name, MeterMath.band_name(band)]
	name_label.modulate = BAND_COLORS[band]
	if not member.is_alive():
		name_label.text = "%s  —  DOWN" % member.display_name
		name_label.modulate = Color(0.6, 0.6, 0.6)

	_set_bar(controls["hp"], member.stats.current_hp, member.stats.max_hp(), true)
	_set_bar(controls["aether"], member.stats.current_aether, member.stats.max_aether(), true)
	_set_bar(controls["resolve"], int(member.meters.resolve()), int(MeterMath.RESOLVE_MAX), true)
	_set_bar(controls["duty"], int(member.meters.duty()), int(MeterMath.DUTY_MAX), false)
	_set_bar(controls["burden"], int(member.meters.burden()), int(MeterMath.BURDEN_MAX), false)
	var burden_bar: ProgressBar = controls["burden"]["bar"]
	var burden_style: StyleBoxFlat = burden_bar.get_theme_stylebox("fill")
	burden_style.bg_color = (
		Color(0.95, 0.25, 0.2) if MeterMath.is_burden_dragging(member.meters.burden())
		else Color(0.6, 0.45, 0.4)
	)
	var resolve_bar: ProgressBar = controls["resolve"]["bar"]
	var fill_style: StyleBoxFlat = resolve_bar.get_theme_stylebox("fill")
	fill_style.bg_color = BAND_COLORS[band]
	if controls.has("darkness"):
		_set_bar(
			controls["darkness"], int(member.meters.darkness()), int(MeterMath.DARKNESS_MAX), true
		)
	_set_bar(controls["echo"], int(member.meters.echo()), int(EchoMath.ECHO_MAX), false)
	var echo_tag: Label = controls["echo"]["tag"]
	echo_tag.modulate = (
		Color(0.3, 0.9, 0.95) if member.meters.echo_ready() else Color(0.7, 0.7, 0.7)
	)


func _set_bar(bar_controls: Dictionary, value: int, max_value: int, show_max: bool) -> void:
	var bar: ProgressBar = bar_controls["bar"]
	bar.max_value = maxi(max_value, 1)  # merc has 0 Aether; avoid a 0-range bar
	bar.value = value
	var value_label: Label = bar_controls["value"]
	value_label.text = "%d/%d" % [value, max_value] if show_max else str(value)
