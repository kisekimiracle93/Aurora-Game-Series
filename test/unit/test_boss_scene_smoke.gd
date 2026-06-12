extends GutTest
## M5 smoke: fight-select and boss scenes instantiate headless without errors.


func test_fight_select_boots() -> void:
	var scene: PackedScene = load("res://world/fight_select.tscn")
	var select: Node2D = scene.instantiate()
	add_child_autofree(select)
	await get_tree().process_frame
	assert_true(select.is_inside_tree())


func test_boss_scene_boots_with_controller_wired() -> void:
	var scene: PackedScene = load("res://world/boss_test.tscn")
	var battle: Node2D = scene.instantiate()
	add_child_autofree(battle)
	await get_tree().process_frame
	await get_tree().process_frame

	var encounter: CombatEncounter = battle.get("encounter")
	assert_not_null(encounter)
	if encounter == null:
		return
	assert_eq(encounter.state, CombatEncounter.State.AWAITING_PLAYER)
	assert_eq(encounter.party.size(), 6)
	assert_eq(encounter.enemies.size(), 1, "the Shepherd stands alone... at first")
	assert_eq(encounter.enemies[0].display_name, "Frozen Shepherd")
	var controller: FrozenShepherdController = battle.get("boss_controller")
	assert_not_null(controller)
	if controller != null:
		assert_eq(controller.phase, 1)
	assert_not_null(encounter.boss_controller, "encounter routes boss turns to the script")
