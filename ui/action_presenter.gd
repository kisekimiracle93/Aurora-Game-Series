class_name ActionPresenter
extends Node
## Cinematic pacing for battle actions (the encounter awaits these hooks).
## Windup: the actor strides forward (or braces for guard/pray), a stone
## declaration banner announces the deed, casters gather light, echoes bend
## time. Followthrough: screen-weight lands (stage shake, flash, X-slash),
## then the actor returns and the banner fades.
##
## Durations scale with the action's gravity: basics stay punchy, echoes are
## mythic. All knobs are constants below.

const STEP_DISTANCE: float = 52.0
const BRACE_DISTANCE: float = 26.0
const ECHO_TIME_SCALE: float = 0.55

## seconds: [windup_hold, follow_hold]
const PACING: Dictionary = {
	"basic": [0.7, 0.85],
	"skill": [1.05, 1.2],
	"spell": [1.3, 1.4],
	"support": [0.9, 0.85],
	"echo": [2.1, 2.6],
	"brace": [0.5, 0.55],
}

var stage: Node2D  # the world layer that shakes
var overlay_parent: Node  # full-screen flash/X layer (UI level)
var banner: DeclarationBanner
## Headless runs (tests, CI boots) skip all waits — logic stays synchronous.
var instant: bool = DisplayServer.get_name() == "headless"

var _flash: ColorRect


func setup(stage_in: Node2D, overlay_parent_in: Node) -> void:
	stage = stage_in
	overlay_parent = overlay_parent_in
	banner = DeclarationBanner.new()
	overlay_parent.add_child(banner)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0.0)
	_flash.size = Vector2(1280, 720)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.z_index = 80
	overlay_parent.add_child(_flash)


func _pace(ability: AbilityData) -> Array:
	if ability.id == "guard" or ability.id == "pray":
		return PACING["brace"]
	if ability.ability_type == "echo":
		return PACING["echo"]
	if ability.ability_type == "spell":
		return PACING["spell"]
	if ability.ability_type == "support":
		return PACING["support"]
	if ability.id == "attack_basic":
		return PACING["basic"]
	return PACING["skill"]


func present_windup(actor: BaseCombatant, ability: AbilityData) -> void:
	if instant:
		return
	var pace: Array = _pace(ability)
	var braces: bool = ability.id == "guard" or ability.id == "pray"
	banner.declare(actor, ability)

	# Stride toward the foe — or plant the feet to brace.
	var direction: float = 1.0 if actor.is_player_controlled else -1.0
	var offset: Vector2 = (
		Vector2(-direction * BRACE_DISTANCE, 0) if braces
		else Vector2(direction * STEP_DISTANCE, 0)
	)
	var step: Tween = create_tween()
	step.tween_property(actor, "position", actor.position + offset, 0.28)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Casters gather light; echoes bend the world.
	if ability.ability_type == "echo":
		Engine.time_scale = ECHO_TIME_SCALE
		BattleFX.echo_burst(stage, actor.position, ability.element)
		_flash_screen(Color(1.0, 0.97, 0.85), 0.22)
	elif ability.ability_type == "spell" or ability.darkness_cost > 0:
		BattleFX.caster_aura(
			stage, actor.position, "Dark" if ability.darkness_cost > 0 else ability.element
		)

	await get_tree().create_timer(float(pace[0]), true, false, true).timeout


func present_followthrough(actor: BaseCombatant, ability: AbilityData) -> void:
	if instant:
		return
	var pace: Array = _pace(ability)
	var braces: bool = ability.id == "guard" or ability.id == "pray"

	# Weight of impact: every offensive action rattles the world a little;
	# the heavy stuff rattles it a lot.
	if not braces and ability.damage_type != "none":
		var heavy: bool = ability.coeff >= 2.2 or ability.ability_type == "echo"
		shake_stage(14.0 if heavy else 7.0)
		_flash_screen(_element_tint(ability.element), 0.16 if heavy else 0.10)
		if heavy:
			_x_slash_screen()

	if ability.ability_type == "echo":
		Engine.time_scale = 1.0

	await get_tree().create_timer(float(pace[1]), true, false, true).timeout

	# Return to rank.
	var direction: float = 1.0 if actor.is_player_controlled else -1.0
	var offset: Vector2 = (
		Vector2(-direction * BRACE_DISTANCE, 0) if braces
		else Vector2(direction * STEP_DISTANCE, 0)
	)
	if actor.is_alive():
		var back: Tween = create_tween()
		back.tween_property(actor, "position", actor.position - offset, 0.24)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	banner.dismiss()


## Safety: battles can end mid-echo; never leave the world slowed.
func reset_time_scale() -> void:
	Engine.time_scale = 1.0


func shake_stage(strength: float) -> void:
	if stage == null:
		return
	var origin: Vector2 = Vector2.ZERO
	var tween: Tween = create_tween()
	for i: int in range(5):
		tween.tween_property(
			stage,
			"position",
			origin + Vector2(randf_range(-strength, strength), randf_range(-strength, strength)),
			0.045
		)
	tween.tween_property(stage, "position", origin, 0.06)


func _flash_screen(color: Color, peak_alpha: float) -> void:
	_flash.color = Color(color, peak_alpha)
	var tween: Tween = create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.45)


## Two blazing streaks carving an X across the whole screen.
func _x_slash_screen() -> void:
	for flip: float in [1.0, -1.0]:
		var streak: ColorRect = ColorRect.new()
		streak.color = Color(1, 1, 1, 0.85)
		streak.size = Vector2(1700.0, 5.0)
		streak.position = Vector2(-210.0, 360.0 - flip * 40.0)
		streak.rotation_degrees = 24.0 * flip
		streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
		streak.z_index = 85
		streak.pivot_offset = Vector2(850.0, 2.5)
		overlay_parent.add_child(streak)
		streak.scale = Vector2(0.0, 1.0)
		var tween: Tween = create_tween()
		tween.tween_property(streak, "scale:x", 1.0, 0.13)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(streak, "modulate:a", 0.0, 0.3)
		tween.tween_callback(streak.queue_free)


func _element_tint(element: String) -> Color:
	match element:
		"Fire":
			return Color(1.0, 0.5, 0.2)
		"Ice":
			return Color(0.6, 0.85, 1.0)
		_:
			return Color(1.0, 1.0, 1.0)
