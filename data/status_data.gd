class_name StatusData
extends Resource
## Status effect definition (build plan 5.1 + 5.5).
## Instances live in /data/statuses as .tres files.
## Behavior flags beyond the base schema are data-driven here rather than
## hardcoded by id (logged in BUILD_LOG.md).

@export var id: String = ""  # "freeze"|"burn"|"slow"|"silence"|"bleed"|"resolve_shock"
@export var display_name: String = ""
@export var base_duration: int = 2  # in turns
@export var speed_mult: float = 1.0  # for slow/haste-type statuses (else 1.0)
@export var on_tick: String = ""  # effect hook id (e.g. "burn_damage", "bleed_damage")
## Fraction of the victim's max HP dealt by each on_tick hit (burn/bleed).
@export var tick_fraction: float = 0.0
@export var blocks_action: bool = false  # Freeze: locked out of acting
@export var blocks_spells: bool = false  # Silence: spells unavailable
@export var accuracy_delta: float = 0.0  # flat accuracy change while active
## Resolve Shock: instant Resolve hit rolled in [resolve_drop_min, resolve_drop_max].
@export var resolve_drop_min: int = 0
@export var resolve_drop_max: int = 0
