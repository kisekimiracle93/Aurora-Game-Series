class_name StatusComponent
extends Node
## Active status instances on one combatant: application rolls (deterministic —
## the caller supplies the rolls), resistance stacking, immunity, per-turn ticks.
## Damage from ticks is NOT applied here; the encounter listens to status_ticked
## and routes it through the damage pipeline (components stay decoupled).

signal status_applied(status_id: String, duration: int)
signal status_resisted(status_id: String)
signal status_expired(status_id: String)
signal status_ticked(status_id: String, hook: String, tick_fraction: float)

## Innate resistance points (bosses: mapped from EnemyData.stability in M4/M5).
var innate_resistance: float = 0.0

## status_id -> {"data": StatusData, "remaining": int}
var _active: Dictionary = {}
## status_id -> successful application count (resistance stacking).
var _applied_counts: Dictionary = {}
## status_id -> true (hard immunity).
var _immunities: Dictionary = {}


func setup(resistance_points: float = 0.0) -> void:
	innate_resistance = resistance_points
	_active.clear()
	_applied_counts.clear()
	_immunities.clear()


func set_immunity(status_id: String, immune: bool = true) -> void:
	if immune:
		_immunities[status_id] = true
	else:
		_immunities.erase(status_id)


func is_immune(status_id: String) -> bool:
	return _immunities.has(status_id)


## Resistance the NEXT application of this status must overcome.
func resistance_for(status_id: String) -> float:
	var count: int = int(_applied_counts.get(status_id, 0))
	return innate_resistance + StatusMath.RESISTANCE_STACK_STEP * float(count)


## Attempt to land `data` on this combatant. roll_hit in [0,100); lands when
## roll_hit < chance. roll01_shock in [0,1] picks the Resolve Shock drop size.
## Returns {"landed": bool, "chance": float, "duration": int, "resolve_drop": int}.
func try_apply(
	data: StatusData,
	base_chance: float,
	caster_focus: float,
	target_ward: float,
	target_resolve: float,
	roll_hit: float,
	roll01_shock: float = 0.5,
	duration_override: int = 0
) -> Dictionary:
	var result: Dictionary = {"landed": false, "chance": 0.0, "duration": 0, "resolve_drop": 0}
	if is_immune(data.id):
		status_resisted.emit(data.id)
		return result
	var chance: float = StatusMath.hit_chance(
		base_chance, caster_focus, target_ward, target_resolve, resistance_for(data.id)
	)
	result["chance"] = chance
	if roll_hit >= chance:
		status_resisted.emit(data.id)
		return result
	var base_duration: int = duration_override if duration_override > 0 else data.base_duration
	var duration: int = StatusMath.duration_turns(
		base_duration, caster_focus, target_ward, target_resolve
	)
	var existing: Dictionary = _active.get(data.id, {})
	if existing.is_empty():
		_active[data.id] = {"data": data, "remaining": duration}
	else:
		existing["remaining"] = maxi(int(existing["remaining"]), duration)
	_applied_counts[data.id] = int(_applied_counts.get(data.id, 0)) + 1
	result["landed"] = true
	result["duration"] = duration
	if data.resolve_drop_max > 0:
		result["resolve_drop"] = StatusMath.resolve_shock_drop(
			data.resolve_drop_min, data.resolve_drop_max, roll01_shock
		)
	status_applied.emit(data.id, duration)
	return result


func has_status(status_id: String) -> bool:
	return _active.has(status_id)


func get_remaining(status_id: String) -> int:
	if not has_status(status_id):
		return 0
	return int(_active[status_id]["remaining"])


func active_ids() -> Array[String]:
	var ids: Array[String] = []
	for status_id: String in _active:
		ids.append(status_id)
	return ids


## Freeze-type lockout: the combatant skips their turn.
func is_action_blocked() -> bool:
	for status_id: String in _active:
		var data: StatusData = _active[status_id]["data"]
		if data.blocks_action:
			return true
	return false


## Silence-type lockout: spells unavailable.
func is_spell_blocked() -> bool:
	for status_id: String in _active:
		var data: StatusData = _active[status_id]["data"]
		if data.blocks_spells:
			return true
	return false


## Combined CTB speed multiplier from active statuses (clamped 0.05-1.50).
func speed_mult() -> float:
	var mults: Array[float] = []
	for status_id: String in _active:
		var data: StatusData = _active[status_id]["data"]
		mults.append(data.speed_mult)
	return CTBMath.combined_status_mult(mults)


## Sum of flat accuracy changes from active statuses (e.g. Resolve Shock daze).
func accuracy_delta() -> float:
	var total: float = 0.0
	for status_id: String in _active:
		var data: StatusData = _active[status_id]["data"]
		total += data.accuracy_delta
	return total


## Advance one turn for this combatant: emit on_tick hooks (burn/bleed), then
## decrement durations and expire. Returns tick payloads for the encounter:
## [{"status_id": String, "hook": String, "tick_fraction": float}, ...]
func tick_turn() -> Array[Dictionary]:
	var payloads: Array[Dictionary] = []
	var expired: Array[String] = []
	for status_id: String in _active:
		var entry: Dictionary = _active[status_id]
		var data: StatusData = entry["data"]
		if data.on_tick != "":
			var payload: Dictionary = {
				"status_id": status_id, "hook": data.on_tick, "tick_fraction": data.tick_fraction
			}
			payloads.append(payload)
			status_ticked.emit(status_id, data.on_tick, data.tick_fraction)
		entry["remaining"] = int(entry["remaining"]) - 1
		if int(entry["remaining"]) <= 0:
			expired.append(status_id)
	for status_id: String in expired:
		_active.erase(status_id)
		status_expired.emit(status_id)
	return payloads


## Clear battle-scoped state (statuses don't persist between battles).
func clear_all() -> void:
	for status_id: String in _active.keys():
		status_expired.emit(status_id)
	_active.clear()
	_applied_counts.clear()
