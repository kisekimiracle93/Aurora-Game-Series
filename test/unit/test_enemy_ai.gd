extends GutTest
## M4: EnemyAI target priority (merc -> low Resolve -> high Darkness) and
## ability selection.


func _rng(seed_value: int = 7) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _player(
	player_name: String, resolve: float, darkness: float = -1.0, merc: bool = false
) -> BaseCombatant:
	var data: CharacterData = CharacterData.new()
	data.name = player_name
	data.is_merc = merc
	data.is_heir = darkness >= 0.0
	data.base_stats = {
		"hp": 200, "aether": 30, "power": 20, "focus": 20, "guard": 15, "ward": 15,
		"speed": 25, "accuracy": 95, "evasion": 5, "crit": 5,
	}
	var combatant: BaseCombatant = autofree(BaseCombatant.from_character(data))
	combatant.meters.set_value(MetersComponent.RESOLVE, resolve)
	if darkness >= 0.0:
		combatant.meters.set_value(MetersComponent.DARKNESS, darkness)
	return combatant


func test_priority_targets_merc_first() -> void:
	var merc: BaseCombatant = _player("Merc", 90.0, -1.0, true)
	var weak: BaseCombatant = _player("Weak", 10.0)
	var candidates: Array[BaseCombatant] = [weak, merc]
	assert_eq(EnemyAI.pick_target("priority", candidates, _rng()), merc)


func test_priority_falls_to_lowest_resolve_without_merc() -> void:
	var steady: BaseCombatant = _player("Steady", 80.0)
	var shaken: BaseCombatant = _player("Shaken", 35.0)
	var broken: BaseCombatant = _player("Broken", 12.0)
	var candidates: Array[BaseCombatant] = [steady, broken, shaken]
	assert_eq(EnemyAI.pick_target("priority", candidates, _rng()), broken)


func test_priority_resolve_tie_breaks_to_higher_darkness() -> void:
	var plain: BaseCombatant = _player("Plain", 40.0)
	var heir: BaseCombatant = _player("Heir", 40.0, 55.0)
	var candidates: Array[BaseCombatant] = [plain, heir]
	assert_eq(EnemyAI.pick_target("priority", candidates, _rng()), heir)


func test_hunt_dark_targets_highest_darkness() -> void:
	var low: BaseCombatant = _player("LowDark", 20.0, 15.0)
	var high: BaseCombatant = _player("HighDark", 90.0, 70.0)
	var merc: BaseCombatant = _player("Merc", 60.0, -1.0, true)
	var candidates: Array[BaseCombatant] = [merc, low, high]
	assert_eq(EnemyAI.pick_target("hunt_dark", candidates, _rng()), high)


func test_hunt_dark_falls_back_to_priority_when_no_darkness() -> void:
	var merc: BaseCombatant = _player("Merc", 60.0, -1.0, true)
	var plain: BaseCombatant = _player("Plain", 30.0)
	var candidates: Array[BaseCombatant] = [plain, merc]
	assert_eq(EnemyAI.pick_target("hunt_dark", candidates, _rng()), merc)


func test_basic_profile_returns_some_candidate() -> void:
	var a: BaseCombatant = _player("A", 60.0)
	var b: BaseCombatant = _player("B", 60.0)
	var candidates: Array[BaseCombatant] = [a, b]
	var picked: BaseCombatant = EnemyAI.pick_target("basic", candidates, _rng())
	assert_true(picked == a or picked == b)


func _wolf_like() -> BaseCombatant:
	var data: EnemyData = EnemyData.new()
	data.name = "TestWolf"
	data.base_stats = {
		"hp": 160, "aether": 0, "power": 26, "focus": 16, "guard": 16, "ward": 14,
		"speed": 26, "accuracy": 90, "evasion": 8, "crit": 5,
	}
	data.ability_ids = ["attack_basic", "fearful_howl"] as Array[String]
	return autofree(BaseCombatant.from_enemy(data))


func test_pick_ability_mixes_basic_and_specials() -> void:
	var wolf: BaseCombatant = _wolf_like()
	var rng: RandomNumberGenerator = _rng(123)
	var picked_basic: int = 0
	var picked_special: int = 0
	for i: int in range(200):
		var ability: AbilityData = EnemyAI.pick_ability(wolf, rng)
		assert_not_null(ability)
		if ability.id == "attack_basic":
			picked_basic += 1
		else:
			picked_special += 1
	assert_gt(picked_basic, picked_special, "basic attack dominates")
	assert_gt(picked_special, 0, "specials do come out")


func test_pick_ability_respects_silence() -> void:
	var wolf: BaseCombatant = _wolf_like()
	var silence: StatusData = load("res://data/statuses/silence.tres")
	wolf.status.try_apply(silence, 95.0, 50.0, 0.0, 60.0, 0.0)
	var rng: RandomNumberGenerator = _rng(9)
	for i: int in range(50):
		assert_eq(EnemyAI.pick_ability(wolf, rng).id, "attack_basic")


func test_pick_ability_never_uses_echo_guard_or_pray() -> void:
	var wolf: BaseCombatant = _wolf_like()
	for extra_id: String in ["guard", "pray", "echo_trial_by_fire"]:
		wolf.abilities.add_ability(AbilityLibrary.load_ability(extra_id))
	var rng: RandomNumberGenerator = _rng(77)
	for i: int in range(100):
		var ability: AbilityData = EnemyAI.pick_ability(wolf, rng)
		assert_false(ability.id in ["guard", "pray", "echo_trial_by_fire"])
