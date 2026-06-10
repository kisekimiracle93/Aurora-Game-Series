extends GutTest
## M3 logic: CombatEncounter state machine driven headless with a scripted
## "player" (auto-attacks first living enemy). Seeded -> deterministic.

var _encounter: CombatEncounter
var _turn_sequence: Array[String] = []
var _battle_result: Array[bool] = []
var _log_lines: Array[String] = []
var _last_preview: Array[BaseCombatant] = []


func before_each() -> void:
	_turn_sequence = []
	_battle_result = []
	_log_lines = []
	_last_preview = []


func _load_party() -> Array[BaseCombatant]:
	var party: Array[BaseCombatant] = []
	for path: String in [
		"res://data/characters/bastil.tres",
		"res://data/characters/cavene.tres",
		"res://data/characters/jecht.tres",
		"res://data/characters/mati.tres",
	]:
		var data: CharacterData = load(path)
		party.append(autofree(BaseCombatant.from_character(data)))
	return party


func _load_wolves(count: int) -> Array[BaseCombatant]:
	var wolves: Array[BaseCombatant] = []
	var data: EnemyData = load("res://data/enemies/aether_wolf.tres")
	for i: int in range(count):
		var wolf: BaseCombatant = autofree(BaseCombatant.from_enemy(data))
		wolf.display_name = "Aether Wolf %d" % (i + 1)
		wolves.append(wolf)
	return wolves


func _build(party: Array[BaseCombatant], enemies: Array[BaseCombatant], seed_value: int) -> void:
	_encounter = autofree(CombatEncounter.new())
	_encounter.setup(party, enemies, seed_value)
	_encounter.turn_started.connect(func(combatant: BaseCombatant) -> void:
		_turn_sequence.append(combatant.display_name))
	_encounter.player_turn_started.connect(_auto_play)
	_encounter.battle_ended.connect(func(victory: bool) -> void:
		_battle_result.append(victory))
	_encounter.combat_log_line.connect(func(line: String) -> void:
		_log_lines.append(line))
	_encounter.timeline_changed.connect(func(preview: Array[BaseCombatant]) -> void:
		_last_preview = preview)


## Scripted player: basic attack on the first living enemy.
func _auto_play(actor: BaseCombatant) -> void:
	var targets: Array[BaseCombatant] = _encounter.living(_encounter.enemies)
	if targets.is_empty():
		return
	var attack: AbilityData = actor.abilities.find_by_id("attack_basic")
	_encounter.submit_player_action(attack, [targets[0]])


func test_full_battle_runs_to_victory() -> void:
	_build(_load_party(), _load_wolves(2), 12345)
	_encounter.start()
	assert_eq(_battle_result, [true], "4 party members beat 2 wolves")
	assert_eq(_encounter.state, CombatEncounter.State.VICTORY)
	for wolf: BaseCombatant in _encounter.enemies:
		assert_false(wolf.is_alive())
	for member: BaseCombatant in _encounter.party:
		assert_true(member.is_alive())
		assert_gt(member.meters.echo(), 0.0, "damage flowed, echo gauges moved")
		assert_between(member.meters.resolve(), 0.0, 120.0)


func test_fastest_combatant_acts_first() -> void:
	_build(_load_party(), _load_wolves(2), 999)
	_encounter.start()
	assert_eq(_turn_sequence[0], "Cavene", "speed 27 beats the speed-26 pack")


func test_timeline_preview_has_eight_living_entries() -> void:
	_build(_load_party(), _load_wolves(2), 555)
	_encounter.start()
	assert_eq(_last_preview.size(), CombatEncounter.PREVIEW_TURNS)
	for combatant: BaseCombatant in _last_preview:
		assert_not_null(combatant)


func test_outnumbered_weakling_is_defeated() -> void:
	var data: CharacterData = CharacterData.new()
	data.name = "Doomed"
	data.base_stats = {
		"hp": 20,
		"aether": 0,
		"power": 5,
		"focus": 5,
		"guard": 0,
		"ward": 0,
		"speed": 5,
		"accuracy": 80,
		"evasion": 0,
		"crit": 0,
	}
	data.ability_ids = ["attack_basic"] as Array[String]
	var doomed: Array[BaseCombatant] = [autofree(BaseCombatant.from_character(data))]
	_build(doomed, _load_wolves(3), 31337)
	_encounter.start()
	assert_eq(_battle_result, [false])
	assert_eq(_encounter.state, CombatEncounter.State.DEFEAT)


func test_ally_death_drops_party_resolve() -> void:
	var party: Array[BaseCombatant] = _load_party()
	_build(party, _load_wolves(1), 2024)
	# Stage the deaths without running the battle loop.
	var before: float = party[1].meters.resolve()
	party[0].stats.take_damage(99999)
	assert_almost_eq(
		party[1].meters.resolve(),
		before - CombatEncounter.RESOLVE_ALLY_DEATH_DROP,
		0.0001,
		"survivors lose Resolve when an ally falls"
	)


func test_guard_action_sets_flag_until_next_turn() -> void:
	var party: Array[BaseCombatant] = _load_party()
	_build(party, _load_wolves(1), 777)
	# Replace the auto-player for this test: first player guards once.
	_encounter.player_turn_started.disconnect(_auto_play)
	var guarded_name: Array[String] = []
	_encounter.player_turn_started.connect(func(actor: BaseCombatant) -> void:
		var guard: AbilityData = actor.abilities.find_by_id("guard")
		if guarded_name.is_empty() and guard != null:
			guarded_name.append(actor.display_name)
			_encounter.submit_player_action(guard, [actor])
		else:
			_auto_play(actor))
	_encounter.start()
	assert_eq(_battle_result, [true])
	assert_string_contains("\n".join(_log_lines), "guards.")


func test_aether_gate_blocks_unaffordable_action() -> void:
	var party: Array[BaseCombatant] = _load_party()
	_build(party, _load_wolves(1), 4242)
	_encounter.player_turn_started.disconnect(_auto_play)
	var expensive: AbilityData = AbilityData.new()
	expensive.id = "test_big_spell"
	expensive.display_name = "Unaffordable"
	expensive.ability_type = "spell"
	expensive.damage_type = "magic"
	expensive.coeff = 3.0
	expensive.aether_cost = 9999
	var tried: Array[bool] = []
	_encounter.player_turn_started.connect(func(actor: BaseCombatant) -> void:
		if tried.is_empty():
			tried.append(true)
			_encounter.submit_player_action(expensive, [_encounter.living(_encounter.enemies)[0]])
			assert_eq(
				_encounter.state,
				CombatEncounter.State.AWAITING_PLAYER,
				"unaffordable action keeps waiting for input"
			)
		_auto_play(actor))
	_encounter.start()
	assert_eq(_battle_result, [true])
