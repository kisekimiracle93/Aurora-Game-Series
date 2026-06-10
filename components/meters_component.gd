class_name MetersComponent
extends Node
## Generic meter registry. The slice registers Resolve (everyone) and Darkness
## (Heirs only); Duty/Burden plug in later through the same registry — do not
## special-case meter ids outside the convenience helpers below.

signal meter_changed(meter_id: StringName, old_value: float, new_value: float)

const RESOLVE: StringName = &"resolve"
const DARKNESS: StringName = &"darkness"
const ECHO: StringName = &"echo"

## meter_id -> {"value": float, "min": float, "max": float, "persistent": bool}
var _meters: Dictionary = {}


func register_meter(
	meter_id: StringName,
	min_value: float,
	max_value: float,
	default_value: float,
	persistent: bool = false
) -> void:
	_meters[meter_id] = {
		"value": clampf(default_value, min_value, max_value),
		"min": min_value,
		"max": max_value,
		"persistent": persistent,
	}


func has_meter(meter_id: StringName) -> bool:
	return _meters.has(meter_id)


func get_value(meter_id: StringName) -> float:
	if not has_meter(meter_id):
		return 0.0
	return _meters[meter_id]["value"]


func set_value(meter_id: StringName, value: float) -> void:
	if not has_meter(meter_id):
		return
	var meter: Dictionary = _meters[meter_id]
	var old: float = meter["value"]
	meter["value"] = clampf(value, meter["min"], meter["max"])
	if meter["value"] != old:
		meter_changed.emit(meter_id, old, meter["value"])


func add(meter_id: StringName, delta: float) -> void:
	set_value(meter_id, get_value(meter_id) + delta)


func is_full(meter_id: StringName) -> bool:
	return has_meter(meter_id) and get_value(meter_id) >= _meters[meter_id]["max"]


## Ids of meters that persist between battles (saved at save points).
func get_persistent_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for meter_id: StringName in _meters:
		if _meters[meter_id]["persistent"]:
			ids.append(meter_id)
	return ids


# --- Slice convenience -------------------------------------------------------


func register_resolve(default_value: float = MeterMath.RESOLVE_DEFAULT) -> void:
	register_meter(RESOLVE, MeterMath.RESOLVE_MIN, MeterMath.RESOLVE_MAX, default_value, true)


func register_darkness(default_value: float = 0.0) -> void:
	register_meter(DARKNESS, MeterMath.DARKNESS_MIN, MeterMath.DARKNESS_MAX, default_value, true)


func resolve() -> float:
	return get_value(RESOLVE)


func darkness() -> float:
	return get_value(DARKNESS)


func resolve_band() -> MeterMath.ResolveBand:
	return MeterMath.resolve_band(resolve())
