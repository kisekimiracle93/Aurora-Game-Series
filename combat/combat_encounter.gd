class_name CombatEncounter
extends Node
## The battle brain: owns the combatant lists, the jump-time turn loop, and the
## state machine Init → BuildPreview → ChooseAction → ResolveAction → PostTurn →
## CheckEnd. Synchronous: it advances until player input is required, so it is
## fully drivable headless (tests) and from UI (battle scene) alike.

enum State { IDLE, AWAITING_PLAYER, RESOLVING, VICTORY, DEFEAT }

signal combat_log_line(text: String)
signal turn_started(combatant: BaseCombatant)
signal player_turn_started(combatant: BaseCombatant)
signal action_resolved(actor: BaseCombatant, ability: AbilityData, results: Array[Dictionary])
signal combatant_died(combatant: BaseCombatant)
signal combatant_added(combatant: BaseCombatant)
signal timeline_changed(preview: Array[BaseCombatant])
signal battle_ended(victory: bool)

const PREVIEW_TURNS: int = 8
const MAX_AUTO_STEPS: int = 10000
## Feel knobs (tunable; see BUILD_LOG.md).
const RESOLVE_ALLY_DEATH_DROP: float = 20.0
const RESOLVE_VICTORY_GAIN: float = 10.0
const BURDEN_ALLY_DEATH_GAIN: float = 10.0
const FROZEN_TURN_COST: int = CTBMath.COST_NORMAL

var party: Array[BaseCombatant] = []
var enemies: Array[BaseCombatant] = []
var state: State = State.IDLE
var current_actor: BaseCombatant = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Scripted boss brain (M5+); takes over that combatant's turns from EnemyAI.
var boss_controller: Node = null
## Optional cinematic pacing hook (battle scene sets it). When null, every
## action resolves instantly — headless tests and AI sims stay synchronous.
var presenter: Node = null


## seed_value 0 = randomized battle; anything else = deterministic (tests).
func setup(
	party_in: Array[BaseCombatant], enemies_in: Array[BaseCombatant], seed_value: int = 0
) -> void:
	party = party_in
	enemies = enemies_in
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for combatant: BaseCombatant in all_combatants():
		combatant.stats.died.connect(_on_combatant_died.bind(combatant))


func start() -> void:
	state = State.IDLE
	_log("Battle start!")
	_apply_battle_start_reactions()
	_emit_timeline()
	advance_until_input()


## Enemy-type triggers (GDD): certain foes shake or steel certain hearts.
const REACTIONS: Array[Dictionary] = [
	{
		"member": "Mati", "enemy_contains": "Wolf",
		"meter": MetersComponent.RESOLVE, "delta": -15.0,
		"line": "Mati falters — she has feared the wolves since the village burned. (Resolve -15)",
	},
	{
		"member": "Bastil", "enemy_contains": "Bandit",
		"meter": MetersComponent.DUTY, "delta": 12.0,
		"line": "Bastil squares his shoulders — these roads are his to keep. (Duty +12)",
	},
	{
		"member": "Jecht", "enemy_contains": "Stag",
		"meter": MetersComponent.DARKNESS, "delta": 5.0,
		"line": "The Stag's hunt stirs something cold in Jecht's blood. (Darkness +5)",
	},
]


func _apply_battle_start_reactions() -> void:
	for reaction: Dictionary in REACTIONS:
		var member: BaseCombatant = null
		for candidate: BaseCombatant in party:
			if candidate.display_name == String(reaction["member"]):
				member = candidate
		if member == null or not member.is_alive():
			continue
		var triggered: bool = false
		for enemy: BaseCombatant in enemies:
			if enemy.display_name.contains(String(reaction["enemy_contains"])):
				triggered = true
		if not triggered:
			continue
		var meter_id: StringName = reaction["meter"]
		if meter_id == MetersComponent.DARKNESS and not member.is_heir():
			continue
		member.meters.add(meter_id, float(reaction["delta"]))
		_log(String(reaction["line"]))


func register_boss_controller(controller: Node) -> void:
	boss_controller = controller


## Mid-battle reinforcement (boss summons). The scene listens to combatant_added.
func add_enemy(combatant: BaseCombatant) -> void:
	enemies.append(combatant)
	combatant.stats.died.connect(_on_combatant_died.bind(combatant))
	combatant_added.emit(combatant)
	_emit_timeline()


## Public surface for boss controllers (resolve through the normal pipeline).
func execute_action(
	actor: BaseCombatant, ability: AbilityData, targets: Array[BaseCombatant]
) -> void:
	_execute(actor, ability, targets)


## Same, but paced by the cinematic presenter when one is attached.
func execute_action_presented(
	actor: BaseCombatant, ability: AbilityData, targets: Array[BaseCombatant]
) -> void:
	if presenter != null:
		await presenter.present_windup(actor, ability, targets)
	_execute(actor, ability, targets)
	if presenter != null:
		await presenter.present_followthrough(actor, ability, targets)


func log_line(text: String) -> void:
	_log(text)


func all_combatants() -> Array[BaseCombatant]:
	var all: Array[BaseCombatant] = []
	all.append_array(party)
	all.append_array(enemies)
	return all


func living(group: Array[BaseCombatant]) -> Array[BaseCombatant]:
	var result: Array[BaseCombatant] = []
	for combatant: BaseCombatant in group:
		if combatant.is_alive():
			result.append(combatant)
	return result


## Run enemy/system turns until a player must choose, or the battle ends.
## The step guard only trips on logic bugs (it would otherwise hang the game).
## With no presenter attached this never suspends (fully synchronous).
func advance_until_input() -> void:
	var steps: int = 0
	while state != State.AWAITING_PLAYER and state != State.VICTORY and state != State.DEFEAT:
		await _step_one_turn()
		steps += 1
		if steps > MAX_AUTO_STEPS:
			push_error("CombatEncounter: turn loop exceeded %d steps; aborting." % MAX_AUTO_STEPS)
			return


## UI / tests call this while AWAITING_PLAYER to act with the current actor.
func submit_player_action(ability: AbilityData, targets: Array[BaseCombatant]) -> void:
	if state != State.AWAITING_PLAYER or current_actor == null:
		return
	if not current_actor.stats.can_spend_aether(ability.aether_cost):
		_log("%s lacks the Aether for %s." % [current_actor.display_name, ability.display_name])
		return  # stays AWAITING_PLAYER; UI should grey these out
	if ability.ability_type == "echo" and not current_actor.meters.echo_ready():
		_log("%s's Echo gauge is not full." % current_actor.display_name)
		return
	if ability.ability_type == "echo" and MeterMath.is_echo_locked_by_burden(
		current_actor.burden_for_math()
	):
		_log("%s's grief is too heavy — the Echo will not answer." % current_actor.display_name)
		return
	state = State.RESOLVING
	if presenter != null:
		await execute_action_presented(current_actor, ability, targets)
	else:
		_execute(current_actor, ability, targets)
	if state == State.RESOLVING:
		state = State.IDLE
	await advance_until_input()


func _step_one_turn() -> void:
	if _check_end():
		return
	var actor: BaseCombatant = _advance_timeline()
	current_actor = actor
	turn_started.emit(actor)
	actor.is_guarding = false  # guard protects until your next turn starts

	for payload: Dictionary in actor.status.tick_turn():
		_apply_tick_damage(actor, payload)
	if not actor.is_alive():
		_check_end()
		return
	if actor.status.is_action_blocked():
		_log("%s is frozen solid and cannot act!" % actor.display_name)
		actor.ctb.pay_action_cost(FROZEN_TURN_COST)
		_emit_timeline()
		_check_end()
		return

	if actor.is_player_controlled:
		state = State.AWAITING_PLAYER
		player_turn_started.emit(actor)
	else:
		state = State.RESOLVING
		if boss_controller != null and boss_controller.get("boss") == actor:
			await boss_controller.take_boss_turn(self)
		else:
			await _enemy_take_turn(actor)
		if state == State.RESOLVING:
			state = State.IDLE


## Jump-time: advance everyone by the minimum ticks-to-act, return the actor.
func _advance_timeline() -> BaseCombatant:
	var alive: Array[BaseCombatant] = living(all_combatants())
	var min_ticks: int = -1
	for combatant: BaseCombatant in alive:
		var ticks: int = combatant.ctb.ticks_to_act(combatant.effective_speed())
		if min_ticks < 0 or ticks < min_ticks:
			min_ticks = ticks
	var actor: BaseCombatant = null
	for combatant: BaseCombatant in alive:
		combatant.ctb.advance(min_ticks, combatant.effective_speed())
		if combatant.ctb.is_ready():
			if (
				actor == null
				or combatant.ctb.ct > actor.ctb.ct
				or (
					combatant.ctb.ct == actor.ctb.ct
					and combatant.effective_speed() > actor.effective_speed()
				)
			):
				actor = combatant
	return actor


func _enemy_take_turn(actor: BaseCombatant) -> void:
	var ability: AbilityData = EnemyAI.pick_ability(actor, rng)
	if ability == null:
		_log("%s hesitates..." % actor.display_name)
		actor.ctb.pay_action_cost(CTBMath.COST_NORMAL)
		_emit_timeline()
		return
	var targets_pool: Array[BaseCombatant] = living(party)
	if targets_pool.is_empty():
		return
	var targets: Array[BaseCombatant]
	if ability.targeting == "aoe":
		targets = targets_pool
	else:
		var profile: String = _ai_profile_for(actor)
		targets = [EnemyAI.pick_target(profile, targets_pool, rng)]
	await execute_action_presented(actor, ability, targets)


func _ai_profile_for(actor: BaseCombatant) -> String:
	var data: EnemyData = actor.source_enemy_data
	return data.ai_profile if data != null else "basic"


func _execute(actor: BaseCombatant, ability: AbilityData, targets: Array[BaseCombatant]) -> void:
	actor.stats.spend_aether(ability.aether_cost)
	if ability.ability_type == "echo":
		actor.meters.spend_echo()
	var results: Array[Dictionary] = []
	if ability.id == "guard":
		actor.is_guarding = true
		_log("%s guards." % actor.display_name)
	elif ability.id == "pray":
		_log("%s prays, leaving themselves open..." % actor.display_name)
	else:
		results = ActionResolver.resolve_action(ability, actor, targets, rng)
		_log_results(actor, ability, results)
	actor.add_darkness(float(ability.darkness_cost))
	action_resolved.emit(actor, ability, results)
	var ct_cost: int = ability.ct_cost
	if ability.ability_type == "echo":  # conviction makes the deed cheaper
		ct_cost = int(round(ct_cost * MeterMath.duty_echo_cost_mult(actor.duty_for_math())))
	if MeterMath.is_burden_dragging(actor.burden_for_math()):
		ct_cost = int(round(ct_cost * MeterMath.BURDEN_CT_COST_MULT))
		_log("%s moves heavily under the weight." % actor.display_name)
	actor.ctb.pay_action_cost(ct_cost)
	_emit_timeline()
	_check_end()


func _apply_tick_damage(actor: BaseCombatant, payload: Dictionary) -> void:
	var fraction: float = float(payload.get("tick_fraction", 0.0))
	if fraction <= 0.0:
		return
	var damage: int = maxi(int(ceil(actor.stats.max_hp() * fraction)), 1)
	actor.stats.take_damage(damage)
	_log(
		"%s takes %d %s damage."
		% [actor.display_name, damage, String(payload.get("status_id", "tick"))]
	)


func _on_combatant_died(combatant: BaseCombatant) -> void:
	_log("%s falls!" % combatant.display_name)
	combatant_died.emit(combatant)
	if party.has(combatant):
		for ally: BaseCombatant in living(party):
			ally.meters.add(MetersComponent.RESOLVE, -RESOLVE_ALLY_DEATH_DROP)
			ally.meters.add(MetersComponent.BURDEN, BURDEN_ALLY_DEATH_GAIN)


func _check_end() -> bool:
	if state == State.VICTORY or state == State.DEFEAT:
		return true
	if living(party).is_empty():
		state = State.DEFEAT
		_log("The party has fallen...")
		battle_ended.emit(false)
		return true
	if living(enemies).is_empty():
		state = State.VICTORY
		for member: BaseCombatant in living(party):
			member.meters.add(MetersComponent.RESOLVE, RESOLVE_VICTORY_GAIN)
		_log("Victory!")
		battle_ended.emit(true)
		return true
	return false


func _emit_timeline() -> void:
	var entries: Array = []
	for combatant: BaseCombatant in living(all_combatants()):
		entries.append(
			{"id": combatant, "ct": combatant.ctb.ct, "spd": combatant.effective_speed()}
		)
	if entries.is_empty():
		return
	var preview_raw: Array = CTBMath.build_preview(entries, PREVIEW_TURNS)
	var preview: Array[BaseCombatant] = []
	for entry: Variant in preview_raw:
		preview.append(entry as BaseCombatant)
	timeline_changed.emit(preview)


func _log_results(
	actor: BaseCombatant, ability: AbilityData, results: Array[Dictionary]
) -> void:
	for result: Dictionary in results:
		var target: BaseCombatant = result["target"]
		var parts: Array[String] = []
		if result["missed"]:
			_log("%s's %s misses %s!" % [actor.display_name, ability.display_name, target.display_name])
			continue
		if bool(result.get("reflected", false)):
			_log(
				"%s's %s is hurled back by the Ice Mirror for %d!"
				% [actor.display_name, ability.display_name, result["damage"]]
			)
			continue
		if int(result["damage"]) > 0:
			var crit_tag: String = " CRITICAL!" if bool(result["crit"]) else ""
			parts.append("hits %s for %d%s" % [target.display_name, result["damage"], crit_tag])
		if int(result["healed"]) > 0:
			parts.append("restores %d HP to %s" % [result["healed"], target.display_name])
		var applied: Array[String] = result["statuses_applied"]
		if not applied.is_empty():
			parts.append("inflicts %s" % ", ".join(applied))
		if bool(result["delayed"]):
			parts.append("delays %s" % target.display_name)
		if int(result.get("resolve_gain", 0)) > 0:
			parts.append("steels %s (+%d Resolve)" % [target.display_name, result["resolve_gain"]])
		if parts.is_empty():
			parts.append("has no effect on %s" % target.display_name)
		_log("%s: %s %s." % [actor.display_name, ability.display_name, " — ".join(parts)])


func _log(text: String) -> void:
	combat_log_line.emit(text)
