class_name PlayerAvatar
extends CharacterBody2D
## Top-down walker for town/overworld/dungeon. Arrow keys / WASD / left stick.
## [G] toggles a run; [T] raises an unseen lantern (pure warm light around you
## — it earns its keep after dark). Emits walked distance for encounter rolls.

signal stepped(distance: float)

const WALK_SPEED: float = 230.0
const RUN_SPEED: float = 352.0

var running: bool = false
var lantern_lit: bool = false

var _sprite_set: bool = false
var _lantern: PointLight2D
var _dust_timer: float = 0.0


func _ready() -> void:
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(26, 30)
	shape.shape = rect
	add_child(shape)

	var art: Texture2D = AssetLibrary.texture("characters", "Bastil")
	if WalkerSprite.attach(self, "Bastil", 2.0):
		_sprite_set = true
	elif art != null:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = art
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(2.0, 2.0)
		add_child(sprite)
		_sprite_set = true
	else:
		var body: ColorRect = ColorRect.new()
		body.color = Color(0.35, 0.55, 0.9)
		body.size = Vector2(28, 36)
		body.position = Vector2(-14, -18)
		add_child(body)

	var shadow: Node2D = Node2D.new()
	shadow.position = Vector2(0, 26)
	shadow.draw.connect(func() -> void:
		shadow.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
		shadow.draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.35)))
	add_child(shadow)

	# The carried lantern: implied, not drawn — just the bloom it throws.
	_lantern = PointLight2D.new()
	_lantern.texture = load("res://assets/sprites/ui/light_radial.png")
	_lantern.position = Vector2(6, -6)
	_lantern.color = Color(1.0, 0.78, 0.42)
	_lantern.energy = 0.0
	_lantern.texture_scale = 2.3
	_lantern.shadow_enabled = true
	add_child(_lantern)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("run_toggle"):
		running = not running
	elif event.is_action_pressed("lantern"):
		lantern_lit = not lantern_lit
		var tween: Tween = _lantern.create_tween()
		tween.tween_property(_lantern, "energy", 1.4 if lantern_lit else 0.0, 0.5)
		var sfx: Node = get_node_or_null("/root/SfxManager")
		if sfx != null:
			sfx.play("hover")


func _physics_process(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * (RUN_SPEED if running else WALK_SPEED)
	move_and_slide()
	if velocity.length() > 1.0:
		stepped.emit(velocity.length() * delta)
		if running:
			_dust_timer -= delta
			if _dust_timer <= 0.0:
				_dust_timer = 0.16
				_kick_dust()


## A little heel-kick puff when sprinting: speed you can see.
func _kick_dust() -> void:
	var puff: CPUParticles2D = CPUParticles2D.new()
	puff.position = position + Vector2(0, 22)
	puff.one_shot = true
	puff.emitting = true
	puff.amount = 4
	puff.lifetime = 0.45
	puff.spread = 60.0
	puff.direction = Vector2(0, -0.4)
	puff.initial_velocity_min = 8.0
	puff.initial_velocity_max = 26.0
	puff.scale_amount_min = 1.4
	puff.scale_amount_max = 2.6
	puff.color = Color(0.82, 0.78, 0.68, 0.5)
	if get_parent() != null:
		get_parent().add_child(puff)
		var cleanup: Tween = puff.create_tween()
		cleanup.tween_interval(0.8)
		cleanup.tween_callback(puff.queue_free)
