class_name EchoMath
extends RefCounted
## Echo gauge fill rules (build plan M2): earned by damage dealt and taken,
## spent on Echo abilities, refillable within a battle (multi-use).
## Rates are tunable; chosen so a hard fight yields 1-3 Echoes (see BUILD_LOG.md).

const ECHO_MAX: float = 100.0
## Points per 100% of the TARGET's max HP dealt as damage.
const GAIN_DEALT_RATE: float = 25.0
## Points per 100% of the OWNER's max HP taken as damage.
const GAIN_TAKEN_RATE: float = 50.0


static func gain_from_damage_dealt(damage: int, target_max_hp: int) -> float:
	if damage <= 0:
		return 0.0
	return GAIN_DEALT_RATE * float(damage) / float(maxi(target_max_hp, 1))


static func gain_from_damage_taken(damage: int, own_max_hp: int) -> float:
	if damage <= 0:
		return 0.0
	return GAIN_TAKEN_RATE * float(damage) / float(maxi(own_max_hp, 1))
