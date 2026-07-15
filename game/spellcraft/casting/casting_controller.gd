class_name CastingController
extends Node

enum CASTING_STATE {
	IDLE,
	SKETCHING,
	SPELL_HELD,
}

@export var enable_sketching_state_time: float = 0.8
@export var sketching_cursor_sensitivity := 1.0

var current_state: CASTING_STATE = CASTING_STATE.IDLE

var _player: WizardPlayer
var _hud: WizardHud
var sketching_state_time_accumulator: float = 0.0
var sketching_cursor_pos: Vector2


func _ready() -> void:
	_player = owner as WizardPlayer
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as WizardPlayer
	assert(_player != null, "CastingController must live under a WizardPlayer.")


func _process(delta: float) -> void:
	match current_state:
		CASTING_STATE.IDLE:
			_update_idle(delta)
		CASTING_STATE.SKETCHING:
			_update_sketching()


func _input(event: InputEvent) -> void:
	if current_state != CASTING_STATE.SKETCHING:
		return
	if event is InputEventMouseMotion:
		_on_sketch_motion((event as InputEventMouseMotion).relative)


func _update_idle(delta: float) -> void:
	if Input.is_action_pressed("cast_focus"):
		sketching_state_time_accumulator += delta
		if sketching_state_time_accumulator >= enable_sketching_state_time:
			_set_state(CASTING_STATE.SKETCHING)
	else:
		sketching_state_time_accumulator = 0.0


func _update_sketching() -> void:
	if not Input.is_action_pressed("cast_focus"):
		_set_state(CASTING_STATE.IDLE)


func _set_state(next: CASTING_STATE) -> void:
	if next == current_state:
		return
	match current_state:
		CASTING_STATE.SKETCHING: _exit_sketching()
	current_state = next
	match next:
		CASTING_STATE.SKETCHING: _enter_sketching()


func _enter_sketching() -> void:
	_player.look_enabled= false
	sketching_cursor_pos = get_viewport().get_visible_rect().size * 0.5
	if _get_hud() != null:
		_hud.set_sketch_cursor(sketching_cursor_pos)
		_hud.show_sketch_cursor(true)


func _exit_sketching() -> void:
	if _get_hud() != null:
		_hud.show_sketch_cursor(false)
	_player.look_enabled =true
	sketching_state_time_accumulator = 0.0


func _on_sketch_motion(relative: Vector2) -> void:
	var bounds := get_viewport().get_visible_rect().size
	sketching_cursor_pos = (sketching_cursor_pos + relative * sketching_cursor_sensitivity) \
		.clamp(Vector2.ZERO, bounds)
	if _get_hud() != null:
		_hud.set_sketch_cursor(sketching_cursor_pos)


func _get_hud() -> WizardHud:
	if _hud == null and _player != null:
		_hud = _player.hud
	return _hud
