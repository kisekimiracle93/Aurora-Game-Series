extends GutTest
## The beauty/feel pass: re-cropped art (real pines!), corrected walk-facing
## frames, the soundscape score sheet, the party mood reader, night-heavy
## clock, biome battle stages, battle facing, new inputs, postfx layering,
## minimap bookkeeping, and the enemy HP cuts.

var _atmosphere: Node
var _saved_hour: float = 10.0
var _saved_advancing: bool = false


func before_each() -> void:
	_atmosphere = get_node_or_null("/root/Atmosphere")
	if _atmosphere != null:
		_saved_hour = _atmosphere.hour
		_saved_advancing = _atmosphere.advancing


func after_each() -> void:
	if _atmosphere != null:
		_atmosphere.hour = _saved_hour
		_atmosphere.advancing = _saved_advancing
		_atmosphere.set("_was_night", _atmosphere.is_night())


## --- art regeneration ------------------------------------------------------------


func test_recropped_props_exist_and_pine_is_a_real_grove() -> void:
	for prop_name: String in [
		"pine_cluster", "pine_single", "house_inn", "house_tall", "chest", "barrel",
		"water_tile", "waterfall", "rock_wall", "cobble_h", "cobble_v", "dirt_patch", "posts",
	]:
		assert_not_null(AssetLibrary.texture("props", prop_name), prop_name)
	var pines: Texture2D = AssetLibrary.texture("props", "pine_cluster")
	if pines != null:
		assert_gt(pines.get_width(), 60, "the grove, not a fence sliver")
		assert_gt(pines.get_height(), 100)
	var single: Texture2D = AssetLibrary.texture("props", "pine_single")
	if single != null:
		assert_lt(single.get_width(), 16, "one slim pine")


func test_walk_sets_regenerated_with_all_four_facings() -> void:
	for character: String in ["bastil", "cavene", "church_lancer", "roadside_bandit"]:
		for direction: String in ["up", "down", "left", "right"]:
			for frame: int in range(3):
				assert_true(
					ResourceLoader.exists(
						"res://assets/sprites/walk/%s_%s_%d.png" % [character, direction, frame]
					),
					"%s %s %d" % [character, direction, frame]
				)


## --- the soundscape score sheet ----------------------------------------------------


func test_soundscape_profiles_pick_the_right_voices() -> void:
	var script: GDScript = load("res://world/soundscape_manager.gd")
	assert_has(script.beds_for("town", false), "murmur", "village hubbub by day")
	assert_has(script.beds_for("town", true), "crickets", "crickets after dark")
	assert_has(script.beds_for("town", true), "water", "the river never sleeps")
	assert_has(script.beds_for("forest", true), "night_wind")
	assert_has(script.oneshots_for("forest", true), "wolf_howl")
	assert_has(script.oneshots_for("forest", true), "owl")
	assert_has(script.oneshots_for("forest", false), "bird")
	assert_has(script.oneshots_for("fields", true), "coyote")
	assert_has(script.beds_for("dungeon", true), "drips")
	assert_eq(script.beds_for("battle", false).size(), 0, "battles keep a clean mix")
	assert_eq(script.beds_for("menu", true).size(), 0)
	assert_true(script.ducks_music("wolf_howl"), "the big calls bow the music")
	assert_false(script.ducks_music("bird"))


func test_soundscape_synthesizes_every_named_sound() -> void:
	var script: GDScript = load("res://world/soundscape_manager.gd")
	for sound_name: String in [
		"wind", "night_wind", "leaves", "crickets", "murmur", "water", "drips",
		"owl", "wolf_howl", "coyote", "bird", "cricket_solo", "frog", "dog",
		"chicken", "giggle", "hammer", "branch", "bell", "plink", "rumble",
	]:
		var stream: AudioStreamWAV = script.synth_stream(sound_name)
		assert_not_null(stream, sound_name)
		if stream != null:
			assert_gt(stream.data.size(), 1000, sound_name + " has real audio")
	assert_not_null(get_node_or_null("/root/Soundscape"), "autoload present")


## --- the party mood reader ----------------------------------------------------------


func test_member_states_read_the_meters() -> void:
	assert_eq(PartyMood.member_state(60.0, 50.0, 0.0, 0.0, false), "steady", "fresh party")
	assert_eq(PartyMood.member_state(88.0, 70.0, 0.0, 0.0, false), "burning with conviction")
	assert_eq(PartyMood.member_state(88.0, 30.0, 0.0, 0.0, false), "fearless")
	assert_eq(PartyMood.member_state(75.0, 50.0, 0.0, 0.0, false), "confident")
	assert_eq(PartyMood.member_state(45.0, 50.0, 0.0, 0.0, false), "unsure")
	assert_eq(PartyMood.member_state(30.0, 50.0, 0.0, 0.0, false), "wavering")
	assert_eq(PartyMood.member_state(10.0, 50.0, 0.0, 0.0, false), "breaking")
	assert_eq(PartyMood.member_state(80.0, 50.0, 50.0, 0.0, false), "carrying too much")
	assert_eq(PartyMood.member_state(80.0, 50.0, 75.0, 0.0, false), "buried in grief")
	assert_eq(PartyMood.member_state(80.0, 50.0, 0.0, 65.0, true), "slipping into the dark")
	assert_eq(PartyMood.member_state(80.0, 50.0, 0.0, 40.0, true), "hearing the ice")
	assert_eq(
		PartyMood.member_state(80.0, 50.0, 0.0, 65.0, false), "confident",
		"darkness only weighs on Heirs"
	)


func test_party_state_bands() -> void:
	var fresh: Dictionary = {
		"Bastil": {"resolve": 60.0, "duty": 50.0, "burden": 0.0, "darkness": 0.0},
		"Mati": {"resolve": 60.0, "duty": 50.0, "burden": 0.0, "darkness": 0.0},
	}
	assert_eq(PartyMood.party_state(fresh), "The party is ready.")
	var triumphant: Dictionary = {
		"Bastil": {"resolve": 95.0, "duty": 70.0, "burden": 0.0, "darkness": 0.0},
	}
	assert_eq(PartyMood.party_state(triumphant), "The party stands greatly resolved.")
	var grieving: Dictionary = {
		"Bastil": {"resolve": 40.0, "duty": 50.0, "burden": 70.0, "darkness": 0.0},
	}
	assert_eq(PartyMood.party_state(grieving), "The party is near breaking.")
	assert_eq(PartyMood.party_state({}), "The party is ready.", "empty-safe")
	for state: String in ["confident", "buried in grief", "slipping into the dark", "steady"]:
		assert_gt(PartyMood.state_color(state).a, 0.5, state + " has a reading color")


## --- the night-heavy clock -----------------------------------------------------------


func test_clock_runs_long_and_night_heavy() -> void:
	var script: GDScript = load("res://world/atmosphere_manager.gd")
	assert_almost_eq(float(script.DAY_LENGTH_MINUTES), 15.0, 0.001, "15-minute day")
	assert_true(script.is_night_hour(19.0), "dark by 19:00")
	assert_true(script.is_night_hour(6.0), "still dark at 06:00")
	assert_false(script.is_night_hour(7.5))
	assert_false(script.is_night_hour(18.0))
	var midnight: Color = script.tint_for_hour(0.0)
	assert_lt(midnight.r, 0.30, "nights run properly dark now")
	assert_gt(midnight.b, midnight.r, "and deep blue")
	assert_almost_eq(script.night_depth_for_hour(0.5), 1.0, 0.001, "dead of night")
	assert_almost_eq(script.night_depth_for_hour(12.0), 0.0, 0.001, "no moon at noon")
	assert_between(script.night_depth_for_hour(19.5), 0.1, 0.5, "moon still rising at dusk")


## --- battle: biomes, facing, debug win, camera -----------------------------------------


func test_battle_biome_picker() -> void:
	var script: GDScript = load("res://world/battle_test.gd")
	assert_eq(script.biome_for_scene("res://world/town.tscn", "wolves_2"), "meadow")
	assert_eq(script.biome_for_scene("res://world/forest.tscn", "bandit_pair"), "forest")
	assert_eq(script.biome_for_scene("res://world/outside.tscn", "wolfpack"), "tundra")
	assert_eq(script.biome_for_scene("res://world/dungeon.tscn", "dungeon_gauntlet"), "cavern")
	assert_eq(script.biome_for_scene("", "boss"), "cavern", "the Shepherd keeps his cave")
	assert_eq(script.biome_for_scene("", "wolfpack"), "tundra", "standalone default")


func test_party_tokens_face_the_enemy_line() -> void:
	var member: BaseCombatant = autofree(
		BaseCombatant.from_character(load("res://data/characters/bastil.tres"))
	)
	var token: CombatantToken = CombatantToken.new()
	member.add_child(token)
	token.setup(member, Color.WHITE, 1.0, "right")
	add_child_autofree(member)
	await get_tree().process_frame
	var profile: AnimatedSprite2D = null
	for child: Node in token.get_children():
		if child is AnimatedSprite2D:
			profile = child
	assert_not_null(profile, "profile frames in use")
	if profile != null:
		assert_eq(String(profile.animation), "idle_right", "eyes on the foe")


func test_trash_hp_cut_but_within_plan_ranges() -> void:
	var wolf: EnemyData = load("res://data/enemies/aether_wolf.tres")
	assert_between(int(wolf.base_stats["hp"]), 80, 130, "wolf trimmed for faster fights")
	var stag: EnemyData = load("res://data/enemies/icebound_stag.tres")
	assert_gt(int(stag.base_stats["hp"]), 300, "mini-elite keeps its bulk")
	var boss: EnemyData = load("res://data/enemies/frozen_shepherd.tres")
	assert_eq(int(boss.base_stats["hp"]), 1500, "the Shepherd is untouched")
	assert_gt(BattleCamera.ACT_ZOOM, 1.4, "the camera really commits now")
	assert_gt(BattleCamera.ECHO_ZOOM, BattleCamera.ACT_ZOOM)


## --- inputs, lens layering, minimap ---------------------------------------------------


func test_new_input_actions_registered() -> void:
	assert_true(InputMap.has_action("run_toggle"), "G sprint")
	assert_true(InputMap.has_action("lantern"), "T lantern")
	assert_true(InputMap.has_action("lens_zoom"), "Z tight lens")
	assert_lt(PlayerAvatar.WALK_SPEED, PlayerAvatar.RUN_SPEED)


func test_battle_weather_palettes_cover_every_biome() -> void:
	for biome_name: String in ["meadow", "forest", "tundra", "cavern"]:
		var look: Dictionary = BattleWeather.palette(biome_name)
		assert_true(look.has("fall") and look.has("pile") and look.has("ray"), biome_name)
		assert_gt(int(look["amount"]), 0, biome_name + " weather falls")
	assert_gt(BattleCamera.FREE_LOOK_REACH.x, 100.0, "a real few inches of freedom")
	assert_lt(BattleCamera.FREE_LOOK_REACH.x, 400.0, "freedom, not a map scroll")


func test_lens_sits_below_the_ui() -> void:
	var postfx: Node = get_node_or_null("/root/PostFX")
	assert_not_null(postfx)
	if postfx != null:
		assert_eq(int((postfx as CanvasLayer).layer), 55, "lens under the UI layers")
		assert_lt(int((postfx as CanvasLayer).layer), 80, "UI (80+) stays sharp")


func test_area_minimap_tracks_exits_and_saves() -> void:
	if _atmosphere != null:
		_atmosphere.hour = 12.0
	var area: AreaBase = AreaBase.new()
	add_child_autofree(area)
	await get_tree().process_frame
	assert_not_null(area._minimap, "minimap built into the HUD")
	area.add_exit(Rect2(0, 300, 40, 100), "res://world/town.tscn", Vector2.ZERO)
	area.add_save_crystal(Vector2(400, 300))
	assert_eq(area._exit_rects.size(), 1)
	assert_eq(area._save_points.size(), 1)
	# Night decor wiring: fireflies exist and obey the dark.
	assert_not_null(area._fireflies)
	if area._fireflies != null:
		area._apply_night_decor(true)
		assert_true(area._fireflies.emitting, "fireflies wake at night")
		area._apply_night_decor(false)
		assert_false(area._fireflies.emitting)
