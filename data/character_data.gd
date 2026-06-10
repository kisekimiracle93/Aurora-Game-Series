class_name CharacterData
extends Resource
## Playable character definition (see VERTICAL_SLICE_BUILD_PLAN.md 5.1).
## Instances live in /data/characters as .tres files — content is data, not code.

@export var name: String = ""
@export var class_type: String = "Aetherion"  # "Aetherion" | "Heir"
@export var element: String = "Fire"  # "Fire" | "Ice"
@export var is_heir: bool = false  # enables the Darkness meter
## hp, aether, power, focus, guard, ward, speed, accuracy, evasion, crit
@export var base_stats: Dictionary = {}
## element -> "weak"|"neutral"|"resist"|"absorb"|"immune"
@export var affinities: Dictionary = {}
@export var ability_ids: Array[String] = []
## Hireable mercenary: low HP, no magic, draws enemy aggro (AI priority).
@export var is_merc: bool = false
## Jecht's passive: CTB speed bonus scaling with Darkness (CTBMath).
@export var darkness_speed_passive: bool = false
