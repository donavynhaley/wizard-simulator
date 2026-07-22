class_name SightController
extends Node

## Wizard Sight: the hold-only reading of the world (game-bible.md, "The casting
## sentence"). While the sight action is held the world desaturates through a
## fullscreen grade and every on-screen ElementSource renders a ringed marker on
## the HUD's source overlay. Sight also owns the elemental manipulation input:
## holding cast while Sight is active draws on the aimed source - the element
## strains toward the palm until the hold completes and the transfer fires.
## Refusals (no source, full hand, foreign essence) stay immediate.
## The ElementHandController performs the transfer and owns carried essence.
## Later the same component renders knowledge glyphs, smudges, and threads; the
## journal will decide what qualifies as a source.

signal sight_changed(active: bool)
signal element_action_requested(source: ElementSource)
signal element_pull_started(source: ElementSource, is_push: bool)
signal element_pull_updated(source: ElementSource, progress: float)
signal element_pull_canceled(source: ElementSource)
signal binding_analyzed(binding: MagicalBinding)

const SHADER := preload("res://game/player/sight/sight_overlay.gdshader")

enum HoldKind { PULL, PUSH }

## The aim may drift this factor beyond aim_radius mid-hold before it breaks.
const HOLD_AIM_SLACK := 1.6
## Seconds the completion flash ring lives on the HUD.
const FLASH_TIME := 0.3

## Pixels from screen centre within which a source counts as aimed.
@export var aim_radius := 90.0
@export var fade_in_time := 0.15
@export var fade_out_time := 0.1
## Seconds the cast press must be held to rip an element from its source.
@export var pull_time := 0.45
## Seconds to pour held essence back into an empty vessel; giving is easier.
@export var push_time := 0.25
var active := false

var _player: WizardPlayer
var _camera: Camera3D
var _layer: CanvasLayer
var _rect: ColorRect
var _material: ShaderMaterial
var _fade := 0.0
var _aimed: Node3D
var _activation_blocked_until_release := false
var _hold_target: Node3D
var _hold_kind := HoldKind.PULL
var _pull_progress := 0.0
var _attuning_binding: MagicalBinding
var _flash_screen := Vector2.ZERO
var _flash_color := Color.WHITE
var _flash_age := -1.0


func _ready() -> void:
	_player = owner as WizardPlayer
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as WizardPlayer
	assert(_player != null, "SightController must live under a WizardPlayer.")
	_camera = _player.get_node_or_null("Head/Camera3D") as Camera3D
	_build_overlay()


## The grade lives on its own CanvasLayer under the HUD (WizardHud defaults to
## layer 1) so markers, crosshair, and toasts stay readable above the wash.
func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 0
	add_child(_layer)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	_rect.visible = false
	_layer.add_child(_rect)


func _process(delta: float) -> void:
	if _activation_blocked_until_release and not Input.is_action_pressed(&"sight"):
		_activation_blocked_until_release = false
	var held := _player != null and _player.control_enabled() \
		and Input.is_action_pressed(&"sight") \
		and not _activation_blocked_until_release \
		and (_player.casting == null or not _player.casting.blocks_wizard_sight())
	if held != active:
		_set_active(held)
	var target := 1.0 if active else 0.0
	var rate := fade_in_time if active else fade_out_time
	_fade = move_toward(_fade, target, delta / maxf(rate, 0.01))
	_rect.visible = _fade > 0.001
	if _rect.visible:
		_material.set_shader_parameter(&"intensity", _fade)
	if _flash_age >= 0.0:
		_flash_age += delta
		if _flash_age > FLASH_TIME:
			_flash_age = -1.0
	if _hold_target != null:
		_advance_hold(delta)
	if _attuning_binding != null:
		_maintain_attunement()
	if active:
		_update_markers()


func _input(event: InputEvent) -> void:
	if _player == null or not _player.control_enabled():
		return
	if event.is_action_pressed(&"sight"):
		if _player.casting != null and _player.casting.blocks_wizard_sight():
			_activation_blocked_until_release = true
			WizardHud.toast(self, "Finish sketching before using Sight")
			return
		_set_active(true)
		_update_markers()
	elif event.is_action_released(&"sight"):
		_activation_blocked_until_release = false
		_set_active(false)
	if active and event.is_action_pressed(&"cast"):
		# Refresh synchronously so a quick Q-plus-click chord cannot use the
		# previous frame's camera aim or silently lose the click.
		_update_markers()
		_begin_element_action()
		get_viewport().set_input_as_handled()


## The source currently under the centre aim, or null when sight is down.
func aimed_source() -> ElementSource:
	return (_aimed as ElementSource) if active else null


## The binding strand currently under the centre aim, or null.
func aimed_binding() -> MagicalBinding:
	return (_aimed as MagicalBinding) if active else null


## Forces sight fully down immediately (menu takeovers): clears markers and
## the overlay without waiting for the key release or the fade.
func deactivate() -> void:
	_activation_blocked_until_release = false
	_set_active(false)
	_fade = 0.0
	if _rect != null:
		_rect.visible = false


## Decides what the cast press means at this aim. A grab or matching placement
## becomes a held gesture; an unread strand enters the resonance attunement
## (first press begins it, following presses are the timing strikes); every
## refusal fires immediately so its error toast answers the press.
func _begin_element_action() -> void:
	var binding := _aimed as MagicalBinding
	if binding != null:
		_press_on_binding(binding)
		return
	var source := _aimed as ElementSource
	var hand := _player.element_hand if _player != null else null
	if source == null or hand == null:
		element_action_requested.emit(source)
		return
	if not hand.has_element() and source.available():
		_start_hold(source, HoldKind.PULL)
	elif hand.can_place_into(source):
		_start_hold(source, HoldKind.PUSH)
	else:
		element_action_requested.emit(source)


func _press_on_binding(binding: MagicalBinding) -> void:
	if binding.is_analyzed():
		return  # Its inscription already shows in the world while aimed.
	if _attuning_binding != binding:
		_end_attunement()
		binding.begin_attunement()
		_attuning_binding = binding
		return
	if binding.strike() == MagicalBinding.StrikeResult.COMPLETED:
		_attuning_binding = null
		if _camera != null:
			_flash_screen = _camera.unproject_position(binding.midpoint())
			_flash_color = binding.marker_color()
			_flash_age = 0.0
		binding_analyzed.emit(binding)


## The attunement survives small aim drift but dies with Sight, distance, or
## a target that stops mattering.
func _maintain_attunement() -> void:
	if not is_instance_valid(_attuning_binding):
		_attuning_binding = null
		return
	if not active or _hold_aim_broken_for(_attuning_binding.midpoint()):
		_end_attunement()


func _end_attunement() -> void:
	if _attuning_binding != null and is_instance_valid(_attuning_binding):
		_attuning_binding.end_attunement()
	_attuning_binding = null


func _start_hold(target: Node3D, kind: HoldKind) -> void:
	_hold_target = target
	_hold_kind = kind
	_pull_progress = 0.0
	element_pull_started.emit(target as ElementSource, kind == HoldKind.PUSH)


func _advance_hold(delta: float) -> void:
	if not is_instance_valid(_hold_target) or not active \
			or not Input.is_action_pressed(&"cast") or _hold_aim_broken():
		_cancel_hold()
		return
	var hold_time := push_time if _hold_kind == HoldKind.PUSH else pull_time
	_pull_progress = minf(_pull_progress + delta / maxf(hold_time, 0.01), 1.0)
	if _hold_kind == HoldKind.PULL:
		(_hold_target as ElementSource).set_pull(_pull_progress, _hand_position())
	element_pull_updated.emit(_hold_target as ElementSource, _pull_progress)
	if _pull_progress >= 1.0:
		_complete_hold()


func _complete_hold() -> void:
	var target := _hold_target
	_hold_target = null
	_pull_progress = 0.0
	if _camera != null:
		_flash_screen = _camera.unproject_position(_aim_point_of(target))
		_flash_color = _color_of(target)
		_flash_age = 0.0
	element_action_requested.emit(target as ElementSource)


func _cancel_hold() -> void:
	var target := _hold_target
	var kind := _hold_kind
	_hold_target = null
	_pull_progress = 0.0
	if is_instance_valid(target):
		if kind == HoldKind.PULL:
			(target as ElementSource).release_pull()
		element_pull_canceled.emit(target as ElementSource)


## Mid-hold the aim gets slack beyond aim_radius - small drift should not drop
## a pull the player is clearly still committing to.
func _hold_aim_broken() -> bool:
	return _hold_aim_broken_for(_aim_point_of(_hold_target))


func _hold_aim_broken_for(point: Vector3) -> bool:
	if _camera == null:
		return false
	if _camera.is_position_behind(point):
		return true
	var center := get_viewport().get_visible_rect().size * 0.5
	return center.distance_to(_camera.unproject_position(point)) \
		> aim_radius * HOLD_AIM_SLACK


func _aim_point_of(target: Node3D) -> Vector3:
	var source := target as ElementSource
	if source != null:
		return source.siphon_point()
	var binding := target as MagicalBinding
	if binding != null:
		return binding.midpoint()
	return target.global_position if target != null else Vector3.ZERO


func _color_of(target: Node3D) -> Color:
	var source := target as ElementSource
	if source != null and source.element != null:
		return source.element.color
	var binding := target as MagicalBinding
	if binding != null:
		return binding.marker_color()
	return Color.WHITE


func _hand_position() -> Vector3:
	if _player != null and _player.element_hand != null:
		return _player.element_hand.hand_position()
	return _camera.global_position if _camera != null else Vector3.ZERO


## Tracks the aimed target and tells strands when they gain or lose the aim,
## which drives their world inscriptions.
func _set_aimed_target(aimed: Node3D) -> void:
	if aimed == _aimed:
		return
	var previous := _aimed as MagicalBinding
	if previous != null and is_instance_valid(previous):
		previous.set_aimed(false)
	_aimed = aimed
	var current := _aimed as MagicalBinding
	if current != null:
		current.set_aimed(true)


func _set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	get_tree().call_group(MagicalBinding.GROUP, &"set_sight_visible", active)
	if not active:
		if _hold_target != null:
			_cancel_hold()
		_end_attunement()
		_set_aimed_target(null)
		_set_markers([])
	sight_changed.emit(active)


## Projects every on-screen ElementSource and journal-relevant binding strand
## to a HUD marker and picks the one nearest the screen centre (within
## aim_radius) as the aimed target.
func _update_markers() -> void:
	if _camera == null:
		return
	var bounds := get_viewport().get_visible_rect().size
	var center := bounds * 0.5
	var markers: Array = []
	var best_distance := aim_radius
	var aimed: Node3D = null
	for node in get_tree().get_nodes_in_group(ElementSource.GROUP):
		var src := node as ElementSource
		if src == null or src.element == null:
			continue
		var projected: Variant = _screen_point(src.siphon_point(), bounds)
		if projected == null:
			continue
		var screen := projected as Vector2
		# A depleted source renders as an empty vessel: hollow, still aimable,
		# waiting for matching essence to be placed back in.
		markers.append({"pos": screen, "color": src.element.color,
			"progress": _pull_progress if src == _hold_target else 0.0,
			"empty": not src.available(), "aimed": false, "src": src})
		var distance := center.distance_to(screen)
		if distance <= best_distance:
			best_distance = distance
			aimed = src
	for node in get_tree().get_nodes_in_group(MagicalBinding.GROUP):
		var binding := node as MagicalBinding
		if binding == null or not binding.sight_relevant():
			continue
		var projected: Variant = _screen_point(binding.midpoint(), bounds)
		if projected == null:
			continue
		var screen := projected as Vector2
		var attuning := binding == _attuning_binding
		markers.append({"pos": screen, "color": binding.marker_color(),
			"kind": "binding", "analyzed": binding.is_analyzed(),
			"progress": binding.attunement_progress() if attuning else 0.0,
			"window": attuning and binding.is_phase_in_window(),
			"aimed": false, "src": binding})
		var distance := center.distance_to(screen)
		if distance <= best_distance:
			best_distance = distance
			aimed = binding
	_set_aimed_target(aimed)
	for marker: Dictionary in markers:
		marker["aimed"] = marker["src"] == _aimed
		marker.erase("src")
	if _flash_age >= 0.0:
		markers.append({"pos": _flash_screen, "color": _flash_color,
			"flash": clampf(_flash_age / FLASH_TIME, 0.0, 1.0)})
	_set_markers(markers)


## Projects a world point to the screen, or null when behind or off-screen.
func _screen_point(world_point: Vector3, bounds: Vector2) -> Variant:
	if _camera.is_position_behind(world_point):
		return null
	var screen := _camera.unproject_position(world_point)
	if screen.x < 0.0 or screen.y < 0.0 or screen.x > bounds.x or screen.y > bounds.y:
		return null
	return screen


func _set_markers(markers: Array) -> void:
	if _player != null and _player.hud != null:
		_player.hud.set_siphon_markers(markers)
