extends GutTest
## M1: Resolve band classification + Darkness curves (build plan 5.2).

const EPS: float = 0.0001


func test_resolve_band_classification() -> void:
	assert_eq(MeterMath.resolve_band(0.0), MeterMath.ResolveBand.BROKEN)
	assert_eq(MeterMath.resolve_band(15.0), MeterMath.ResolveBand.BROKEN)
	assert_eq(MeterMath.resolve_band(30.0), MeterMath.ResolveBand.BROKEN)
	assert_eq(MeterMath.resolve_band(31.0), MeterMath.ResolveBand.SHAKEN)
	assert_eq(MeterMath.resolve_band(39.0), MeterMath.ResolveBand.SHAKEN)
	assert_eq(MeterMath.resolve_band(40.0), MeterMath.ResolveBand.NEUTRAL)
	assert_eq(MeterMath.resolve_band(60.0), MeterMath.ResolveBand.NEUTRAL)
	assert_eq(MeterMath.resolve_band(80.0), MeterMath.ResolveBand.NEUTRAL)
	assert_eq(MeterMath.resolve_band(81.0), MeterMath.ResolveBand.STEADY)
	assert_eq(MeterMath.resolve_band(100.0), MeterMath.ResolveBand.STEADY)
	assert_eq(MeterMath.resolve_band(101.0), MeterMath.ResolveBand.UNYIELDING)
	assert_eq(MeterMath.resolve_band(120.0), MeterMath.ResolveBand.UNYIELDING)


func test_resolve_band_clamps_out_of_range() -> void:
	assert_eq(MeterMath.resolve_band(-10.0), MeterMath.ResolveBand.BROKEN)
	assert_eq(MeterMath.resolve_band(500.0), MeterMath.ResolveBand.UNYIELDING)


func test_band_names() -> void:
	assert_eq(MeterMath.band_name(MeterMath.ResolveBand.BROKEN), "Broken")
	assert_eq(MeterMath.band_name(MeterMath.ResolveBand.SHAKEN), "Shaken")
	assert_eq(MeterMath.band_name(MeterMath.ResolveBand.NEUTRAL), "Neutral")
	assert_eq(MeterMath.band_name(MeterMath.ResolveBand.STEADY), "Steady")
	assert_eq(MeterMath.band_name(MeterMath.ResolveBand.UNYIELDING), "Unyielding")


func test_darkness_hp_degradation() -> void:
	assert_almost_eq(MeterMath.darkness_max_hp_mult(0.0), 1.0, EPS)
	assert_almost_eq(MeterMath.darkness_max_hp_mult(50.0), 0.85, EPS)
	assert_almost_eq(MeterMath.darkness_max_hp_mult(100.0), 0.70, EPS)


func test_darkness_accuracy_penalty() -> void:
	assert_almost_eq(MeterMath.darkness_accuracy_penalty(0.0), 0.0, EPS)
	assert_almost_eq(MeterMath.darkness_accuracy_penalty(19.9), 0.0, EPS)
	assert_almost_eq(MeterMath.darkness_accuracy_penalty(20.0), 0.0, EPS)
	assert_almost_eq(MeterMath.darkness_accuracy_penalty(60.0), 10.0, EPS)
	assert_almost_eq(MeterMath.darkness_accuracy_penalty(100.0), 20.0, EPS)


func test_darkness_forced_ko_threshold() -> void:
	assert_false(MeterMath.is_forced_ko(0.0))
	assert_false(MeterMath.is_forced_ko(99.9))
	assert_true(MeterMath.is_forced_ko(100.0))
