class_name PlayerAvatar
extends CharacterBody2D
## Top-down walker for town/overworld/dungeon. Arrow keys / WASD / left stick.
## Emits how far it has walked so areas can roll random encounters.

signal stepped(distance: float)

const SPEED: float = 230.0

var _sprite_set: bool = false


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


func _physics_process(_delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * SPEED
	move_and_slide()
	if velocity.length() > 1.0:
		stepped.emit(velocity.length() * _delta_safe())


func _delta_safe() -> float:
	return get_physics_process_delta_time()
