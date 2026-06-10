extends GutTest
## M4: content sanity — kits load, coefficients stay inside build-plan ranges,
## echo costs in range, the merc carries no magic, enemies are wired for AI.

const PARTY: Dictionary = {
	"res://data/characters/bastil.tres": 6,
	"res://data/characters/cavene.tres": 6,
	"res://data/characters/jecht.tres": 6,
	"res://data/characters/mati.tres": 6,
}


func _all_ability_files() -> Array[String]:
	var paths: Array[String] = []
	var dir: DirAccess = DirAccess.open("res://data/abilities")
	assert_not_null(dir)
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			paths.append("res://data/abilities/" + file_name)
		file_name = dir.get_next()
	return paths


func test_party_kits_load_with_one_echo_each() -> void:
	for path: String in PARTY:
		var data: CharacterData = load(path)
		assert_eq(data.ability_ids.size(), PARTY[path], "%s kit size" % data.name)
		var abilities: Array[AbilityData] = AbilityLibrary.load_many(data.ability_ids)
		assert_eq(abilities.size(), data.ability_ids.size(), "%s: every id resolves" % data.name)
		var echo_count: int = 0
		for ability: AbilityData in abilities:
			if ability.ability_type == "echo":
				echo_count += 1
		assert_eq(echo_count, 1, "%s has exactly one Echo" % data.name)


func test_heir_flags_and_passives() -> void:
	var jecht: CharacterData = load("res://data/characters/jecht.tres")
	assert_true(jecht.is_heir)
	assert_true(jecht.darkness_speed_passive)
	var mati: CharacterData = load("res://data/characters/mati.tres")
	assert_true(mati.is_heir)
	assert_false(mati.darkness_speed_passive)
	# Darkness costs live only on Heir kits.
	for path: String in PARTY:
		var data: CharacterData = load(path)
		var has_dark_cost: bool = false
		for ability: AbilityData in AbilityLibrary.load_many(data.ability_ids):
			if ability.darkness_cost > 0:
				has_dark_cost = true
		assert_eq(has_dark_cost, data.is_heir, "%s darkness costs match heir flag" % data.name)


func test_merc_is_fragile_and_magicless() -> void:
	var merc: CharacterData = load("res://data/characters/merc_lancer.tres")
	assert_true(merc.is_merc)
	assert_false(merc.is_heir)
	assert_eq(int(merc.base_stats["aether"]), 0)
	assert_lt(int(merc.base_stats["hp"]), 260, "lowest HP in the party")
	for ability: AbilityData in AbilityLibrary.load_many(merc.ability_ids):
		assert_eq(ability.aether_cost, 0, "%s costs no aether" % ability.id)
		assert_ne(ability.ability_type, "spell", "%s is not magic" % ability.id)
		assert_ne(ability.ability_type, "echo", "merc has no Echo")


func test_ability_coeffs_and_costs_within_plan_ranges() -> void:
	var files: Array[String] = _all_ability_files()
	assert_gt(files.size(), 15)
	for path: String in files:
		var ability: AbilityData = load(path)
		assert_not_null(ability, path)
		if ability.coeff > 0.0 and ability.damage_type == "physical":
			assert_between(ability.coeff, 1.2, 3.5, "%s SkillCoeff" % ability.id)
		elif ability.coeff > 0.0 and ability.damage_type == "magic":
			assert_between(ability.coeff, 1.3, 4.0, "%s SpellCoeff" % ability.id)
		if ability.ability_type == "echo":
			assert_between(ability.ct_cost, 1200, 1500, "%s echo CT cost" % ability.id)
		else:
			assert_between(ability.ct_cost, 650, 1350, "%s CT cost" % ability.id)
		for entry: Dictionary in ability.statuses:
			var status: StatusData = StatusLibrary.load_status(String(entry["status_id"]))
			assert_not_null(status, "%s references real status" % ability.id)


func test_enemy_roster_wiring() -> void:
	var wolf: EnemyData = load("res://data/enemies/aether_wolf.tres")
	assert_eq(wolf.ai_profile, "priority")
	assert_has(wolf.ability_ids, "fearful_howl")
	assert_eq(String(wolf.affinities["Fire"]), "weak")
	assert_eq(String(wolf.affinities["Ice"]), "resist")

	var stag: EnemyData = load("res://data/enemies/icebound_stag.tres")
	assert_eq(stag.ai_profile, "hunt_dark")
	assert_almost_eq(stag.stability, 0.3, 0.0001)
	assert_has(stag.ability_ids, "glacial_breath")
	var breath: AbilityData = AbilityLibrary.load_ability("glacial_breath")
	assert_eq(breath.targeting, "aoe")
	assert_gt(int(stag.base_stats["hp"]), 300, "mini-elite bulk")

	var crystal: EnemyData = load("res://data/enemies/crystal_wolf.tres")
	assert_eq(String(crystal.affinities["Ice"]), "absorb")
	assert_eq(String(crystal.affinities["Fire"]), "weak")
	assert_gt(int(crystal.base_stats["speed"]), 26, "fast add")


func test_pray_is_a_true_noop_action() -> void:
	var pray: AbilityData = AbilityLibrary.load_ability("pray")
	assert_eq(pray.ability_type, "support")
	assert_eq(pray.damage_type, "none")
	assert_almost_eq(pray.coeff, 0.0, 0.0001)
	assert_eq(pray.aether_cost, 0)
	assert_eq(pray.targeting, "self")
	assert_false(pray.heals)
	assert_eq(pray.statuses.size(), 0)
	assert_eq(pray.ct_cost, 1100, "Heavy: praying leaves you open")
