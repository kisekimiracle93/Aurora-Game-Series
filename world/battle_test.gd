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

## Y of the party HUD strip; command menus bottom-anchor just above it.
const HUD_TOP: float = 556.0

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
var _active_arrow: SelectionArrow
var _target_arrow: SelectionArrow
## World layer (backdrop + combatants + impact FX) — shaken by the presenter
## while the UI stays rock steady.
var stage: Node2D
var presenter: ActionPresenter
## Set when this battle was launched from the world flow (WorldState pending).
var world_mode: bool = false
var world_roster: String = ""


## Encounter compositions per roster id (world flow + playtest variety).
static func enemy_paths_for(roster_id: String) -> Array[String]:
	const WOLF: String = "res://data/enemies/aether_wolf.tres"
	const STAG: String = "res://data/enemies/icebound_stag.tres"
	match roster_id:
		"wolves_2":
			return [WOLF, WOLF]
		"wolves_3":
			return [WOLF, WOLF, WOLF]
		"stag_hunt":
			return [STAG, WOLF]
		"dungeon_gauntlet":
			return [WOLF, STAG, WOLF]
		"bandit_ambush":
			return [
				"res://data/enemies/roadside_bandit.tres",
				"res://data/enemies/bandit_cutthroat.tres",
				"res://data/enemies/roadside_bandit.tres",
			]
		"bandit_pair":
			return [
				"res://data/enemies/roadside_bandit.tres",
				"res://data/enemies/roadside_bandit.tres",
			]
		"wisp_pack":
			return [
				"res://data/enemies/frost_wisp.tres",
				"res://data/enemies/frost_wisp.tres",
				WOLF,
			]
		_:
			return [WOLF, WOLF, STAG]  # classic wolfpack


func _ready() -> void:
	_start_battle(false)


func _exit_tree() -> void:
	Engine.time_scale = 1.0  # never leak echo slow-mo out of the battle


## Controller B / Esc backs out of target selection.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and target_select != null and target_select.visible:
		_on_target_cancelled()
		get_viewport().set_input_as_handled()


func _start_battle(is_defeat_retry: bool) -> void:
	for child: Node in get_children():
		child.queue_free()
	party = []
	enemies = []
	tokens = {}
	pending_ability = null
	boss_controller = null
	_add_slot = 0

	# World hand-off: a pending roster means we arrived from town/field/dungeon.
	var world: Node = get_node_or_null("/root/WorldState")
	if world != null and world.in_world_run and String(world.pending_roster) != "":
		world_mode = true
		world_roster = String(world.consume_pending_roster())
		if world_roster != "boss":
			roster = world_roster

	stage = Node2D.new()
	stage.name = "Stage"
	add_child(stage)
	_build_battlefield()
	_spawn_party(is_defeat_retry)
	if roster == "boss":
		_spawn_boss()
	else:
		_spawn_enemies()
	_build_ui()
	presenter = ActionPresenter.new()
	add_child(presenter)
	presenter.setup(stage, self)

	encounter = CombatEncounter.new()
	encounter.name = "Encounter"
	add_child(encounter)
	encounter.setup(party, enemies)
	encounter.presenter = presenter
	encounter.combat_log_line.connect(combat_log.append_line)
	encounter.timeline_changed.connect(timeline.show_preview)
	encounter.turn_started.connect(_on_turn_started)
	encounter.player_turn_started.connect(_on_player_turn)
	encounter.battle_ended.connect(_on_battle_ended)
	encounter.combatant_added.connect(_on_combatant_added)
	encounter.action_resolved.connect(_on_action_feedback)
	if boss_controller != null:
		encounter.register_boss_controller(boss_controller)
		boss_controller.phase_changed.connect(_on_boss_phase_changed)
	var music: Node = get_node_or_null("/root/MusicManager")
	if music != null:
		if roster == "boss":
			music.play_track("boss")
		else:
			var pick: String = "battle"
			if randf() < 0.5 and AssetLibrary.music_stream("battle_alt") != null:
				pick = "battle_alt"
			music.play_track(pick)
	encounter.start()


func _build_battlefield() -> void:
	# Real backdrop art when supplied (assets/sprites/backgrounds/boss.png or
	# battle.png); the phase-tint ColorRect rides on top either way so boss
	# phase cues stay readable over any art.
	var art: Texture2D = AssetLibrary.texture(
		"backgrounds", "boss" if roster == "boss" else "battle"
	)
	if art != null:
		var image: TextureRect = TextureRect.new()
		image.texture = art
		image.size = Vector2(1280, 720)
		image.stretch_mode = TextureRect.STRETCH_SCALE
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel-art stretch
		stage.add_child(image)
	background = ColorRect.new()
	background.color = PHASE_TINTS[1] if art == null else Color(PHASE_TINTS[1], 0.35)
	background.size = Vector2(1280, 720)
	stage.add_child(background)
	if art == null:
		var ground: ColorRect = ColorRect.new()
		ground.color = Color(0.13, 0.15, 0.20)
		ground.position = Vector2(0, 420)
		ground.size = Vector2(1280, 140)
		stage.add_child(ground)


## FFX-style staggered ranks: melee-forward, casters back, merc in the rear.
const PARTY_SLOTS: Array[Vector2] = [
	Vector2(330, 150), Vector2(285, 235), Vector2(330, 320),
	Vector2(285, 405), Vector2(330, 480),
]
const ENEMY_SLOTS: Array[Vector2] = [
	Vector2(920, 160), Vector2(1010, 320), Vector2(920, 480),
]


func _spawn_party(is_defeat_retry: bool) -> void:
	var world: Node = get_node_or_null("/root/WorldState")
	for i: int in range(PARTY_PATHS.size()):
		var data: CharacterData = load(PARTY_PATHS[i])
		if world_mode and data.is_merc and world != null and not world.merc_hired:
			continue  # the Lancer only marches if hired in town
		var member: BaseCombatant = BaseCombatant.from_character(data)
		if world_mode and world != null:
			world.apply_to_member(member)
		else:
			_apply_carried_meters(member, is_defeat_retry)
		member.position = PARTY_SLOTS[party.size() % PARTY_SLOTS.size()]
		stage.add_child(member)
		party.append(member)
		var color: Color = PARTY_COLOR
		if data.is_heir:
			color = HEIR_COLOR
		elif data.is_merc:
			color = MERC_COLOR
		_add_token(member, color)


func _spawn_enemies() -> void:
	var paths: Array[String] = (
		enemy_paths_for(roster) if world_mode or roster != "wolfpack" else ENEMY_PATHS
	)
	var name_counts: Dictionary = {}
	for i: int in range(paths.size()):
		var data: EnemyData = load(paths[i])
		var enemy: BaseCombatant = BaseCombatant.from_enemy(data)
		name_counts[data.name] = int(name_counts.get(data.name, 0)) + 1
		if int(name_counts[data.name]) > 1 or ENEMY_PATHS.count(ENEMY_PATHS[i]) > 1:
			enemy.display_name = "%s %d" % [data.name, name_counts[data.name]]
		enemy.position = ENEMY_SLOTS[i % ENEMY_SLOTS.size()]
		stage.add_child(enemy)
		enemies.append(enemy)
		_add_token(enemy, ENEMY_COLOR, 1.3)  # foes read bigger on the field


func _spawn_boss() -> void:
	var data: EnemyData = load(BOSS_PATH)
	var boss: BaseCombatant = BaseCombatant.from_enemy(data)
	boss.position = Vector2(950, 300)
	stage.add_child(boss)
	enemies.append(boss)
	_add_token(boss, BOSS_COLOR, 1.7)
	boss_controller = FrozenShepherdController.new()
	boss_controller.attach_to(boss)


## Mid-fight reinforcements (Crystal Wolves) get tokens beside the boss.
func _on_combatant_added(combatant: BaseCombatant) -> void:
	combatant.position = Vector2(1120, 180 + _add_slot * 240)
	_add_slot += 1
	stage.add_child(combatant)
	_add_token(combatant, ENEMY_COLOR)


func _on_boss_phase_changed(phase: int, title: String) -> void:
	if background != null and PHASE_TINTS.has(phase):
		var tint: Color = PHASE_TINTS[phase]
		if background.color.a < 0.9:  # art underneath: stay translucent
			tint = Color(tint, background.color.a)
		var tween: Tween = create_tween()
		tween.tween_property(background, "color", tint, 0.6)
	# Optional phase-3 music shift — only if a release track actually exists.
	if phase == 3 and AssetLibrary.music_stream("boss_release") != null:
		var music: Node = get_node_or_null("/root/MusicManager")
		if music != null:
			music.play_track("boss_release")
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
	combatant.stats.hp_changed.connect(_on_combatant_hp_changed.bind(combatant))
	combatant.status.status_ticked.connect(_on_status_ticked.bind(combatant))


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

	# History log lives in the corner now — the declaration banner is the
	# loud center-stage narrator.
	combat_log = CombatLog.new()
	combat_log.position = Vector2(962, 8)
	combat_log.custom_minimum_size = Vector2(306, 140)
	# stone-opaque per playtest feedback (was translucent)
	add_child(combat_log)

	hud = PartyHUD.new()
	hud.position = Vector2(12, 556)
	add_child(hud)
	hud.setup(party)

	action_menu = ActionMenu.new()
	action_menu.position = Vector2(16, 300)
	add_child(action_menu)
	action_menu.ability_chosen.connect(_on_ability_chosen)
	action_menu.page_changed.connect(func() -> void:
		_place_menu_above_hud.call_deferred(action_menu))

	target_select = TargetSelect.new()
	target_select.position = Vector2(16, 300)
	add_child(target_select)
	target_select.target_chosen.connect(_on_target_chosen)
	target_select.cancelled.connect(_on_target_cancelled)
	target_select.target_hovered.connect(_on_target_hovered)
	action_menu.button_hovered.connect(func() -> void: _sfx("hover"))

	_active_arrow = SelectionArrow.new(Color(1.0, 0.85, 0.2))
	stage.add_child(_active_arrow)
	_target_arrow = SelectionArrow.new(Color(0.95, 0.25, 0.2))
	stage.add_child(_target_arrow)

	# Testing hatch: end any fight instantly (no penalty, no rewards).
	var debug_exit: Button = Button.new()
	debug_exit.text = "✕ debug: end fight"
	debug_exit.add_theme_font_size_override("font_size", 11)
	debug_exit.modulate = Color(1, 1, 1, 0.6)
	debug_exit.position = Vector2(1140, 690)
	debug_exit.pressed.connect(_on_debug_exit)
	add_child(debug_exit)


func _on_debug_exit() -> void:
	if presenter != null:
		presenter.reset_time_scale()
	var world: Node = get_node_or_null("/root/WorldState")
	if world_mode and world != null:
		world.snapshot_party(party)
		if world.return_scene != "":
			get_tree().change_scene_to_file(world.return_scene)
			return
	get_tree().change_scene_to_file("res://world/fight_select.tscn")


## Bottom-anchor a menu just above the party HUD so it never covers the panels.
## Deferred: open_for() queue_frees old buttons, which pollute the size until
## end of frame.
func _place_menu_above_hud(menu: Control) -> void:
	if not menu.visible:
		return
	menu.reset_size()
	menu.position = Vector2(16, HUD_TOP - menu.get_combined_minimum_size().y - 10.0)


func _on_turn_started(actor: BaseCombatant) -> void:
	if actor.is_player_controlled:
		_active_arrow.point_at(actor.position)
	else:
		_active_arrow.hide_arrow()
	hud.set_active(actor if actor.is_player_controlled else null)


func _on_player_turn(actor: BaseCombatant) -> void:
	target_select.close()
	_target_arrow.hide_arrow()
	action_menu.open_for(actor)
	_place_menu_above_hud.call_deferred(action_menu)


func _on_ability_chosen(ability: AbilityData) -> void:
	_sfx("click")
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
	_place_menu_above_hud.call_deferred(target_select)


func _on_target_hovered(target: BaseCombatant) -> void:
	_sfx("hover")
	_target_arrow.point_at(target.position)


func _on_target_chosen(target: BaseCombatant) -> void:
	_sfx("click")
	target_select.close()
	_target_arrow.hide_arrow()
	encounter.submit_player_action(pending_ability, [target])


func _on_target_cancelled() -> void:
	_sfx("click")
	target_select.close()
	_target_arrow.hide_arrow()
	action_menu.open_for(encounter.current_actor)
	_place_menu_above_hud.call_deferred(action_menu)


func _sfx(sfx_name: String) -> void:
	var sfx: Node = get_node_or_null("/root/SfxManager")
	if sfx != null:
		sfx.play(sfx_name)


# --- combat feedback: FX + SFX per resolved action ------------------------------

const STATUS_POP_COLORS: Dictionary = {
	"freeze": Color(0.6, 0.9, 1.0),
	"burn": Color(1.0, 0.55, 0.2),
	"slow": Color(0.5, 0.65, 1.0),
	"silence": Color(0.75, 0.75, 0.75),
	"bleed": Color(1.0, 0.35, 0.3),
	"resolve_shock": Color(0.8, 0.4, 1.0),
}


func _on_action_feedback(
	actor: BaseCombatant, ability: AbilityData, results: Array[Dictionary]
) -> void:
	if ability.id == "guard":
		BattleFX.guard_ring(stage, actor.position)
		_sfx("guard")
		return
	if ability.id == "pray":
		BattleFX.heal_sparkle(stage, actor.position, Color(1.0, 0.98, 0.85))
		_sfx("pray")
		return
	if ability.is_item:
		var world_items: Node = get_node_or_null("/root/WorldState")
		if world_items != null:
			world_items.consume_item(ability.id)
		_sfx("heal")
	if ability.ability_type == "echo":
		_sfx(ability.id)
		_sfx("echo")
	if ability.darkness_cost > 0:
		BattleFX.elemental_burst(stage, actor.position, "Dark")

	var impact_played: bool = false
	for result: Dictionary in results:
		var target: BaseCombatant = result["target"]
		if bool(result["missed"]):
			BattleFX.text_pop(stage, target.position, "MISS", Color(0.8, 0.8, 0.8))
			if not impact_played:
				_sfx("miss")
				impact_played = true
			continue
		if bool(result.get("reflected", false)):
			BattleFX.text_pop(stage, actor.position, "REFLECTED!", Color(0.6, 0.95, 1.0))
			BattleFX.elemental_burst(stage, actor.position, "Ice")
			_sfx("shock")
			impact_played = true
			continue
		if int(result["damage"]) > 0:
			if ability.ability_type == "echo":
				BattleFX.echo_burst(stage, target.position, ability.element)
				BattleFX.spell_cinematic(stage, actor.position, target.position, ability.element, true)
			elif ability.damage_type == "physical":
				BattleFX.slash(stage, target.position)
				BattleFX.blood_spray(stage, target.position, bool(result["crit"]))
				if ability.element != "Neutral":
					BattleFX.spell_cinematic(stage, actor.position, target.position, ability.element)
			else:
				BattleFX.spell_cinematic(stage, actor.position, target.position, ability.element)
			BattleFX.shake(target, 10.0)
			if not target.is_alive():
				BattleFX.blood_pool(stage, target.position)
			if bool(result["crit"]):
				BattleFX.text_pop(stage, target.position, "CRITICAL!", Color(1.0, 0.85, 0.25))
			if not impact_played:
				if bool(result["crit"]):
					_sfx("crit")
				elif ability.damage_type == "magic":
					_sfx(ability.id)
				else:
					_sfx("hit")
				impact_played = true
		if int(result["healed"]) > 0:
			BattleFX.heal_sparkle(stage, target.position)
			if not impact_played:
				_sfx("heal")
				impact_played = true
		var applied: Array[String] = result["statuses_applied"]
		for status_id: String in applied:
			BattleFX.text_pop(stage, target.position,
				status_id.to_upper().replace("_", " "),
				STATUS_POP_COLORS.get(status_id, Color.WHITE)
			)
			_sfx("shock" if status_id == "resolve_shock" else "status")
		if bool(result["delayed"]):
			BattleFX.text_pop(stage, target.position, "DELAYED", Color(0.7, 0.8, 1.0))
			_sfx("delay")


func _on_combatant_hp_changed(old_value: int, new_value: int, combatant: BaseCombatant) -> void:
	var delta: int = new_value - old_value
	if delta < 0:
		BattleFX.damage_number(stage, combatant.position, -delta, "hurt")
	elif delta > 0:
		BattleFX.damage_number(stage, combatant.position, delta, "heal")


func _on_status_ticked(
	status_id: String, _hook: String, _fraction: float, combatant: BaseCombatant
) -> void:
	BattleFX.elemental_burst(stage, combatant.position, "Fire" if status_id == "burn" else "Dark"
	)
	_sfx(status_id if status_id in ["burn", "bleed"] else "status")


func _on_battle_ended(victory: bool) -> void:
	action_menu.close()
	target_select.close()
	if presenter != null:
		presenter.reset_time_scale()
	_active_arrow.hide_arrow()
	_target_arrow.hide_arrow()
	var music: Node = get_node_or_null("/root/MusicManager")
	if music != null and AssetLibrary.music_stream("victory" if victory else "defeat") != null:
		music.play_track("victory" if victory else "defeat")
	for member: BaseCombatant in party:
		carried_meters[member.display_name] = {
			"resolve": member.meters.resolve(),
			"darkness": member.meters.darkness() if member.is_heir() else 0.0,
		}
	_show_end_overlay(victory)


func _show_end_overlay(victory: bool) -> void:
	var world: Node = get_node_or_null("/root/WorldState")
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

	if world_mode and world != null:
		if victory:
			if world_roster == "boss":
				world.boss_cleared = true
			var go_on: Button = Button.new()
			go_on.text = "Continue the pilgrimage"
			go_on.pressed.connect(func() -> void:
				world.finish_battle(get_tree(), party, true))
			box.add_child(go_on)
			go_on.grab_focus()
		else:
			var retry: Button = Button.new()
			retry.text = "Retry (Resolve -%d)" % int(SaveSystem.RETRY_RESOLVE_PENALTY)
			retry.pressed.connect(func() -> void:
				world.apply_retry_penalty()
				world.pending_roster = world_roster
				call_deferred("_start_battle", false))
			box.add_child(retry)
			retry.grab_focus()
			var flee: Button = Button.new()
			flee.text = "Limp back to town (Resolve -%d)" % int(SaveSystem.RETRY_RESOLVE_PENALTY)
			flee.pressed.connect(func() -> void:
				world.return_scene = world.TOWN_SCENE
				world.has_return_position = false
				world.finish_battle(get_tree(), party, false))
			box.add_child(flee)
		var menu_btn: Button = Button.new()
		menu_btn.text = "Main menu"
		menu_btn.pressed.connect(
			func() -> void: get_tree().change_scene_to_file("res://world/main_menu.tscn")
		)
		box.add_child(menu_btn)
		return

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

	var menu: Button = Button.new()
	menu.text = "Main menu"
	menu.pressed.connect(
		func() -> void: get_tree().change_scene_to_file("res://world/main_menu.tscn")
	)
	box.add_child(menu)

	var quit: Button = Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)
