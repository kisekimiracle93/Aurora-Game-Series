extends Node
## Autoload: the living sky. Tracks time-of-day (advancing while you walk the
## world), grades the whole palette through warm dawn -> clear noon -> bruised
## purple dusk -> deep blue night, and drives each area's sun (a shadow-casting
## DirectionalLight2D). Battles sample a softened version so arenas match the
## hour without losing readability.

## Minutes of real time for a full 24h day while in world areas.
const DAY_LENGTH_MINUTES: float = 6.0

## hour -> ambient grade (interpolated around the clock).
const GRADE_KEYS: Array = [
	[0.0, Color(0.42, 0.48, 0.85)],   # deep night blue
	[5.0, Color(0.55, 0.52, 0.80)],   # last of the night
	[7.0, Color(1.05, 0.92, 0.80)],   # warm morning gold
	[12.0, Color(1.0, 1.0, 1.0)],     # clean noon
	[17.0, Color(1.0, 0.88, 0.78)],   # late warmth
	[19.5, Color(0.78, 0.62, 0.88)],  # desaturated purple dusk
	[22.0, Color(0.45, 0.50, 0.86)],  # night falls
	[24.0, Color(0.42, 0.48, 0.85)],
]

var hour: float = 10.0
var advancing: bool = false  # areas turn this on; battles/menus freeze time

var _modulates: Array[CanvasModulate] = []
var _suns: Array[DirectionalLight2D] = []


func _process(delta: float) -> void:
	if not advancing:
		return
	hour = fmod(hour + delta * 24.0 / (DAY_LENGTH_MINUTES * 60.0), 24.0)
	_apply_grade()


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
	return h < 6.0 or h > 20.0


func is_night() -> bool:
	return is_night_hour(hour)


## Wire a world area into the cycle: ambient grade + a shadow-casting sun.
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
	_apply_grade()


## Battles freeze the clock and take a gentler grade on their stage.
func apply_to_battle(stage: Node2D) -> void:
	advancing = false
	var ambient: CanvasModulate = CanvasModulate.new()
	ambient.color = tint_for_hour(hour).lerp(Color.WHITE, 0.5)
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
	for ambient: CanvasModulate in _modulates:
		ambient.color = tint
	# The sun arcs: low + warm at the edges of day, gone at night.
	var daylight: float = clampf(1.0 - absf(hour - 12.0) / 8.0, 0.0, 1.0)
	for sun: DirectionalLight2D in _suns:
		sun.energy = 0.35 * daylight
		sun.rotation = deg_to_rad(lerpf(-55.0, 55.0, clampf((hour - 6.0) / 12.0, 0.0, 1.0)))
		sun.visible = daylight > 0.02
