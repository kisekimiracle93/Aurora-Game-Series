extends GutTest
## The depth loop: keepsakes (owner-locked, meter-moving), relics (permanent
## HP), forced-encounter intros with meter strikes, foe rewards + the hoard
## trade-off (buffed Shepherd), the Selinoran Deep, and slower patrols.

const KEEPSAKES: Dictionary = {
	"item_holy_water": "Cavene",
	"item_childs_letter": "Bastil",
	"item_parents_ring": "Jecht",
	"item_snow_totem": "Mati",
}
const RELICS: Dictionary = {
	"item_warden_sigil": "Bastil",
	"item_pale_antler": "Mati",
	"item_predator_fang": "Jecht",
	"item_gilded_censer": "Cavene",
}

var _world: Node


func before_each() -> void:
	_world = get_node_or_null("/root/WorldState")
	if _world != null:
		_world.reset_run()


func after_each() -> void:
	if _world != null:
		_world.reset_run()


func _member(path: String) -> BaseCombatant:
	return autofree(BaseCombatant.from_character(load(path)))


func test_keepsakes_are_owner_locked_hearts() -> void:
	for item_id: String in KEEPSAKES:
		var item: AbilityData = AbilityLibrary.load_ability(item_id)
		assert_not_null(item, item_id)
		if item == null:
			continue
		assert_eq(item.owner_only, KEEPSAKES[item_id], item_id + " belongs to one hand")
		assert_true(item.is_item and item.targeting == "self", item_id)
		assert_false(item.meter_effects.is_empty(), item_id + " moves the heart")
		assert_gt(item.description.length(), 10, item_id + " carries its clue")
		assert_gt(item.use_line.length(), 5, item_id + " has words for its owner")


func test_relics_bless_forty_hp_each_to_a_different_pilgrim() -> void:
	var owners: Array[String] = []
	for item_id: String in RELICS:
		var item: AbilityData = AbilityLibrary.load_ability(item_id)
		assert_not_null(item, item_id)
		if item == null:
			continue
		assert_eq(item.permanent_hp, 40, item_id)
		assert_eq(item.owner_only, RELICS[item_id], item_id)
		owners.append(item.owner_only)
	assert_eq(owners.size(), 4)
	for member_name: String in ["Bastil", "Cavene", "Jecht", "Mati"]:
		assert_has(owners, member_name, "every pilgrim has a relic waiting")


func test_keepsake_blocked_rule() -> void:
	var battle_script: GDScript = load("res://world/battle_test.gd")
	var bastil: BaseCombatant = _member("res://data/characters/bastil.tres")
	var letter: AbilityData = AbilityLibrary.load_ability("item_childs_letter")
	var phial: AbilityData = AbilityLibrary.load_ability("item_holy_water")
	var potion: AbilityData = AbilityLibrary.load_ability("item_hp_potion")
	assert_false(battle_script.keepsake_blocked(letter, bastil), "his letter answers him")
	assert_true(battle_script.keepsake_blocked(phial, bastil), "her phial stays cold")
	assert_false(battle_script.keepsake_blocked(potion, bastil), "plain items serve anyone")


func test_keepsake_and_relic_resolve_on_use() -> void:
	var bastil: BaseCombatant = _member("res://data/characters/bastil.tres")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var duty_before: float = bastil.meters.duty()
	var resolve_before: float = bastil.meters.resolve()
	var letter: AbilityData = AbilityLibrary.load_ability("item_childs_letter")
	ActionResolver.resolve_action(letter, bastil, [bastil] as Array[BaseCombatant], rng)
	assert_almost_eq(bastil.meters.duty(), duty_before + 15.0, 0.001, "the letter steels duty")
	assert_almost_eq(bastil.meters.resolve(), resolve_before + 12.0, 0.001)
	var hp_before: int = bastil.stats.max_hp()
	var sigil: AbilityData = AbilityLibrary.load_ability("item_warden_sigil")
	var results: Array[Dictionary] = ActionResolver.resolve_action(
		sigil, bastil, [bastil] as Array[BaseCombatant], rng
	)
	assert_eq(bastil.stats.max_hp(), hp_before + 40, "the sigil widens the vessel")
	assert_eq(int(results[0].get("permanent_hp", 0)), 40)


func test_blessings_persist_through_world_state() -> void:
	_world.hp_blessings["Bastil"] = 40
	var fresh: BaseCombatant = _member("res://data/characters/bastil.tres")
	var base: int = fresh.stats.max_hp()
	_world.apply_to_member(fresh)
	assert_eq(fresh.stats.max_hp(), base + 40, "the run remembers the relic")


func test_forced_encounter_intros_cover_every_gate() -> void:
	var battle_script: GDScript = load("res://world/battle_test.gd")
	for roster: String in ["gate_warden", "pass_horror", "deep_predator", "hoarfang"]:
		assert_true(battle_script.INTROS.has(roster), roster + " speaks before it strikes")
		var intro: Dictionary = battle_script.INTROS[roster]
		assert_gt((intro["enemy_lines"] as Array).size(), 0, roster)
		for strike: Dictionary in intro["strikes"]:
			for member_name: String in strike["names"]:
				assert_has(
					["Bastil", "Cavene", "Jecht", "Mati"], member_name,
					roster + " strikes a real pilgrim"
				)
		var paths: Array[String] = battle_script.enemy_paths_for(roster)
		assert_gt(paths.size(), 0, roster)
		for path: String in paths:
			assert_true(ResourceLoader.exists(path), path)


func test_new_foes_have_unique_movesets() -> void:
	var expected: Dictionary = {
		"gate_warden": "measuring_blow",
		"pass_horror": "rending_howl",
		"selinoran_predator": "pounce",
		"hoarfang": "gluttonous_bite",
	}
	for foe_name: String in expected:
		var data: EnemyData = load("res://data/enemies/%s.tres" % foe_name)
		assert_not_null(data, foe_name)
		if data == null:
			continue
		assert_has(data.ability_ids, expected[foe_name], foe_name + " signature move")
		for ability_id: String in data.ability_ids:
			assert_not_null(AbilityLibrary.load_ability(ability_id), ability_id)
	var warden: EnemyData = load("res://data/enemies/gate_warden.tres")
	var predator: EnemyData = load("res://data/enemies/selinoran_predator.tres")
	assert_lt(int(warden.base_stats["hp"]), int(predator.base_stats["hp"]),
		"the gates grow teeth as the road goes on")


func test_hoard_rewards_and_the_shepherds_price() -> void:
	_world.in_world_run = true
	_world.pending_foe_id = "fields_hoarfang"
	var resolve_before: float = float(_world.party_meters["Bastil"]["resolve"])
	_world._grant_foe_rewards("fields_hoarfang")
	assert_true(_world.hoard_blessing, "the trade is struck")
	assert_gt(_world.item_count("item_gilded_censer"), 0, "the censer is in the hoard")
	assert_gt(_world.item_count("item_hp_potion"), 2, "potions pour out")
	assert_almost_eq(
		float(_world.party_meters["Bastil"]["resolve"]), resolve_before + 20.0, 0.001
	)
	# And each forced gate drops its relic.
	_world.reset_run()
	_world._grant_foe_rewards("gate_town_warden")
	assert_eq(_world.item_count("item_warden_sigil"), 1)


func test_selinoran_deep_boots_dark_and_narrow() -> void:
	var area: AreaBase = load("res://world/deep_woods.tscn").instantiate()
	add_child_autofree(area)
	await get_tree().process_frame
	assert_not_null(area.player, "player walks the deep")
	assert_eq(area.map_size, Vector2(1800, 3600), "tall, not wide")
	assert_gt(area.firefly_scale, 1.5, "bigger fireflies, as ordered")
	assert_gt(area.cloud_density, 1.4)
	assert_eq(area.ambience_profile, "deepwoods")
	var torches: int = 0
	for node: Node in get_tree().get_nodes_in_group("torch_light"):
		if area.is_ancestor_of(node):
			torches += 1
	assert_eq(torches, 2, "the deep keeps few lights")
	assert_false(area.get("_raining"), "dry until the rain line")


func test_deepwoods_soundscape_and_rain_voices() -> void:
	var script: GDScript = load("res://world/soundscape_manager.gd")
	assert_has(script.beds_for("deepwoods", false), "crickets", "always dusk under there")
	assert_has(script.oneshots_for("deepwoods", true), "wolf_howl")
	assert_not_null(script.synth_stream("rain"), "the rain has a voice")
	assert_not_null(script.synth_stream("thunder"))
	assert_lt(OverworldFoe.PATROL_SPEED, 60.0, "basic foes amble now")
