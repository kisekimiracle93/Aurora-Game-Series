class_name EchoMath
extends RefCounted
## Echo gauge fill rules (build plan M2): earned by damage dealt and taken,
## spent on Echo abilities, refillable within a battle (multi-use).
## Gains are normalized by the OWNER's max HP (not the target's) so big-HP
## bosses still feed the gauge — retuned after checkpoint feedback that Echoes
## never came online (see BUILD_LOG.md).

const ECHO_MAX: float = 100.0
## Points per 100% of the ATTACKER's own max HP dealt as damage.
const GAIN_DEALT_RATE: float = 60.0
## Points per 100% of the OWNER's max HP taken as damage.
const GAIN_TAKEN_RATE: float = 90.0


static func gain_from_damage_dealt(damage: int, attacker_max_hp: int) -> float:
	if damage <= 0:
		return 0.0
	return GAIN_DEALT_RATE * float(damage) / float(maxi(attacker_max_hp, 1))


static func gain_from_damage_taken(damage: int, own_max_hp: int) -> float:
	if damage <= 0:
		return 0.0
	return GAIN_TAKEN_RATE * float(damage) / float(maxi(own_max_hp, 1))
