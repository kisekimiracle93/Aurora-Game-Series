extends GutTest
## M6 logic: WorldState run/battle/save flow, roster compositions, and the
## three world scenes booting headless with a player inside.

var _world: Node


func before_each() -> void:
	_world = get_node_or_null("/root/WorldState")
	assert_not_null(_world, "WorldState autoload present")
	if _world != null:
		_world.reset_run()
	SaveSystem.delete()


func after_each() -> void:
	if _world != null:
		_world.reset_run()
	SaveSystem.delete()


func _member(path: String) -> BaseCombatant:
	return autofree(BaseCombatant.from_character(load(path)))


func test_run_defaults_cover_party_and_merc() -> void:
	for member_name: String in ["Bastil", "Cavene", "Jecht", "Mati", "Church Lancer"]:
		assert_true(_world.party_meters.has(member_name), member_name)
		assert_almost_eq(
			float(_world.party_meters[member_name]["resolve"]), 60.0, 0.001
		)
	assert_false(_world.merc_hired)
	assert_false(_world.in_world_run)
	assert_false(_world.boss_cleared)


func test_snapshot_and_apply_round_trip() -> void:
	var jecht: BaseCombatant = _member("res://data/characters/jecht.tres")
	jecht.meters.set_value(MetersComponent.RESOLVE, 87.0)
	jecht.meters.set_value(MetersComponent.DARKNESS, 42.0)
	_world.snapshot_party([jecht] as Array[BaseCombatant])
	assert_almost_eq(float(_world.party_meters["Jecht"]["resolve"]), 87.0, 0.001)
	assert_almost_eq(float(_world.party_meters["Jecht"]["darkness"]), 42.0, 0.001)

	var fresh: BaseCombatant = _member("res://data/characters/jecht.tres")
	_world.apply_to_member(fresh)
	assert_almost_eq(fresh.meters.resolve(), 87.0, 0.001)
	assert_almost_eq(fresh.meters.darkness(), 42.0, 0.001)


func test_retry_penalty_hits_the_whole_roster() -> void:
	_world.party_meters["Bastil"]["resolve"] = 70.0
	_world.party_meters["Mati"]["resolve"] = 10.0
	_world.apply_retry_penalty()
	assert_almost_eq(float(_world.party_meters["Bastil"]["resolve"]), 55.0, 0.001)
	assert_almost_eq(float(_world.party_meters["Mati"]["resolve"]), 0.0, 0.001, "clamped")


func test_rest_and_save_drains_darkness_and_persists() -> void:
	_world.in_world_run = true
	_world.merc_hired = true
	_world.party_meters["Jecht"]["darkness"] = 66.0
	_world.party_meters["Jecht"]["resolve"] = 31.0
	assert_eq(_world.rest_and_save("res://world/town.tscn"), OK)
	assert_almost_eq(float(_world.party_meters["Jecht"]["darkness"]), 0.0, 0.001)
	assert_almost_eq(
		float(_world.party_meters["Jecht"]["resolve"]),
		SaveSystem.SAVE_POINT_RESOLVE_FLOOR,
		0.001
	)
	assert_true(_world.has_save())
	var save: SaveData = SaveSystem.read()
	assert_eq(save.scene_path, "res://world/town.tscn")
	assert_true(save.merc_hired)
	assert_almost_eq(float(save.heir_darkness["Jecht"]), 0.0, 0.001)


func test_pending_roster_hand_off() -> void:
	_world.in_world_run = true
	_world.pending_roster = "dungeon_gauntlet"
	_world.return_scene = "res://world/dungeon.tscn"
	assert_eq(_world.consume_pending_roster(), "dungeon_gauntlet")
	assert_eq(_world.consume_pending_roster(), "", "consumed once")


func test_roster_compositions() -> void:
	var battle_script: GDScript = load("res://world/battle_test.gd")
	assert_eq(battle_script.enemy_paths_for("wolves_2").size(), 2)
	assert_eq(battle_script.enemy_paths_for("wolves_3").size(), 3)
	assert_eq(battle_script.enemy_paths_for("dungeon_gauntlet").size(), 3)
	assert_eq(battle_script.enemy_paths_for("wolfpack").size(), 3)
	for path: String in battle_script.enemy_paths_for("stag_hunt"):
		assert_true(ResourceLoader.exists(path), path)


func test_world_scenes_boot_with_a_player() -> void:
	for scene_path: String in [
		"res://world/town.tscn", "res://world/outside.tscn", "res://world/dungeon.tscn",
	]:
		var scene: PackedScene = load(scene_path)
		var area: AreaBase = scene.instantiate()
		add_child_autofree(area)
		await get_tree().process_frame
		assert_not_null(area.player, "%s has a player avatar" % scene_path)
		assert_true(area.player.is_inside_tree())


func test_world_battle_uses_world_meters_and_respects_merc_flag() -> void:
	_world.in_world_run = true
	_world.merc_hired = false
	_world.party_meters["Bastil"]["resolve"] = 95.0
	_world.pending_roster = "wolves_2"
	var scene: PackedScene = load("res://world/battle_test.tscn")
	var battle: Node2D = scene.instantiate()
	add_child_autofree(battle)
	await get_tree().process_frame
	var encounter: CombatEncounter = battle.get("encounter")
	assert_not_null(encounter)
	if encounter == null:
		return
	assert_eq(encounter.party.size(), 4, "no Lancer without hiring him")
	assert_eq(encounter.enemies.size(), 2, "wolves_2 roster honored")
	assert_almost_eq(encounter.party[0].meters.resolve(), 95.0, 0.001, "world meters applied")
	assert_true(bool(battle.get("world_mode")))
