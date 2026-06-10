class_name MeterMath
extends RefCounted
## Pure meter formulas (build plan 5.2). Static, no scene tree — unit-testable headless.

const RESOLVE_MIN: float = 0.0
const RESOLVE_MAX: float = 120.0
const RESOLVE_DEFAULT: float = 60.0

const DARKNESS_MIN: float = 0.0
const DARKNESS_MAX: float = 100.0
## Meter full = forced KO requiring a special revive (tunable; logged in BUILD_LOG.md).
const DARKNESS_FORCED_KO_THRESHOLD: float = 100.0
## Max HP shrinks by up to 30% at Darkness 100 (until drained at a save point).
const DARKNESS_MAX_HP_LOSS: float = 0.30
## Accuracy drops by up to 20 points, ramping from Darkness 20 to 100.
const DARKNESS_ACCURACY_LOSS: float = 20.0

enum ResolveBand { BROKEN, SHAKEN, NEUTRAL, STEADY, UNYIELDING }

const BAND_NAMES: Dictionary = {
	ResolveBand.BROKEN: "Broken",
	ResolveBand.SHAKEN: "Shaken",
	ResolveBand.NEUTRAL: "Neutral",
	ResolveBand.STEADY: "Steady",
	ResolveBand.UNYIELDING: "Unyielding",
}


## Bands: 0-30 Broken, 31-39 Shaken, 40-80 Neutral, 81-100 Steady, 101-120 Unyielding.
static func resolve_band(resolve: float) -> ResolveBand:
	var r: float = clampf(resolve, RESOLVE_MIN, RESOLVE_MAX)
	if r <= 30.0:
		return ResolveBand.BROKEN
	if r <= 39.0:
		return ResolveBand.SHAKEN
	if r <= 80.0:
		return ResolveBand.NEUTRAL
	if r <= 100.0:
		return ResolveBand.STEADY
	return ResolveBand.UNYIELDING


static func band_name(band: ResolveBand) -> String:
	return String(BAND_NAMES.get(band, "Neutral"))


## HP degradation: multiplier on max HP while Darkness is undrained.
static func darkness_max_hp_mult(darkness: float) -> float:
	return 1.0 - DARKNESS_MAX_HP_LOSS * clampf(darkness / DARKNESS_MAX, 0.0, 1.0)


## Flat accuracy penalty (points) from Darkness; kicks in above 20.
static func darkness_accuracy_penalty(darkness: float) -> float:
	if darkness < 20.0:
		return 0.0
	return DARKNESS_ACCURACY_LOSS * clampf((darkness - 20.0) / 80.0, 0.0, 1.0)


static func is_forced_ko(darkness: float) -> bool:
	return darkness >= DARKNESS_FORCED_KO_THRESHOLD
