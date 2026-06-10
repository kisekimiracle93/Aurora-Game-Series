extends GutTest
## M2: Echo gauge fill/spend + SaveData round-trip + retry penalty + save-point recovery.

const EPS: float = 0.0001
const TEST_SAVE_PATH: String = "user://test_save_roundtrip.tres"


func after_each() -> void:
	SaveSystem.delete(TEST_SAVE_PATH)


# --- Echo gauge ---------------------------------------------------------------


func test_echo_gain_math() -> void:
	# Dealing half the target's max HP: 25 * 0.5 = 12.5 points.
	assert_almost_eq(EchoMath.gain_from_damage_dealt(170, 340), 12.5, EPS)
	# Taking half your own max HP: 50 * 0.5 = 25 points.
	assert_almost_eq(EchoMath.gain_from_damage_taken(170, 340), 25.0, EPS)
	assert_almost_eq(EchoMath.gain_from_damage_dealt(0, 340), 0.0, EPS)
	assert_almost_eq(EchoMath.gain_from_damage_taken(-5, 340), 0.0, EPS)


func test_echo_gauge_fills_and_spends_multi_use() -> void:
	var meters: MetersComponent = autofree(MetersComponent.new())
	meters.register_echo()
	assert_almost_eq(meters.echo(), 0.0, EPS)
	assert_false(meters.echo_ready())
	assert_false(meters.spend_echo(), "cannot spend an unfilled gauge")
	meters.add(MetersComponent.ECHO, 60.0)
	meters.add(MetersComponent.ECHO, 55.0)  # clamps at 100
	assert_almost_eq(meters.echo(), 100.0, EPS)
	assert_true(meters.echo_ready())
	assert_true(meters.spend_echo())
	assert_almost_eq(meters.echo(), 0.0, EPS)
	# Multi-use per battle: refill and spend again.
	meters.add(MetersComponent.ECHO, 100.0)
	assert_true(meters.spend_echo())


# --- SaveData round-trip ------------------------------------------------------


func test_save_load_round_trips_meters() -> void:
	var save: SaveData = SaveData.new()
	save.character_resolve = {"Bastil": 72.5, "Cavene": 64.0, "Jecht": 88.0, "Mati": 41.5}
	save.heir_darkness = {"Jecht": 35.0, "Mati": 12.5}
	save.unlocked_echo_ids = ["echo_throne_of_winter"]
	save.scene_path = "res://world/town.tscn"
	save.merc_hired = true

	assert_eq(SaveSystem.write(save, TEST_SAVE_PATH), OK)
	assert_true(SaveSystem.exists(TEST_SAVE_PATH))

	var loaded: SaveData = SaveSystem.read(TEST_SAVE_PATH)
	assert_not_null(loaded)
	if loaded == null:
		return
	assert_almost_eq(float(loaded.character_resolve["Bastil"]), 72.5, EPS)
	assert_almost_eq(float(loaded.character_resolve["Mati"]), 41.5, EPS)
	assert_almost_eq(float(loaded.heir_darkness["Jecht"]), 35.0, EPS)
	assert_almost_eq(float(loaded.heir_darkness["Mati"]), 12.5, EPS)
	assert_eq(loaded.unlocked_echo_ids, ["echo_throne_of_winter"] as Array[String])
	assert_eq(loaded.scene_path, "res://world/town.tscn")
	assert_true(loaded.merc_hired)


func test_read_missing_save_returns_null() -> void:
	assert_null(SaveSystem.read("user://no_such_save.tres"))


# --- retry penalty ------------------------------------------------------------


func test_retry_lowers_resolve_clamped_at_zero() -> void:
	var save: SaveData = SaveData.new()
	save.character_resolve = {"Bastil": 72.0, "Jecht": 10.0}
	SaveSystem.apply_retry_penalty(save)
	assert_almost_eq(float(save.character_resolve["Bastil"]), 57.0, EPS)
	assert_almost_eq(float(save.character_resolve["Jecht"]), 0.0, EPS)


# --- save-point recovery ------------------------------------------------------


func test_save_point_drains_darkness_and_restores_resolve() -> void:
	var heir: MetersComponent = autofree(MetersComponent.new())
	heir.register_resolve(50.0)
	heir.register_darkness(80.0)
	SaveSystem.apply_save_point_recovery(heir)
	assert_almost_eq(heir.resolve(), 75.0, EPS, "low Resolve restored to the floor")
	assert_almost_eq(heir.darkness(), 0.0, EPS, "Darkness drained")

	var steady: MetersComponent = autofree(MetersComponent.new())
	steady.register_resolve(90.0)
	SaveSystem.apply_save_point_recovery(steady)
	assert_almost_eq(steady.resolve(), 90.0, EPS, "high Resolve is never lowered")


# --- collect / apply ----------------------------------------------------------


func test_collect_and_apply_meters() -> void:
	var jecht: MetersComponent = autofree(MetersComponent.new())
	jecht.register_resolve(88.0)
	jecht.register_darkness(35.0)
	var save: SaveData = SaveData.new()
	SaveSystem.collect_meters(save, "Jecht", jecht)
	assert_almost_eq(float(save.character_resolve["Jecht"]), 88.0, EPS)
	assert_almost_eq(float(save.heir_darkness["Jecht"]), 35.0, EPS)

	var fresh: MetersComponent = autofree(MetersComponent.new())
	fresh.register_resolve()
	fresh.register_darkness()
	SaveSystem.apply_meters(save, "Jecht", fresh)
	assert_almost_eq(fresh.resolve(), 88.0, EPS)
	assert_almost_eq(fresh.darkness(), 35.0, EPS)

	# Non-heir: no darkness meter registered, apply skips it cleanly.
	var bastil: MetersComponent = autofree(MetersComponent.new())
	bastil.register_resolve(70.0)
	SaveSystem.collect_meters(save, "Bastil", bastil)
	assert_false(save.heir_darkness.has("Bastil"))
	SaveSystem.apply_meters(save, "Bastil", bastil)
	assert_false(bastil.has_meter(MetersComponent.DARKNESS))
