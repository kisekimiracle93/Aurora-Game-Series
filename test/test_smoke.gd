extends GutTest
## M0 smoke tests: the harness runs and a stub CharacterData resource loads.


func test_harness_runs() -> void:
	assert_eq(1 + 1, 2, "GUT is alive")


func test_character_data_stub_loads() -> void:
	var data: CharacterData = load("res://data/characters/bastil.tres") as CharacterData
	assert_not_null(data, "bastil.tres should load as CharacterData")
	if data == null:
		return
	assert_eq(data.name, "Bastil")
	assert_eq(data.class_type, "Aetherion")
	assert_eq(data.element, "Fire")
	assert_false(data.is_heir)
	assert_eq(int(data.base_stats["hp"]), 340)
	assert_eq(String(data.affinities["Fire"]), "resist")
	assert_has(data.ability_ids, "attack_basic")
