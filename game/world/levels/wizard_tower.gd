extends Node3D

const TERRAIN_PASSAGE_RADIUS := 5.1
const TERRAIN_PASSAGE_MAX_Y := 1.0

@onready var tower_architecture: TowerArchitecture = $TowerArchitecture
@onready var player: WizardPlayer = $Player

var _respawn_pending := false
var _terrain_body: StaticBody3D
var _terrain_exception_active := false


func _ready() -> void:
	assert(tower_architecture != null, "WizardTower requires its architecture scene.")
	assert(player != null, "WizardTower requires a player.")
	var terrain_mesh := $WorldBlockout.find_child("terrain-ground", true, false)
	if terrain_mesh != null:
		_terrain_body = terrain_mesh.find_child("*", true, false) as StaticBody3D
	assert(_terrain_body != null, "WizardTower requires imported terrain collision.")
	player.health.died.connect(_on_player_died)


func _physics_process(_delta: float) -> void:
	if _terrain_body == null:
		return
	var horizontal_position := Vector2(player.global_position.x, player.global_position.z)
	var should_ignore_terrain := tower_architecture.is_basement_revealed() \
		and horizontal_position.length() < TERRAIN_PASSAGE_RADIUS \
		and player.global_position.y < TERRAIN_PASSAGE_MAX_Y
	if should_ignore_terrain == _terrain_exception_active:
		return
	_terrain_exception_active = should_ignore_terrain
	if should_ignore_terrain:
		player.add_collision_exception_with(_terrain_body)
	else:
		player.remove_collision_exception_with(_terrain_body)


func _on_player_died() -> void:
	if _respawn_pending:
		return
	_respawn_pending = true
	player.set_control_enabled(false)
	tower_architecture.reveal_basement()
	_respawn_player.call_deferred()


func _respawn_player() -> void:
	player.global_transform = tower_architecture.basement_respawn.global_transform
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	player.health.reset()
	player.set_control_enabled(true)
	WizardHud.toast(player, "The Second Vessel drags you back into the world")
	_respawn_pending = false
