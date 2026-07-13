class_name BookVisual
extends Node3D

signal page_turn_midpoint_reached
signal page_turn_finished

const PAGE_TURN_ANIMATION := &"turn_page"

@export_group("Visual Nodes")
@export_node_path("Node3D") var visual_root_path: NodePath = ^"VisualRoot"
@export_node_path("Node3D") var closed_visual_path: NodePath = ^"VisualRoot/ClosedVisual"
@export_node_path("Node3D") var open_visual_path: NodePath = ^"VisualRoot/OpenVisual"
@export_node_path("Sprite3D") var page_surface_path: NodePath = ^"VisualRoot/OpenVisual/PageSurface"
@export_node_path("Node3D") var page_turn_pivot_path: NodePath = ^"VisualRoot/OpenVisual/PageTurnPivot"
@export_node_path("Sprite3D") var page_turn_front_path: NodePath = ^"VisualRoot/OpenVisual/PageTurnPivot/Front"
@export_node_path("Sprite3D") var page_turn_back_path: NodePath = ^"VisualRoot/OpenVisual/PageTurnPivot/Back"
@export_node_path("AnimationPlayer") var animation_player_path: NodePath = ^"AnimationPlayer"

@export_group("Editor Authored Poses")
@export_node_path("Marker3D") var world_pose_path: NodePath = ^"WorldPose"
@export_node_path("Marker3D") var held_pose_path: NodePath = ^"HeldPose"
@export_node_path("Marker3D") var reading_pose_path: NodePath = ^"ReadingPose"
@export_node_path("Marker3D") var table_pose_path: NodePath = ^"TablePose"
@export_range(0.05, 1.0, 0.01) var pose_transition_seconds := 0.24

var _visual_root: Node3D
var _closed_visual: Node3D
var _open_visual: Node3D
var _page_surface: Sprite3D
var _page_turn_pivot: Node3D
var _page_turn_front: Sprite3D
var _page_turn_back: Sprite3D
var _animation_player: AnimationPlayer
var _world_pose: Marker3D
var _held_pose: Marker3D
var _reading_pose: Marker3D
var _table_pose: Marker3D
var _pose_tween: Tween
var _opening_held := false


func _ready() -> void:
	_visual_root = get_node_or_null(visual_root_path) as Node3D
	_closed_visual = get_node_or_null(closed_visual_path) as Node3D
	_open_visual = get_node_or_null(open_visual_path) as Node3D
	_page_surface = get_node_or_null(page_surface_path) as Sprite3D
	_page_turn_pivot = get_node_or_null(page_turn_pivot_path) as Node3D
	_page_turn_front = get_node_or_null(page_turn_front_path) as Sprite3D
	_page_turn_back = get_node_or_null(page_turn_back_path) as Sprite3D
	_animation_player = get_node_or_null(animation_player_path) as AnimationPlayer
	_world_pose = get_node_or_null(world_pose_path) as Marker3D
	_held_pose = get_node_or_null(held_pose_path) as Marker3D
	_reading_pose = get_node_or_null(reading_pose_path) as Marker3D
	_table_pose = get_node_or_null(table_pose_path) as Marker3D
	if _animation_player != null:
		_animation_player.animation_finished.connect(_on_animation_finished)
	show_world_closed()


func set_page_texture(texture: Texture2D) -> void:
	if _page_surface != null:
		_page_surface.texture = texture
	if _page_turn_front != null:
		_page_turn_front.texture = texture
	if _page_turn_back != null:
		_page_turn_back.texture = texture


func show_world_closed() -> void:
	_opening_held = false
	_kill_pose_tween()
	_apply_pose(_world_pose)
	_set_open(false)
	_hide_page_turn()


func show_held_closed() -> void:
	_opening_held = false
	_kill_pose_tween()
	_apply_pose(_held_pose)
	_set_open(false)
	_hide_page_turn()


func open_held() -> void:
	_opening_held = true
	_set_open(true)
	_tween_to_pose(_reading_pose)


func close_held() -> void:
	_opening_held = false
	_tween_to_pose(_held_pose, true)


func show_table_open() -> void:
	_opening_held = false
	_kill_pose_tween()
	_apply_pose(_table_pose)
	_set_open(true)
	_hide_page_turn()


func play_page_turn(direction: int) -> bool:
	if _animation_player == null or not _animation_player.has_animation(PAGE_TURN_ANIMATION):
		return false
	if _page_turn_pivot == null:
		return false
	_page_turn_pivot.visible = true
	if direction >= 0:
		_animation_player.play(PAGE_TURN_ANIMATION)
	else:
		_animation_player.play_backwards(PAGE_TURN_ANIMATION)
	return true


func _emit_page_turn_midpoint() -> void:
	page_turn_midpoint_reached.emit()


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name != PAGE_TURN_ANIMATION:
		return
	_hide_page_turn()
	page_turn_finished.emit()


func _set_open(open: bool) -> void:
	if _closed_visual != null:
		_closed_visual.visible = not open
	if _open_visual != null:
		_open_visual.visible = open


func _apply_pose(marker: Marker3D) -> void:
	if _visual_root == null or marker == null:
		return
	_visual_root.transform = marker.transform


func _tween_to_pose(marker: Marker3D, close_when_finished: bool = false) -> void:
	if _visual_root == null or marker == null:
		if close_when_finished:
			_set_open(false)
		return
	_kill_pose_tween()
	_pose_tween = create_tween()
	_pose_tween.set_parallel(true)
	_pose_tween.tween_property(_visual_root, "position", marker.position, pose_transition_seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(_visual_root, "quaternion", marker.quaternion, pose_transition_seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(_visual_root, "scale", marker.scale, pose_transition_seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if close_when_finished:
		_pose_tween.chain().tween_callback(_finish_closing_held)


func _finish_closing_held() -> void:
	if not _opening_held:
		_set_open(false)


func _kill_pose_tween() -> void:
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	_pose_tween = null


func _hide_page_turn() -> void:
	if _page_turn_pivot != null:
		_page_turn_pivot.visible = false
