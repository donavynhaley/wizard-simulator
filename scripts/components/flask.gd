extends Item
class_name Flask

@export var pickup_prompt_text =  "pick up flask of "
@export var break_impact_speed: float = 1.2
@export_flags_3d_physics var active_collision_layer: int = 2
@export_flags_3d_physics var active_collision_mask: int = 1

const GLASS_BREAK_SOUND: AudioStream = preload("res://assets/sounds/glass-breaking.wav")

var item_in_flask: Reagent = null
var is_cooked := false
var _is_held := false
@export var _is_stationed := false
var _is_broken := false
var _last_free_speed := 0.0


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = maxi(max_contacts_reported, 4)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func get_flask_item() -> Reagent:
	return item_in_flask

func cook() -> void:
	is_cooked = true

func focus_prompt(player: WizardPlayer, _collider: Object) -> String:
	if player == null or player.hands == null:
		return ""
	var hands := player.hands
	if hands.held_item == null:
		return _get_reagent_name()
	return "empty your hands"

func _get_reagent_name() -> String:
	if is_cooked:
		return "Pick up cooked flask"
	var reagent = get_flask_item()
	if reagent != null:
		return pickup_prompt_text + reagent.get_name()
	return "Pick up empty flask"
	
func interact(player: WizardPlayer, _collider: Object) -> void:
	if _is_broken:
		return
	if player == null or player.hands == null:
		return
	var hands := player.hands
	if hands.held_item != null and not (hands.held_item is Flask):
		return
	hands.pick_up(self)


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


func should_drop_straight_down() -> bool:
	return true


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
	var cleanup := func() -> void:
		if is_instance_valid(player):
			player.queue_free()
	player.finished.connect(cleanup, CONNECT_ONE_SHOT)
	var cleanup_delay: float = clampf(GLASS_BREAK_SOUND.get_length() + 0.15, 0.25, 2.5)
	get_tree().create_timer(cleanup_delay).timeout.connect(cleanup, CONNECT_ONE_SHOT)
	player.play()
