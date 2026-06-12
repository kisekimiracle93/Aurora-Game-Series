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

## Consumables (item ability id -> count) + world pickups/progress.
var inventory: Dictionary = {}
var opened_chests: Array = []
var cleared_foes: Array = []
var quests_done: Array = []
## Map foe that initiated the current battle (cleared on victory).
var pending_foe_id: String = ""
## Config handed to the generic interior scene on door entry.
var next_interior: Dictionary = {}
## Travel trail for the world map: where you are, where you came from.
var current_area: String = ""
var previous_area: String = ""
## Permanent max-HP blessings from the relics (name -> bonus HP this run).
var hp_blessings: Dictionary = {}
## Hoarfang's hoard taken: the party rises — and the Shepherd rises to match.
var hoard_blessing: bool = false

## What falls from each forced encounter when it breaks (per foe id).
const FOE_REWARDS: Dictionary = {
	"gate_town_warden": {"items": {"item_warden_sigil": 1}},
	"gate_pass_horror": {"items": {"item_pale_antler": 1}},
	"gate_deep_predator": {"items": {"item_predator_fang": 1}},
	"fields_hoarfang": {
		"items": {"item_gilded_censer": 1, "item_hp_potion": 4, "item_aether_draught": 3},
		"resolve": 20.0, "burden": -20.0, "hoard": true,
	},
}


func note_area_visit(scene_path: String) -> void:
	if scene_path == current_area:
		return
	previous_area = current_area
	current_area = scene_path


func _ready() -> void:
	reset_run()


func reset_run() -> void:
	party_meters = {}
	for member_name: String in PARTY_NAMES + [MERC_NAME]:
		party_meters[member_name] = {
			"resolve": MeterMath.RESOLVE_DEFAULT, "darkness": 0.0,
			"duty": MeterMath.DUTY_DEFAULT, "burden": 0.0,
		}
	inventory = {"item_hp_potion": 2, "item_aether_draught": 1}
	opened_chests = []
	cleared_foes = []
	quests_done = []
	pending_foe_id = ""
	merc_hired = false
	in_world_run = false
	pending_roster = ""
	return_scene = ""
	has_return_position = false
	dungeon_gauntlet_cleared = false
	boss_cleared = false
	current_area = ""
	previous_area = ""
	hp_blessings = {}
	hoard_blessing = false


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
	inventory = save.inventory.duplicate() if not save.inventory.is_empty() else inventory
	opened_chests = save.opened_chests.duplicate()
	quests_done = save.quests_done.duplicate()
	for member_name: String in party_meters:
		if save.character_resolve.has(member_name):
			party_meters[member_name]["resolve"] = float(save.character_resolve[member_name])
		if save.heir_darkness.has(member_name):
			party_meters[member_name]["darkness"] = float(save.heir_darkness[member_name])
		if save.character_duty.has(member_name):
			party_meters[member_name]["duty"] = float(save.character_duty[member_name])
		if save.character_burden.has(member_name):
			party_meters[member_name]["burden"] = float(save.character_burden[member_name])
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
	if victory and pending_foe_id != "":
		cleared_foes.append(pending_foe_id)
		_grant_foe_rewards(pending_foe_id)
	pending_foe_id = ""
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
		party_meters[member.display_name]["duty"] = member.meters.duty()
		party_meters[member.display_name]["burden"] = member.meters.burden()


func _grant_foe_rewards(foe_id: String) -> void:
	if not FOE_REWARDS.has(foe_id):
		return
	var reward: Dictionary = FOE_REWARDS[foe_id]
	var loot: Dictionary = reward.get("items", {})
	for item_id: String in loot:
		add_item(item_id, int(loot[item_id]))
	if reward.has("resolve"):
		adjust_party_meter("resolve", float(reward["resolve"]))
	if reward.has("burden"):
		adjust_party_meter("burden", float(reward["burden"]))
	if bool(reward.get("hoard", false)):
		hoard_blessing = true


func apply_to_member(member: BaseCombatant) -> void:
	if hp_blessings.has(member.display_name):
		member.stats.base_stats["hp"] = (
			int(member.stats.base_stats.get("hp", 1)) + int(hp_blessings[member.display_name])
		)
		member.stats.heal(int(hp_blessings[member.display_name]))
	if not party_meters.has(member.display_name):
		return
	var saved: Dictionary = party_meters[member.display_name]
	member.meters.set_value(MetersComponent.RESOLVE, float(saved.get("resolve", 60.0)))
	member.meters.set_value(MetersComponent.DUTY, float(saved.get("duty", MeterMath.DUTY_DEFAULT)))
	member.meters.set_value(MetersComponent.BURDEN, float(saved.get("burden", 0.0)))
	if member.is_heir():
		member.meters.set_value(MetersComponent.DARKNESS, float(saved.get("darkness", 0.0)))


func apply_retry_penalty() -> void:
	for member_name: String in party_meters:
		party_meters[member_name]["resolve"] = maxf(
			float(party_meters[member_name]["resolve"]) - SaveSystem.RETRY_RESOLVE_PENALTY,
			MeterMath.RESOLVE_MIN
		)


## --- save point --------------------------------------------------------------


## Rest at a save point: drain Darkness, restore Resolve, ease Burden, save.
const SAVE_POINT_BURDEN_RELIEF: float = 15.0


func rest_and_save(scene_path: String) -> Error:
	for member_name: String in party_meters:
		party_meters[member_name]["darkness"] = 0.0
		party_meters[member_name]["resolve"] = maxf(
			float(party_meters[member_name]["resolve"]), SaveSystem.SAVE_POINT_RESOLVE_FLOOR
		)
		party_meters[member_name]["burden"] = maxf(
			float(party_meters[member_name]["burden"]) - SAVE_POINT_BURDEN_RELIEF, 0.0
		)
	var save: SaveData = SaveData.new()
	for member_name: String in party_meters:
		save.character_resolve[member_name] = party_meters[member_name]["resolve"]
		save.character_duty[member_name] = party_meters[member_name]["duty"]
		save.character_burden[member_name] = party_meters[member_name]["burden"]
		if member_name in ["Jecht", "Mati"]:
			save.heir_darkness[member_name] = party_meters[member_name]["darkness"]
	save.scene_path = scene_path
	save.merc_hired = merc_hired
	save.inventory = inventory.duplicate()
	save.opened_chests = []
	for chest_id: Variant in opened_chests:
		save.opened_chests.append(String(chest_id))
	save.quests_done = []
	for quest_id: Variant in quests_done:
		save.quests_done.append(String(quest_id))
	return SaveSystem.write(save)


## --- inventory + world pickups -------------------------------------------------


func add_item(item_id: String, count: int = 1) -> void:
	inventory[item_id] = int(inventory.get(item_id, 0)) + count


func item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))


func consume_item(item_id: String) -> bool:
	if item_count(item_id) <= 0:
		return false
	inventory[item_id] = item_count(item_id) - 1
	return true


## Party-wide meter nudges from quests/dialogue (darkness only touches Heirs).
func adjust_party_meter(meter: String, delta: float) -> void:
	for member_name: String in party_meters:
		if meter == "darkness" and member_name not in ["Jecht", "Mati"]:
			continue
		var limits: Array = {
			"resolve": [MeterMath.RESOLVE_MIN, MeterMath.RESOLVE_MAX],
			"darkness": [MeterMath.DARKNESS_MIN, MeterMath.DARKNESS_MAX],
			"duty": [MeterMath.DUTY_MIN, MeterMath.DUTY_MAX],
			"burden": [MeterMath.BURDEN_MIN, MeterMath.BURDEN_MAX],
		}.get(meter, [0.0, 100.0])
		party_meters[member_name][meter] = clampf(
			float(party_meters[member_name].get(meter, 0.0)) + delta,
			float(limits[0]), float(limits[1])
		)
