class_name CTBMath
extends RefCounted
## Pure CTB formulas (build plan 5.3). Static, no scene tree — unit-testable headless.

const CT_THRESHOLD: int = 1000

const STATUS_MULT_MIN: float = 0.05
const STATUS_MULT_MAX: float = 1.50

# Action CT costs (build plan 5.3).
const COST_LIGHT: int = 650
const COST_NORMAL: int = 850
const COST_HEAVY: int = 1100
const COST_VERY_HEAVY: int = 1350
const COST_ATTACK: int = 850
const COST_GUARD: int = 650
const COST_ITEM: int = 750
const COST_BASIC_SPELL: int = 900
const COST_BIG_SPELL: int = 1150
const COST_ECHO_MIN: int = 1200
const COST_ECHO_MAX: int = 1500

# Delay (Time-element utility).
const DELAY_SMALL: int = 200
const DELAY_MEDIUM: int = 350
const DELAY_BIG: int = 500
const DELAY_RESISTANCE_STEP: float = 0.25

## Jecht passive cap: up to +15% speed at Darkness 100.
const DARKNESS_SPEED_BONUS_MAX: float = 0.15


static func resolve_speed_mult(resolve: float) -> float:
	if resolve < 40.0:
		return 0.70 + 0.30 * (resolve / 40.0)
	if resolve > 80.0:
		return 1.0 + 0.25 * pow((resolve - 80.0) / 40.0, 1.2)
	return 1.0


## Multiply stacked status speed multipliers, clamped to 0.05-1.50.
static func combined_status_mult(mults: Array[float]) -> float:
	var total: float = 1.0
	for m: float in mults:
		total *= m
	return clampf(total, STATUS_MULT_MIN, STATUS_MULT_MAX)


## Heir passive (Jecht): small speed bonus scaling with Darkness.
static func darkness_speed_bonus(darkness: float) -> float:
	return 1.0 + DARKNESS_SPEED_BONUS_MAX * clampf(darkness / 100.0, 0.0, 1.0)


static func effective_speed(
	base_speed: float, resolve: float, status_mult: float = 1.0, darkness_bonus: float = 1.0
) -> float:
	var clamped_status: float = clampf(status_mult, STATUS_MULT_MIN, STATUS_MULT_MAX)
	var spd: float = base_speed * resolve_speed_mult(resolve) * clamped_status * darkness_bonus
	return maxf(spd, 0.01)  # floor: everyone eventually acts, no div-by-zero


static func ticks_to_act(ct: float, spd_eff: float) -> int:
	if ct >= float(CT_THRESHOLD):
		return 0
	return int(ceil((float(CT_THRESHOLD) - ct) / maxf(spd_eff, 0.01)))


## Subtract the action's CT cost after acting (build plan 5.3).
static func pay_action_cost(ct: float, cost: int) -> float:
	return ct - float(cost)


## Push a combatant back on the timeline. delay_resistance 0-1; at 1.0 immune.
static func apply_delay(ct: float, delay_amount: float, delay_resistance: float) -> float:
	var dr: float = clampf(delay_resistance, 0.0, 1.0)
	return ct - delay_amount * (1.0 - dr)


## Boss DR ramp: +25% per successful delay, capped at 100% (immune).
static func next_delay_resistance(delay_resistance: float) -> float:
	return minf(delay_resistance + DELAY_RESISTANCE_STEP, 1.0)


## Jump-time execution (build plan 5.3): advance everyone by min(ticks_to_act),
## then the entry at/above threshold with the highest CT acts (ties: higher
## speed, then earlier list position).
## entries: Array of {"id": Variant, "ct": float, "spd": float} — mutated in place.
## Returns {"actor_id": Variant, "ticks": int}.
static func advance_to_next_turn(entries: Array) -> Dictionary:
	assert(not entries.is_empty(), "advance_to_next_turn needs at least one entry")
	var min_ticks: int = -1
	for e: Dictionary in entries:
		var t: int = ticks_to_act(e["ct"], e["spd"])
		if min_ticks < 0 or t < min_ticks:
			min_ticks = t
	var actor: Dictionary = {}
	for e: Dictionary in entries:
		e["ct"] = float(e["ct"]) + float(e["spd"]) * float(min_ticks)
		if e["ct"] >= float(CT_THRESHOLD):
			if (
				actor.is_empty()
				or e["ct"] > actor["ct"]
				or (e["ct"] == actor["ct"] and e["spd"] > actor["spd"])
			):
				actor = e
	return {"actor_id": actor["id"], "ticks": min_ticks}


## Simulate the next `count` turns for the timeline preview, assuming each
## actor pays `assumed_cost` after acting. Does not mutate `entries`.
static func build_preview(entries: Array, count: int, assumed_cost: int = COST_NORMAL) -> Array:
	var sim: Array = []
	for e: Dictionary in entries:
		sim.append({"id": e["id"], "ct": float(e["ct"]), "spd": float(e["spd"])})
	var order: Array = []
	while order.size() < count:
		var result: Dictionary = advance_to_next_turn(sim)
		order.append(result["actor_id"])
		for e: Dictionary in sim:
			if e["id"] == result["actor_id"]:
				e["ct"] = pay_action_cost(e["ct"], assumed_cost)
	return order
