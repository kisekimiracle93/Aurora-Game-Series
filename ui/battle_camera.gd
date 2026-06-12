class_name BattleCamera
extends Camera2D
## The intelligent battle rig: rests on a wide framing of the arena, leans in
## with a slight roll when someone acts (2.5D feel), punches toward impacts,
## shakes with the blow, and breathes back out — driving the post stack's
## depth of field in sync.

const REST_POS: Vector2 = Vector2(640, 360)
const ACT_ZOOM: float = 1.16
const ECHO_ZOOM: float = 1.26
const PUNCH_ZOOM: float = 1.10

var _shake_tween: Tween


func _ready() -> void:
	position = REST_POS
	make_current()


## Windup: drift toward the actor with a hair of roll.
func focus_on(target_pos: Vector2, big: bool = false) -> void:
	var lean: Vector2 = REST_POS.lerp(target_pos, 0.38 if big else 0.28)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", lean, 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "zoom", Vector2.ONE * (ECHO_ZOOM if big else ACT_ZOOM), 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		self, "rotation_degrees", randf_range(0.8, 1.6) * (1.0 if target_pos.x < 640.0 else -1.0), 0.45
	)
	var postfx: Node = get_node_or_null("/root/PostFX")
	if postfx != null:
		postfx.set_param("dof_amount", 0.75)


## Impact: snap a step closer onto the victim.
func punch(target_pos: Vector2) -> void:
	var lean: Vector2 = REST_POS.lerp(target_pos, 0.34)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", lean, 0.1)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "zoom", zoom * PUNCH_ZOOM, 0.1)
	var postfx: Node = get_node_or_null("/root/PostFX")
	if postfx != null:
		postfx.pulse_dof(0.95, 0.6)


func shake(strength: float) -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	for i: int in range(5):
		_shake_tween.tween_property(
			self, "offset",
			Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), 0.04
		)
	_shake_tween.tween_property(self, "offset", Vector2.ZERO, 0.06)


## Breathe back out to the resting frame.
func release() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", REST_POS, 0.55)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "zoom", Vector2.ONE, 0.55)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation_degrees", 0.0, 0.55)
	var postfx: Node = get_node_or_null("/root/PostFX")
	if postfx != null:
		postfx.set_param("dof_amount", 0.5)
