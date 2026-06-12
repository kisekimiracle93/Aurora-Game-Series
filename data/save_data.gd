class_name SaveData
extends Resource
## Persistent slice state (build plan §4 Persistence): per-character Resolve,
## per-heir Darkness, plus minimal world position. Written at save points.

@export var character_resolve: Dictionary = {}  # character name -> float (0-120)
@export var heir_darkness: Dictionary = {}  # heir name -> float (0-100)
@export var character_duty: Dictionary = {}  # name -> float (0-100)
@export var character_burden: Dictionary = {}  # name -> float (0-100)
@export var unlocked_echo_ids: Array[String] = []
@export var scene_path: String = ""  # where to respawn on load
@export var merc_hired: bool = false
@export var inventory: Dictionary = {}  # item ability id -> count
@export var opened_chests: Array[String] = []
@export var quests_done: Array[String] = []
