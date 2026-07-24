extends Item
class_name Flask

@export var break_impact_speed: float = 1.2
@export_flags_3d_physics var active_collision_layer: int = 2
@export_flags_3d_physics var active_collision_mask: int = 1

const GLASS_BREAK_SOUND: AudioStream = preload("res://assets/sounds/glass-breaking.wav")

var _is_held := false
@export var _is_stationed := false
var _is_broken := false
var _last_free_speed := 0.0


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = maxi(max_contacts_reported, 4)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if _is_stationed:
		# Shelf scenes author flasks with _is_stationed set; without this they
		# load as live unfrozen bodies that can be jostled yet never break.
		_set_physics_active(false)


func set_held(value: bool) -> void:
	_is_held = value
	_is_stationed = false
	if _is_held:
		_set_physics_active(false)
	else:
		_set_physics_active(true)


func set_stationed(value: bool) -> void:
	_is_stationed = value
	if _is_stationed:
		_set_physics_active(false)
	elif not _is_held:
		_set_physics_active(true)


func _physics_process(_delta: float) -> void:
	if _is_broken or _is_held or _is_stationed or freeze:
		return
	_last_free_speed = maxf(_last_free_speed, linear_velocity.length())
	if get_contact_count() > 0:
		_try_break_from_impact()


func _on_body_entered(_body: Node) -> void:
	if _is_broken or _is_held or _is_stationed:
		return
	_try_break_from_impact()


func _try_break_from_impact() -> void:
	if _last_free_speed < break_impact_speed:
		_last_free_speed = 0.0
		return
	_break()


func _set_physics_active(active: bool) -> void:
	freeze = not active
	sleeping = not active
	linear_velocity = Vector3.ZERO if not active else linear_velocity
	angular_velocity = Vector3.ZERO if not active else angular_velocity
	collision_layer = active_collision_layer if active else 0
	collision_mask = active_collision_mask if active else 0
	if active:
		_last_free_speed = 0.0


func _break() -> void:
	_is_broken = true
	_set_physics_active(false)
	visible = false
	_play_break_sound()
	queue_free()


func _play_break_sound() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.name = "GlassBreakAudio"
	player.stream = GLASS_BREAK_SOUND
	player.unit_size = 1.5
	player.max_distance = 18.0
	scene.add_child(player)
	player.global_position = global_position
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
	player.play()
