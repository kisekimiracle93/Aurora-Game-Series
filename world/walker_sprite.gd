class_name WalkerSprite
extends AnimatedSprite2D
## Drop-in directional body: watches its parent's motion every frame and plays
## the matching walk animation (down/left/right/up), settling into the facing
## idle frame when still. Falls back to nothing if the walk set is missing —
## callers keep their static sprite in that case.

var _last_parent_pos: Vector2 = Vector2.INF
var _facing: String = "down"


static func attach(parent: Node2D, character_name: String, body_scale: float = 2.0) -> bool:
	var frames: SpriteFrames = AssetLibrary.walk_frames(character_name)
	if frames == null:
		return false
	var walker: WalkerSprite = WalkerSprite.new()
	walker.sprite_frames = frames
	walker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	walker.scale = Vector2(body_scale, body_scale)
	walker.animation = "idle_down"
	walker.play()
	parent.add_child(walker)
	return true


func _process(_delta: float) -> void:
	var parent: Node2D = get_parent() as Node2D
	if parent == null:
		return
	if _last_parent_pos == Vector2.INF:
		_last_parent_pos = parent.global_position
		return
	var motion: Vector2 = parent.global_position - _last_parent_pos
	_last_parent_pos = parent.global_position
	if motion.length() < 0.5:
		if not animation.begins_with("idle_"):
			play("idle_" + _facing)
		return
	if absf(motion.x) > absf(motion.y):
		_facing = "right" if motion.x > 0.0 else "left"
	else:
		_facing = "down" if motion.y > 0.0 else "up"
	if animation != _facing:
		play(_facing)
