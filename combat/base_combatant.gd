class_name BaseCombatant
extends Node2D
## One combatant (player, enemy, or merc) composed of component children.
## The turn system talks to components and getters; it never cares which side
## the combatant is on beyond `is_player_controlled`.

signal forced_ko_triggered

## Enemies have no Resolve meter; they act at the neutral midline for the math.
const ENEMY_NEUTRAL_RESOLVE: float = 60.0

var display_name: String = ""
var is_player_controlled: bool = false
var is_merc: bool = false
## Enemy offense bias (stand-in for Resolve on the LayerMod side).
var ferocity: float = 1.0
## Jecht's passive: speed scales with Darkness (set true via M4 kit data).
var has_darkness_speed_passive: bool = false
## Guard action: halves incoming damage until the next turn starts.
var is_guarding: bool = false
## Darkness hit the forced-KO threshold; needs the special revive (save point).
var needs_special_revive: bool = false
## Set for enemies: the EnemyData this combatant was built from (AI profile etc.).
var source_enemy_data: EnemyData = null
## Ice Mirror-type wards: while charges remain, damage of reflect_element
## bounces back at the attacker instead of landing here.
var reflect_element: String = ""
var reflect_charges: int = 0

var stats: StatsComponent
var meters: MetersComponent
var ctb: CTBComponent
var status: StatusComponent
var abilities: AbilitiesComponent


func _init() -> void:
	stats = StatsComponent.new()
	stats.name = "Stats"
	meters = MetersComponent.new()
	meters.name = "Meters"
	ctb = CTBComponent.new()
	ctb.name = "CTB"
	status = StatusComponent.new()
	status.name = "Status"
	abilities = AbilitiesComponent.new()
	abilities.name = "Abilities"
	for component: Node in [stats, meters, ctb, status, abilities]:
		add_child(component)
	meters.meter_changed.connect(_on_meter_changed)


static func from_character(data: CharacterData) -> BaseCombatant:
	var combatant: BaseCombatant = BaseCombatant.new()
	combatant.display_name = data.name
	combatant.name = data.name
	combatant.is_player_controlled = true
	combatant.is_merc = data.is_merc
	combatant.has_darkness_speed_passive = data.darkness_speed_passive
	combatant.stats.setup(data.base_stats, data.affinities)
	combatant.meters.register_resolve()
	combatant.meters.register_echo()
	if data.is_heir:
		combatant.meters.register_darkness()
	combatant.ctb.setup(float(combatant.stats.get_stat("speed")))
	combatant.status.setup(0.0)
	for ability: AbilityData in AbilityLibrary.load_many(data.ability_ids):
		combatant.abilities.add_ability(ability)
	return combatant


static func from_enemy(data: EnemyData) -> BaseCombatant:
	var combatant: BaseCombatant = BaseCombatant.new()
	combatant.display_name = data.name
	combatant.name = data.name
	combatant.is_player_controlled = false
	combatant.source_enemy_data = data
	combatant.ferocity = data.ferocity
	combatant.stats.setup(data.base_stats, data.affinities)
	combatant.ctb.setup(
		float(combatant.stats.get_stat("speed")), data.accumulates_delay_resistance
	)
	## stability 0-1 maps to up to 50 innate resistance points (logged choice).
	combatant.status.setup(data.stability * 50.0)
	for ability: AbilityData in AbilityLibrary.load_many(data.ability_ids):
		combatant.abilities.add_ability(ability)
	return combatant


func is_alive() -> bool:
	return stats.is_alive()


func is_heir() -> bool:
	return meters.has_meter(MetersComponent.DARKNESS)


## Resolve value the formulas should use (enemies: fixed neutral).
func resolve_for_math() -> float:
	if meters.has_meter(MetersComponent.RESOLVE):
		return meters.resolve()
	return ENEMY_NEUTRAL_RESOLVE


func darkness_for_math() -> float:
	if is_heir():
		return meters.darkness()
	return 0.0


func effective_speed() -> float:
	var darkness_bonus: float = 1.0
	if has_darkness_speed_passive:
		darkness_bonus = CTBMath.darkness_speed_bonus(darkness_for_math())
	return ctb.effective_speed(resolve_for_math(), status.speed_mult(), darkness_bonus)


## Accuracy after status debuffs and Darkness degradation.
func current_accuracy() -> float:
	return (
		float(stats.get_stat("accuracy"))
		+ status.accuracy_delta()
		- MeterMath.darkness_accuracy_penalty(darkness_for_math())
	)


func add_darkness(amount: float) -> void:
	if not is_heir() or amount == 0.0:
		return
	meters.add(MetersComponent.DARKNESS, amount)


func _on_meter_changed(meter_id: StringName, _old: float, new_value: float) -> void:
	if meter_id != MetersComponent.DARKNESS:
		return
	stats.set_max_hp_mult(MeterMath.darkness_max_hp_mult(new_value))
	if MeterMath.is_forced_ko(new_value) and is_alive():
		needs_special_revive = true
		stats.take_damage(stats.current_hp)
		forced_ko_triggered.emit()
