extends GutTest
## M3 smoke: the battle scene instantiates headless without script errors and
## reaches the "waiting for player input" state with its UI in place.
## (Whether it LOOKS right is the human's playtest call, not this test's.)


func test_battle_scene_boots_to_player_input() -> void:
	var scene: PackedScene = load("res://world/battle_test.tscn")
	var battle: Node2D = scene.instantiate()
	add_child_autofree(battle)
	await get_tree().process_frame
	await get_tree().process_frame

	var encounter: CombatEncounter = battle.get("encounter")
	assert_not_null(encounter)
	if encounter == null:
		return
	assert_eq(encounter.state, CombatEncounter.State.AWAITING_PLAYER)
	assert_eq(encounter.party.size(), 5)
	assert_eq(encounter.enemies.size(), 3)
	assert_not_null(encounter.current_actor)
	assert_true(encounter.current_actor.is_player_controlled)

	var menu: ActionMenu = battle.get("action_menu")
	assert_not_null(menu)
	if menu != null:
		assert_true(menu.visible, "action menu should be open on the player's turn")


func test_battle_scene_player_can_attack_through_the_ui_path() -> void:
	var scene: PackedScene = load("res://world/battle_test.tscn")
	var battle: Node2D = scene.instantiate()
	add_child_autofree(battle)
	await get_tree().process_frame

	var encounter: CombatEncounter = battle.get("encounter")
	var actor: BaseCombatant = encounter.current_actor
	var attack: AbilityData = actor.abilities.find_by_id("attack_basic")
	var first_enemy: BaseCombatant = encounter.living(encounter.enemies)[0]
	var hp_before: int = first_enemy.stats.current_hp
	encounter.submit_player_action(attack, [first_enemy])
	await get_tree().process_frame
	# Either the hit landed (HP dropped) or it whiffed — but the loop must have
	# moved on to the next player decision without crashing.
	assert_eq(encounter.state, CombatEncounter.State.AWAITING_PLAYER)
	assert_lte(first_enemy.stats.current_hp, hp_before)
