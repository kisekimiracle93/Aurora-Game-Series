extends GutTest
## M7, the last milestone: the memory crystal wakes Phi's echo, and Selenora
## holds the gate until five farewells are spoken.

var _world: Node


func before_each() -> void:
	_world = get_node_or_null("/root/WorldState")
	if _world != null:
		_world.reset_run()
	SaveSystem.delete()


func after_each() -> void:
	if _world != null:
		_world.reset_run()
	SaveSystem.delete()


func test_the_promised_ocean_is_a_true_echo() -> void:
	var ocean: AbilityData = AbilityLibrary.load_ability("echo_promised_ocean")
	assert_not_null(ocean)
	if ocean == null:
		return
	assert_eq(ocean.ability_type, "echo", "gated behind a full gauge")
	assert_true(ocean.heals, "it mends, in his memory")
	assert_eq(ocean.targeting, "aoe", "the whole party")
	assert_gt(ocean.resolve_gain, 0, "and emboldens")
	assert_between(ocean.ct_cost, 1200, 1500, "echo weight per the plan")
	assert_string_contains(ocean.use_line, "Phi", "his name is in it")


func test_memory_unlock_travels_with_bastil() -> void:
	_world.in_world_run = true
	_world.quests_done.append("memory_echo")
	_world.pending_roster = "wolves_2"
	var battle: Node2D = load("res://world/battle_test.tscn").instantiate()
	add_child_autofree(battle)
	await get_tree().process_frame
	var encounter: CombatEncounter = battle.get("encounter")
	assert_not_null(encounter)
	if encounter == null:
		return
	var bastil: BaseCombatant = encounter.party[0]
	assert_eq(bastil.display_name, "Bastil")
	assert_not_null(
		bastil.abilities.find_by_id("echo_promised_ocean"), "Phi's gift rides with him"
	)


func test_memory_stays_locked_until_the_crystal() -> void:
	_world.in_world_run = true
	_world.pending_roster = "wolves_2"
	var battle: Node2D = load("res://world/battle_test.tscn").instantiate()
	add_child_autofree(battle)
	await get_tree().process_frame
	var encounter: CombatEncounter = battle.get("encounter")
	if encounter == null:
		return
	assert_null(
		encounter.party[0].abilities.find_by_id("echo_promised_ocean"),
		"no shortcut past the memory chamber"
	)


func test_memory_unlock_survives_the_save_file() -> void:
	_world.in_world_run = true
	_world.quests_done.append("memory_echo")
	assert_eq(_world.rest_and_save("res://world/dungeon.tscn"), OK)
	var save: SaveData = SaveSystem.read()
	assert_has(save.quests_done, "memory_echo", "the crystal stays quiet forever after")


func test_farewells_count_unique_souls() -> void:
	assert_false(_world.farewells_done())
	assert_eq(_world.note_farewell("baker_woman"), 1)
	assert_eq(_world.note_farewell("baker_woman"), 1, "one goodbye per soul")
	for npc_id: String in ["doom_crier", "fisher_elder", "old_priest"]:
		_world.note_farewell(npc_id)
	assert_eq(_world.farewell_ids.size(), 4)
	assert_false(_world.farewells_done())
	_world.note_farewell("transient_beggar")
	assert_true(_world.farewells_done(), "five farewells open the road")
	_world.reset_run()
	assert_eq(_world.farewell_ids.size(), 0, "a new run owes new goodbyes")


func test_selenora_holds_the_gate_until_goodbyes_are_said() -> void:
	_world.in_world_run = true
	var town: AreaBase = load("res://world/town.tscn").instantiate()
	add_child_autofree(town)
	await get_tree().process_frame
	assert_false(bool(town.get("_farewell_satisfied")), "fresh run: the bar is down")
	assert_not_null(town.get("_farewell_barricade"), "and it is a real wall")
	town.queue_free()
	await get_tree().process_frame
	for npc_id: String in ["a", "b", "c", "d", "e"]:
		_world.note_farewell(npc_id)
	var town_after: AreaBase = load("res://world/town.tscn").instantiate()
	add_child_autofree(town_after)
	await get_tree().process_frame
	assert_true(bool(town_after.get("_farewell_satisfied")), "goodbyes said: road open")


func test_talking_emits_the_farewell_signal() -> void:
	var area: AreaBase = AreaBase.new()
	add_child_autofree(area)
	await get_tree().process_frame
	watch_signals(area)
	area.add_roamer("test_soul", [Vector2(200, 200)] as Array[Vector2],
		["Safe roads."] as Array[String], Color.WHITE)
	for entry: Dictionary in area._interactables:
		if String(entry["prompt"]) == "Talk":
			(entry["callback"] as Callable).call()
	assert_signal_emitted_with_parameters(area, "someone_talked", ["test_soul"])
