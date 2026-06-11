class_name FrozenShepherdController
extends Node
## The Frozen Shepherd's scripted brain (build plan M5). Attached as a child of
## the boss combatant; the encounter routes the boss's turns here.
##
## P1 "Preservation"  (HP > 60%): Merc Freeze early, Summon 2 Crystal Wolves,
##   Glacial Command (chill: Slow + accuracy down), then rake rotation.
## P2 "Stagnation"    (HP <= 60%): Echo Roar (Resolve Shock AoE), Ice Mirror
##   (reflect Fire once, re-armed periodically), Hunt the Dark targeting.
## P3 "Release"       (HP <= 25%): vulnerable to Ice, sheds armor, hits harder.
## Overflow Pulse substitute (NOT Burden): from boss turn OVERFLOW_START on,
##   every boss turn drains party Resolve.

signal phase_changed(phase: int, title: String)

const PHASE_2_HP_RATIO: float = 0.60
const PHASE_3_HP_RATIO: float = 0.25
## Overflow drain begins on this boss turn (GDD: "if the fight lasts > 6 turns").
const OVERFLOW_START_TURN: int = 7
const OVERFLOW_RESOLVE_DRAIN: float = 6.0
## Ice Mirror re-arms every N boss turns in P2/P3 while unspent.
const MIRROR_REARM_INTERVAL: int = 3
## P3: armor sheds and ferocity climbs.
const P3_GUARD_WARD_MULT: float = 0.7
const P3_FEROCITY: float = 1.4

const PHASE_TITLES: Dictionary = {
	1: "Preservation",
	2: "Stagnation — the stillness cracks",
	3: "Release — the glacier splits",
}

var boss: BaseCombatant
var phase: int = 1
var boss_turn_count: int = 0
var summoned: bool = false
var _opened_with_freeze: bool = false
var _p2_roared: bool = false
var _mirror_cast_turn: int = -99
var _rotation_step: int = 0

var _rake: AbilityData
var _freeze: AbilityData
var _command: AbilityData
var _roar: AbilityData
var _mirror: AbilityData
var _summon: AbilityData


func attach_to(boss_in: BaseCombatant) -> void:
	boss = boss_in
	name = "BossController"
	boss.add_child(self)
	boss.stats.hp_changed.connect(_on_boss_hp_changed)
	_rake = AbilityLibrary.load_ability("glacial_rake")
	_freeze = AbilityLibrary.load_ability("merc_freeze")
	_command = AbilityLibrary.load_ability("glacial_command")
	_roar = AbilityLibrary.load_ability("echo_roar")
	_mirror = AbilityLibrary.load_ability("ice_mirror")
	_summon = AbilityLibrary.load_ability("summon_crystal_wolves")


func take_boss_turn(encounter: CombatEncounter) -> void:
	boss_turn_count += 1
	var living_party: Array[BaseCombatant] = encounter.living(encounter.party)
	if living_party.is_empty():
		return

	match phase:
		1:
			await _phase_one_turn(encounter, living_party)
		_:
			await _phase_two_three_turn(encounter, living_party)

	# Overflow Pulse substitute: late-fight Resolve bleed, not an action.
	if boss_turn_count >= OVERFLOW_START_TURN and not encounter.living(encounter.party).is_empty():
		for member: BaseCombatant in encounter.living(encounter.party):
			member.meters.add(MetersComponent.RESOLVE, -OVERFLOW_RESOLVE_DRAIN)
		encounter.log_line(
			"Overflow Pulse! Cold dread seeps in (party Resolve -%d)."
			% int(OVERFLOW_RESOLVE_DRAIN)
		)


func _phase_one_turn(encounter: CombatEncounter, living_party: Array[BaseCombatant]) -> void:
	# 1) Freeze the merc early — the Church's shield is disposable.
	if not _opened_with_freeze:
		_opened_with_freeze = true
		var merc: BaseCombatant = _find_merc(living_party)
		if merc != null:
			await encounter.execute_action_presented(boss, _freeze, [merc])
			return
	# 2) Call the pack.
	if not summoned:
		await _cast_summon(encounter)
		return
	# 3) Then settle into the rotation: Command, Rake, Rake...
	await _rotation(encounter, living_party, [_command, _rake, _rake])


func _phase_two_three_turn(
	encounter: CombatEncounter, living_party: Array[BaseCombatant]
) -> void:
	if not _p2_roared:
		_p2_roared = true
		await encounter.execute_action_presented(boss, _roar, living_party)
		return
	if boss.reflect_charges <= 0 and boss_turn_count - _mirror_cast_turn >= MIRROR_REARM_INTERVAL:
		await _cast_ice_mirror(encounter)
		return
	if phase == 2:
		await _rotation(encounter, living_party, [_rake, _command, _rake, _roar])
	else:
		await _rotation(encounter, living_party, [_rake, _rake, _command])


func _rotation(
	encounter: CombatEncounter, living_party: Array[BaseCombatant], steps: Array
) -> void:
	var ability: AbilityData = steps[_rotation_step % steps.size()]
	_rotation_step += 1
	var targets: Array[BaseCombatant]
	if ability.targeting == "aoe":
		targets = living_party
	else:
		targets = [_pick_target(living_party, encounter.rng)]
	await encounter.execute_action_presented(boss, ability, targets)


func _find_merc(living_party: Array[BaseCombatant]) -> BaseCombatant:
	for member: BaseCombatant in living_party:
		if member.is_merc:
			return member
	return null


## P1: priority list (merc first). P2+: Hunt the Dark — stalk the corrupted.
func _pick_target(
	living_party: Array[BaseCombatant], rng: RandomNumberGenerator
) -> BaseCombatant:
	var profile: String = "priority" if phase == 1 else "hunt_dark"
	return EnemyAI.pick_target(profile, living_party, rng)


func _cast_summon(encounter: CombatEncounter) -> void:
	summoned = true
	if encounter.presenter != null:
		await encounter.presenter.present_windup(boss, _summon)
	var data: EnemyData = load("res://data/enemies/crystal_wolf.tres")
	for i: int in range(2):
		var wolf: BaseCombatant = BaseCombatant.from_enemy(data)
		wolf.display_name = "Crystal Wolf %d" % (i + 1)
		encounter.add_enemy(wolf)
	encounter.log_line("The Frozen Shepherd howls — two Crystal Wolves answer!")
	boss.ctb.pay_action_cost(_summon.ct_cost)
	encounter.action_resolved.emit(boss, _summon, [] as Array[Dictionary])
	if encounter.presenter != null:
		await encounter.presenter.present_followthrough(boss, _summon)


func _cast_ice_mirror(encounter: CombatEncounter) -> void:
	_mirror_cast_turn = boss_turn_count
	if encounter.presenter != null:
		await encounter.presenter.present_windup(boss, _mirror)
	boss.reflect_element = "Fire"
	boss.reflect_charges = 1
	encounter.log_line("The Shepherd raises an Ice Mirror — the next flame will rebound!")
	boss.ctb.pay_action_cost(_mirror.ct_cost)
	encounter.action_resolved.emit(boss, _mirror, [] as Array[Dictionary])
	if encounter.presenter != null:
		await encounter.presenter.present_followthrough(boss, _mirror)


func _on_boss_hp_changed(_old: int, new_value: int) -> void:
	var ratio: float = float(new_value) / float(boss.stats.max_hp())
	if phase < 3 and ratio <= PHASE_3_HP_RATIO:
		_enter_phase(3)
	elif phase < 2 and ratio <= PHASE_2_HP_RATIO:
		_enter_phase(2)


func _enter_phase(new_phase: int) -> void:
	# Never skip P2's kit: crossing both thresholds at once still arms the mirror.
	if new_phase == 3 and phase == 1:
		phase = 2
		phase_changed.emit(2, PHASE_TITLES[2])
	phase = new_phase
	if new_phase == 3:
		# Release: Ice flash-freezes INTO the wound — the Heirs' moment.
		boss.stats.affinities["Ice"] = "weak"
		boss.stats.base_stats["guard"] = int(
			round(boss.stats.get_stat("guard") * P3_GUARD_WARD_MULT)
		)
		boss.stats.base_stats["ward"] = int(
			round(boss.stats.get_stat("ward") * P3_GUARD_WARD_MULT)
		)
		boss.ferocity = P3_FEROCITY
	phase_changed.emit(new_phase, PHASE_TITLES[new_phase])
