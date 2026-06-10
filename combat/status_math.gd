class_name StatusMath
extends RefCounted
## Pure status formulas (build plan 5.5). Static, no scene tree — unit-testable headless.

const HIT_CHANCE_MIN: float = 5.0
const HIT_CHANCE_MAX: float = 95.0
const FOCUS_WARD_HIT_SCALE: float = 0.5  # +0.5% per point of (Focus - Ward)
const RESOLVE_FACTOR_LOW: float = 15.0  # target R<40 -> +15%
const RESOLVE_FACTOR_HIGH: float = -10.0  # target R>80 -> -10%
const DURATION_MOD_LOW: float = 1.3
const DURATION_MOD_HIGH: float = 0.7
## Each successful application adds this many resistance points to the next try.
const RESISTANCE_STACK_STEP: float = 20.0


static func resolve_factor(target_resolve: float) -> float:
	if target_resolve < 40.0:
		return RESOLVE_FACTOR_LOW
	if target_resolve > 80.0:
		return RESOLVE_FACTOR_HIGH
	return 0.0


## Percent chance the status lands, clamped to 5-95.
static func hit_chance(
	base_chance: float,
	caster_focus: float,
	target_ward: float,
	target_resolve: float,
	resistance: float = 0.0
) -> float:
	var chance: float = (
		base_chance
		+ (caster_focus - target_ward) * FOCUS_WARD_HIT_SCALE
		+ resolve_factor(target_resolve)
		- resistance
	)
	return clampf(chance, HIT_CHANCE_MIN, HIT_CHANCE_MAX)


static func resolve_duration_mod(target_resolve: float) -> float:
	if target_resolve < 40.0:
		return DURATION_MOD_LOW
	if target_resolve > 80.0:
		return DURATION_MOD_HIGH
	return 1.0


## Duration in turns; a landed status always lasts at least 1 turn.
static func duration_turns(
	base_duration: int, caster_focus: float, target_ward: float, target_resolve: float
) -> int:
	var dur: float = (
		float(base_duration)
		* (1.0 + (caster_focus - target_ward) / 100.0)
		* resolve_duration_mod(target_resolve)
	)
	return maxi(int(round(dur)), 1)


## Resolve Shock: instant drop rolled between the status's min/max (roll01 in [0,1]).
static func resolve_shock_drop(drop_min: int, drop_max: int, roll01: float) -> int:
	return int(round(lerpf(float(drop_min), float(drop_max), clampf(roll01, 0.0, 1.0))))
