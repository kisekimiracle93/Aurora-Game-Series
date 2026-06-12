class_name OverworldFoe
extends Area2D
## A visible enemy on the map (replaces random encounters): patrols its
## waypoints, gives chase when the player strays close, gives up at its leash
## and walks home. Touching the player starts its battle roster. Defeated
## foes stay gone for the run (WorldState.cleared_foes).

const PATROL_SPEED: float = 70.0
const CHASE_SPEED: float = 150.0
const AGGRO_RADIUS: float = 185.0
const LEASH_RADIUS: float = 360.0

enum FoeState { PATROL, CHASE, RETURN }

var foe_id: String = ""
var roster: String = "wolves_2"
var sprite_name: String = "Aether Wolf"
var waypoints: Array[Vector2] = []
var state: FoeState = FoeState.PATROL

var _home: Vector2
var _waypoint_index: int = 0
var _player: PlayerAvatar
var _exclaim: Label
var _beast_sprite: Sprite2D  # single-tile beasts flip to face their motion


## Pure decision rule — unit-testable without a scene.
static func decide_state(
	current: FoeState, dist_to_player: float, dist_to_home: float
) -> FoeState:
	match current:
		FoeState.PATROL:
			return FoeState.CHASE if dist_to_player < AGGRO_RADIUS else FoeState.PATROL
		FoeState.CHASE:
			if dist_to_home > LEASH_RADIUS:
				return FoeState.RETURN
			return FoeState.CHASE
		_:
			if dist_to_home < 12.0:
				return FoeState.PATROL
			return FoeState.RETURN


func setup(
	id: String, roster_in: String, sprite_in: String, points: Array[Vector2]
) -> void:
	foe_id = id
	roster = roster_in
	sprite_name = sprite_in
	waypoints = points
	position = points[0]
	_home = points[0]


func _ready() -> void:
	z_index = 8
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 24.0
	shape.shape = circle
	add_child(shape)
	if WalkerSprite.attach(self, sprite_name, 2.2):
		pass  # bandit-type foes get full directional bodies
	elif AssetLibrary.texture("characters", sprite_name) != null:
		var art: Texture2D = AssetLibrary.texture("characters", sprite_name)
		_beast_sprite = Sprite2D.new()
		_beast_sprite.texture = art
		_beast_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_beast_sprite.scale = Vector2(2.4, 2.4)
		add_child(_beast_sprite)
	else:
		var body: ColorRect = ColorRect.new()
		body.color = Color(0.85, 0.3, 0.25)
		body.size = Vector2(30, 30)
		body.position = Vector2(-15, -15)
		add_child(body)
	_exclaim = Label.new()
	_exclaim.text = "!"
	_exclaim.add_theme_font_size_override("font_size", 26)
	_exclaim.modulate = Color(1.0, 0.3, 0.25)
	_exclaim.position = Vector2(-6, -58)
	_exclaim.visible = false
	add_child(_exclaim)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _player == null:
		var area: AreaBase = get_parent() as AreaBase
		if area != null:
			_player = area.player
		return
	var previous: FoeState = state
	state = decide_state(
		state, position.distance_to(_player.position), position.distance_to(_home)
	)
	if state == FoeState.CHASE and previous != FoeState.CHASE:
		_exclaim.visible = true
		var sfx: Node = get_node_or_null("/root/SfxManager")
		if sfx != null:
			sfx.play("shock")
	elif state != FoeState.CHASE:
		_exclaim.visible = false

	var before: Vector2 = position
	match state:
		FoeState.PATROL:
			var target: Vector2 = waypoints[_waypoint_index % waypoints.size()]
			if position.distance_to(target) < 8.0:
				_waypoint_index += 1
			else:
				position = position.move_toward(target, PATROL_SPEED * delta)
		FoeState.CHASE:
			position = position.move_toward(_player.position, CHASE_SPEED * delta)
		FoeState.RETURN:
			position = position.move_toward(_home, PATROL_SPEED * delta)
	if _beast_sprite != null and absf(position.x - before.x) > 0.1:
		_beast_sprite.flip_h = position.x < before.x  # DCSS beasts face right


func _on_body_entered(body: Node2D) -> void:
	if body != _player or _player == null:
		return
	var world: Node = get_node_or_null("/root/WorldState")
	if world == null or not world.in_world_run:
		return
	set_deferred("monitoring", false)
	world.pending_foe_id = foe_id
	world.start_battle(
		get_tree(), roster, get_parent().scene_file_path, _player.position
	)
