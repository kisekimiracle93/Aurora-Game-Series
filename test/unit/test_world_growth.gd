extends GutTest
## World-growth pass: the Verdant Pass, the bigger castle town, night-variant
## music, self-lighting torches, the travel trail + character-menu world map,
## and the 3-frame hit-stop spec.

var _world: Node
var _atmosphere: Node
var _saved_hour: float = 10.0
var _saved_advancing: bool = false


func before_each() -> void:
	_world = get_node_or_null("/root/WorldState")
	_atmosphere = get_node_or_null("/root/Atmosphere")
	assert_not_null(_world, "WorldState autoload present")
	if _world != null:
		_world.reset_run()
	if _atmosphere != null:
		_saved_hour = _atmosphere.hour
		_saved_advancing = _atmosphere.advancing


func after_each() -> void:
	if _world != null:
		_world.reset_run()
	if _atmosphere != null:
		_atmosphere.hour = _saved_hour
		_atmosphere.advancing = _saved_advancing
		_atmosphere.set("_was_night", _atmosphere.is_night())
	var music: Node = get_node_or_null("/root/MusicManager")
	if music != null:
		music.stop_music()


func test_hit_stop_is_three_frames_not_three_seconds() -> void:
	assert_almost_eq(ActionPresenter.HIT_STOP_LIGHT, 3.0 / 60.0, 0.001, "3 frames @60fps")
	assert_lt(ActionPresenter.HIT_STOP_LIGHT, ActionPresenter.HIT_STOP_HEAVY)
	assert_lt(ActionPresenter.HIT_STOP_HEAVY, ActionPresenter.HIT_STOP_ECHO)
	assert_lt(ActionPresenter.HIT_STOP_ECHO, 0.5, "nothing close to seconds-long")


func test_travel_trail_tracks_current_and_previous() -> void:
	_world.note_area_visit("res://world/town.tscn")
	assert_eq(String(_world.current_area), "res://world/town.tscn")
	assert_eq(String(_world.previous_area), "")
	_world.note_area_visit("res://world/forest.tscn")
	assert_eq(String(_world.current_area), "res://world/forest.tscn")
	assert_eq(String(_world.previous_area), "res://world/town.tscn")
	_world.note_area_visit("res://world/forest.tscn")  # re-entering is a no-op
	assert_eq(String(_world.previous_area), "res://world/town.tscn")
	_world.reset_run()
	assert_eq(String(_world.current_area), "", "a new run starts the trail clean")
	assert_eq(String(_world.previous_area), "")


func test_interiors_stay_off_the_travel_trail() -> void:
	var interior_script: GDScript = load("res://world/interior.gd")
	var inside: AreaBase = interior_script.new()
	assert_false(inside.tracks_on_map, "a house is still 'in town' on the map")
	inside.free()
	var open_area: AreaBase = AreaBase.new()
	assert_true(open_area.tracks_on_map, "real areas join the trail")
	open_area.free()


func test_night_music_variants_resolve_from_manifest() -> void:
	for track: String in ["forest", "forest_night", "town_night", "world_night"]:
		assert_not_null(AssetLibrary.music_stream(track), track + " has a stream")
	assert_null(AssetLibrary.music_stream("dungeon_night"), "dungeon keeps one theme")


func test_area_music_switches_at_night() -> void:
	var music: Node = get_node_or_null("/root/MusicManager")
	assert_not_null(music)
	if music == null or _atmosphere == null:
		return
	_atmosphere.hour = 23.0  # deep night
	var area: AreaBase = AreaBase.new()
	area.music_track = "forest"
	add_child_autofree(area)
	await get_tree().process_frame
	assert_eq(String(music.get("_current_track")), "forest_night", "night variant picked")
	_atmosphere.hour = 12.0
	area._play_area_music()
	assert_eq(String(music.get("_current_track")), "forest", "day theme by daylight")
	# An area without a night variant keeps its day theme after dark.
	_atmosphere.hour = 23.0
	area.music_track = "dungeon"
	area._play_area_music()
	assert_eq(String(music.get("_current_track")), "dungeon", "no variant -> day theme")


func test_torches_idle_by_day_and_ignite_at_night() -> void:
	if _atmosphere != null:
		_atmosphere.hour = 12.0  # boot in daylight
	var area: AreaBase = AreaBase.new()
	add_child_autofree(area)
	await get_tree().process_frame
	area.add_torch(Vector2(140, 140))
	var mine: Array[PointLight2D] = []
	for node: Node in get_tree().get_nodes_in_group("torch_light"):
		if node is PointLight2D and area.is_ancestor_of(node):
			mine.append(node)
	assert_eq(mine.size(), 1, "torch registers one grouped light")
	if mine.is_empty():
		return
	assert_almost_eq(mine[0].energy, 0.0, 0.001, "unlit by day")
	area._set_torches_lit(true)
	await wait_seconds(0.3)
	assert_gt(mine[0].energy, 0.05, "night ignition ramping up")


func test_forest_boots_big_with_foes_torches_and_save() -> void:
	var area: AreaBase = load("res://world/forest.tscn").instantiate()
	add_child_autofree(area)
	await get_tree().process_frame
	assert_not_null(area.player, "player avatar present")
	assert_eq(area.map_size, Vector2(3200, 2000), "the pass is massive")
	var foes: int = 0
	for child: Node in area.get_children():
		if child is OverworldFoe:
			foes += 1
	assert_eq(foes, 4, "four patrols on a fresh run")
	var torches: int = 0
	for node: Node in get_tree().get_nodes_in_group("torch_light"):
		if area.is_ancestor_of(node):
			torches += 1
	assert_eq(torches, 6, "six road torches")
	var prompts: Array[String] = []
	for entry: Dictionary in area._interactables:
		prompts.append(String(entry["prompt"]))
	assert_has(prompts, "Rest at the save crystal")


func test_town_carries_castle_save_and_torches() -> void:
	var area: AreaBase = load("res://world/town.tscn").instantiate()
	add_child_autofree(area)
	await get_tree().process_frame
	assert_eq(area.map_size, Vector2(2560, 1600), "town doubled in size")
	var prompts: Array[String] = []
	for entry: Dictionary in area._interactables:
		prompts.append(String(entry["prompt"]))
	assert_has(prompts, "Knock at the castle gate")
	assert_has(prompts, "Rest at the save crystal")
	var torches: int = 0
	for node: Node in get_tree().get_nodes_in_group("torch_light"):
		if area.is_ancestor_of(node):
			torches += 1
	assert_eq(torches, 7, "seven town torches")


func test_map_chain_scenes_exist_and_page_toggles() -> void:
	for stop: Dictionary in CharacterMenuOverlay.MAP_CHAIN:
		assert_true(ResourceLoader.exists(String(stop["scene"])), String(stop["scene"]))
	_world.note_area_visit("res://world/town.tscn")
	_world.note_area_visit("res://world/forest.tscn")
	var overlay: CharacterMenuOverlay = CharacterMenuOverlay.new()
	add_child_autofree(overlay)
	await get_tree().process_frame
	assert_false(overlay._on_map_page, "opens on the front menu page")
	assert_true(overlay._menu_root.visible)
	overlay._toggle_map()
	assert_true(overlay._on_map_page)
	assert_true(overlay._map_root.visible)
	assert_false(overlay._menu_root.visible)
	overlay._toggle_map()  # Esc/C on the map returns to the menu, not out
	assert_false(overlay._on_map_page)
	assert_true(overlay._menu_root.visible)
	assert_false(overlay._map_root.visible)
	overlay._show_page("party")
	assert_true(overlay._cards_root.visible, "party cards live one page deeper")
	overlay._show_page("guide")
	assert_true(overlay._guide_root.visible)
