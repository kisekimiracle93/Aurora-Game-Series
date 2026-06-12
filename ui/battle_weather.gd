class_name BattleWeather
extends CanvasLayer
## The owner asked for the battle FX dialed to 1000%: enormous light shafts
## sweeping the arena, biome weather falling across the whole screen, and
## drifts of snow / leaves / dust PILING UP at the screen edges over time —
## until the cameraman gives the rig a gentle shake and the buildup tumbles
## off. Lives between the lens (55) and the UI (80).

const PILE_GROW_SECONDS: float = 42.0
const SHAKE_OFF_PERIOD: float = 48.0

var biome: String = "tundra"
var camera: BattleCamera

var _piles: Array[Node2D] = []
var _pile_tweens: Array[Tween] = []


static func palette(biome_name: String) -> Dictionary:
	match biome_name:
		"meadow":
			return {
				"fall": Color(0.85, 0.95, 0.55, 0.8), "pile": Color(0.55, 0.72, 0.38, 0.85),
				"ray": Color(1.0, 0.97, 0.7), "amount": 26,
			}
		"forest":
			return {
				"fall": Color(0.72, 0.88, 0.45, 0.85), "pile": Color(0.42, 0.58, 0.3, 0.88),
				"ray": Color(0.95, 1.0, 0.75), "amount": 34,
			}
		"cavern":
			return {
				"fall": Color(0.75, 0.85, 1.0, 0.5), "pile": Color(0.45, 0.55, 0.75, 0.7),
				"ray": Color(0.6, 0.8, 1.0), "amount": 18,
			}
		_:  # tundra
			return {
				"fall": Color(0.97, 0.99, 1.0, 0.9), "pile": Color(0.93, 0.97, 1.0, 0.92),
				"ray": Color(0.85, 0.93, 1.0), "amount": 44,
			}


func _init(biome_in: String = "tundra", camera_in: BattleCamera = null) -> void:
	biome = biome_in
	camera = camera_in
	layer = 60


func _ready() -> void:
	var look: Dictionary = palette(biome)
	_build_rays(look)
	_build_fall(look)
	_build_piles(look)
	# The cameraman shakes the buildup off on a slow cycle.
	var timer: Timer = Timer.new()
	timer.wait_time = SHAKE_OFF_PERIOD
	timer.timeout.connect(_shake_off)
	add_child(timer)
	timer.start()


## Light shafts the size of the sky, sweeping slowly.
func _build_rays(look: Dictionary) -> void:
	var ray_material: CanvasItemMaterial = CanvasItemMaterial.new()
	ray_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9
	for i: int in range(4):
		var ray: Polygon2D = Polygon2D.new()
		var width: float = rng.randf_range(120.0, 260.0)
		ray.polygon = PackedVector2Array([
			Vector2(0, -100), Vector2(width, -100),
			Vector2(width + 320.0, 900.0), Vector2(320.0, 900.0),
		])
		ray.color = Color(look["ray"], rng.randf_range(0.05, 0.10))
		ray.material = ray_material
		ray.position = Vector2(-200.0 + i * 380.0, 0.0)
		add_child(ray)
		var sweep: Tween = ray.create_tween().set_loops()
		sweep.tween_property(ray, "position:x", ray.position.x + rng.randf_range(140.0, 260.0), rng.randf_range(9.0, 15.0))\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sweep.parallel().tween_property(ray, "modulate:a", 0.25, rng.randf_range(4.0, 7.0))\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sweep.tween_property(ray, "position:x", ray.position.x, rng.randf_range(9.0, 15.0))\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sweep.parallel().tween_property(ray, "modulate:a", 1.0, rng.randf_range(4.0, 7.0))\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Screen-wide falling weather: snow / leaves / dustmotes by biome.
func _build_fall(look: Dictionary) -> void:
	var fall: CPUParticles2D = CPUParticles2D.new()
	fall.position = Vector2(640, -30)
	fall.amount = int(look["amount"])
	fall.lifetime = 7.0
	fall.preprocess = 7.0
	fall.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fall.emission_rect_extents = Vector2(720, 10)
	fall.direction = Vector2(0.2, 1.0)
	fall.spread = 14.0
	fall.gravity = Vector2(4.0, 30.0)
	fall.initial_velocity_min = 24.0
	fall.initial_velocity_max = 70.0
	fall.angular_velocity_min = -90.0
	fall.angular_velocity_max = 90.0
	fall.scale_amount_min = 1.4
	fall.scale_amount_max = 3.0
	fall.color = look["fall"]
	add_child(fall)


## Drifts that grow at the screen's bottom corners and lower edge.
func _build_piles(look: Dictionary) -> void:
	for config: Array in [
		[Vector2(0, 720), 340.0, 60.0], [Vector2(1280, 720), 340.0, 60.0],
		[Vector2(640, 728), 520.0, 38.0],
	]:
		var pile: Node2D = Node2D.new()
		var anchor: Vector2 = config[0]
		var width: float = float(config[1])
		var height: float = float(config[2])
		var pile_color: Color = look["pile"]
		pile.position = anchor
		pile.draw.connect(func() -> void:
			var points: PackedVector2Array = PackedVector2Array()
			points.append(Vector2(-width / 2.0, 4.0))
			for step: int in range(9):
				var t: float = float(step) / 8.0
				points.append(Vector2(
					-width / 2.0 + width * t,
					-height * sin(PI * t) * (0.8 + 0.2 * sin(t * 17.0))
				))
			points.append(Vector2(width / 2.0, 4.0))
			pile.draw_colored_polygon(points, pile_color))
		pile.scale = Vector2(1.0, 0.06)
		add_child(pile)
		_piles.append(pile)
		_grow_pile(pile)


func _grow_pile(pile: Node2D) -> void:
	var grow: Tween = pile.create_tween()
	grow.tween_property(pile, "scale:y", 1.0, PILE_GROW_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_pile_tweens.append(grow)


## The gentle Nintendo shake: wiggle the camera, tumble the drifts off.
func _shake_off() -> void:
	if camera != null and is_instance_valid(camera):
		camera.wiggle(5.0)
	for tween: Tween in _pile_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_pile_tweens.clear()
	for pile: Node2D in _piles:
		if not is_instance_valid(pile):
			continue
		var drop: Tween = pile.create_tween()
		drop.tween_property(pile, "scale:y", 0.06, 0.7)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		drop.tween_callback(func() -> void: _grow_pile(pile))
