extends Node
## Autoload: the slice's world flow. Carries party meters between scenes and
## battles, owns the merc-hire flag, brokers battle hand-offs (which roster,
## where to return), applies the defeat retry penalty, and talks to SaveSystem
## at save points. Battle scenes launched directly from Playtest jump-offs
## work without it (no pending battle = standalone mode).

const TOWN_SCENE: String = "res://world/town.tscn"
const PARTY_NAMES: Array[String] = ["Bastil", "Cavene", "Jecht", "Mati"]
const MERC_NAME: String = "Church Lancer"

## name -> {"resolve": float, "darkness": float}
var party_meters: Dictionary = {}
var merc_hired: bool = false
var in_world_run: bool = false  # true once a Start/Continue run begins

## Pending battle hand-off (empty when battles are standalone).
var pending_roster: String = ""
var return_scene: String = ""
var return_position: Vector2 = Vector2.ZERO
var has_return_position: bool = false

## Per-run world flags (not persisted in the slice save).
var dungeon_gauntlet_cleared: bool = false
var boss_cleared: bool = false


func _ready() -> void:
	reset_run()


func reset_run() -> void:
	party_meters = {}
	for member_name: String in PARTY_NAMES + [MERC_NAME]:
		party_meters[member_name] = {"resolve": MeterMath.RESOLVE_DEFAULT, "darkness": 0.0}
	merc_hired = false
	in_world_run = false
	pending_roster = ""
	return_scene = ""
	has_return_position = false
	dungeon_gauntlet_cleared = false
	boss_cleared = false


## --- run lifecycle -----------------------------------------------------------


func start_new_run(tree: SceneTree) -> void:
	reset_run()
	in_world_run = true
	tree.change_scene_to_file(TOWN_SCENE)


## Playtest jump-off: begin a fresh run directly in any world scene.
func start_run_at(tree: SceneTree, scene_path: String) -> void:
	reset_run()
	in_world_run = true
	tree.change_scene_to_file(scene_path)


## Returns false when there is no save to continue from.
func continue_run(tree: SceneTree) -> bool:
	var save: SaveData = SaveSystem.read()
	if save == null:
		return false
	reset_run()
	in_world_run = true
	merc_hired = save.merc_hired
	for member_name: String in party_meters:
		if save.character_resolve.has(member_name):
			party_meters[member_name]["resolve"] = float(save.character_resolve[member_name])
		if save.heir_darkness.has(member_name):
			party_meters[member_name]["darkness"] = float(save.heir_darkness[member_name])
	var target: String = save.scene_path if save.scene_path != "" else TOWN_SCENE
	tree.change_scene_to_file(target)
	return true


func has_save() -> bool:
	return SaveSystem.exists()


## --- battle hand-off ---------------------------------------------------------


func start_battle(
	tree: SceneTree, roster: String, from_scene: String, at_position: Vector2
) -> void:
	pending_roster = roster
	return_scene = from_scene
	return_position = at_position
	has_return_position = true
	tree.change_scene_to_file(
		"res://world/boss_test.tscn" if roster == "boss" else "res://world/battle_test.tscn"
	)


func consume_pending_roster() -> String:
	var roster: String = pending_roster
	pending_roster = ""
	return roster


## Battle scene reports the post-battle meters; world flow resumes.
func finish_battle(tree: SceneTree, party: Array[BaseCombatant], victory: bool) -> void:
	snapshot_party(party)
	if not victory:
		apply_retry_penalty()
	if return_scene != "":
		tree.change_scene_to_file(return_scene)
	else:
		tree.change_scene_to_file(TOWN_SCENE)


func snapshot_party(party: Array[BaseCombatant]) -> void:
	for member: BaseCombatant in party:
		if not party_meters.has(member.display_name):
			party_meters[member.display_name] = {}
		party_meters[member.display_name]["resolve"] = member.meters.resolve()
		party_meters[member.display_name]["darkness"] = (
			member.meters.darkness() if member.is_heir() else 0.0
		)


func apply_to_member(member: BaseCombatant) -> void:
	if not party_meters.has(member.display_name):
		return
	var saved: Dictionary = party_meters[member.display_name]
	member.meters.set_value(MetersComponent.RESOLVE, float(saved.get("resolve", 60.0)))
	if member.is_heir():
		member.meters.set_value(MetersComponent.DARKNESS, float(saved.get("darkness", 0.0)))


func apply_retry_penalty() -> void:
	for member_name: String in party_meters:
		party_meters[member_name]["resolve"] = maxf(
			float(party_meters[member_name]["resolve"]) - SaveSystem.RETRY_RESOLVE_PENALTY,
			MeterMath.RESOLVE_MIN
		)


## --- save point --------------------------------------------------------------


## Rest at a save point: drain Darkness, restore Resolve to the floor, save.
func rest_and_save(scene_path: String) -> Error:
	for member_name: String in party_meters:
		party_meters[member_name]["darkness"] = 0.0
		party_meters[member_name]["resolve"] = maxf(
			float(party_meters[member_name]["resolve"]), SaveSystem.SAVE_POINT_RESOLVE_FLOOR
		)
	var save: SaveData = SaveData.new()
	for member_name: String in party_meters:
		save.character_resolve[member_name] = party_meters[member_name]["resolve"]
		if member_name in ["Jecht", "Mati"]:
			save.heir_darkness[member_name] = party_meters[member_name]["darkness"]
	save.scene_path = scene_path
	save.merc_hired = merc_hired
	return SaveSystem.write(save)
