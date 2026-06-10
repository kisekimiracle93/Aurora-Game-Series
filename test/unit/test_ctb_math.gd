extends GutTest
## M1: CTB formulas (build plan 5.3) against hand-computed values.

const EPS: float = 0.0001


# --- effective speed ---------------------------------------------------------


func test_resolve_speed_mult_neutral_band_is_flat() -> void:
	assert_almost_eq(CTBMath.resolve_speed_mult(40.0), 1.0, EPS)
	assert_almost_eq(CTBMath.resolve_speed_mult(60.0), 1.0, EPS)
	assert_almost_eq(CTBMath.resolve_speed_mult(80.0), 1.0, EPS)


func test_resolve_speed_mult_low_resolve_slows() -> void:
	assert_almost_eq(CTBMath.resolve_speed_mult(0.0), 0.70, EPS)
	assert_almost_eq(CTBMath.resolve_speed_mult(20.0), 0.85, EPS)


func test_resolve_speed_mult_high_resolve_hastens() -> void:
	assert_almost_eq(CTBMath.resolve_speed_mult(120.0), 1.25, EPS)
	# 1.0 + 0.25 * (20/40)^1.2 = 1.0 + 0.25 * 0.4352752816...
	assert_almost_eq(CTBMath.resolve_speed_mult(100.0), 1.1088188, EPS)


func test_combined_status_mult_multiplies_and_clamps() -> void:
	assert_almost_eq(CTBMath.combined_status_mult([0.7] as Array[float]), 0.7, EPS)
	assert_almost_eq(CTBMath.combined_status_mult([0.7, 0.7] as Array[float]), 0.49, EPS)
	assert_almost_eq(CTBMath.combined_status_mult([1.3, 1.3] as Array[float]), 1.50, EPS)
	assert_almost_eq(CTBMath.combined_status_mult([0.05, 0.5] as Array[float]), 0.05, EPS)
	assert_almost_eq(CTBMath.combined_status_mult([] as Array[float]), 1.0, EPS)


func test_darkness_speed_bonus_caps_at_15_percent() -> void:
	assert_almost_eq(CTBMath.darkness_speed_bonus(0.0), 1.0, EPS)
	assert_almost_eq(CTBMath.darkness_speed_bonus(50.0), 1.075, EPS)
	assert_almost_eq(CTBMath.darkness_speed_bonus(100.0), 1.15, EPS)
	assert_almost_eq(CTBMath.darkness_speed_bonus(250.0), 1.15, EPS)


func test_effective_speed_combines_factors() -> void:
	assert_almost_eq(CTBMath.effective_speed(24.0, 60.0), 24.0, EPS)
	assert_almost_eq(CTBMath.effective_speed(24.0, 0.0), 16.8, EPS)
	assert_almost_eq(CTBMath.effective_speed(24.0, 60.0, 0.7), 16.8, EPS)
	# Stop-lite floor keeps speed positive.
	assert_gt(CTBMath.effective_speed(24.0, 60.0, 0.05), 0.0)


# --- ticks to act ------------------------------------------------------------


func test_ticks_to_act_known_stats() -> void:
	assert_eq(CTBMath.ticks_to_act(0.0, 25.0), 40)
	assert_eq(CTBMath.ticks_to_act(0.0, 24.0), 42)  # ceil(41.67)
	assert_eq(CTBMath.ticks_to_act(999.0, 100.0), 1)
	assert_eq(CTBMath.ticks_to_act(1000.0, 100.0), 0)
	assert_eq(CTBMath.ticks_to_act(1200.0, 100.0), 0)


# --- turn order / jump time --------------------------------------------------


func _mixed_group() -> Array:
	return [
		{"id": "A", "ct": 0.0, "spd": 30.0},
		{"id": "B", "ct": 0.0, "spd": 25.0},
		{"id": "C", "ct": 0.0, "spd": 20.0},
	]


func test_advance_to_next_turn_fastest_acts_first() -> void:
	var entries: Array = _mixed_group()
	var result: Dictionary = CTBMath.advance_to_next_turn(entries)
	assert_eq(result["actor_id"], "A")
	assert_eq(result["ticks"], 34)  # ceil(1000/30)
	assert_almost_eq(entries[0]["ct"], 1020.0, EPS)
	assert_almost_eq(entries[1]["ct"], 850.0, EPS)
	assert_almost_eq(entries[2]["ct"], 680.0, EPS)


func test_turn_order_across_mixed_group_with_action_costs() -> void:
	# Hand-simulated with Normal (850) costs: A, B, C, then A laps back around.
	var order: Array = CTBMath.build_preview(_mixed_group(), 4, CTBMath.COST_NORMAL)
	assert_eq(order, ["A", "B", "C", "A"])


func test_build_preview_does_not_mutate_input() -> void:
	var entries: Array = _mixed_group()
	CTBMath.build_preview(entries, 5)
	assert_almost_eq(entries[0]["ct"], 0.0, EPS)
	assert_almost_eq(entries[2]["ct"], 0.0, EPS)


func test_tie_breaks_higher_ct_then_higher_speed() -> void:
	# Both reach threshold on the same tick; D overflows further.
	var entries: Array = [
		{"id": "D", "ct": 900.0, "spd": 60.0},
		{"id": "E", "ct": 900.0, "spd": 50.0},
	]
	var result: Dictionary = CTBMath.advance_to_next_turn(entries)
	assert_eq(result["actor_id"], "D")
	# Exact CT tie: higher speed wins.
	var tied: Array = [
		{"id": "F", "ct": 950.0, "spd": 25.0},
		{"id": "G", "ct": 950.0, "spd": 50.0},
	]
	var tied_result: Dictionary = CTBMath.advance_to_next_turn(tied)
	assert_eq(tied_result["actor_id"], "G")


# --- action cost pushback ----------------------------------------------------


func test_action_cost_pushes_next_turn_back() -> void:
	assert_almost_eq(CTBMath.pay_action_cost(1000.0, CTBMath.COST_ATTACK), 150.0, EPS)
	# Heavier actions wait longer for the next turn (spd 100).
	var after_guard: float = CTBMath.pay_action_cost(1000.0, CTBMath.COST_GUARD)
	var after_very_heavy: float = CTBMath.pay_action_cost(1000.0, CTBMath.COST_VERY_HEAVY)
	assert_eq(CTBMath.ticks_to_act(after_guard, 100.0), 7)  # ceil(650/100)
	assert_eq(CTBMath.ticks_to_act(after_very_heavy, 100.0), 14)  # ceil(1350/100)
	assert_gt(
		CTBMath.ticks_to_act(after_very_heavy, 100.0),
		CTBMath.ticks_to_act(after_guard, 100.0)
	)


# --- delay + delay resistance ------------------------------------------------


func test_delay_pushes_ct_back() -> void:
	assert_almost_eq(CTBMath.apply_delay(800.0, CTBMath.DELAY_MEDIUM, 0.0), 450.0, EPS)
	assert_almost_eq(CTBMath.apply_delay(800.0, CTBMath.DELAY_SMALL, 0.0), 600.0, EPS)
	assert_almost_eq(CTBMath.apply_delay(800.0, CTBMath.DELAY_BIG, 0.0), 300.0, EPS)


func test_delay_resistance_reduces_delay() -> void:
	assert_almost_eq(CTBMath.apply_delay(800.0, 350.0, 0.25), 537.5, EPS)
	assert_almost_eq(CTBMath.apply_delay(800.0, 350.0, 0.5), 625.0, EPS)
	assert_almost_eq(CTBMath.apply_delay(800.0, 350.0, 0.75), 712.5, EPS)


func test_delay_immune_at_full_resistance() -> void:
	assert_almost_eq(CTBMath.apply_delay(800.0, 500.0, 1.0), 800.0, EPS)


func test_delay_resistance_ramps_25_percent_per_delay_capped() -> void:
	var dr: float = 0.0
	for i: int in range(4):
		dr = CTBMath.next_delay_resistance(dr)
	assert_almost_eq(dr, 1.0, EPS)
	assert_almost_eq(CTBMath.next_delay_resistance(dr), 1.0, EPS)
