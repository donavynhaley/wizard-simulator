class_name ElementSource
extends Node3D

## A world source the player can pull an element from through Sight (a flame
## for fire, water for water, ...). Registered in the "element_source" group so
## Sight can project every source to screen and pick the aimed one.
##
## One-shot sources are the sourcing rule made visible: pulling consumes the
## source, and its visual is sucked into the caster's palm to merge with the
## primed rune. While the pull dwells, the visual leans and shrinks toward the
## hand; a cancelled pull eases it back; a completed pull rips it free.
## A depleted source stays in the group as an EMPTY VESSEL - Sight renders it
## hollow, and held essence of the matching element can be poured back in
## (restore), reversing the suck. Power is never created, only moved.

## The group ("tag") every pullable source joins, so the caster finds them all.
const GROUP := &"element_source"

signal consumed
signal restored

@export var element: Element
## When true the source is spent by a single completed pull.
@export var one_shot := false
## The prop visual that leans, shrinks, and is finally sucked into the palm
## (e.g. the MagicalFlame node). Optional: without it the source still depletes.
@export var visual: Node3D
## Seconds for the final suck-into-the-hand animation.
@export var consume_time := 0.35

var _depleted := false
var _visual_base: Transform3D
var _visual_base_saved := false
var _visual_light_energy := 0.0
var _return_tween: Tween
var _consume_tween: Tween


func _ready() -> void:
	add_to_group(GROUP)


## World point the pull streams from (this node's position by default).
func siphon_point() -> Vector3:
	return global_position


## False once a one-shot source has been consumed.
func available() -> bool:
	return not _depleted


## Called every frame of an active pull: the visual leans toward the hand and
## compresses, so the player feels the element resisting before it gives.
func set_pull(progress: float, hand_position: Vector3) -> void:
	if _depleted or visual == null:
		return
	_save_visual_base()
	_kill_return_tween()
	var eased := clampf(progress, 0.0, 1.0)
	var parent := visual.get_parent_node_3d()
	var hand_local := parent.to_local(hand_position) if parent != null else _visual_base.origin
	visual.transform = _visual_base
	visual.position = _visual_base.origin.lerp(hand_local, eased * 0.18)
	visual.scale = _visual_base.basis.get_scale() * (1.0 - 0.35 * eased)


## Pull abandoned: ease the visual back to where it lives.
func release_pull() -> void:
	if _depleted or visual == null or not _visual_base_saved:
		return
	_kill_return_tween()
	_return_tween = create_tween()
	_return_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_return_tween.tween_property(visual, "transform", _visual_base, 0.25)


## Pull completed: the element rips free and is sucked into the palm. One-shot
## sources deplete immediately (Sight drops the ring) and hide once the suck
## lands; persistent sources just settle back.
func consume(hand_position: Vector3) -> void:
	if not one_shot:
		release_pull()
		return
	if _depleted:
		return
	_depleted = true
	consumed.emit()
	if visual == null:
		return
	_save_visual_base()
	_kill_return_tween()
	if "light_energy" in visual:
		_visual_light_energy = visual.light_energy
	_consume_tween = create_tween()
	_consume_tween.set_parallel(true)
	_consume_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_consume_tween.tween_property(visual, "global_position", hand_position, consume_time)
	_consume_tween.tween_property(visual, "scale", Vector3.ONE * 0.02, consume_time)
	# MagicalFlame exposes light_energy; dim it as the flame leaves its wick.
	if "light_energy" in visual:
		_consume_tween.tween_property(visual, "light_energy", 0.0, consume_time)
	_consume_tween.chain().tween_callback(func() -> void:
		if is_instance_valid(visual):
			visual.visible = false)


## Held essence poured back into the empty vessel: the suck in reverse. The
## visual reappears at the hand, flies home, and rekindles its light.
func restore(from_position: Vector3) -> void:
	if not _depleted:
		return
	_depleted = false
	restored.emit()
	if visual == null:
		return
	if _consume_tween != null and _consume_tween.is_valid():
		_consume_tween.kill()
	_consume_tween = null
	_kill_return_tween()
	visual.visible = true
	visual.global_position = from_position
	visual.scale = Vector3.ONE * 0.02
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "transform", _visual_base, consume_time)
	if "light_energy" in visual:
		tween.tween_property(visual, "light_energy", _visual_light_energy, consume_time)


func _save_visual_base() -> void:
	if not _visual_base_saved:
		_visual_base = visual.transform
		_visual_base_saved = true


func _kill_return_tween() -> void:
	if _return_tween != null and _return_tween.is_valid():
		_return_tween.kill()
	_return_tween = null
