class_name BattleCamera
extends Camera2D
## The intelligent battle rig: rests on a wide framing, leans in with a hair
## of roll when someone acts, PANS to the victim to watch the hit land,
## punches with impacts, shakes, and breathes back out — while the player
## keeps a few inches of free-look on the arrows/stick (the camera-freedom
## feel; it glides home the moment an action is chosen). [Z] snaps a tight
## lens that slowly relaxes. UI lives on CanvasLayers, so it rides along.

const REST_POS: Vector2 = Vector2(640, 360)
## Owner spec: "zoom in much much more" — these are real close-ups now.
const ACT_ZOOM: float = 1.55
const ECHO_ZOOM: float = 1.95
const PUNCH_ZOOM: float = 1.16
## Free-look reach (a few inches, not a map scroll) and feel.
const FREE_LOOK_REACH: Vector2 = Vector2(170.0, 110.0)
const FREE_LOOK_EASE: float = 4.0

## Tweens drive these; _process composites them onto the real camera.
var base_zoom: Vector2 = Vector2.ONE
var shake_value: Vector2 = Vector2.ZERO
var lens: float = 1.0  # the [Z] press
var free_look: Vector2 = Vector2.ZERO
var _free_suppressed_until: float = 0.0

var _shake_tween: Tween
var _lens_tween: Tween


func _ready() -> void:
	position = REST_POS
	make_current()


func _process(delta: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var target: Vector2 = Vector2.ZERO
	if now >= _free_suppressed_until:
		target = Input.get_vector(
			"move_left", "move_right", "move_up", "move_down"
		) * FREE_LOOK_REACH
	free_look = free_look.lerp(target, clampf(delta * FREE_LOOK_EASE, 0.0, 1.0))
	offset = shake_value + free_look
	zoom = base_zoom * lens


## An action was chosen: glide the free-look home so the framing is clean.
func recenter(hold_seconds: float = 0.6) -> void:
	_free_suppressed_until = Time.get_ticks_msec() / 1000.0 + hold_seconds


## Windup: drift toward the actor with a hair of roll.
func focus_on(target_pos: Vector2, big: bool = false) -> void:
	recenter(1.2)
	var lean: Vector2 = REST_POS.lerp(target_pos, 0.62 if big else 0.50)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", lean, 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "base_zoom", Vector2.ONE * (ECHO_ZOOM if big else ACT_ZOOM), 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		self, "rotation_degrees", randf_range(0.8, 1.6) * (1.0 if target_pos.x < 640.0 else -1.0), 0.45
	)
	var postfx: Node = get_node_or_null("/root/PostFX")
	if postfx != null:
		postfx.set_param("dof_amount", 0.75)


## The cinematic turn: stay tight, glide from the caster to the victim.
func pan_to(target_pos: Vector2, seconds: float = 0.45) -> void:
	recenter(seconds + 0.4)
	var lean: Vector2 = REST_POS.lerp(target_pos, 0.55)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", lean, seconds)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		self, "rotation_degrees", randf_range(0.5, 1.1) * (1.0 if target_pos.x < 640.0 else -1.0),
		seconds
	)


## Impact: snap a step closer onto the victim.
func punch(target_pos: Vector2) -> void:
	recenter(0.9)
	var lean: Vector2 = REST_POS.lerp(target_pos, 0.55)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", lean, 0.1)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "base_zoom", base_zoom * PUNCH_ZOOM, 0.1)
	var postfx: Node = get_node_or_null("/root/PostFX")
	if postfx != null:
		postfx.pulse_dof(0.95, 0.6)


func shake(strength: float) -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	for i: int in range(5):
		_shake_tween.tween_property(
			self, "shake_value",
			Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), 0.04
		)
	_shake_tween.tween_property(self, "shake_value", Vector2.ZERO, 0.06)


## A gentle cameraman wiggle (the edge-pile shake-off, weather beats).
func wiggle(strength: float = 4.0) -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		return  # never fight a real impact shake
	_shake_tween = create_tween()
	for i: int in range(7):
		_shake_tween.tween_property(
			self, "shake_value",
			Vector2(randf_range(-strength, strength), randf_range(-strength * 0.6, strength * 0.6)),
			0.07
		).set_trans(Tween.TRANS_SINE)
	_shake_tween.tween_property(self, "shake_value", Vector2.ZERO, 0.12)


## [Z]: the cameraman racks a tight lens, then slowly relaxes his grip.
func lens_snap(tight: float = 1.45, relax_seconds: float = 6.0) -> void:
	if _lens_tween != null and _lens_tween.is_valid():
		_lens_tween.kill()
	_lens_tween = create_tween()
	_lens_tween.tween_property(self, "lens", tight, 0.14)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_lens_tween.tween_property(self, "lens", 1.0, relax_seconds)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Breathe back out to the resting frame.
func release() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", REST_POS, 0.55)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "base_zoom", Vector2.ONE, 0.55)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation_degrees", 0.0, 0.55)
	var postfx: Node = get_node_or_null("/root/PostFX")
	if postfx != null:
		postfx.set_param("dof_amount", 0.38)
