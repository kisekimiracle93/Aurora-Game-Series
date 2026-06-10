class_name CTBComponent
extends Node
## A combatant's place on the CTB timeline: CT value, effective speed inputs,
## action-cost payment, and delay (+ boss Delay Resistance). Formulas live in CTBMath.

signal ct_changed(old_value: float, new_value: float)

var ct: float = 0.0
var base_speed: float = 20.0
## Bosses set this true (EnemyData.accumulates_delay_resistance).
var accumulates_delay_resistance: bool = false
var delay_resistance: float = 0.0


func setup(speed: float, builds_delay_resistance: bool = false) -> void:
	base_speed = speed
	accumulates_delay_resistance = builds_delay_resistance
	ct = 0.0
	delay_resistance = 0.0


func effective_speed(
	resolve: float, status_mult: float = 1.0, darkness_bonus: float = 1.0
) -> float:
	return CTBMath.effective_speed(base_speed, resolve, status_mult, darkness_bonus)


func ticks_to_act(spd_eff: float) -> int:
	return CTBMath.ticks_to_act(ct, spd_eff)


func is_ready() -> bool:
	return ct >= float(CTBMath.CT_THRESHOLD)


func advance(ticks: int, spd_eff: float) -> void:
	_set_ct(ct + spd_eff * float(ticks))


func pay_action_cost(cost: int) -> void:
	_set_ct(CTBMath.pay_action_cost(ct, cost))


## Returns true if the delay landed (false once DR has reached immunity).
func receive_delay(amount: float) -> bool:
	if delay_resistance >= 1.0:
		return false
	_set_ct(CTBMath.apply_delay(ct, amount, delay_resistance))
	if accumulates_delay_resistance:
		delay_resistance = CTBMath.next_delay_resistance(delay_resistance)
	return true


func _set_ct(value: float) -> void:
	var old: float = ct
	ct = value
	if ct != old:
		ct_changed.emit(old, ct)
