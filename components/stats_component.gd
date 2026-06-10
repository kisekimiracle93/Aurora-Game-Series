class_name StatsComponent
extends Node
## Holds a combatant's stats, HP/Aether pools, and element affinities.
## Pure numbers only — damage math lives in /combat helpers.

signal hp_changed(old_value: int, new_value: int)
signal aether_changed(old_value: int, new_value: int)
signal died

var base_stats: Dictionary = {}
var affinities: Dictionary = {}
var current_hp: int = 1
var current_aether: int = 0
## Set from Darkness degradation (MeterMath.darkness_max_hp_mult); 1.0 = intact.
var max_hp_mult: float = 1.0


func setup(stats: Dictionary, element_affinities: Dictionary = {}) -> void:
	base_stats = stats.duplicate()
	affinities = element_affinities.duplicate()
	current_hp = max_hp()
	current_aether = get_stat("aether")


func get_stat(stat_name: String) -> int:
	return int(base_stats.get(stat_name, 0))


func max_hp() -> int:
	return maxi(int(round(get_stat("hp") * max_hp_mult)), 1)


func max_aether() -> int:
	return get_stat("aether")


## "weak"|"neutral"|"resist"|"absorb"|"immune" for an incoming element.
func affinity_for(element: String) -> String:
	return String(affinities.get(element, "neutral"))


func is_alive() -> bool:
	return current_hp > 0


## Positive amount damages; emits died once HP reaches 0.
func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	var old: int = current_hp
	current_hp = maxi(current_hp - amount, 0)
	hp_changed.emit(old, current_hp)
	if old > 0 and current_hp == 0:
		died.emit()


func heal(amount: int) -> void:
	if amount <= 0 or current_hp <= 0:
		return  # the dead need a revive, not a heal
	var old: int = current_hp
	current_hp = mini(current_hp + amount, max_hp())
	hp_changed.emit(old, current_hp)


func revive(hp_amount: int) -> void:
	if current_hp > 0:
		return
	var old: int = current_hp
	current_hp = clampi(hp_amount, 1, max_hp())
	hp_changed.emit(old, current_hp)


func can_spend_aether(amount: int) -> bool:
	return current_aether >= amount


func spend_aether(amount: int) -> bool:
	if not can_spend_aether(amount):
		return false
	var old: int = current_aether
	current_aether -= amount
	aether_changed.emit(old, current_aether)
	return true


func restore_aether(amount: int) -> void:
	if amount <= 0:
		return
	var old: int = current_aether
	current_aether = mini(current_aether + amount, max_aether())
	aether_changed.emit(old, current_aether)


## Apply Darkness HP degradation; clamps current HP into the shrunken pool.
func set_max_hp_mult(mult: float) -> void:
	max_hp_mult = mult
	if current_hp > max_hp():
		var old: int = current_hp
		current_hp = max_hp()
		hp_changed.emit(old, current_hp)
