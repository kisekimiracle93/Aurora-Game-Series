class_name EnemyAI
extends RefCounted
## Enemy decision-making (build plan M4). Pure static helpers over combatant
## getters — deterministic given the injected RNG, so fully testable headless.
##
## Profiles:
##  "priority"  — merc first, then lowest Resolve, tie-break highest Darkness.
##  "hunt_dark" — highest Darkness first (Icebound Stag's Instinctive Hunt);
##                falls back to "priority" when nobody carries Darkness.
##  "basic"     — random living target (M3 stub behavior).

## Chance an enemy with specials uses one instead of its basic attack.
const SPECIAL_CHANCE: float = 0.35


static func pick_target(
	profile: String, candidates: Array[BaseCombatant], rng: RandomNumberGenerator
) -> BaseCombatant:
	if candidates.is_empty():
		return null
	match profile:
		"hunt_dark":
			var darkest: BaseCombatant = null
			for candidate: BaseCombatant in candidates:
				if candidate.darkness_for_math() <= 0.0:
					continue
				if darkest == null or candidate.darkness_for_math() > darkest.darkness_for_math():
					darkest = candidate
			if darkest != null:
				return darkest
			return _priority_target(candidates)
		"priority":
			return _priority_target(candidates)
		_:
			return candidates[rng.randi_range(0, candidates.size() - 1)]


## Merc first; otherwise lowest Resolve, ties broken by highest Darkness.
static func _priority_target(candidates: Array[BaseCombatant]) -> BaseCombatant:
	for candidate: BaseCombatant in candidates:
		if candidate.is_merc:
			return candidate
	var best: BaseCombatant = null
	for candidate: BaseCombatant in candidates:
		if best == null:
			best = candidate
			continue
		var resolve: float = candidate.resolve_for_math()
		var best_resolve: float = best.resolve_for_math()
		if resolve < best_resolve:
			best = candidate
		elif resolve == best_resolve and candidate.darkness_for_math() > best.darkness_for_math():
			best = candidate
	return best


## Affordable, castable ability: mostly the basic attack, sometimes a special.
static func pick_ability(actor: BaseCombatant, rng: RandomNumberGenerator) -> AbilityData:
	var basic: AbilityData = null
	var specials: Array[AbilityData] = []
	for ability: AbilityData in actor.abilities.get_all():
		if not actor.stats.can_spend_aether(ability.aether_cost):
			continue
		if ability.ability_type == "spell" and actor.status.is_spell_blocked():
			continue
		if ability.ability_type == "echo":
			continue  # enemies don't use Echoes in the slice
		if ability.id == "attack_basic":
			basic = ability
		elif ability.id != "guard" and ability.id != "pray":
			specials.append(ability)
	if not specials.is_empty() and (basic == null or rng.randf() < SPECIAL_CHANCE):
		return specials[rng.randi_range(0, specials.size() - 1)]
	return basic if basic != null else (specials[0] if not specials.is_empty() else null)
