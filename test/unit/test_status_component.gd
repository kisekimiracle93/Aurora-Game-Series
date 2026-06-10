extends GutTest
## M2: StatusComponent — application, resistance stacking, immunity, blocks, ticks.

const EPS: float = 0.0001

var _freeze: StatusData
var _burn: StatusData
var _slow: StatusData
var _silence: StatusData
var _bleed: StatusData
var _shock: StatusData


func before_each() -> void:
	_freeze = load("res://data/statuses/freeze.tres")
	_burn = load("res://data/statuses/burn.tres")
	_slow = load("res://data/statuses/slow.tres")
	_silence = load("res://data/statuses/silence.tres")
	_bleed = load("res://data/statuses/bleed.tres")
	_shock = load("res://data/statuses/resolve_shock.tres")


func _make_component(resistance: float = 0.0) -> StatusComponent:
	var status: StatusComponent = autofree(StatusComponent.new())
	status.setup(resistance)
	return status


## Neutral midline: focus 20 vs ward 20, Resolve 60 -> chance == base_chance.
func _apply(
	status: StatusComponent, data: StatusData, base_chance: float, roll: float
) -> Dictionary:
	return status.try_apply(data, base_chance, 20.0, 20.0, 60.0, roll)


func test_all_six_status_resources_load() -> void:
	for data: StatusData in [_freeze, _burn, _slow, _silence, _bleed, _shock]:
		assert_not_null(data)
	assert_eq(_freeze.id, "freeze")
	assert_true(_freeze.blocks_action)
	assert_eq(_burn.on_tick, "burn_damage")
	assert_almost_eq(_slow.speed_mult, 0.7, EPS)
	assert_true(_silence.blocks_spells)
	assert_almost_eq(_bleed.tick_fraction, 0.04, EPS)
	assert_eq(_shock.resolve_drop_min, 20)
	assert_eq(_shock.resolve_drop_max, 40)


func test_apply_lands_below_chance_and_misses_above() -> void:
	var status: StatusComponent = _make_component()
	watch_signals(status)
	var hit: Dictionary = _apply(status, _freeze, 80.0, 50.0)
	assert_true(hit["landed"])
	assert_almost_eq(hit["chance"], 80.0, EPS)
	assert_eq(hit["duration"], 2)
	assert_true(status.has_status("freeze"))
	assert_signal_emitted(status, "status_applied")

	var status2: StatusComponent = _make_component()
	watch_signals(status2)
	var miss: Dictionary = _apply(status2, _freeze, 80.0, 85.0)
	assert_false(miss["landed"])
	assert_false(status2.has_status("freeze"))
	assert_signal_emitted(status2, "status_resisted")


func test_immunity_blocks_application() -> void:
	var status: StatusComponent = _make_component()
	status.set_immunity("freeze")
	var result: Dictionary = _apply(status, _freeze, 95.0, 0.0)
	assert_false(result["landed"])
	assert_false(status.has_status("freeze"))
	status.set_immunity("freeze", false)
	assert_true(_apply(status, _freeze, 95.0, 0.0)["landed"])


func test_resistance_stacks_per_successful_application() -> void:
	var status: StatusComponent = _make_component()
	assert_almost_eq(status.resistance_for("burn"), 0.0, EPS)
	assert_true(_apply(status, _burn, 80.0, 10.0)["landed"])
	assert_almost_eq(status.resistance_for("burn"), 20.0, EPS)
	# Next chance is 60: a roll of 70 now fails where it would have landed.
	var second: Dictionary = _apply(status, _burn, 80.0, 70.0)
	assert_false(second["landed"])
	assert_almost_eq(second["chance"], 60.0, EPS)
	# Failed tries do not stack further resistance.
	assert_almost_eq(status.resistance_for("burn"), 20.0, EPS)
	assert_true(_apply(status, _burn, 80.0, 50.0)["landed"])
	assert_almost_eq(status.resistance_for("burn"), 40.0, EPS)
	# Other statuses are unaffected.
	assert_almost_eq(status.resistance_for("freeze"), 0.0, EPS)


func test_innate_resistance_lowers_chance() -> void:
	var status: StatusComponent = _make_component(25.0)
	var result: Dictionary = _apply(status, _freeze, 80.0, 60.0)
	assert_almost_eq(result["chance"], 55.0, EPS)
	assert_false(result["landed"])


func test_freeze_blocks_action_and_silence_blocks_spells() -> void:
	var status: StatusComponent = _make_component()
	assert_false(status.is_action_blocked())
	assert_false(status.is_spell_blocked())
	_apply(status, _freeze, 95.0, 0.0)
	assert_true(status.is_action_blocked())
	assert_false(status.is_spell_blocked())
	_apply(status, _silence, 95.0, 0.0)
	assert_true(status.is_spell_blocked())


func test_speed_mult_combines_active_statuses() -> void:
	var status: StatusComponent = _make_component()
	assert_almost_eq(status.speed_mult(), 1.0, EPS)
	_apply(status, _slow, 95.0, 0.0)
	assert_almost_eq(status.speed_mult(), 0.7, EPS)
	_apply(status, _shock, 95.0, 0.0)
	assert_almost_eq(status.speed_mult(), 0.595, EPS)  # 0.7 * 0.85


func test_resolve_shock_returns_drop_and_debuffs() -> void:
	var status: StatusComponent = _make_component()
	var result: Dictionary = status.try_apply(_shock, 95.0, 20.0, 20.0, 60.0, 0.0, 0.5)
	assert_true(result["landed"])
	assert_eq(result["resolve_drop"], 30)  # midpoint of 20-40
	assert_almost_eq(status.accuracy_delta(), -10.0, EPS)
	assert_almost_eq(status.speed_mult(), 0.85, EPS)
	# Non-shock statuses report no drop.
	var plain: Dictionary = _apply(status, _slow, 95.0, 0.0)
	assert_eq(plain["resolve_drop"], 0)


func test_tick_emits_hooks_then_expires() -> void:
	var status: StatusComponent = _make_component()
	_apply(status, _burn, 95.0, 0.0)  # duration 3 at neutral midline
	watch_signals(status)
	var first: Array[Dictionary] = status.tick_turn()
	assert_eq(first.size(), 1)
	assert_eq(first[0]["hook"], "burn_damage")
	assert_almost_eq(float(first[0]["tick_fraction"]), 0.05, EPS)
	assert_eq(status.get_remaining("burn"), 2)
	status.tick_turn()
	var third: Array[Dictionary] = status.tick_turn()
	assert_eq(third.size(), 1, "burn ticks on its final turn too")
	assert_false(status.has_status("burn"))
	assert_signal_emitted(status, "status_expired")
	assert_eq(status.tick_turn().size(), 0)


func test_reapply_refreshes_to_longer_duration() -> void:
	var status: StatusComponent = _make_component()
	_apply(status, _burn, 95.0, 0.0)
	status.tick_turn()
	status.tick_turn()
	assert_eq(status.get_remaining("burn"), 1)
	var again: Dictionary = _apply(status, _burn, 95.0, 0.0)
	assert_true(again["landed"])
	assert_eq(status.get_remaining("burn"), 3, "refresh extends, never shortens")


func test_duration_override_from_ability_data() -> void:
	var status: StatusComponent = _make_component()
	var result: Dictionary = status.try_apply(_burn, 95.0, 20.0, 20.0, 60.0, 0.0, 0.5, 5)
	assert_eq(result["duration"], 5)


func test_clear_all_resets_battle_state() -> void:
	var status: StatusComponent = _make_component()
	_apply(status, _slow, 95.0, 0.0)
	_apply(status, _slow, 95.0, 0.0)
	assert_almost_eq(status.resistance_for("slow"), 40.0, EPS)
	status.clear_all()
	assert_false(status.has_status("slow"))
	assert_almost_eq(status.resistance_for("slow"), 0.0, EPS)
	assert_almost_eq(status.speed_mult(), 1.0, EPS)
