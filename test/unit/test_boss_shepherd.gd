extends GutTest
## M5: Frozen Shepherd — phase transitions, P1 script (Merc Freeze -> Summon ->
## Command), Overflow Resolve drain, Echo Roar / Ice Mirror / Hunt the Dark in
## P2, and the P3 Ice vulnerability + armor shed.

var _encounter: CombatEncounter
var _boss: BaseCombatant
var _controller: FrozenShepherdController
var _log_lines: Array[String] = []
var _actions: Array[Dictionary] = []
var _phases: Array[int] = []


func before_each() -> void:
	_log_lines = []
	_actions = []
	_phases = []


func after_each() -> void:
	# Summoned wolves have no scene parent in headless tests; free them.
	if _encounter != null:
		for enemy: BaseCombatant in _encounter.enemies:
			if enemy.get_parent() == null:
				enemy.free()


func _char(path: String) -> BaseCombatant:
	return autofree(BaseCombatant.from_character(load(path)))


func _full_party() -> Array[BaseCombatant]:
	return [
		_char("res://data/characters/bastil.tres"),
		_char("res://data/characters/cavene.tres"),
		_char("res://data/characters/jecht.tres"),
		_char("res://data/characters/mati.tres"),
		_char("res://data/characters/merc_lancer.tres"),
	]


func _build_boss_fight(party: Array[BaseCombatant], seed_value: int) -> void:
	_boss = autofree(BaseCombatant.from_enemy(load("res://data/enemies/frozen_shepherd.tres")))
	_controller = FrozenShepherdController.new()
	_controller.attach_to(_boss)  # becomes a child of the boss; freed with it
	_controller.phase_changed.connect(func(phase: int, _title: String) -> void:
		_phases.append(phase))
	_encounter = autofree(CombatEncounter.new())
	_encounter.setup(party, [_boss], seed_value)
	_encounter.register_boss_controller(_controller)
	_encounter.combat_log_line.connect(func(line: String) -> void: _log_lines.append(line))
	_encounter.action_resolved.connect(
		func(actor: BaseCombatant, ability: AbilityData, results: Array[Dictionary]) -> void:
			_actions.append({"actor": actor, "ability_id": ability.id, "results": results})
	)


func _boss_action_ids() -> Array[String]:
	var ids: Array[String] = []
	for action: Dictionary in _actions:
		if action["actor"] == _boss:
			ids.append(String(action["ability_id"]))
	return ids


## Everyone prays: the boss acts freely so we can observe its script.
func _pray_bots() -> void:
	_encounter.player_turn_started.connect(func(actor: BaseCombatant) -> void:
		_encounter.submit_player_action(actor.abilities.find_by_id("pray"), [actor]))


func _run_until_boss_turns(count: int) -> void:
	_pray_bots()
	_encounter.start()
	var guard_steps: int = 0
	while _controller.boss_turn_count < count and _encounter.state == CombatEncounter.State.AWAITING_PLAYER:
		guard_steps += 1
		if guard_steps > 500:
			break
		# pray-bots resume the loop automatically on each player turn; nothing
		# to do here — start() already drove until input, so just submit again.
		_encounter.submit_player_action(
			_encounter.current_actor.abilities.find_by_id("pray"), [_encounter.current_actor]
		)


func test_phase_one_script_freeze_summon_command() -> void:
	_build_boss_fight(_full_party(), 12345)
	_run_until_boss_turns(4)
	var ids: Array[String] = _boss_action_ids()
	assert_gte(ids.size(), 3)
	assert_eq(ids[0], "merc_freeze", "opener freezes the merc slot")
	assert_eq(ids[1], "summon_crystal_wolves")
	assert_eq(ids[2], "glacial_command")
	assert_eq(_encounter.enemies.size(), 3, "boss + 2 summoned Crystal Wolves")
	# The merc actually got frozen by the opener (95% clamp, seeded).
	var merc: BaseCombatant = _encounter.party[4]
	assert_true(merc.is_merc)
	var froze: bool = false
	for action: Dictionary in _actions:
		if action["ability_id"] == "merc_freeze":
			var applied: Array[String] = action["results"][0]["statuses_applied"]
			froze = applied.has("freeze")
	assert_true(froze, "Merc Freeze landed")


func test_overflow_pulse_drains_resolve_after_turn_six() -> void:
	_build_boss_fight(_full_party(), 777)
	_run_until_boss_turns(8)
	var overflow_lines: int = 0
	for line: String in _log_lines:
		if line.contains("Overflow Pulse"):
			overflow_lines += 1
	assert_gte(
		_controller.boss_turn_count,
		FrozenShepherdController.OVERFLOW_START_TURN,
		"sanity: the fight ran long enough to see overflow"
	)
	assert_gt(overflow_lines, 0, "the drain kicked in late-fight")
	assert_eq(
		overflow_lines,
		_controller.boss_turn_count - FrozenShepherdController.OVERFLOW_START_TURN + 1,
		"one pulse per boss turn from turn 7 on, never before"
	)


func test_phase_transitions_fire_at_60_and_25_percent() -> void:
	_build_boss_fight(_full_party(), 42)
	# No combat needed: drive HP directly; the controller listens to hp_changed.
	_boss.stats.take_damage(int(1500 * 0.45))  # -> 55% => P2
	assert_eq(_controller.phase, 2)
	assert_eq(_phases, [2] as Array[int])
	_boss.stats.take_damage(int(1500 * 0.35))  # -> 20% => P3
	assert_eq(_controller.phase, 3)
	assert_has(_phases, 3)


func test_phase_three_opens_ice_weakness_and_sheds_armor() -> void:
	_build_boss_fight(_full_party(), 42)
	var guard_before: int = _boss.stats.get_stat("guard")
	assert_eq(_boss.stats.affinity_for("Ice"), "resist")
	_boss.stats.take_damage(1200)  # straight to 20% (P1 -> P2 -> P3)
	assert_eq(_boss.stats.affinity_for("Ice"), "weak", "the Heirs' payoff")
	assert_lt(_boss.stats.get_stat("guard"), guard_before, "armor shed")
	assert_almost_eq(_boss.ferocity, FrozenShepherdController.P3_FEROCITY, 0.0001)
	assert_eq(_phases, [2, 3] as Array[int], "P2 cue is never skipped")


func test_phase_two_roars_then_raises_the_mirror() -> void:
	_build_boss_fight(_full_party(), 999)
	_boss.stats.take_damage(int(1500 * 0.45))  # enter P2 before any boss turn
	_run_until_boss_turns(3)
	var ids: Array[String] = _boss_action_ids()
	assert_gte(ids.size(), 2)
	assert_eq(ids[0], "echo_roar", "P2 announces itself with the Resolve Shock AoE")
	assert_has(ids, "ice_mirror")
	assert_eq(_boss.reflect_element, "Fire")
	assert_eq(_boss.reflect_charges, 1, "one Fire hit will rebound")


func test_ice_mirror_reflects_fire_once() -> void:
	var cavene: BaseCombatant = _char("res://data/characters/cavene.tres")
	_build_boss_fight([cavene], 31337)
	_boss.reflect_element = "Fire"
	_boss.reflect_charges = 1
	var flare: AbilityData = AbilityLibrary.load_ability("aetherflare")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var boss_hp: int = _boss.stats.current_hp
	var cavene_hp: int = cavene.stats.current_hp
	var first: Dictionary = ActionResolver.resolve_action(flare, cavene, [_boss], rng)[0]
	assert_true(first["reflected"], "the flame rebounds")
	assert_eq(_boss.stats.current_hp, boss_hp, "boss untouched")
	assert_lt(cavene.stats.current_hp, cavene_hp, "caster eats their own fire")
	assert_eq(_boss.reflect_charges, 0)
	var second: Dictionary = ActionResolver.resolve_action(flare, cavene, [_boss], rng)[0]
	if not second["missed"]:
		assert_false(second["reflected"], "mirror spent: damage lands")
		assert_lt(_boss.stats.current_hp, boss_hp)


func test_phase_two_hunts_the_dark() -> void:
	var party: Array[BaseCombatant] = _full_party()
	var jecht: BaseCombatant = party[2]
	jecht.meters.set_value(MetersComponent.DARKNESS, 60.0)
	_build_boss_fight(party, 2026)
	_boss.stats.take_damage(int(1500 * 0.45))  # P2
	_run_until_boss_turns(4)
	# After roar + mirror, single-target attacks stalk the highest Darkness.
	for action: Dictionary in _actions:
		if action["actor"] != _boss:
			continue
		if String(action["ability_id"]) == "glacial_rake":
			var results: Array[Dictionary] = action["results"]
			assert_eq(results[0]["target"], jecht, "Hunt the Dark")
			return
	# Rake may not surface within 4 turns on some scripts — fail loudly if so.
	fail_test("no glacial_rake observed in the first P2 turns; widen the run")
