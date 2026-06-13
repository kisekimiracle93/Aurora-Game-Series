extends GutTest
## The HD-2D pilot: 3D world, 2D souls. Kit loaders resolve, the pixel
## mapping holds, and Selenora-3D boots with a billboarded walker and the
## diorama camera live.


func test_pixel_to_world_mapping() -> void:
	assert_eq(HDAssets.to3d(Vector2(64, 128)), Vector3(1, 0, 2), "64px = 1 unit")
	assert_eq(HDAssets.to3d(Vector2(3840, 2400), 0.5), Vector3(60, 0.5, 37.5))


func test_kit_loaders_resolve_models() -> void:
	var castle: Node3D = HDAssets.medieval("building_castle_red")
	assert_not_null(castle, "the castle is real now")
	if castle != null:
		assert_true(castle is MeshInstance3D, "obj wraps into a mesh instance")
		castle.free()
	var wall: Node3D = HDAssets.dungeon("wall")
	assert_not_null(wall, "dungeon kit loads")
	if wall != null:
		wall.free()
	var pine: Node3D = HDAssets.nature("PineTree_1")
	assert_not_null(pine, "nature kit loads")
	if pine != null:
		pine.free()
	assert_null(HDAssets.medieval("no_such_building"), "missing models fail soft")


func test_hd_selenora_boots_with_player_and_camera() -> void:
	var area: HDBase = load("res://world3d/hd_selenora.tscn").instantiate()
	add_child_autofree(area)
	await get_tree().process_frame
	assert_not_null(area.player, "the billboarded walker stands")
	assert_not_null(area.player.camera, "the diorama rig rides along")
	assert_almost_eq(area.player.camera.fov, 33.0, 0.1, "long lens, miniature world")
	assert_not_null(area.player.camera.attributes, "depth of field armed")
	var lights: int = 0
	var environment_found: bool = false
	for child: Node in area.get_children():
		if child is OmniLight3D:
			lights += 1
		if child is WorldEnvironment:
			environment_found = true
			var env: Environment = (child as WorldEnvironment).environment
			assert_true(env.ssao_enabled, "SSAO on (Forward+)")
			assert_true(env.volumetric_fog_enabled, "volumetric fog on (Forward+)")
			assert_true(env.glow_enabled)
	assert_true(environment_found, "the HD-2D environment stack exists")
	assert_gt(lights, 5, "torches burn in 3D")
	assert_lt(PlayerAvatar3D.WALK_SPEED, PlayerAvatar3D.RUN_SPEED)
	assert_true(
		ResourceLoader.exists("res://world/town.tscn"), "the portal home exists"
	)


func test_full_3d_world_chain_boots() -> void:
	# Every HD-2D area instances with a player, a graded environment, and the
	# cinematic post layer — the whole walkable world ported to 3D.
	for path: String in [
		"res://world3d/hd_selenora.tscn", "res://world3d/hd_forest.tscn",
		"res://world3d/hd_deepwoods.tscn", "res://world3d/hd_fields.tscn",
		"res://world3d/hd_dungeon.tscn",
	]:
		var area: HDBase = load(path).instantiate()
		add_child_autofree(area)
		await get_tree().process_frame
		assert_not_null(area.player, "%s walker" % path.get_file())
		assert_not_null(area.environment, "%s graded environment" % path.get_file())
		var has_cinema: bool = false
		for child: Node in area.get_children():
			if child is CanvasLayer and (child as CanvasLayer).layer == 70:
				has_cinema = true
		assert_true(has_cinema, "%s cinematic post layer" % path.get_file())
		area.queue_free()
		await get_tree().process_frame


func test_cinematic_shader_and_foley_present() -> void:
	assert_true(
		ResourceLoader.exists("res://world3d/shaders/hd_cinematic.gdshader"),
		"the tilt-shift / grade / grain post shader"
	)
	# Footstep + ambience foley wired from the uploaded library.
	assert_not_null(PlayerAvatar3D._load_foley("Footsteps_walking"), "footsteps")
	assert_not_null(PlayerAvatar3D._load_foley("Rain_Heavy"), "deep-woods rain")
