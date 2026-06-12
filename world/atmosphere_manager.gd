extends Node

signal night_changed(now_night: bool)
## Autoload: the living sky. Tracks time-of-day (advancing while you walk the
## world), grades the whole palette through warm dawn -> clear noon -> bruised
## purple dusk -> deep blue night, and drives each area's sun (a shadow-casting
## DirectionalLight2D) plus a cool moon that takes over after dark. Battles
## sample a softened version so arenas match the hour without losing
## readability.

## Minutes of real time for a full 24h day while in world areas. The clock is
## deliberately night-heavy: dark runs ~19:00 to ~06:45 (owner spec).
const DAY_LENGTH_MINUTES: float = 15.0
const NIGHT_END_HOUR: float = 6.75
const NIGHT_START_HOUR: float = 18.75

## hour -> ambient grade (interpolated around the clock). Nights run DARK —
## torches, windows, and the lantern are supposed to matter.
const GRADE_KEYS: Array = [
	[0.0, Color(0.225, 0.26, 0.60)],   # dead of night
	[5.5, Color(0.30, 0.33, 0.66)],    # last of the night
	[7.5, Color(1.05, 0.92, 0.80)],    # warm morning gold
	[12.0, Color(1.0, 1.0, 1.0)],      # clean noon
	[16.5, Color(1.0, 0.88, 0.78)],    # late warmth
	[18.2, Color(0.74, 0.58, 0.86)],   # desaturated purple dusk
	[19.6, Color(0.27, 0.30, 0.64)],   # night falls fast
	[24.0, Color(0.225, 0.26, 0.60)],
]

var hour: float = 10.0
var advancing: bool = false  # areas turn this on; battles/menus freeze time
var _was_night: bool = false

var _modulates: Array[CanvasModulate] = []
var _suns: Array[DirectionalLight2D] = []
var _moons: Array[DirectionalLight2D] = []


func _process(delta: float) -> void:
	if not advancing:
		return
	hour = fmod(hour + delta * 24.0 / (DAY_LENGTH_MINUTES * 60.0), 24.0)
	_apply_grade()
	if is_night() != _was_night:
		_was_night = is_night()
		night_changed.emit(_was_night)


## Pure + testable: the palette for any hour.
static func tint_for_hour(at_hour: float) -> Color:
	var h: float = fposmod(at_hour, 24.0)
	for i: int in range(GRADE_KEYS.size() - 1):
		var a: Array = GRADE_KEYS[i]
		var b: Array = GRADE_KEYS[i + 1]
		if h >= float(a[0]) and h <= float(b[0]):
			var t: float = (h - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001)
			return (a[1] as Color).lerp(b[1] as Color, t)
	return Color.WHITE


static func is_night_hour(at_hour: float) -> bool:
	var h: float = fposmod(at_hour, 24.0)
	return h < NIGHT_END_HOUR or h >= NIGHT_START_HOUR


func is_night() -> bool:
	return is_night_hour(hour)


## 0..1 how deep into the night we are (for fireflies, moon strength, beams).
static func night_depth_for_hour(at_hour: float) -> float:
	if not is_night_hour(at_hour):
		return 0.0
	var h: float = fposmod(at_hour, 24.0)
	# Distance from the nearest night edge, normalized to ~3h of full dark.
	var from_dusk: float = (h - NIGHT_START_HOUR) if h >= NIGHT_START_HOUR else (h + 24.0 - NIGHT_START_HOUR)
	var to_dawn: float = (NIGHT_END_HOUR - h) if h < NIGHT_END_HOUR else (NIGHT_END_HOUR + 24.0 - h)
	return clampf(minf(from_dusk, to_dawn) / 3.0, 0.0, 1.0)


func night_depth() -> float:
	return night_depth_for_hour(hour)


## Wire a world area into the cycle: ambient grade + a sun and a moon.
func apply_to_area(area: Node2D) -> void:
	advancing = true
	var ambient: CanvasModulate = CanvasModulate.new()
	ambient.color = tint_for_hour(hour)
	area.add_child(ambient)
	_modulates.append(ambient)

	var sun: DirectionalLight2D = DirectionalLight2D.new()
	sun.shadow_enabled = true
	sun.shadow_color = Color(0.05, 0.06, 0.12, 0.55)
	sun.blend_mode = Light2D.BLEND_MODE_ADD
	area.add_child(sun)
	_suns.append(sun)

	var moon: DirectionalLight2D = DirectionalLight2D.new()
	moon.shadow_enabled = true
	moon.shadow_color = Color(0.02, 0.03, 0.10, 0.45)
	moon.blend_mode = Light2D.BLEND_MODE_ADD
	moon.color = Color(0.62, 0.72, 1.0)
	area.add_child(moon)
	_moons.append(moon)
	_apply_grade()


## Battles freeze the clock and take a gentler grade on their stage.
func apply_to_battle(stage: Node2D) -> void:
	advancing = false
	var ambient: CanvasModulate = CanvasModulate.new()
	ambient.color = tint_for_hour(hour).lerp(Color.WHITE, 0.55)
	stage.add_child(ambient)
	_modulates.append(ambient)


func _apply_grade() -> void:
	var tint: Color = tint_for_hour(hour)
	var live_modulates: Array[CanvasModulate] = []
	for ambient: CanvasModulate in _modulates:
		if is_instance_valid(ambient):
			live_modulates.append(ambient)
	_modulates = live_modulates
	var live_suns: Array[DirectionalLight2D] = []
	for sun: DirectionalLight2D in _suns:
		if is_instance_valid(sun):
			live_suns.append(sun)
	_suns = live_suns
	var live_moons: Array[DirectionalLight2D] = []
	for moon: DirectionalLight2D in _moons:
		if is_instance_valid(moon):
			live_moons.append(moon)
	_moons = live_moons
	for ambient: CanvasModulate in _modulates:
		ambient.color = tint
	# The sun arcs: low + warm at the edges of day, gone at night.
	var daylight: float = clampf(1.0 - absf(hour - 12.0) / 7.5, 0.0, 1.0)
	for sun: DirectionalLight2D in _suns:
		sun.energy = 0.35 * daylight
		sun.rotation = deg_to_rad(lerpf(-55.0, 55.0, clampf((hour - 6.0) / 12.0, 0.0, 1.0)))
		sun.visible = daylight > 0.02
	# The moon rises with the dark: a faint silver wash with its own shadows.
	var moonlight: float = night_depth()
	for moon: DirectionalLight2D in _moons:
		moon.energy = 0.16 * moonlight
		moon.rotation = deg_to_rad(lerpf(40.0, -40.0, clampf(fposmod(hour - 19.0, 24.0) / 12.0, 0.0, 1.0)))
		moon.visible = moonlight > 0.03
