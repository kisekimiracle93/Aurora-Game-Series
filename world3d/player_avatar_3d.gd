class_name PlayerAvatar3D
extends CharacterBody3D
## The HD-2D walker: your existing pixel walker, billboarded into the 3D
## world. Same controls as the 2D game — WASD/stick, G run, T lantern,
## Tab swaps the lead — plus the diorama camera riding on a pitched arm.

const WALK_SPEED: float = 3.6
const RUN_SPEED: float = 5.5

var running: bool = false
var lantern_lit: bool = false
var lead_name: String = "Bastil"

var _sprite: AnimatedSprite3D
var _lantern: OmniLight3D
var camera: Camera3D
var _facing: String = "down"
var _steps: AudioStreamPlayer
var _step_stream: AudioStream
var _run_stream: AudioStream


func _ready() -> void:
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.1
	shape.shape = capsule
	shape.position.y = 0.55
	add_child(shape)

	var world: Node = get_node_or_null("/root/WorldState")
	if world != null:
		lead_name = String(world.get("avatar_name"))
	_sprite = AnimatedSprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.shaded = true
	_sprite.pixel_size = 0.024
	_sprite.position.y = 0.62
	add_child(_sprite)
	_build_body()

	_lantern = OmniLight3D.new()
	_lantern.light_color = Color(1.0, 0.78, 0.42)
	_lantern.light_energy = 0.0
	_lantern.omni_range = 5.0
	_lantern.shadow_enabled = true
	_lantern.position = Vector3(0.2, 1.0, 0.0)
	add_child(_lantern)

	# Real footstep foley (from the uploaded library), looped while moving.
	_steps = AudioStreamPlayer.new()
	_steps.bus = "Sfx" if AudioServer.get_bus_index("Sfx") != -1 else "Master"
	_steps.volume_db = -8.0
	add_child(_steps)
	_step_stream = _load_foley("Footsteps_walking")
	_run_stream = _load_foley("Footsteps_ running")

	# The diorama rig: a long lens pitched down at the miniature world.
	var arm: Node3D = Node3D.new()
	arm.rotation_degrees = Vector3(-42.0, 0.0, 0.0)
	add_child(arm)
	camera = Camera3D.new()
	camera.position = Vector3(0.0, 0.0, 14.0)
	camera.fov = 33.0
	var attributes: CameraAttributesPractical = CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_far_distance = 14.0
	attributes.dof_blur_far_transition = 9.0
	attributes.dof_blur_near_enabled = true
	attributes.dof_blur_near_distance = 4.5
	attributes.dof_blur_near_transition = 3.0
	attributes.dof_blur_amount = 0.12
	camera.attributes = attributes
	arm.add_child(camera)
	camera.make_current()


func _build_body() -> void:
	var frames: SpriteFrames = AssetLibrary.walk_frames(lead_name)
	if frames != null:
		_sprite.sprite_frames = frames
		_sprite.animation = "idle_down"
		_sprite.play()


static func _load_foley(base: String) -> AudioStream:
	for ext: String in ["wav", "ogg", "mp3"]:
		var path: String = "res://assets/audio/foley/%s.%s" % [base, ext]
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			if stream is AudioStreamWAV:
				(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			return stream
	return null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("swap_lead"):
		var world: Node = get_node_or_null("/root/WorldState")
		if world != null:
			lead_name = String(world.call("next_avatar"))
			_build_body()
			_sprite.modulate = Color(1.8, 1.8, 1.8)
			var settle: Tween = create_tween()
			settle.tween_property(_sprite, "modulate", Color.WHITE, 0.4)
	elif event.is_action_pressed("run_toggle"):
		running = not running
	elif event.is_action_pressed("lantern"):
		lantern_lit = not lantern_lit
		var tween: Tween = create_tween()
		tween.tween_property(_lantern, "light_energy", 1.6 if lantern_lit else 0.0, 0.5)
	elif event.is_action_pressed("lens_zoom") and camera != null:
		var lens: Tween = create_tween()
		lens.tween_property(camera, "fov", 21.0, 0.15)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		lens.tween_property(camera, "fov", 30.0, 6.0)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _physics_process(_delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed: float = RUN_SPEED if running else WALK_SPEED
	velocity.x = input_dir.x * speed
	velocity.z = input_dir.y * speed
	velocity.y = velocity.y - 16.0 * _delta if not is_on_floor() else 0.0
	move_and_slide()
	# Same facing logic as the 2D walker, mapped onto the ground plane.
	if input_dir.length() < 0.2:
		if _sprite.sprite_frames != null and not _sprite.animation.begins_with("idle_"):
			_sprite.play("idle_" + _facing)
		if _steps != null and _steps.playing:
			_steps.stop()
		return
	# Footsteps: the matching foley loops while you move (faster when running).
	if _steps != null:
		var want: AudioStream = _run_stream if running else _step_stream
		if want != null and (_steps.stream != want or not _steps.playing):
			_steps.stream = want
			_steps.pitch_scale = randf_range(0.95, 1.06)
			_steps.play()
	if absf(input_dir.x) > absf(input_dir.y):
		_facing = "right" if input_dir.x > 0.0 else "left"
	else:
		_facing = "down" if input_dir.y > 0.0 else "up"
	if _sprite.sprite_frames != null and _sprite.animation != _facing:
		_sprite.play(_facing)
