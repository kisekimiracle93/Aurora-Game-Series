extends Node2D
## M3 first playable: Bastil/Cavene/Jecht/Mati vs a pack of Aether Wolves.
## Grey-box visuals, full UI wiring, victory/defeat + retry flow with meter
## carryover (defeat retry applies the Resolve penalty).

const PARTY_PATHS: Array[String] = [
	"res://data/characters/bastil.tres",
	"res://data/characters/cavene.tres",
	"res://data/characters/jecht.tres",
	"res://data/characters/mati.tres",
	"res://data/characters/merc_lancer.tres",
]
const ENEMY_PATHS: Array[String] = [
	"res://data/enemies/aether_wolf.tres",
	"res://data/enemies/aether_wolf.tres",
	"res://data/enemies/icebound_stag.tres",
]
const MERC_COLOR: Color = Color(0.55, 0.65, 0.6)
const BOSS_COLOR: Color = Color(0.75, 0.92, 1.0)
const BOSS_PATH: String = "res://data/enemies/frozen_shepherd.tres"
const PHASE_TINTS: Dictionary = {
	1: Color(0.09, 0.10, 0.14),
	2: Color(0.07, 0.08, 0.16),
	3: Color(0.13, 0.07, 0.10),
}

## "wolfpack" (M4 trash fight) or "boss" (M5 Frozen Shepherd arena).
@export var roster: String = "wolfpack"

const PARTY_COLOR: Color = Color(0.35, 0.55, 0.9)
const HEIR_COLOR: Color = Color(0.62, 0.4, 0.95)
const ENEMY_COLOR: Color = Color(0.85, 0.3, 0.25)

var encounter: CombatEncounter
var party: Array[BaseCombatant] = []
var enemies: Array[BaseCombatant] = []
var tokens: Dictionary = {}  # BaseCombatant -> CombatantToken

var timeline: TurnTimeline
var hud: PartyHUD
var action_menu: ActionMenu
var target_select: TargetSelect
var combat_log: CombatLog

var pending_ability: AbilityData
## name -> {"resolve": float, "darkness": float} carried across rebuilds.
var carried_meters: Dictionary = {}
var background: ColorRect
var boss_controller: FrozenShepherdController
var _add_slot: int = 0


func _ready() -> void:
	_start_battle(false)


func _start_battle(is_defeat_retry: bool) -> void:
	for child: Node in get_children():
		child.queue_free()
	party = []
	enemies = []
	tokens = {}
	pending_ability = null
	boss_controller = null
	_add_slot = 0

	_build_battlefield()
	_spawn_party(is_defeat_retry)
	if roster == "boss":
		_spawn_boss()
	else:
		_spawn_enemies()
	_build_ui()

	encounter = CombatEncounter.new()
	encounter.name = "Encounter"
	add_child(encounter)
	encounter.setup(party, enemies)
	encounter.combat_log_line.connect(combat_log.append_line)
	encounter.timeline_changed.connect(timeline.show_preview)
	encounter.turn_started.connect(_on_turn_started)
	encounter.player_turn_started.connect(_on_player_turn)
	encounter.battle_ended.connect(_on_battle_ended)
	encounter.combatant_added.connect(_on_combatant_added)
	if boss_controller != null:
		encounter.register_boss_controller(boss_controller)
		boss_controller.phase_changed.connect(_on_boss_phase_changed)
	encounter.start()


func _build_battlefield() -> void:
	background = ColorRect.new()
	background.color = PHASE_TINTS[1]
	background.size = Vector2(1280, 720)
	add_child(background)
	var ground: ColorRect = ColorRect.new()
	ground.color = Color(0.13, 0.15, 0.20)
	ground.position = Vector2(0, 420)
	ground.size = Vector2(1280, 140)
	add_child(ground)


func _spawn_party(is_defeat_retry: bool) -> void:
	for i: int in range(PARTY_PATHS.size()):
		var data: CharacterData = load(PARTY_PATHS[i])
		var member: BaseCombatant = BaseCombatant.from_character(data)
		_apply_carried_meters(member, is_defeat_retry)
		member.position = Vector2(300, 100 + i * 82)
		add_child(member)
		party.append(member)
		var color: Color = PARTY_COLOR
		if data.is_heir:
			color = HEIR_COLOR
		elif data.is_merc:
			color = MERC_COLOR
		_add_token(member, color)


func _spawn_enemies() -> void:
	var name_counts: Dictionary = {}
	for i: int in range(ENEMY_PATHS.size()):
		var data: EnemyData = load(ENEMY_PATHS[i])
		var enemy: BaseCombatant = BaseCombatant.from_enemy(data)
		name_counts[data.name] = int(name_counts.get(data.name, 0)) + 1
		if int(name_counts[data.name]) > 1 or ENEMY_PATHS.count(ENEMY_PATHS[i]) > 1:
			enemy.display_name = "%s %d" % [data.name, name_counts[data.name]]
		enemy.position = Vector2(950, 140 + i * 105)
		add_child(enemy)
		enemies.append(enemy)
		_add_token(enemy, ENEMY_COLOR)


func _spawn_boss() -> void:
	var data: EnemyData = load(BOSS_PATH)
	var boss: BaseCombatant = BaseCombatant.from_enemy(data)
	boss.position = Vector2(960, 250)
	add_child(boss)
	enemies.append(boss)
	_add_token(boss, BOSS_COLOR, 1.7)
	boss_controller = FrozenShepherdController.new()
	boss_controller.attach_to(boss)


## Mid-fight reinforcements (Crystal Wolves) get tokens beside the boss.
func _on_combatant_added(combatant: BaseCombatant) -> void:
	combatant.position = Vector2(1120, 170 + _add_slot * 190)
	_add_slot += 1
	add_child(combatant)
	_add_token(combatant, ENEMY_COLOR)


func _on_boss_phase_changed(phase: int, title: String) -> void:
	if background != null and PHASE_TINTS.has(phase):
		var tween: Tween = create_tween()
		tween.tween_property(background, "color", PHASE_TINTS[phase], 0.6)
	var banner: Label = Label.new()
	banner.text = "PHASE %d — %s" % [phase, title]
	banner.add_theme_font_size_override("font_size", 34)
	banner.modulate = Color(0.8, 0.95, 1.0)
	banner.position = Vector2(0, 200)
	banner.size = Vector2(1280, 60)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(banner)
	var fade: Tween = create_tween()
	fade.tween_interval(1.6)
	fade.tween_property(banner, "modulate:a", 0.0, 0.9)
	fade.tween_callback(banner.queue_free)


func _add_token(combatant: BaseCombatant, color: Color, size_scale: float = 1.0) -> void:
	var token: CombatantToken = CombatantToken.new()
	combatant.add_child(token)
	token.setup(combatant, color, size_scale)
	tokens[combatant] = token


func _apply_carried_meters(member: BaseCombatant, is_defeat_retry: bool) -> void:
	if not carried_meters.has(member.display_name):
		return
	var saved: Dictionary = carried_meters[member.display_name]
	var resolve: float = float(saved.get("resolve", MeterMath.RESOLVE_DEFAULT))
	if is_defeat_retry:
		resolve = maxf(resolve - SaveSystem.RETRY_RESOLVE_PENALTY, MeterMath.RESOLVE_MIN)
	member.meters.set_value(MetersComponent.RESOLVE, resolve)
	if member.is_heir():
		member.meters.set_value(MetersComponent.DARKNESS, float(saved.get("darkness", 0.0)))


func _build_ui() -> void:
	timeline = TurnTimeline.new()
	timeline.position = Vector2(16, 16)
	add_child(timeline)

	combat_log = CombatLog.new()
	combat_log.position = Vector2(360, 12)
	add_child(combat_log)

	hud = PartyHUD.new()
	hud.position = Vector2(12, 556)
	add_child(hud)
	hud.setup(party)

	action_menu = ActionMenu.new()
	action_menu.position = Vector2(16, 400)
	add_child(action_menu)
	action_menu.ability_chosen.connect(_on_ability_chosen)

	target_select = TargetSelect.new()
	target_select.position = Vector2(16, 400)
	add_child(target_select)
	target_select.target_chosen.connect(_on_target_chosen)
	target_select.cancelled.connect(_on_target_cancelled)


func _on_turn_started(actor: BaseCombatant) -> void:
	for combatant: BaseCombatant in tokens:
		(tokens[combatant] as CombatantToken).set_highlighted(combatant == actor)
	hud.set_active(actor if actor.is_player_controlled else null)


func _on_player_turn(actor: BaseCombatant) -> void:
	target_select.close()
	action_menu.open_for(actor)


func _on_ability_chosen(ability: AbilityData) -> void:
	pending_ability = ability
	action_menu.close()
	if ability.targeting == "self":
		encounter.submit_player_action(ability, [encounter.current_actor])
		return
	var friendly: bool = ability.heals or ability.ability_type == "support"
	var candidates: Array[BaseCombatant] = (
		encounter.living(encounter.party) if friendly else encounter.living(encounter.enemies)
	)
	if ability.targeting == "aoe":
		encounter.submit_player_action(ability, candidates)
		return
	target_select.open_for(candidates)


func _on_target_chosen(target: BaseCombatant) -> void:
	target_select.close()
	encounter.submit_player_action(pending_ability, [target])


func _on_target_cancelled() -> void:
	target_select.close()
	action_menu.open_for(encounter.current_actor)


func _on_battle_ended(victory: bool) -> void:
	action_menu.close()
	target_select.close()
	for member: BaseCombatant in party:
		carried_meters[member.display_name] = {
			"resolve": member.meters.resolve(),
			"darkness": member.meters.darkness() if member.is_heir() else 0.0,
		}
	_show_end_overlay(victory)


func _show_end_overlay(victory: bool) -> void:
	var overlay: PanelContainer = PanelContainer.new()
	overlay.custom_minimum_size = Vector2(420, 0)
	overlay.position = Vector2(430, 270)
	add_child(overlay)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	overlay.add_child(box)

	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "VICTORY" if victory else "DEFEAT"
	title.modulate = Color(0.6, 1.0, 0.65) if victory else Color(1.0, 0.45, 0.4)
	box.add_child(title)

	var body: Label = Label.new()
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.text = (
		"Resolve carried forward (+%d victory bonus already applied)."
		% int(CombatEncounter.RESOLVE_VICTORY_GAIN)
		if victory
		else "Retrying lowers everyone's Resolve by %d." % int(SaveSystem.RETRY_RESOLVE_PENALTY)
	)
	box.add_child(body)

	var again: Button = Button.new()
	again.text = "Fight again" if victory else "Retry (Resolve -%d)" % int(SaveSystem.RETRY_RESOLVE_PENALTY)
	again.pressed.connect(func() -> void: call_deferred("_start_battle", not victory))
	box.add_child(again)
	again.grab_focus()

	var select: Button = Button.new()
	select.text = "Fight select"
	select.pressed.connect(
		func() -> void: get_tree().change_scene_to_file("res://world/fight_select.tscn")
	)
	box.add_child(select)

	var quit: Button = Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)
