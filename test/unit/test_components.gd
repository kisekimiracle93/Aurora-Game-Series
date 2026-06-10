extends GutTest
## M1: component wrappers (Stats / Meters / CTB) around the pure math.

const EPS: float = 0.0001

const BASTIL_STATS: Dictionary = {
	"hp": 340,
	"aether": 40,
	"power": 32,
	"focus": 22,
	"guard": 30,
	"ward": 24,
	"speed": 24,
	"accuracy": 92,
	"evasion": 6,
	"crit": 6,
}


func _make_stats() -> StatsComponent:
	var stats: StatsComponent = autofree(StatsComponent.new())
	stats.setup(BASTIL_STATS, {"Fire": "resist", "Ice": "neutral"})
	return stats


# --- StatsComponent -----------------------------------------------------------


func test_stats_setup_fills_pools() -> void:
	var stats: StatsComponent = _make_stats()
	assert_eq(stats.max_hp(), 340)
	assert_eq(stats.current_hp, 340)
	assert_eq(stats.current_aether, 40)
	assert_eq(stats.get_stat("power"), 32)
	assert_eq(stats.affinity_for("Fire"), "resist")
	assert_eq(stats.affinity_for("Time"), "neutral")
	assert_true(stats.is_alive())


func test_take_damage_and_death_signal() -> void:
	var stats: StatsComponent = _make_stats()
	watch_signals(stats)
	stats.take_damage(100)
	assert_eq(stats.current_hp, 240)
	assert_signal_emitted(stats, "hp_changed")
	assert_signal_not_emitted(stats, "died")
	stats.take_damage(999)
	assert_eq(stats.current_hp, 0)
	assert_signal_emitted(stats, "died")
	assert_false(stats.is_alive())
	# Dying again does not re-emit.
	stats.take_damage(5)
	assert_signal_emit_count(stats, "died", 1)


func test_heal_clamps_and_ignores_the_dead() -> void:
	var stats: StatsComponent = _make_stats()
	stats.take_damage(50)
	stats.heal(500)
	assert_eq(stats.current_hp, 340)
	stats.take_damage(9999)
	stats.heal(100)
	assert_eq(stats.current_hp, 0, "heal should not raise the dead")
	stats.revive(50)
	assert_eq(stats.current_hp, 50)


func test_aether_spend_and_restore() -> void:
	var stats: StatsComponent = _make_stats()
	assert_true(stats.spend_aether(15))
	assert_eq(stats.current_aether, 25)
	assert_false(stats.spend_aether(26), "cannot overspend")
	assert_eq(stats.current_aether, 25)
	stats.restore_aether(100)
	assert_eq(stats.current_aether, 40)


func test_darkness_hp_degradation_clamps_current_hp() -> void:
	var stats: StatsComponent = _make_stats()
	stats.set_max_hp_mult(MeterMath.darkness_max_hp_mult(100.0))  # 0.70
	assert_eq(stats.max_hp(), 238)
	assert_eq(stats.current_hp, 238, "current HP clamps into the shrunken pool")
	stats.set_max_hp_mult(1.0)
	assert_eq(stats.max_hp(), 340)
	assert_eq(stats.current_hp, 238, "restoring the cap does not heal")


# --- MetersComponent ----------------------------------------------------------


func test_meters_register_and_clamp() -> void:
	var meters: MetersComponent = autofree(MetersComponent.new())
	meters.register_resolve()
	meters.register_darkness()
	assert_almost_eq(meters.resolve(), 60.0, EPS)
	meters.set_value(MetersComponent.RESOLVE, 500.0)
	assert_almost_eq(meters.resolve(), 120.0, EPS)
	meters.add(MetersComponent.RESOLVE, -500.0)
	assert_almost_eq(meters.resolve(), 0.0, EPS)
	meters.add(MetersComponent.DARKNESS, 150.0)
	assert_almost_eq(meters.darkness(), 100.0, EPS)


func test_meters_signal_on_change_only() -> void:
	var meters: MetersComponent = autofree(MetersComponent.new())
	meters.register_resolve()
	watch_signals(meters)
	meters.add(MetersComponent.RESOLVE, -20.0)
	assert_signal_emitted_with_parameters(
		meters, "meter_changed", [MetersComponent.RESOLVE, 60.0, 40.0]
	)
	meters.set_value(MetersComponent.RESOLVE, 40.0)  # no change
	assert_signal_emit_count(meters, "meter_changed", 1)


func test_meters_generic_registry_for_future_meters() -> void:
	var meters: MetersComponent = autofree(MetersComponent.new())
	meters.register_resolve()
	meters.register_darkness()
	meters.register_meter(&"duty", 0.0, 100.0, 50.0, true)  # future meter plugs in
	assert_true(meters.has_meter(&"duty"))
	assert_almost_eq(meters.get_value(&"duty"), 50.0, EPS)
	var persistent: Array[StringName] = meters.get_persistent_ids()
	assert_has(persistent, MetersComponent.RESOLVE)
	assert_has(persistent, MetersComponent.DARKNESS)
	assert_has(persistent, &"duty")
	assert_false(meters.has_meter(&"burden"))
	assert_eq(meters.get_value(&"burden"), 0.0, "unregistered meter reads 0")


func test_meters_resolve_band_passthrough() -> void:
	var meters: MetersComponent = autofree(MetersComponent.new())
	meters.register_resolve(20.0)
	assert_eq(meters.resolve_band(), MeterMath.ResolveBand.BROKEN)


# --- CTBComponent ---------------------------------------------------------------


func test_ctb_component_advance_and_act() -> void:
	var ctb: CTBComponent = autofree(CTBComponent.new())
	ctb.setup(25.0)
	var spd: float = ctb.effective_speed(60.0)
	assert_almost_eq(spd, 25.0, EPS)
	assert_eq(ctb.ticks_to_act(spd), 40)
	ctb.advance(40, spd)
	assert_true(ctb.is_ready())
	ctb.pay_action_cost(CTBMath.COST_ATTACK)
	assert_almost_eq(ctb.ct, 150.0, EPS)
	assert_false(ctb.is_ready())


func test_ctb_component_resolve_affects_speed() -> void:
	var ctb: CTBComponent = autofree(CTBComponent.new())
	ctb.setup(24.0)
	assert_almost_eq(ctb.effective_speed(0.0), 16.8, EPS)
	assert_almost_eq(ctb.effective_speed(120.0), 30.0, EPS)


func test_ctb_component_delay_without_resistance() -> void:
	var ctb: CTBComponent = autofree(CTBComponent.new())
	ctb.setup(20.0)  # trash mob: no DR accumulation
	ctb.advance(40, 20.0)  # ct 800
	assert_true(ctb.receive_delay(350.0))
	assert_almost_eq(ctb.ct, 450.0, EPS)
	assert_almost_eq(ctb.delay_resistance, 0.0, EPS)
	assert_true(ctb.receive_delay(350.0), "no resistance buildup on trash")
	assert_almost_eq(ctb.ct, 100.0, EPS)


func test_ctb_component_boss_delay_resistance_to_immunity() -> void:
	var ctb: CTBComponent = autofree(CTBComponent.new())
	ctb.setup(20.0, true)  # boss: accumulates DR
	ctb.advance(50, 20.0)  # ct 1000
	assert_true(ctb.receive_delay(200.0))  # full 200 lands
	assert_almost_eq(ctb.ct, 800.0, EPS)
	assert_almost_eq(ctb.delay_resistance, 0.25, EPS)
	assert_true(ctb.receive_delay(200.0))  # 150 lands
	assert_almost_eq(ctb.ct, 650.0, EPS)
	assert_true(ctb.receive_delay(200.0))  # 100 lands
	assert_almost_eq(ctb.ct, 550.0, EPS)
	assert_true(ctb.receive_delay(200.0))  # 50 lands; DR caps at 1.0
	assert_almost_eq(ctb.ct, 500.0, EPS)
	assert_almost_eq(ctb.delay_resistance, 1.0, EPS)
	assert_false(ctb.receive_delay(500.0), "immune at DR=100%")
	assert_almost_eq(ctb.ct, 500.0, EPS)
