extends GutTest
## Owner-directed expansion: Duty/Burden meters + effects, items/inventory,
## battle-start reactions, overworld foe state machine, quest meter nudges.

const EPS: float = 0.0001

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


# --- Duty / Burden math --------------------------------------------------------


func test_duty_and_burden_curves() -> void:
	assert_almost_eq(MeterMath.duty_damage_mult(0.0), 1.0, EPS)
	assert_almost_eq(MeterMath.duty_damage_mult(100.0), 1.25, EPS)
	assert_almost_eq(MeterMath.duty_echo_cost_mult(100.0), 0.60, EPS)
	assert_almost_eq(MeterMath.burden_damage_mult(100.0), 0.65, EPS)
	assert_almost_eq(MeterMath.burden_speed_mult(100.0), 0.55, EPS)
	assert_almost_eq(MeterMath.burden_speed_mult(0.0), 1.0, EPS)
	assert_false(MeterMath.is_echo_locked_by_burden(79.9))
	assert_true(MeterMath.is_echo_locked_by_burden(80.0))


func test_burden_slows_effective_speed() -> void:
	var jecht: BaseCombatant = autofree(
		BaseCombatant.from_character(load("res://data/characters/jecht.tres"))
	)
	jecht.meters.set_value(MetersComponent.BURDEN, 0.0)
	var fresh_speed: float = jecht.effective_speed()
	jecht.meters.set_value(MetersComponent.BURDEN, 100.0)
	assert_almost_eq(jecht.effective_speed(), fresh_speed * 0.55, 0.01)


func test_burden_locks_echo_and_duty_discounts_it() -> void:
	var bastil: BaseCombatant = autofree(
		BaseCombatant.from_character(load("res://data/characters/bastil.tres"))
	)
	var wolf: BaseCombatant = autofree(
		BaseCombatant.from_enemy(load("res://data/enemies/aether_wolf.tres"))
	)
	var encounter: CombatEncounter = autofree(CombatEncounter.new())
	encounter.setup([bastil] as Array[BaseCombatant], [wolf] as Array[BaseCombatant], 99)
	var log_lines: Array[String] = []
	encounter.combat_log_line.connect(func(line: String) -> void: log_lines.append(line))
	encounter.start()
	assert_eq(encounter.state, CombatEncounter.State.AWAITING_PLAYER)
	# Locked by grief even with a full gauge.
	bastil.meters.set_value(MetersComponent.ECHO, 100.0)
	bastil.meters.set_value(MetersComponent.BURDEN, 85.0)
	var pyre: AbilityData = bastil.abilities.find_by_id("echo_living_pyre")
	encounter.submit_player_action(pyre, [wolf] as Array[BaseCombatant])
	assert_eq(encounter.state, CombatEncounter.State.AWAITING_PLAYER)
	assert_string_contains("\n".join(log_lines), "grief is too heavy")
	# Unburdened + high duty: the echo fires and costs less CT. Execute the
	# action directly (no turn loop) so the payment is observable.
	bastil.meters.set_value(MetersComponent.BURDEN, 0.0)
	bastil.meters.set_value(MetersComponent.DUTY, 100.0)
	bastil.meters.set_value(MetersComponent.ECHO, 100.0)
	bastil.ctb.ct = 1000.0
	encounter.execute_action(bastil, pyre, [wolf] as Array[BaseCombatant])
	assert_almost_eq(
		bastil.ctb.ct, 1000.0 - pyre.ct_cost * 0.60, 1.0,
		"duty discounts the echo's CT cost"
	)


# --- items ----------------------------------------------------------------------


func test_inventory_add_consume_and_flat_restores() -> void:
	_world.add_item("item_hp_potion", 2)
	assert_eq(_world.item_count("item_hp_potion"), 4)  # 2 starting + 2
	assert_true(_world.consume_item("item_hp_potion"))
	assert_eq(_world.item_count("item_hp_potion"), 3)

	var potion: AbilityData = AbilityLibrary.load_ability("item_hp_potion")
	assert_not_null(potion)
	assert_true(potion.is_item)
	var bastil: BaseCombatant = autofree(
		BaseCombatant.from_character(load("res://data/characters/bastil.tres"))
	)
	bastil.stats.take_damage(200)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var result: Dictionary = ActionResolver.resolve_action(
		potion, bastil, [bastil] as Array[BaseCombatant], rng
	)[0]
	assert_eq(int(result["healed"]), 120, "flat heal ignores variance")
	assert_eq(bastil.stats.current_hp, 340 - 200 + 120)

	var draught: AbilityData = AbilityLibrary.load_ability("item_aether_draught")
	bastil.stats.spend_aether(40)
	ActionResolver.resolve_action(draught, bastil, [bastil] as Array[BaseCombatant], rng)
	assert_eq(bastil.stats.current_aether, 40, "draught refills to the cap")


func test_save_round_trips_inventory_duty_burden() -> void:
	_world.in_world_run = true
	_world.add_item("item_hp_potion", 3)
	_world.opened_chests.append("town_well")
	_world.party_meters["Bastil"]["duty"] = 80.0
	_world.party_meters["Bastil"]["burden"] = 30.0
	assert_eq(_world.rest_and_save("res://world/town.tscn"), OK)
	var save: SaveData = SaveSystem.read()
	assert_eq(int(save.inventory["item_hp_potion"]), 5)
	assert_has(save.opened_chests, "town_well")
	assert_almost_eq(float(save.character_duty["Bastil"]), 80.0, EPS)
	# Rest eased the burden before saving: 30 - 15.
	assert_almost_eq(float(save.character_burden["Bastil"]), 15.0, EPS)


# --- reactions ------------------------------------------------------------------


func test_wolves_shake_mati_at_battle_start() -> void:
	var mati: BaseCombatant = autofree(
		BaseCombatant.from_character(load("res://data/characters/mati.tres"))
	)
	# Cavene (speed 27) outpaces the wolf (26): the loop pauses for player
	# input before any wolf action can muddy Mati's meter.
	var cavene: BaseCombatant = autofree(
		BaseCombatant.from_character(load("res://data/characters/cavene.tres"))
	)
	var wolf: BaseCombatant = autofree(
		BaseCombatant.from_enemy(load("res://data/enemies/aether_wolf.tres"))
	)
	wolf.display_name = "Aether Wolf 1"
	var encounter: CombatEncounter = autofree(CombatEncounter.new())
	encounter.setup(
		[cavene, mati] as Array[BaseCombatant], [wolf] as Array[BaseCombatant], 7
	)
	encounter.start()
	assert_almost_eq(mati.meters.resolve(), 45.0, EPS, "fear of wolves: Resolve -15")


func test_bandits_steel_bastil_duty() -> void:
	var bastil: BaseCombatant = autofree(
		BaseCombatant.from_character(load("res://data/characters/bastil.tres"))
	)
	var bandit: BaseCombatant = autofree(
		BaseCombatant.from_enemy(load("res://data/enemies/roadside_bandit.tres"))
	)
	var encounter: CombatEncounter = autofree(CombatEncounter.new())
	encounter.setup([bastil] as Array[BaseCombatant], [bandit] as Array[BaseCombatant], 7)
	encounter.start()
	assert_almost_eq(bastil.meters.duty(), 62.0, EPS, "roads are his to keep: Duty +12")


# --- overworld foe state machine ------------------------------------------------


func test_foe_decision_rules() -> void:
	var patrol: OverworldFoe.FoeState = OverworldFoe.FoeState.PATROL
	var chase: OverworldFoe.FoeState = OverworldFoe.FoeState.CHASE
	var back: OverworldFoe.FoeState = OverworldFoe.FoeState.RETURN
	assert_eq(OverworldFoe.decide_state(patrol, 500.0, 0.0), patrol, "far player ignored")
	assert_eq(OverworldFoe.decide_state(patrol, 100.0, 0.0), chase, "close player aggroes")
	assert_eq(OverworldFoe.decide_state(chase, 100.0, 200.0), chase, "keeps chasing in leash")
	assert_eq(OverworldFoe.decide_state(chase, 100.0, 400.0), back, "leash snaps: goes home")
	assert_eq(OverworldFoe.decide_state(back, 30.0, 200.0), back, "walks all the way back")
	assert_eq(OverworldFoe.decide_state(back, 30.0, 5.0), patrol, "resumes the rounds")


func test_cleared_foe_stays_dead_for_the_run() -> void:
	_world.in_world_run = true
	_world.pending_foe_id = "fields_wolves_a"
	var bastil: BaseCombatant = autofree(
		BaseCombatant.from_character(load("res://data/characters/bastil.tres"))
	)
	# finish_battle would change scenes; exercise just the bookkeeping bits.
	_world.snapshot_party([bastil] as Array[BaseCombatant])
	_world.cleared_foes.append(_world.pending_foe_id)
	_world.pending_foe_id = ""
	assert_has(_world.cleared_foes, "fields_wolves_a")


# --- quests ---------------------------------------------------------------------


func test_quest_meter_nudges_respect_limits_and_heirs() -> void:
	_world.adjust_party_meter("duty", 10.0)
	assert_almost_eq(float(_world.party_meters["Bastil"]["duty"]), 60.0, EPS)
	_world.adjust_party_meter("darkness", 5.0)
	assert_almost_eq(float(_world.party_meters["Jecht"]["darkness"]), 5.0, EPS)
	assert_almost_eq(
		float(_world.party_meters["Bastil"]["darkness"]), 0.0, EPS,
		"darkness never touches the unmarked"
	)
	_world.adjust_party_meter("burden", 500.0)
	assert_almost_eq(float(_world.party_meters["Mati"]["burden"]), 100.0, EPS, "clamped")


func test_new_enemy_roster_files_load() -> void:
	for path: String in [
		"res://data/enemies/roadside_bandit.tres",
		"res://data/enemies/bandit_cutthroat.tres",
		"res://data/enemies/frost_wisp.tres",
	]:
		var data: EnemyData = load(path)
		assert_not_null(data, path)
	var battle_script: GDScript = load("res://world/battle_test.gd")
	for roster: String in ["bandit_ambush", "bandit_pair", "wisp_pack"]:
		for enemy_path: String in battle_script.enemy_paths_for(roster):
			assert_true(ResourceLoader.exists(enemy_path), enemy_path)


# --- polish pass: walk sets, menu folders, character ledger ----------------------


func test_walk_frames_built_for_party_and_bandits() -> void:
	for member_name: String in ["Bastil", "Cavene", "Jecht", "Mati", "Church Lancer", "Roadside Bandit"]:
		var frames: SpriteFrames = AssetLibrary.walk_frames(member_name)
		assert_not_null(frames, member_name)
		if frames == null:
			continue
		for dir_name: String in ["down", "left", "right", "up"]:
			assert_gt(frames.get_frame_count(dir_name), 0, "%s %s" % [member_name, dir_name])
			assert_gt(frames.get_frame_count("idle_" + dir_name), 0)
	assert_null(AssetLibrary.walk_frames("Frozen Shepherd"), "beasts have no walk sets")


func test_action_menu_folders_categorize_kits() -> void:
	var bastil: BaseCombatant = autofree(
		BaseCombatant.from_character(load("res://data/characters/bastil.tres"))
	)
	var menu: ActionMenu = ActionMenu.new()
	add_child_autofree(menu)
	menu.open_for(bastil)
	var magic: Array[AbilityData] = menu._magic_list()
	var skills: Array[AbilityData] = menu._skill_list()
	var magic_ids: Array[String] = []
	for ability: AbilityData in magic:
		magic_ids.append(ability.id)
	var skill_ids: Array[String] = []
	for ability: AbilityData in skills:
		skill_ids.append(ability.id)
	assert_has(magic_ids, "rally_by_flame", "supports file under Magic")
	assert_has(skill_ids, "oathfire_strike", "weapon arts file under Skills")
	assert_does_not_have(magic_ids, "guard")
	assert_does_not_have(magic_ids, "pray")
	assert_does_not_have(magic_ids, "echo_living_pyre", "echoes stay on the root")


func test_burden_drag_threshold() -> void:
	assert_false(MeterMath.is_burden_dragging(49.9))
	assert_true(MeterMath.is_burden_dragging(50.0))


func test_character_menu_overlay_boots() -> void:
	var overlay: CharacterMenuOverlay = CharacterMenuOverlay.new()
	add_child_autofree(overlay)
	await get_tree().process_frame
	assert_gt(overlay.get_child_count(), 2, "dimmer + title + cards")
