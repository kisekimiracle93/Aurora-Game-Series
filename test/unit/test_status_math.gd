extends GutTest
## M2: status formulas (build plan 5.5) against hand-computed values.

const EPS: float = 0.0001


func test_hit_chance_formula() -> void:
	# 50 + (30-20)*0.5 + 0 - 0 = 55
	assert_almost_eq(StatusMath.hit_chance(50.0, 30.0, 20.0, 60.0, 0.0), 55.0, EPS)


func test_hit_chance_resolve_factor() -> void:
	# Low-Resolve targets are easier to afflict (+15), high-Resolve harder (-10).
	assert_almost_eq(StatusMath.hit_chance(50.0, 30.0, 20.0, 20.0, 0.0), 70.0, EPS)
	assert_almost_eq(StatusMath.hit_chance(50.0, 30.0, 20.0, 100.0, 0.0), 45.0, EPS)
	assert_almost_eq(StatusMath.resolve_factor(39.9), 15.0, EPS)
	assert_almost_eq(StatusMath.resolve_factor(40.0), 0.0, EPS)
	assert_almost_eq(StatusMath.resolve_factor(80.0), 0.0, EPS)
	assert_almost_eq(StatusMath.resolve_factor(80.1), -10.0, EPS)


func test_hit_chance_resistance_subtracts() -> void:
	assert_almost_eq(StatusMath.hit_chance(50.0, 30.0, 20.0, 60.0, 30.0), 25.0, EPS)


func test_hit_chance_clamps_5_and_95() -> void:
	assert_almost_eq(StatusMath.hit_chance(200.0, 50.0, 0.0, 20.0, 0.0), 95.0, EPS)
	assert_almost_eq(StatusMath.hit_chance(1.0, 0.0, 100.0, 100.0, 50.0), 5.0, EPS)


func test_duration_scales_with_focus_ward_and_resolve() -> void:
	# 2 * (1 + 10/100) = 2.2 -> 2 at neutral Resolve
	assert_eq(StatusMath.duration_turns(2, 30.0, 20.0, 60.0), 2)
	# low Resolve x1.3: 2.86 -> 3
	assert_eq(StatusMath.duration_turns(2, 30.0, 20.0, 20.0), 3)
	# high Resolve x0.7: 1.54 -> 2
	assert_eq(StatusMath.duration_turns(2, 30.0, 20.0, 100.0), 2)
	# strong caster vs weak target stretches duration: 3 * 1.4 = 4.2 -> 4
	assert_eq(StatusMath.duration_turns(3, 60.0, 20.0, 60.0), 4)


func test_duration_minimum_one_turn() -> void:
	# 1 * (1 - 50/100) * 0.7 = 0.35 -> clamps to 1
	assert_eq(StatusMath.duration_turns(1, 0.0, 50.0, 100.0), 1)


func test_resolve_shock_drop_rolls_between_min_and_max() -> void:
	assert_eq(StatusMath.resolve_shock_drop(20, 40, 0.0), 20)
	assert_eq(StatusMath.resolve_shock_drop(20, 40, 0.5), 30)
	assert_eq(StatusMath.resolve_shock_drop(20, 40, 1.0), 40)
	assert_eq(StatusMath.resolve_shock_drop(20, 40, 9.0), 40, "roll clamps to [0,1]")
