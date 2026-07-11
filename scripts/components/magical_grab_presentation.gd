class_name MagicalGrabPresentation
extends Node3D

## Scene-authored held-item levitation and spell-manipulation presentation.
## WizardHands only binds and releases items. This component owns the bobbing
## animation and applies its authored aura material to arbitrary item meshes.

const PICKUP_ANIMATION := &"pickup"
const HOLD_ANIMATION := &"holding"
const RELEASE_ANIMATION := &"release"
const RESET_ANIMATION := &"RESET"

@export_node_path("Marker3D") var item_anchor_path: NodePath = ^"ItemFloatAnchor"
@export_node_path("MeshInstance3D") var magic_stream_path: NodePath = ^"MagicStream"
@export_node_path("AnimationPlayer") var animation_player_path: NodePath = ^"AnimationPlayer"
@export var item_aura_material: ShaderMaterial
@export_range(0.0, 1.0, 0.01) var aura_strength := 0.0:
	set(value):
		aura_strength = clampf(value, 0.0, 1.0)
		_update_aura_strength()
@export_range(0.0, 1.0, 0.01) var stream_strength := 0.0:
	set(value):
		stream_strength = clampf(value, 0.0, 1.0)
		_update_stream_strength()

var active := false
var _item_anchor: Marker3D
var _magic_stream: MeshInstance3D
var _stream_material: ShaderMaterial
var _animation_player: AnimationPlayer
var _held_item: Node3D
var _original_overlays: Dictionary = {}
var _aura_materials: Array[ShaderMaterial] = []


func _ready() -> void:
	_item_anchor = get_node_or_null(item_anchor_path) as Marker3D
	_magic_stream = get_node_or_null(magic_stream_path) as MeshInstance3D
	if _magic_stream != null:
		_stream_material = _magic_stream.material_override as ShaderMaterial
	_animation_player = get_node_or_null(animation_player_path) as AnimationPlayer
	if _animation_player != null:
		_animation_player.animation_finished.connect(_on_animation_finished)
		_animation_player.play(RESET_ANIMATION)
		_animation_player.advance(0.0)
		_animation_player.stop()


func get_item_anchor() -> Node3D:
	return _item_anchor if _item_anchor != null else self


func show_grab(item: Node3D) -> void:
	if item == null:
		return
	if active and _held_item == item:
		return
	_clear_item_aura()
	active = true
	_held_item = item
	_apply_item_aura(item)
	if _animation_player == null:
		aura_strength = 1.0
		stream_strength = 1.0
		return
	_animation_player.play(PICKUP_ANIMATION, 0.06)
	_animation_player.queue(HOLD_ANIMATION)


func hide_grab() -> void:
	if not active and _held_item == null:
		return
	active = false
	if _animation_player == null:
		aura_strength = 0.0
		stream_strength = 0.0
		_clear_item_aura()
		return
	_animation_player.play(RELEASE_ANIMATION, 0.04)


func has_item_aura() -> bool:
	return not _aura_materials.is_empty()


func has_magic_stream() -> bool:
	return _stream_material != null and stream_strength > 0.05


func _apply_item_aura(node: Node) -> void:
	if node is MeshInstance3D and item_aura_material != null:
		var mesh_instance := node as MeshInstance3D
		_original_overlays[mesh_instance] = mesh_instance.material_overlay
		var aura := item_aura_material.duplicate() as ShaderMaterial
		aura.set_shader_parameter(&"effect_strength", aura_strength)
		mesh_instance.material_overlay = aura
		_aura_materials.append(aura)
	for child in node.get_children():
		_apply_item_aura(child)


func _clear_item_aura() -> void:
	for mesh: Variant in _original_overlays.keys():
		if is_instance_valid(mesh):
			(mesh as MeshInstance3D).material_overlay = _original_overlays[mesh] as Material
	_original_overlays.clear()
	_aura_materials.clear()
	_held_item = null


func _update_aura_strength() -> void:
	for material in _aura_materials:
		material.set_shader_parameter(&"effect_strength", aura_strength)


func _update_stream_strength() -> void:
	if _stream_material != null:
		_stream_material.set_shader_parameter(&"effect_strength", stream_strength)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == RELEASE_ANIMATION and not active:
		_clear_item_aura()
