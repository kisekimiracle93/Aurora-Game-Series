extends GutTest
## M4: encounter-level flow for the new kit mechanics — Echo gating/spending,
## Pray, Rally (Resolve gain), AoE spells, Darkness costs, heals, merc aggro.

var _encounter: CombatEncounter
var _log_lines: Array[String] = []
var _actions: Array[Dictionary] = []  # {actor, ability_id, results}


func before_each() -> void:
	_log_lines = []
	_actions = []


func _char(path: String) -> BaseCombatant:
	return autofree(BaseCombatant.from_character(load(path)))


func _enemy(path: String) -> BaseCombatant:
	return autofree(BaseCombatant.from_enemy(load(path)))


func _build(party: Array[BaseCombatant], enemies: Array[BaseCombatant], seed_value: int) -> void:
	_encounter = autofree(CombatEncounter.new())
	_encounter.setup(party, enemies, seed_value)
	_encounter.combat_log_line.connect(func(line: String) -> void: _log_lines.append(line))
	_encounter.action_resolved.connect(
		func(actor: BaseCombatant, ability: AbilityData, results: Array[Dictionary]) -> void:
			_actions.append({"actor": actor, "ability_id": ability.id, "results": results})
	)


func _log_text() -> String:
	return "\n".join(_log_lines)


## One-shot player script: first player turn runs `first`, later turns attack.
func _script_first_turn(first: Callable) -> void:
	var used: Array[bool] = []
	_encounter.player_turn_started.connect(func(actor: BaseCombatant) -> void:
		if used.is_empty():
			used.append(true)
			first.call(actor)
		else:
			var targets: Array[BaseCombatant] = _encounter.living(_encounter.enemies)
			if not targets.is_empty():
				_encounter.submit_player_action(
					actor.abilities.find_by_id("attack_basic"), [targets[0]]
				))


func test_echo_requires_full_gauge_then_spends_it() -> void:
	var bastil: BaseCombatant = _char("res://data/characters/bastil.tres")
	_build([bastil], [_enemy("res://data/enemies/aether_wolf.tres")], 42)
	_encounter.start()
	assert_eq(_encounter.state, CombatEncounter.State.AWAITING_PLAYER)
	var pyre: AbilityData = bastil.abilities.find_by_id("echo_living_pyre")
	# Gauge empty (or merely chip-filled from the wolf's opener): refused.
	_encounter.submit_player_action(pyre, _encounter.living(_encounter.enemies))
	assert_eq(_encounter.state, CombatEncounter.State.AWAITING_PLAYER, "echo gated")
	assert_string_contains(_log_text(), "Echo gauge is not full")
	# Fill it and go.
	bastil.meters.set_value(MetersComponent.ECHO, 100.0)
	_encounter.submit_player_action(pyre, _encounter.living(_encounter.enemies))
	assert_lt(bastil.meters.echo(), 100.0, "gauge spent (then partially refilled by damage)")
	var found: bool = false
	for action: Dictionary in _actions:
		if action["ability_id"] == "echo_living_pyre":
			found = true
			assert_gt(int(action["results"][0]["damage"]), 0, "the pyre burns")
	assert_true(found, "echo actually resolved")


func test_pray_passes_the_turn_doing_nothing() -> void:
	var bastil: BaseCombatant = _char("res://data/characters/bastil.tres")
	var wolf: BaseCombatant = _enemy("res://data/enemies/aether_wolf.tres")
	_build([bastil], [wolf], 1337)
	_encounter.start()
	var pray: AbilityData = bastil.abilities.find_by_id("pray")
	var wolf_hp: int = wolf.stats.current_hp
	var actions_before: int = _actions.size()
	_encounter.submit_player_action(pray, [bastil])
	assert_string_contains(_log_text(), "prays, leaving themselves open")
	assert_eq(wolf.stats.current_hp, wolf_hp, "pray harms nothing")
	# The Heavy cost pushed Bastil back, so the wolf got at least one free turn
	# before control returned to the player.
	assert_eq(_encounter.state, CombatEncounter.State.AWAITING_PLAYER)
	var enemy_acted: bool = false
	for i: int in range(actions_before, _actions.size()):
		var actor: BaseCombatant = _actions[i]["actor"]
		if not actor.is_player_controlled:
			enemy_acted = true
	assert_true(enemy_acted, "the wolf swung freely while Bastil prayed")


func test_rally_by_flame_restores_ally_resolve() -> void:
	var bastil: BaseCombatant = _char("res://data/characters/bastil.tres")
	var mati: BaseCombatant = _char("res://data/characters/mati.tres")
	mati.meters.set_value(MetersComponent.RESOLVE, 40.0)
	_build([bastil, mati], [_enemy("res://data/enemies/aether_wolf.tres")], 2025)
	# Whoever can rally does so once; everyone else just attacks.
	var rallied: Array[bool] = []
	_encounter.player_turn_started.connect(func(actor: BaseCombatant) -> void:
		var rally: AbilityData = actor.abilities.find_by_id("rally_by_flame")
		if rally != null and rallied.is_empty():
			rallied.append(true)
			_encounter.submit_player_action(rally, [mati])
			return
		var targets: Array[BaseCombatant] = _encounter.living(_encounter.enemies)
		if not targets.is_empty():
			_encounter.submit_player_action(
				actor.abilities.find_by_id("attack_basic"), [targets[0]]
			))
	_encounter.start()
	for action: Dictionary in _actions:
		if action["ability_id"] == "rally_by_flame":
			assert_eq(int(action["results"][0]["resolve_gain"]), 15)
			return
	fail_test("rally_by_flame was never cast; adjust the script")


func test_absolute_zero_costs_darkness_and_hits_every_enemy() -> void:
	var jecht: BaseCombatant = _char("res://data/characters/jecht.tres")
	var wolves: Array[BaseCombatant] = [
		_enemy("res://data/enemies/aether_wolf.tres"),
		_enemy("res://data/enemies/aether_wolf.tres"),
	]
	_build([jecht], wolves, 31415)
	_script_first_turn(func(actor: BaseCombatant) -> void:
		_encounter.submit_player_action(
			actor.abilities.find_by_id("absolute_zero"), _encounter.living(_encounter.enemies)
		))
	_encounter.start()
	assert_almost_eq(jecht.meters.darkness(), 30.0, 0.0001, "the Heir pays in Darkness")
	for action: Dictionary in _actions:
		if action["ability_id"] == "absolute_zero":
			var results: Array[Dictionary] = action["results"]
			assert_eq(results.size(), 2, "AoE resolves once per enemy")
			return
	fail_test("absolute_zero never resolved")


func test_glacial_benediction_heals_in_the_expected_band() -> void:
	var mati: BaseCombatant = _char("res://data/characters/mati.tres")
	var bastil: BaseCombatant = _char("res://data/characters/bastil.tres")
	bastil.stats.take_damage(120)
	_build([mati, bastil], [_enemy("res://data/enemies/aether_wolf.tres")], 555)
	_script_first_turn(func(actor: BaseCombatant) -> void:
		var heal: AbilityData = actor.abilities.find_by_id("glacial_benediction")
		if heal != null:
			_encounter.submit_player_action(heal, [bastil])
		else:
			_encounter.submit_player_action(
				actor.abilities.find_by_id("attack_basic"), _encounter.living(_encounter.enemies)
			))
	_encounter.start()
	for action: Dictionary in _actions:
		if action["ability_id"] == "glacial_benediction":
			# focus 36 * 2.2 = 79.2, variance 0.95-1.05 -> 75..83
			assert_between(int(action["results"][0]["healed"]), 75, 83)
			return
	fail_test("glacial_benediction never cast")


func test_enemies_dogpile_the_merc_first() -> void:
	var party: Array[BaseCombatant] = [
		_char("res://data/characters/bastil.tres"),
		_char("res://data/characters/cavene.tres"),
		_char("res://data/characters/jecht.tres"),
		_char("res://data/characters/mati.tres"),
		_char("res://data/characters/merc_lancer.tres"),
	]
	_build(party, [_enemy("res://data/enemies/aether_wolf.tres")], 8080)
	_encounter.player_turn_started.connect(func(actor: BaseCombatant) -> void:
		_encounter.submit_player_action(actor.abilities.find_by_id("pray"), [actor]))
	_encounter.battle_ended.connect(func(_v: bool) -> void: pass)
	_encounter.start()
	# Walk every enemy action: single-target picks must aim at the merc while
	# the merc lives (the wolf's howl or bite — both run the priority list).
	var enemy_actions: int = 0
	for action: Dictionary in _actions:
		var actor: BaseCombatant = action["actor"]
		if actor.is_player_controlled:
			continue
		enemy_actions += 1
		var results: Array[Dictionary] = action["results"]
		if results.size() == 1:
			var target: BaseCombatant = results[0]["target"]
			assert_true(target.is_merc, "priority AI aims at the merc")
		if enemy_actions >= 4:
			break
	assert_gt(enemy_actions, 0, "the wolf actually took turns")
