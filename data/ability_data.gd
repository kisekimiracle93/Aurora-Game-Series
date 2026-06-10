class_name AbilityData
extends Resource
## Ability definition (build plan 5.1). Instances live in /data/abilities as .tres files.

@export var id: String = ""
@export var display_name: String = ""
@export var ability_type: String = "attack"  # "attack"|"spell"|"support"|"echo"
@export var damage_type: String = "physical"  # "physical"|"magic"|"none"
@export var element: String = "Neutral"  # "Fire"|"Ice"|"Time"|"Neutral"
@export var coeff: float = 1.5  # SkillCoeff 1.2-3.5 | SpellCoeff 1.3-4.0
@export var ct_cost: int = 850  # action weight (build plan 5.3)
@export var aether_cost: int = 0
@export var targeting: String = "single"  # "single"|"aoe"|"line"|"self"
## Each entry: {"status_id": String, "base_chance": float (percent), "base_duration": int}
@export var statuses: Array[Dictionary] = []
@export var requirements: Dictionary = {}  # e.g. {"min_darkness": 20} (slice: minimal)
## Time-element utility: CT push-back applied to the target (0 = none).
@export var delay_amount: int = 0
## Darkness added to the user on cast (Heir dark abilities only).
@export var darkness_cost: int = 0
## Negative-space heal: support abilities heal for coeff * Focus when > 0.
@export var heals: bool = false
## Resolve restored to the target on a landed/support use (Rally-type abilities).
@export var resolve_gain: int = 0
