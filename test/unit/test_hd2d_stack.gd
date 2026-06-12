extends GutTest
## The 2D-HD stack: day/night grading, shaders, baked lighting assets,
## normal-mapped textures, post stack, and the battle camera rig.

const EPS: float = 0.0001


func test_day_night_palette_keys() -> void:
	var atmosphere_script: GDScript = load("res://world/atmosphere_manager.gd")
	var dawn: Color = atmosphere_script.tint_for_hour(7.0)
	assert_gt(dawn.r, dawn.b, "morning runs warm gold")
	var noon: Color = atmosphere_script.tint_for_hour(12.0)
	assert_almost_eq(noon.r, 1.0, 0.01)
	assert_almost_eq(noon.b, 1.0, 0.01)
	var dusk: Color = atmosphere_script.tint_for_hour(19.5)
	assert_gt(dusk.b, dusk.g, "dusk leans desaturated purple")
	var night: Color = atmosphere_script.tint_for_hour(0.0)
	assert_gt(night.b, night.r, "night sinks into deep blue")
	assert_true(atmosphere_script.is_night_hour(23.0))
	assert_false(atmosphere_script.is_night_hour(12.0))


func test_shaders_load() -> void:
	for path: String in [
		"res://ui/shaders/postfx.gdshader",
		"res://ui/shaders/foliage_sway.gdshader",
		"res://ui/shaders/water_flow.gdshader",
		"res://ui/aurora_sky.gdshader",
	]:
		var shader: Shader = load(path)
		assert_not_null(shader, path)
	assert_not_null(AssetLibrary.foliage_material())
	assert_not_null(AssetLibrary.water_material())


func test_baked_lighting_assets_exist() -> void:
	assert_true(ResourceLoader.exists("res://assets/sprites/ui/light_radial.png"))
	assert_true(ResourceLoader.exists("res://assets/sprites/props/house_inn_n.png"))
	assert_true(ResourceLoader.exists("res://assets/sprites/characters/bastil_n.png"))


func test_textures_become_canvas_textures_with_normals() -> void:
	var lit: Texture2D = AssetLibrary.texture("props", "house_inn")
	assert_true(lit is CanvasTexture, "diffuse + baked normal pair up")
	if lit is CanvasTexture:
		assert_not_null((lit as CanvasTexture).normal_texture)
	var character: Texture2D = AssetLibrary.texture("characters", "Bastil")
	assert_true(character is CanvasTexture)


func test_postfx_autoload_moods() -> void:
	var postfx: Node = get_node_or_null("/root/PostFX")
	assert_not_null(postfx, "PostFX autoloaded")
	if postfx == null:
		return
	postfx.mood_world(0.2, 0.1)
	postfx.mood_battle()
	postfx.mood_menu()
	postfx.pulse_dof(0.9, 0.2)
	postfx.set_param("frost_amount", 0.0)


func test_atmosphere_autoload_applies_to_stage() -> void:
	var atmosphere: Node = get_node_or_null("/root/Atmosphere")
	assert_not_null(atmosphere, "Atmosphere autoloaded")
	if atmosphere == null:
		return
	var stage: Node2D = autofree(Node2D.new())
	add_child_autofree(stage)
	atmosphere.apply_to_battle(stage)
	var has_modulate: bool = false
	for child: Node in stage.get_children():
		if child is CanvasModulate:
			has_modulate = true
	assert_true(has_modulate, "battle stage gets the hour's grade")


func test_battle_scene_carries_the_camera_rig() -> void:
	var scene: PackedScene = load("res://world/battle_test.tscn")
	var battle: Node2D = scene.instantiate()
	add_child_autofree(battle)
	await get_tree().process_frame
	var presenter: ActionPresenter = battle.get("presenter")
	assert_not_null(presenter)
	if presenter == null:
		return
	assert_not_null(presenter.camera, "the intelligent rig is wired in")
	assert_true(presenter.camera is BattleCamera)
	var encounter: CombatEncounter = battle.get("encounter")
	assert_eq(encounter.state, CombatEncounter.State.AWAITING_PLAYER)
