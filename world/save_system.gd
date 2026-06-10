class_name SaveSystem
extends RefCounted
## Save/load + save-point effects + retry penalty (build plan M2 / §2).
## Pure static helpers over SaveData and MetersComponent — headless-testable.

const SAVE_PATH: String = "user://aurora_slice_save.tres"
## Resolve is lower when retrying a lost fight (build plan §2). Tunable.
const RETRY_RESOLVE_PENALTY: float = 15.0
## Save points restore Resolve up to this floor (never lower it) and drain Darkness.
const SAVE_POINT_RESOLVE_FLOOR: float = 75.0


static func write(save: SaveData, path: String = SAVE_PATH) -> Error:
	return ResourceSaver.save(save, path)


static func read(path: String = SAVE_PATH) -> SaveData:
	if not FileAccess.file_exists(path):
		return null
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData


static func exists(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


static func delete(path: String = SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Save-point recovery (build plan §2): drain Darkness, restore Resolve.
static func apply_save_point_recovery(meters: MetersComponent) -> void:
	if meters.has_meter(MetersComponent.DARKNESS):
		meters.set_value(MetersComponent.DARKNESS, 0.0)
	if meters.has_meter(MetersComponent.RESOLVE):
		var restored: float = maxf(meters.resolve(), SAVE_POINT_RESOLVE_FLOOR)
		meters.set_value(MetersComponent.RESOLVE, restored)


## Retry after defeat: every saved character restarts with lower Resolve.
static func apply_retry_penalty(save: SaveData) -> void:
	for character_name: String in save.character_resolve:
		var lowered: float = float(save.character_resolve[character_name]) - RETRY_RESOLVE_PENALTY
		save.character_resolve[character_name] = maxf(lowered, MeterMath.RESOLVE_MIN)


## Snapshot one character's persistent meters into the save.
static func collect_meters(save: SaveData, character_name: String, meters: MetersComponent) -> void:
	if meters.has_meter(MetersComponent.RESOLVE):
		save.character_resolve[character_name] = meters.resolve()
	if meters.has_meter(MetersComponent.DARKNESS):
		save.heir_darkness[character_name] = meters.darkness()


## Apply saved meters back onto a character (no-op for values never saved).
static func apply_meters(save: SaveData, character_name: String, meters: MetersComponent) -> void:
	if save.character_resolve.has(character_name) and meters.has_meter(MetersComponent.RESOLVE):
		meters.set_value(MetersComponent.RESOLVE, float(save.character_resolve[character_name]))
	if save.heir_darkness.has(character_name) and meters.has_meter(MetersComponent.DARKNESS):
		meters.set_value(MetersComponent.DARKNESS, float(save.heir_darkness[character_name]))
