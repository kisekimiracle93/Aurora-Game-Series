extends GutTest
## Asset pipeline + main menu: graceful fallbacks with zero asset files, naming
## convention, autoloaded music manager, and the title scene booting headless.


func test_file_name_convention() -> void:
	assert_eq(AssetLibrary.to_file_name("Aether Wolf 2"), "aether_wolf")
	assert_eq(AssetLibrary.to_file_name("Aether Wolf 11"), "aether_wolf")
	assert_eq(AssetLibrary.to_file_name("Church Lancer"), "church_lancer")
	assert_eq(AssetLibrary.to_file_name("Frozen Shepherd"), "frozen_shepherd")
	assert_eq(AssetLibrary.to_file_name("Lancer's Lunge"), "lancers_lunge")
	assert_eq(AssetLibrary.to_file_name("Bastil"), "bastil")


func test_missing_assets_fall_back_to_null_silently() -> void:
	assert_null(AssetLibrary.texture("characters", "Zz Nonexistent Hero"))
	assert_null(AssetLibrary.texture("backgrounds", "zz_nowhere"))
	assert_null(AssetLibrary.music_stream("zz_unwritten_song"))
	assert_null(AssetLibrary.sfx_stream("zz_unheard_blip"))


func test_curated_toolbox_assets_resolve() -> void:
	# Cropped/copied sprites in the convention folders.
	for member_name: String in [
		"Bastil", "Cavene", "Jecht", "Mati", "Church Lancer",
		"Aether Wolf 1", "Icebound Stag", "Crystal Wolf 2", "Frozen Shepherd",
	]:
		assert_not_null(
			AssetLibrary.texture("characters", member_name), "%s sprite" % member_name
		)
	# Manifest-mapped (no-copy) toolbox files.
	assert_not_null(AssetLibrary.texture("backgrounds", "battle"), "battle backdrop")
	assert_not_null(AssetLibrary.texture("backgrounds", "boss"), "boss backdrop")
	assert_not_null(AssetLibrary.music_stream("victory"), "victory sting via manifest")


func test_rpg_ui_theme_is_applied_to_the_window() -> void:
	var theme: Theme = get_tree().root.theme
	assert_not_null(theme, "UiTheme autoload skinned the root window")
	if theme == null:
		return
	assert_true(theme.has_stylebox("panel", "PanelContainer"))
	var box: StyleBox = theme.get_stylebox("normal", "Button")
	assert_true(box is StyleBoxTexture, "Kenney RPG button skin in place")
	if box is StyleBoxTexture:
		assert_not_null((box as StyleBoxTexture).texture)


func test_music_manager_autoload_no_ops_without_files() -> void:
	var music: Node = get_node_or_null("/root/MusicManager")
	assert_not_null(music, "MusicManager is autoloaded")
	if music == null:
		return
	music.play_track("battle")  # no file: must not crash
	music.play_track("battle")  # same-track no-op path
	music.play_track("boss")
	music.stop_music()
	music.set_music_volume_linear(0.5)
	assert_ne(AudioServer.get_bus_index("Music"), -1, "Music bus created")


func test_main_menu_is_the_main_scene_and_boots() -> void:
	assert_eq(
		String(ProjectSettings.get_setting("application/run/main_scene")),
		"res://world/main_menu.tscn"
	)
	var scene: PackedScene = load("res://world/main_menu.tscn")
	var menu: Node2D = scene.instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	await get_tree().process_frame

	var menu_box: VBoxContainer = menu.get("_menu_box")
	assert_not_null(menu_box)
	if menu_box != null:
		assert_eq(menu_box.get_child_count(), 4, "Start / Playtest / Options / Quit")
	var playtest_panel: PanelContainer = menu.get("_playtest_panel")
	var options_panel: PanelContainer = menu.get("_options_panel")
	assert_not_null(playtest_panel)
	assert_not_null(options_panel)
	if playtest_panel != null and options_panel != null:
		assert_false(playtest_panel.visible, "panels closed until toggled")
		assert_false(options_panel.visible)


func test_battle_scene_still_boots_with_asset_hooks() -> void:
	var scene: PackedScene = load("res://world/battle_test.tscn")
	var battle: Node2D = scene.instantiate()
	add_child_autofree(battle)
	await get_tree().process_frame
	var encounter: CombatEncounter = battle.get("encounter")
	assert_not_null(encounter)
	if encounter != null:
		assert_eq(encounter.state, CombatEncounter.State.AWAITING_PLAYER)
