class_name ActionResolver
extends RefCounted
## Resolves one ability use against its targets, wiring the pure math into the
## components: accuracy roll, damage (element/layer/crit/guard), absorb heals,
## status applications, delay, Echo gains, and Resolve loss from damage taken.
## All randomness comes from the injected RNG, so battles are seedable.

## Physical/magic accuracy roll bounds (chosen; see BUILD_LOG.md).
const HIT_CHANCE_MIN: float = 20.0
const HIT_CHANCE_MAX: float = 100.0
const GUARD_DAMAGE_MULT: float = 0.5
## Resolve lost by a player = SCALE * damage / max HP (tunable feel knob).
const RESOLVE_DAMAGE_TAKEN_SCALE: float = 25.0


## Returns one result Dictionary per target:
## {target, missed, damage, healed, crit, statuses_applied: Array[String],
##  resolve_drop, delayed}
static func resolve_action(
	ability: AbilityData,
	actor: BaseCombatant,
	targets: Array[BaseCombatant],
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for target: BaseCombatant in targets:
		results.append(_resolve_on_target(ability, actor, target, rng))
	return results


static func _resolve_on_target(
	ability: AbilityData, actor: BaseCombatant, target: BaseCombatant, rng: RandomNumberGenerator
) -> Dictionary:
	var result: Dictionary = {
		"target": target,
		"missed": false,
		"damage": 0,
		"healed": 0,
		"crit": false,
		"statuses_applied": [] as Array[String],
		"resolve_drop": 0,
		"delayed": false,
	}

	var deals_damage: bool = ability.damage_type != "none" and ability.coeff > 0.0
	if deals_damage:
		var hit_chance: float = clampf(
			actor.current_accuracy() - float(target.stats.get_stat("evasion")),
			HIT_CHANCE_MIN,
			HIT_CHANCE_MAX
		)
		if rng.randf() * 100.0 >= hit_chance:
			result["missed"] = true
			return result  # a whiffed attack applies nothing
		_apply_damage(ability, actor, target, rng, result)
		if not target.is_alive():
			return result  # no statuses/delay on the slain

	if ability.heals:
		var heal_amount: int = int(
			round(
				float(actor.stats.get_stat("focus"))
				* ability.coeff
				* rng.randf_range(DamageMath.RANDOM_MIN, DamageMath.RANDOM_MAX)
			)
		)
		target.stats.heal(heal_amount)
		result["healed"] = heal_amount

	for entry: Dictionary in ability.statuses:
		_try_apply_status(entry, actor, target, rng, result)

	if ability.delay_amount > 0:
		result["delayed"] = target.ctb.receive_delay(float(ability.delay_amount))

	return result


static func _apply_damage(
	ability: AbilityData,
	actor: BaseCombatant,
	target: BaseCombatant,
	rng: RandomNumberGenerator,
	result: Dictionary
) -> void:
	var emod: float = DamageMath.element_mod(target.stats.affinity_for(ability.element))
	## ferocity is the enemy offense bias (players: 1.0) layered like Resolve.
	var lmod: float = (
		DamageMath.layer_mod(actor.resolve_for_math(), actor.darkness_for_math())
		* actor.ferocity
	)
	var variance: float = rng.randf_range(DamageMath.RANDOM_MIN, DamageMath.RANDOM_MAX)
	var damage: int
	if ability.damage_type == "physical":
		damage = DamageMath.physical_damage(
			float(actor.stats.get_stat("power")),
			ability.coeff,
			float(target.stats.get_stat("guard")),
			emod,
			lmod,
			variance
		)
	else:
		damage = DamageMath.magic_damage(
			float(actor.stats.get_stat("focus")),
			ability.coeff,
			float(target.stats.get_stat("ward")),
			emod,
			lmod,
			variance
		)

	if damage < 0:
		target.stats.heal(-damage)  # absorb: the element feeds them
		result["healed"] = -damage
		return
	if damage == 0:
		return  # immune

	if rng.randf() * 100.0 < DamageMath.crit_chance(
		float(actor.stats.get_stat("crit")), actor.resolve_for_math()
	):
		damage = DamageMath.apply_crit(damage)
		result["crit"] = true

	var taken_mult: float = DamageMath.incoming_damage_mult(target.resolve_for_math())
	if target.is_guarding:
		taken_mult *= GUARD_DAMAGE_MULT
	damage = maxi(int(round(float(damage) * taken_mult)), DamageMath.MIN_DAMAGE)

	target.stats.take_damage(damage)
	result["damage"] = damage

	# Echo gains (no-ops for combatants without an echo meter).
	actor.meters.add(
		MetersComponent.ECHO, EchoMath.gain_from_damage_dealt(damage, target.stats.max_hp())
	)
	target.meters.add(
		MetersComponent.ECHO, EchoMath.gain_from_damage_taken(damage, target.stats.max_hp())
	)
	# Getting hurt erodes Resolve (no-op for enemies).
	target.meters.add(
		MetersComponent.RESOLVE,
		-RESOLVE_DAMAGE_TAKEN_SCALE * float(damage) / float(target.stats.max_hp())
	)


static func _try_apply_status(
	entry: Dictionary,
	actor: BaseCombatant,
	target: BaseCombatant,
	rng: RandomNumberGenerator,
	result: Dictionary
) -> void:
	var status_id: String = String(entry.get("status_id", ""))
	var data: StatusData = StatusLibrary.load_status(status_id)
	if data == null:
		return
	var applied: Dictionary = target.status.try_apply(
		data,
		float(entry.get("base_chance", 50.0)),
		float(actor.stats.get_stat("focus")),
		float(target.stats.get_stat("ward")),
		target.resolve_for_math(),
		rng.randf() * 100.0,
		rng.randf(),
		int(entry.get("base_duration", 0))
	)
	if not applied["landed"]:
		return
	var applied_ids: Array[String] = result["statuses_applied"]
	applied_ids.append(status_id)
	var drop: int = applied["resolve_drop"]
	if drop > 0:
		target.meters.add(MetersComponent.RESOLVE, -float(drop))
		result["resolve_drop"] = drop
