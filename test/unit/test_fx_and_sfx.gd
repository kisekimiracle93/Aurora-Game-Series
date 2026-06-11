extends GutTest
## Feedback pass: synthesized SFX, battle FX factories, selection arrows,
## and the sprite-transparency regression guard.

const SFX_NAMES: Array[String] = [
	"hover", "click", "hit", "crit", "miss", "fire", "ice", "heal",
	"guard", "pray", "echo", "status", "shock", "delay", "burn", "bleed",
]


func test_every_sfx_recipe_synthesizes_audio() -> void:
	for sfx_name: String in SFX_NAMES:
		var sfx_script: GDScript = load("res://world/sfx_manager.gd")
		var wav: AudioStreamWAV = sfx_script.synth_stream(sfx_name)
		assert_not_null(wav, sfx_name)
		assert_gt(wav.data.size(), 200, "%s has real audio data" % sfx_name)


func test_sfx_manager_autoload_plays_without_crashing() -> void:
	var sfx: Node = get_node_or_null("/root/SfxManager")
	assert_not_null(sfx, "SfxManager is autoloaded")
	if sfx == null:
		return
	for i: int in range(12):  # cycles through the whole player pool
		sfx.play("click")
	sfx.set_sfx_volume_linear(0.5)
	assert_ne(AudioServer.get_bus_index("Sfx"), -1, "Sfx bus created")


func test_battle_fx_factories_spawn_nodes() -> void:
	var stage: Node2D = autofree(Node2D.new())
	add_child_autofree(stage)
	BattleFX.damage_number(stage, Vector2(100, 100), 42, "hurt")
	BattleFX.damage_number(stage, Vector2(100, 100), 17, "heal")
	BattleFX.text_pop(stage, Vector2(100, 100), "MISS", Color.WHITE)
	BattleFX.slash(stage, Vector2(100, 100))
	BattleFX.elemental_burst(stage, Vector2(100, 100), "Fire")
	BattleFX.elemental_burst(stage, Vector2(100, 100), "Ice")
	BattleFX.heal_sparkle(stage, Vector2(100, 100))
	BattleFX.guard_ring(stage, Vector2(100, 100))
	BattleFX.echo_burst(stage, Vector2(100, 100), "Ice")
	assert_gt(stage.get_child_count(), 9, "all factories produced nodes")


func test_hero_sprites_have_transparent_backgrounds() -> void:
	for sprite_name: String in ["bastil", "cavene", "jecht", "mati", "church_lancer"]:
		var texture: Texture2D = load("res://assets/sprites/characters/%s.png" % sprite_name)
		assert_not_null(texture, sprite_name)
		if texture == null:
			continue
		var img: Image = texture.get_image()
		assert_almost_eq(
			img.get_pixel(0, 0).a, 0.0, 0.001,
			"%s corner is transparent (no grey strip)" % sprite_name
		)


func test_battle_scene_arrows_track_the_active_player() -> void:
	var scene: PackedScene = load("res://world/battle_test.tscn")
	var battle: Node2D = scene.instantiate()
	add_child_autofree(battle)
	await get_tree().process_frame
	await get_tree().process_frame
	var active_arrow: SelectionArrow = battle.get("_active_arrow")
	var target_arrow: SelectionArrow = battle.get("_target_arrow")
	assert_not_null(active_arrow)
	assert_not_null(target_arrow)
	if active_arrow == null:
		return
	assert_true(active_arrow.visible, "gold arrow over the active party member")
	assert_false(target_arrow.visible, "no target arrow until choosing")
	var encounter: CombatEncounter = battle.get("encounter")
	assert_almost_eq(
		active_arrow.position.x, encounter.current_actor.position.x, 0.01,
		"arrow x-locked to the actor"
	)
