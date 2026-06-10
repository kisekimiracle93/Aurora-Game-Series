extends GutTest
## M1: damage formulas (build plan 5.4) against hand-computed values.

const EPS: float = 0.0001


# --- element mods ------------------------------------------------------------


func test_element_mod_table() -> void:
	assert_almost_eq(DamageMath.element_mod("weak"), 1.5, EPS)
	assert_almost_eq(DamageMath.element_mod("neutral"), 1.0, EPS)
	assert_almost_eq(DamageMath.element_mod("resist"), 0.5, EPS)
	assert_almost_eq(DamageMath.element_mod("absorb"), -0.75, EPS)
	assert_almost_eq(DamageMath.element_mod("immune"), 0.0, EPS)
	assert_almost_eq(DamageMath.element_mod("garbage"), 1.0, EPS)


# --- core formulas (hand-computed) -------------------------------------------


func test_physical_damage_hand_computed() -> void:
	# (32 * 2.0 - 20 * 0.6) = 52 ; weak 1.5 -> 78
	assert_eq(DamageMath.physical_damage(32.0, 2.0, 20.0, 1.5, 1.0, 1.0), 78)
	# neutral -> 52
	assert_eq(DamageMath.physical_damage(32.0, 2.0, 20.0, 1.0, 1.0, 1.0), 52)
	# resist -> 26
	assert_eq(DamageMath.physical_damage(32.0, 2.0, 20.0, 0.5, 1.0, 1.0), 26)


func test_magic_damage_hand_computed() -> void:
	# (28 * 2.5 - 20 * 0.7) = 56 ; neutral -> 56
	assert_eq(DamageMath.magic_damage(28.0, 2.5, 20.0, 1.0, 1.0, 1.0), 56)
	# weak -> 84
	assert_eq(DamageMath.magic_damage(28.0, 2.5, 20.0, 1.5, 1.0, 1.0), 84)


func test_absorb_heals_negative() -> void:
	# 56 * -0.75 = -42 (heals the target)
	assert_eq(DamageMath.magic_damage(28.0, 2.5, 20.0, -0.75, 1.0, 1.0), -42)
	assert_eq(DamageMath.physical_damage(32.0, 2.0, 20.0, -0.75, 1.0, 1.0), -39)


func test_immune_is_zero_not_clamped_to_one() -> void:
	assert_eq(DamageMath.physical_damage(32.0, 2.0, 20.0, 0.0, 1.0, 1.0), 0)
	assert_eq(DamageMath.magic_damage(28.0, 2.5, 20.0, 0.0, 1.0, 1.0), 0)


func test_min_damage_clamp() -> void:
	# 10 * 1.2 - 30 * 0.6 = -6 -> base floored to 0 -> clamped to 1
	assert_eq(DamageMath.physical_damage(10.0, 1.2, 30.0, 1.0, 1.0, 1.0), 1)
	# Absorb with zero base heals nothing rather than 1.
	assert_eq(DamageMath.physical_damage(10.0, 1.2, 30.0, -0.75, 1.0, 1.0), 0)


func test_random_variance_bounds() -> void:
	# 52 * 0.95 = 49.4 -> 49 ; 52 * 1.05 = 54.6 -> 55
	assert_eq(DamageMath.physical_damage(32.0, 2.0, 20.0, 1.0, 1.0, DamageMath.RANDOM_MIN), 49)
	assert_eq(DamageMath.physical_damage(32.0, 2.0, 20.0, 1.0, 1.0, DamageMath.RANDOM_MAX), 55)


# --- LayerMod: Resolve x Darkness --------------------------------------------


func test_resolve_damage_mult_bands() -> void:
	assert_almost_eq(DamageMath.resolve_damage_mult(60.0), 1.0, EPS)
	assert_almost_eq(DamageMath.resolve_damage_mult(0.0), 0.70, EPS)
	assert_almost_eq(DamageMath.resolve_damage_mult(20.0), 0.85, EPS)
	assert_almost_eq(DamageMath.resolve_damage_mult(120.0), 1.40, EPS)
	# 1.0 + 0.40 * (20/40)^1.2 = 1.0 + 0.40 * 0.4352752816...
	assert_almost_eq(DamageMath.resolve_damage_mult(100.0), 1.1741101, EPS)


func test_darkness_damage_curve() -> void:
	assert_almost_eq(DamageMath.darkness_damage_mult(0.0), 1.0, EPS)
	assert_almost_eq(DamageMath.darkness_damage_mult(19.9), 1.0, EPS)
	assert_almost_eq(DamageMath.darkness_damage_mult(20.0), 1.0, EPS)
	assert_almost_eq(DamageMath.darkness_damage_mult(60.0), 1.30, EPS)
	assert_almost_eq(DamageMath.darkness_damage_mult(100.0), 1.60, EPS)


func test_layer_mod_combines_resolve_and_darkness() -> void:
	# 0.85 * 1.30 = 1.105
	assert_almost_eq(DamageMath.layer_mod(20.0, 60.0), 1.105, EPS)
	# Non-heir default darkness 0 -> resolve only.
	assert_almost_eq(DamageMath.layer_mod(20.0), 0.85, EPS)
	assert_almost_eq(DamageMath.layer_mod(60.0, 0.0), 1.0, EPS)


func test_layer_mod_feeds_damage() -> void:
	# 52 * 1.105 = 57.46 -> 57
	assert_eq(DamageMath.physical_damage(32.0, 2.0, 20.0, 1.0, 1.105, 1.0), 57)


# --- crit + resolve defense ---------------------------------------------------


func test_crit_chance_and_resolve_bonus() -> void:
	assert_almost_eq(DamageMath.crit_chance(6.0, 60.0), 6.0, EPS)
	assert_almost_eq(DamageMath.crit_chance(6.0, 100.0), 11.0, EPS)  # +10 * 0.5
	assert_almost_eq(DamageMath.crit_chance(6.0, 120.0), 16.0, EPS)  # full +10
	assert_almost_eq(DamageMath.resolve_crit_bonus(80.0), 0.0, EPS)


func test_crit_multiplier() -> void:
	assert_eq(DamageMath.apply_crit(100), 150)
	assert_eq(DamageMath.apply_crit(33), 50)  # 49.5 rounds up
	assert_eq(DamageMath.apply_crit(1), 2)  # 1.5 rounds away from zero


func test_incoming_damage_mult_from_resolve() -> void:
	assert_almost_eq(DamageMath.incoming_damage_mult(81.0), 0.90, EPS)
	assert_almost_eq(DamageMath.incoming_damage_mult(120.0), 0.90, EPS)
	assert_almost_eq(DamageMath.incoming_damage_mult(39.0), 1.15, EPS)
	assert_almost_eq(DamageMath.incoming_damage_mult(0.0), 1.15, EPS)
	assert_almost_eq(DamageMath.incoming_damage_mult(40.0), 1.0, EPS)
	assert_almost_eq(DamageMath.incoming_damage_mult(60.0), 1.0, EPS)
	assert_almost_eq(DamageMath.incoming_damage_mult(80.0), 1.0, EPS)
