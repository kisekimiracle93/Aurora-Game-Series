class_name EnemyData
extends CharacterData
## Enemy definition (build plan 5.1) — CharacterData plus enemy-only fields.
## Instances live in /data/enemies as .tres files.

@export var ferocity: float = 1.0  # offense bias (enemy stand-in for Resolve)
@export var stability: float = 0.0  # resistance to delay/status (0-1)
@export var ai_profile: String = "basic"  # which targeting priority list to use
## Bosses accumulate Delay Resistance (+25% per successful delay); trash does not.
@export var accumulates_delay_resistance: bool = false
