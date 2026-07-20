class_name SightController
extends Node

## Wizard Sight: the hold-only reading of the world (game-bible.md, "The casting
## sentence"). While the sight action is held the world desaturates through a
## fullscreen grade and every on-screen ElementSource renders a ringed marker on
## the HUD's siphon overlay. Sight only reveals - pulling essence through it is
## the CastingController's job, which reads aimed_source() each frame and writes
## aim_progress back so the aimed ring fills as the pull dwells.
## Later the same component renders knowledge glyphs, smudges, and threads; the
## journal will decide what qualifies as a source.

signal sight_changed(active: bool)

const SHADER := preload("res://game/player/sight/sight_overlay.gdshader")

## Pixels from screen centre within which a source counts as aimed.
@export var aim_radius := 90.0
@export var fade_in_time := 0.15
@export var fade_out_time := 0.1

var active := false
## Pull progress (0-1) shown on the aimed source's ring; CastingController owns it.
var aim_progress := 0.0

var _player: WizardPlayer
var _camera: Camera3D
var _layer: CanvasLayer
var _rect: ColorRect
var _material: ShaderMaterial
var _fade := 0.0
var _aimed: ElementSource


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
	var held := Input.is_action_pressed(&"sight")
	if held != active:
		active = held
		if not active:
			_aimed = null
			aim_progress = 0.0
			_set_markers([])
		sight_changed.emit(active)
	var target := 1.0 if active else 0.0
	var rate := fade_in_time if active else fade_out_time
	_fade = move_toward(_fade, target, delta / maxf(rate, 0.01))
	_rect.visible = _fade > 0.001
	if _rect.visible:
		_material.set_shader_parameter(&"intensity", _fade)
	if active:
		_update_markers()


## The source currently under the centre aim, or null when sight is down.
func aimed_source() -> ElementSource:
	return _aimed if active else null


## Projects every on-screen ElementSource to a HUD ring and picks the one
## nearest the screen centre (within aim_radius) as the aimed source.
func _update_markers() -> void:
	if _camera == null:
		return
	var bounds := get_viewport().get_visible_rect().size
	var center := bounds * 0.5
	var markers: Array = []
	var best_distance := aim_radius
	var aimed: ElementSource = null
	var aimed_marker: Dictionary = {}
	for node in get_tree().get_nodes_in_group(ElementSource.GROUP):
		var src := node as ElementSource
		if src == null or src.element == null or not src.available():
			continue
		var world_point := src.siphon_point()
		if _camera.is_position_behind(world_point):
			continue
		var screen := _camera.unproject_position(world_point)
		if screen.x < 0.0 or screen.y < 0.0 or screen.x > bounds.x or screen.y > bounds.y:
			continue
		var marker := {"pos": screen, "color": src.element.color, "progress": 0.0}
		markers.append(marker)
		var distance := center.distance_to(screen)
		if distance <= best_distance:
			best_distance = distance
			aimed = src
			aimed_marker = marker
	if aimed != _aimed:
		_aimed = aimed
		aim_progress = 0.0
	if aimed != null:
		aimed_marker["progress"] = aim_progress
	_set_markers(markers)


func _set_markers(markers: Array) -> void:
	if _player != null and _player.hud != null:
		_player.hud.set_siphon_markers(markers)
