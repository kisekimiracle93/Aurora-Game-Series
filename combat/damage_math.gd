class_name DamageMath
extends RefCounted
## Pure damage formulas (build plan 5.4). Static, no scene tree — unit-testable headless.

const GUARD_COEFF: float = 0.6
const WARD_COEFF: float = 0.7
const RANDOM_MIN: float = 0.95
const RANDOM_MAX: float = 1.05
const CRIT_MULT: float = 1.5
const MIN_DAMAGE: int = 1
const RESOLVE_CRIT_BONUS_MAX: float = 10.0  # up to +10% at high Resolve

const ELEMENT_MODS: Dictionary = {
	"weak": 1.5,
	"neutral": 1.0,
	"resist": 0.5,
	"absorb": -0.75,  # heals the target
	"immune": 0.0,
}


static func element_mod(affinity: String) -> float:
	return float(ELEMENT_MODS.get(affinity, 1.0))


static func resolve_damage_mult(resolve: float) -> float:
	if resolve < 40.0:
		return 0.70 + 0.30 * (resolve / 40.0)
	if resolve > 80.0:
		return 1.0 + 0.40 * pow((resolve - 80.0) / 40.0, 1.2)
	return 1.0


## Heirs only; pass 0 for everyone else.
static func darkness_damage_mult(darkness: float) -> float:
	if darkness < 20.0:
		return 1.0
	return 1.0 + 0.60 * ((darkness - 20.0) / 80.0)


## LayerMod (slice) = M_resolve_dmg * M_darkness. Duty/Burden deferred.
static func layer_mod(resolve: float, darkness: float = 0.0) -> float:
	return resolve_damage_mult(resolve) * darkness_damage_mult(darkness)


## Positive = damage (min-clamped to 1). Negative = absorb heal. 0 = immune.
static func physical_damage(
	power: float, skill_coeff: float, guard: float, emod: float, lmod: float, rand: float = 1.0
) -> int:
	return _raw_damage(power, skill_coeff, guard, GUARD_COEFF, emod, lmod, rand)


static func magic_damage(
	focus: float, spell_coeff: float, ward: float, emod: float, lmod: float, rand: float = 1.0
) -> int:
	return _raw_damage(focus, spell_coeff, ward, WARD_COEFF, emod, lmod, rand)


static func _raw_damage(
	atk: float, coeff: float, def: float, def_coeff: float, emod: float, lmod: float, rand: float
) -> int:
	if emod == 0.0:
		return 0  # immune: no min-clamp
	var base: float = maxf(atk * coeff - def * def_coeff, 0.0)
	var raw: float = base * emod * lmod * rand
	if emod < 0.0:
		return int(round(raw))  # absorb: negative result heals the target
	return maxi(int(round(raw)), MIN_DAMAGE)


## Crit chance (percent) = CritStat + ResolveBonus (up to +10 at high R).
static func crit_chance(crit_stat: float, resolve: float) -> float:
	return crit_stat + resolve_crit_bonus(resolve)


static func resolve_crit_bonus(resolve: float) -> float:
	if resolve <= 80.0:
		return 0.0
	return RESOLVE_CRIT_BONUS_MAX * clampf((resolve - 80.0) / 40.0, 0.0, 1.0)


static func apply_crit(damage: int) -> int:
	return int(round(float(damage) * CRIT_MULT))


## Defense from Resolve: high R -> -10% damage taken; low R -> +15% damage taken.
static func incoming_damage_mult(target_resolve: float) -> float:
	if target_resolve > 80.0:
		return 0.90
	if target_resolve < 40.0:
		return 1.15
	return 1.0
