extends GutTest
## The lore pass: Selenora finds its voice. Tarnaie joins the party, the
## lead avatar is swappable, the street talks (talkers/thinkers/callers),
## the party answers from the bottom of the screen, and the gate fights
## end in reflection.

var _world: Node


func before_each() -> void:
	_world = get_node_or_null("/root/WorldState")
	if _world != null:
		_world.reset_run()
		_world.set("avatar_name", "Bastil")


func after_each() -> void:
	if _world != null:
		_world.reset_run()
		_world.set("avatar_name", "Bastil")


func test_tarnaie_walks_with_the_party() -> void:
	var data: CharacterData = load("res://data/characters/tarnaie.tres")
	assert_not_null(data)
	if data == null:
		return
	assert_eq(data.name, "Tarnaie")
	assert_eq(data.class_type, "Priestess of Selene")
	assert_false(data.is_heir)
	assert_false(data.is_merc)
	assert_has(data.ability_ids, "hymn_of_snowfall", "she mends, she doesn't break")
	var member: BaseCombatant = autofree(BaseCombatant.from_character(data))
	assert_eq(member.display_name, "Tarnaie")
	assert_true(_world.party_meters.has("Tarnaie"), "her heart is tracked like the rest")
	assert_not_null(AssetLibrary.walk_frames("Tarnaie"), "she walks all four ways")
	assert_not_null(AssetLibrary.texture("characters", "Tarnaie"), "she has a face")
	var battle_script: GDScript = load("res://world/battle_test.gd")
	assert_has(battle_script.PARTY_PATHS, "res://data/characters/tarnaie.tres")
	assert_eq(battle_script.PARTY_SLOTS.size(), 6, "six ranks on the platform")


func test_lead_avatar_cycles_through_the_party() -> void:
	assert_eq(String(_world.get("avatar_name")), "Bastil")
	var seen: Array[String] = ["Bastil"]
	for i: int in range(4):
		seen.append(String(_world.call("next_avatar")))
	for member_name: String in ["Bastil", "Cavene", "Jecht", "Mati", "Tarnaie"]:
		assert_has(seen, member_name, member_name + " can take point")
	assert_eq(String(_world.call("next_avatar")), "Bastil", "the cycle wraps home")
	assert_true(InputMap.has_action("swap_lead"), "Tab swaps the lead")


func test_gate_fights_end_in_reflection() -> void:
	var battle_script: GDScript = load("res://world/battle_test.gd")
	for roster: String in ["gate_warden", "pass_horror", "deep_predator", "hoarfang"]:
		var intro: Dictionary = battle_script.INTROS[roster]
		assert_true(intro.has("after"), roster + " gets an aftermath")
		for line: Array in intro["after"]:
			assert_has(
				["Bastil", "Cavene", "Jecht", "Mati", "Tarnaie"], String(line[0]),
				roster + " reflections come from real pilgrims"
			)
			assert_gt(String(line[1]).length(), 8, roster)


func test_party_quips_cross_the_bottom_of_the_screen() -> void:
	var area: AreaBase = AreaBase.new()
	add_child_autofree(area)
	await get_tree().process_frame
	area.party_quip("Tarnaie", "Selene was always quieter than this.")
	assert_not_null(area._quip_label, "the ticker exists")
	if area._quip_label != null:
		assert_string_contains(area._quip_label.text, "Tarnaie")
		assert_string_contains(area._quip_label.text, "quieter")


func test_selenora_speaks_with_many_voices() -> void:
	var area: AreaBase = load("res://world/town.tscn").instantiate()
	add_child_autofree(area)
	await get_tree().process_frame
	assert_string_contains(area.area_name, "SELENORA", "the village is renamed")
	# Talkers + thinkers + quests + chests + doors + saves: a town that TALKS.
	assert_gt(area._interactables.size(), 45, "dozens of street souls to meet")
	var prompts: Dictionary = {}
	for entry: Dictionary in area._interactables:
		prompts[String(entry["prompt"])] = true
	assert_true(prompts.has("Watch quietly"), "thinkers open their heads")
	assert_true(prompts.has("Talk"), "talkers abound")
	var map_label_found: bool = false
	for stop: Dictionary in CharacterMenuOverlay.MAP_CHAIN:
		if String(stop["label"]) == "SELENORA":
			map_label_found = true
	assert_true(map_label_found, "the world map agrees on the name")
	var sheet_names: Array[String] = []
	for sheet: Dictionary in CharacterMenuOverlay.SHEETS:
		sheet_names.append(String(sheet["path"]))
	assert_has(sheet_names, "res://data/characters/tarnaie.tres", "her card is in the menu")
