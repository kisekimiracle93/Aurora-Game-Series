class_name CombatantToken
extends Node2D
## Grey-box battlefield visual for one combatant: colored rect + name + HP sliver.

const BODY_SIZE: Vector2 = Vector2(48, 64)

var combatant: BaseCombatant

var _body: ColorRect
var _hp_fill: ColorRect
var _guard_label: Label
var _flash_target: CanvasItem


## `face`: "right"/"left" turns the fighter toward the enemy line, using the
## profile frames from their walk set when one exists (party faces the foes,
## human foes face the party); beasts/boss art already glares the right way.
func setup(
	combatant_in: BaseCombatant, body_color: Color, size_scale: float = 1.0,
	face: String = ""
) -> void:
	combatant = combatant_in
	scale = Vector2(size_scale, size_scale)

	# Profile-facing walk frame first, then static art, else grey-box.
	var sprite: Node2D = null
	if face != "":
		var frames: SpriteFrames = AssetLibrary.walk_frames(combatant.display_name)
		if frames == null:
			# "Roadside Bandit 2" and friends share the base sheet.
			frames = AssetLibrary.walk_frames(combatant.display_name.rstrip("0123456789 "))
		if frames != null:
			var animated: AnimatedSprite2D = AnimatedSprite2D.new()
			animated.sprite_frames = frames
			animated.animation = "idle_" + face
			animated.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			animated.play()
			sprite = animated
			var frame_height: float = 48.0
			var frame_texture: Texture2D = frames.get_frame_texture("idle_" + face, 0)
			if frame_texture != null:
				frame_height = float(frame_texture.get_height())
			var animated_fit: float = maxf(1.0, round((BODY_SIZE.y * 1.4) / frame_height))
			animated.scale = Vector2(animated_fit, animated_fit)
			animated.position.y = (BODY_SIZE.y - frame_height * animated_fit) / 2.0
			add_child(animated)
	var art: Texture2D = AssetLibrary.texture("characters", combatant.display_name)
	if sprite == null and art != null:
		var still: Sprite2D = Sprite2D.new()
		still.texture = art
		still.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # crisp pixel art
		var height: float = float(art.get_height())
		if height > 0.0:
			# Integer upscale keeps pixels square; bottom-align with the old box.
			var fit: float = maxf(1.0, round((BODY_SIZE.y * 1.4) / height))
			still.scale = Vector2(fit, fit)
			still.position.y = (BODY_SIZE.y - height * fit) / 2.0
		add_child(still)
		sprite = still

	# Grounding shadow under the feet (sells "standing on the floor").
	var shadow: Node2D = Node2D.new()
	shadow.position = Vector2(0, BODY_SIZE.y / 2.0 + 4.0)
	shadow.draw.connect(func() -> void:
		shadow.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
		shadow.draw_circle(Vector2.ZERO, 28.0, Color(0.0, 0.0, 0.0, 0.38)))
	add_child(shadow)

	_body = ColorRect.new()
	_body.color = body_color
	_body.size = BODY_SIZE
	_body.position = -(BODY_SIZE / 2.0)
	_body.visible = sprite == null  # art replaces the grey-box rect
	add_child(_body)
	_flash_target = sprite if sprite != null else (_body as CanvasItem)

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


func _on_hp_changed(old_value: int, new_value: int) -> void:
	var ratio: float = clampf(float(new_value) / float(combatant.stats.max_hp()), 0.0, 1.0)
	_hp_fill.size.x = (BODY_SIZE.x + 4.0) * ratio
	_hp_fill.color = Color(0.85, 0.25, 0.2) if ratio < 0.3 else Color(0.3, 0.85, 0.35)
	if new_value < old_value:
		var tween: Tween = create_tween()
		_flash_target.modulate = Color(3.0, 3.0, 3.0)
		tween.tween_property(_flash_target, "modulate", Color.WHITE, 0.25)


func _on_died() -> void:
	rotation_degrees = 90.0
	modulate = Color(0.45, 0.45, 0.45, 0.8)
