extends CanvasLayer
## Autoload: the lens. A screen-wide post-processing pass (tilt-shift DoF,
## vignette, grain, frost, fog) that every scene tunes for its mood, and the
## battle camera pulses for impact moments.

var _rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	layer = 99
	_rect = ColorRect.new()
	_rect.size = Vector2(1280, 720)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = load("res://ui/shaders/postfx.gdshader")
	_rect.material = _material
	add_child(_rect)


func set_param(param: String, value: float) -> void:
	_material.set_shader_parameter(param, value)


## Scene moods: one call per scene type.
func mood_world(frost: float = 0.0, fog: float = 0.0) -> void:
	set_param("dof_amount", 0.4)
	set_param("focus_y", 0.55)
	set_param("vignette_strength", 0.30)
	set_param("frost_amount", frost)
	set_param("fog_amount", fog)


func mood_battle() -> void:
	set_param("dof_amount", 0.5)
	set_param("focus_y", 0.46)
	set_param("vignette_strength", 0.36)
	set_param("frost_amount", 0.0)
	set_param("fog_amount", 0.08)


func mood_menu() -> void:
	set_param("dof_amount", 0.15)
	set_param("focus_y", 0.5)
	set_param("vignette_strength", 0.42)
	set_param("frost_amount", 0.06)
	set_param("fog_amount", 0.12)


## Impact accent: DoF clamps down hard, then breathes back out.
func pulse_dof(peak: float = 0.85, duration: float = 0.5) -> void:
	var tween: Tween = create_tween()
	tween.tween_method(
		func(value: float) -> void: set_param("dof_amount", value),
		peak, 0.5, duration
	)
