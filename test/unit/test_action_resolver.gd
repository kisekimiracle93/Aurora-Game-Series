extends GutTest
## M3 logic: ActionResolver wires the math into components (seeded, deterministic).

const EPS: float = 0.0001


func _rng(seed_value: int = 1234) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _make_player(
	hp: int = 300, power: int = 30, guard: int = 20, is_heir: bool = false
) -> BaseCombatant:
	var data: CharacterData = CharacterData.new()
	data.name = "TestPlayer"
	data.is_heir = is_heir
	data.base_stats = {
		"hp": hp,
		"aether": 50,
		"power": power,
		"focus": 30,
		"guard": guard,
		"ward": 20,
		"speed": 25,
		"accuracy": 100,
		"evasion": 0,
		"crit": 0,
	}
	data.affinities = {}
	var combatant: BaseCombatant = autofree(BaseCombatant.from_character(data))
	# Meter-neutral fixture: Duty/Burden multipliers pinned to 1.0 so the
	# hand-computed damage expectations stay exact.
	combatant.meters.set_value(MetersComponent.DUTY, 0.0)
	combatant.meters.set_value(MetersComponent.BURDEN, 0.0)
	return combatant


func _make_enemy(hp: int = 200, affinities: Dictionary = {}) -> BaseCombatant:
	var data: EnemyData = EnemyData.new()
	data.name = "TestEnemy"
	data.base_stats = {
		"hp": hp,
		"aether": 0,
		"power": 26,
		"focus": 16,
		"guard": 16,
		"ward": 14,
		"speed": 26,
		"accuracy": 100,
		"evasion": 0,
		"crit": 0,
	}
	data.affinities = affinities
	return autofree(BaseCombatant.from_enemy(data))


func _attack(coeff: float = 1.5, element: String = "Neutral") -> AbilityData:
	var ability: AbilityData = AbilityData.new()
	ability.id = "test_attack"
	ability.display_name = "Test Attack"
	ability.ability_type = "attack"
	ability.damage_type = "physical"
	ability.element = element
	ability.coeff = coeff
	return ability


func test_sure_hit_deals_damage_in_variance_band() -> void:
	var actor: BaseCombatant = _make_player()
	var target: BaseCombatant = _make_enemy()
	# (30*1.5 - 16*0.6) = 35.4 base; variance 0.95-1.05 -> 33.6..37.2 -> 34..37
	var results: Array[Dictionary] = ActionResolver.resolve_action(
		_attack(), actor, [target], _rng()
	)
	assert_false(results[0]["missed"])
	assert_between(int(results[0]["damage"]), 34, 37)
	assert_eq(target.stats.current_hp, 200 - int(results[0]["damage"]))


func test_immune_target_takes_zero() -> void:
	var actor: BaseCombatant = _make_player()
	var target: BaseCombatant = _make_enemy(200, {"Neutral": "immune"})
	var results: Array[Dictionary] = ActionResolver.resolve_action(
		_attack(), actor, [target], _rng()
	)
	assert_eq(int(results[0]["damage"]), 0)
	assert_eq(target.stats.current_hp, 200)
	assert_almost_eq(actor.meters.echo(), 0.0, EPS, "no echo for a null hit")


func test_absorb_heals_instead_of_damaging() -> void:
	var actor: BaseCombatant = _make_player()
	var target: BaseCombatant = _make_enemy(200, {"Neutral": "absorb"})
	target.stats.take_damage(100)
	var results: Array[Dictionary] = ActionResolver.resolve_action(
		_attack(), actor, [target], _rng()
	)
	assert_eq(int(results[0]["damage"]), 0)
	assert_gt(int(results[0]["healed"]), 0)
	assert_gt(target.stats.current_hp, 100)


func test_miss_rate_respects_low_hit_chance() -> void:
	var actor: BaseCombatant = _make_player()
	actor.stats.base_stats["accuracy"] = 0  # clamps to the 20% floor
	var rng: RandomNumberGenerator = _rng(777)
	var misses: int = 0
	var hits: int = 0
	for i: int in range(200):
		var target: BaseCombatant = _make_enemy(100000)
		var result: Dictionary = ActionResolver.resolve_action(
			_attack(), actor, [target], rng
		)[0]
		if result["missed"]:
			misses += 1
		else:
			hits += 1
	assert_gt(misses, hits, "at 20% hit chance, misses should dominate")
	assert_gt(hits, 0, "the 20% floor still lands sometimes")


func test_guard_roughly_halves_damage() -> void:
	var actor: BaseCombatant = _make_player()
	var exposed: BaseCombatant = _make_enemy()
	var guarding: BaseCombatant = _make_enemy()
	guarding.is_guarding = true
	# Same seed -> identical variance/crit rolls for both swings.
	var open_damage: int = int(
		ActionResolver.resolve_action(_attack(), actor, [exposed], _rng(42))[0]["damage"]
	)
	var guarded_damage: int = int(
		ActionResolver.resolve_action(_attack(), actor, [guarding], _rng(42))[0]["damage"]
	)
	assert_between(
		guarded_damage, int(floor(open_damage * 0.45)), int(ceil(open_damage * 0.55))
	)


func test_damage_grants_echo_and_erodes_target_resolve() -> void:
	var attacker: BaseCombatant = _make_player()
	var victim: BaseCombatant = _make_player()  # players have echo + resolve meters
	victim.stats.base_stats["evasion"] = 0
	var results: Array[Dictionary] = ActionResolver.resolve_action(
		_attack(), attacker, [victim], _rng()
	)
	var damage: int = int(results[0]["damage"])
	assert_gt(damage, 0)
	assert_almost_eq(
		attacker.meters.echo(),
		EchoMath.gain_from_damage_dealt(damage, attacker.stats.max_hp()),
		EPS
	)
	assert_almost_eq(
		victim.meters.echo(), EchoMath.gain_from_damage_taken(damage, victim.stats.max_hp()), EPS
	)
	assert_lt(victim.meters.resolve(), 60.0, "taking damage erodes Resolve")


func test_status_rider_applies_and_resolve_shock_drops_meter() -> void:
	var actor: BaseCombatant = _make_player()
	var victim: BaseCombatant = _make_player()
	var shock_spell: AbilityData = AbilityData.new()
	shock_spell.id = "test_shock"
	shock_spell.display_name = "Echo Roar"
	shock_spell.ability_type = "spell"
	shock_spell.damage_type = "none"  # pure status carrier: no accuracy roll
	shock_spell.coeff = 0.0
	shock_spell.statuses = [
		{"status_id": "resolve_shock", "base_chance": 300.0, "base_duration": 2}
	]
	var results: Array[Dictionary] = ActionResolver.resolve_action(
		shock_spell, actor, [victim], _rng()
	)
	# base_chance 300 clamps to 95; seeded roll lands it deterministically.
	var applied: Array[String] = results[0]["statuses_applied"]
	assert_has(applied, "resolve_shock")
	var drop: int = int(results[0]["resolve_drop"])
	assert_between(drop, 20, 40)
	assert_almost_eq(victim.meters.resolve(), 60.0 - float(drop), EPS)
	assert_true(victim.status.has_status("resolve_shock"))


func test_time_delay_pushes_target_ct_back() -> void:
	var actor: BaseCombatant = _make_player()
	var target: BaseCombatant = _make_enemy()
	target.ctb.advance(30, 26.0)  # ct 780
	var delay_spell: AbilityData = AbilityData.new()
	delay_spell.id = "test_delay"
	delay_spell.display_name = "Temporal Drag"
	delay_spell.ability_type = "spell"
	delay_spell.damage_type = "none"
	delay_spell.element = "Time"
	delay_spell.delay_amount = 350
	var results: Array[Dictionary] = ActionResolver.resolve_action(
		delay_spell, actor, [target], _rng()
	)
	assert_true(results[0]["delayed"])
	assert_almost_eq(target.ctb.ct, 430.0, EPS)


func test_heal_support_restores_hp() -> void:
	var healer: BaseCombatant = _make_player()
	var ally: BaseCombatant = _make_player()
	ally.stats.take_damage(150)
	var heal: AbilityData = AbilityData.new()
	heal.id = "test_heal"
	heal.display_name = "Benediction"
	heal.ability_type = "support"
	heal.damage_type = "none"
	heal.coeff = 2.0
	heal.heals = true
	var results: Array[Dictionary] = ActionResolver.resolve_action(heal, healer, [ally], _rng())
	# focus 30 * 2.0 = 60 +-5% -> 57..63
	assert_between(int(results[0]["healed"]), 57, 63)
	assert_eq(ally.stats.current_hp, 150 + int(results[0]["healed"]))


func test_heir_darkness_boosts_damage_via_layer_mod() -> void:
	var heir: BaseCombatant = _make_player(300, 30, 20, true)
	heir.meters.set_value(MetersComponent.DARKNESS, 60.0)  # x1.30 damage
	# Darkness also costs accuracy (-10 at 60); overshoot so the swing still
	# clamps to a guaranteed hit and the rng streams stay aligned.
	heir.stats.base_stats["accuracy"] = 200
	var plain: BaseCombatant = _make_player()
	var target_a: BaseCombatant = _make_enemy(100000)
	var target_b: BaseCombatant = _make_enemy(100000)
	var dark_damage: int = int(
		ActionResolver.resolve_action(_attack(), heir, [target_a], _rng(99))[0]["damage"]
	)
	var plain_damage: int = int(
		ActionResolver.resolve_action(_attack(), plain, [target_b], _rng(99))[0]["damage"]
	)
	assert_gt(dark_damage, plain_damage)
	assert_between(
		dark_damage, int(floor(plain_damage * 1.25)), int(ceil(plain_damage * 1.35))
	)
