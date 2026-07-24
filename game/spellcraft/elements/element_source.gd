class_name ElementSource
extends Node3D

## A world source the player can move an element from through Sight (a flame
## for fire, water for water, ...). Registered in the "element_source" group so
## Sight can project every source to screen and pick the aimed one.
##
## One-shot sources are the sourcing rule made visible: taking consumes the
## source, and its visual is sucked into the caster's left palm. A depleted
## source remains a valid Sight target.
## A depleted source stays in the group as an EMPTY VESSEL - Sight renders it
## hollow, and held essence of the matching element can be placed back in,
## reversing the movement. Power is never created, only moved.

## The group ("tag") every movable source joins, so Sight finds them all.
const GROUP := &"element_source"

signal consumed
signal restored

@export var element: Element
## When true the source is spent by a single completed grab.
@export var one_shot := false
## The prop visual that leans, shrinks, and is finally sucked into the palm
## (e.g. the MagicalFlame node). Optional: without it the source still depletes.
@export var visual: Node3D
## Seconds for the final suck-into-the-hand animation.
@export var consume_time := 0.35
## Seconds for the reverse flight when essence is poured back. Taking is a
## fight; giving back is a release, so it defaults faster than the pull.
@export var restore_time := 0.25
## The mundane vessel holding this essence (the lantern body, the torch pole).
## THE RULE: any object holding an element is untouched by the Wizard Sight
## fade - while the source is lit its container renders fully real, warmed by
## its own flame; drained, it flattens back into a cutout like any mundane
## thing. Every prop with a source should point this at its model.
@export var essence_container: Node3D
## The empty vessel's hunger: a faint rim in the element's colour on the
## flattened cutout, flaring under the aim - "essence can be placed here". Lit
## vessels never show it (they are exempt from the overlay entirely), so the
## rim always and only means empty-and-refillable.
@export var rim_burn := true

## Rim presence while the vessel stands empty: a thin, starved outline.
const EMPTY_RIM := 0.25

var _depleted := false
var _visual_base: Transform3D
var _visual_base_saved := false
var _visual_light_energy := 0.0
var _home_point := Vector3.ZERO
var _return_tween: Tween
var _consume_tween: Tween
var _light_tween: Tween
var _container_meshes: Array[MeshInstance3D] = []
var _flare := 0.0
var _flare_tween: Tween


func _ready() -> void:
	add_to_group(GROUP)
	_home_point = global_position
	# The visual IS the essence made physical (a burning flame is elemental
	# fire), so it keeps its light in the shadow-puppet world: torches burn on
	# while everything around them flattens to cutout.
	if visual != null:
		visual.add_to_group(&"sight_no_fade")
	if essence_container != null and element != null:
		_collect_container_meshes(essence_container)
		if rim_burn:
			_set_essence(&"essence_tint", element.color)
		_apply_essence_presence()
		_apply_container_exemption()
	_ensure_link_anchor()


## Every source is a fount a Bind thread can tether to. Provide a LinkAnchor so
## tethering works project-wide without per-prop wiring; a prop that authors its
## own anchor child (for a custom attach point or label) opts out.
func _ensure_link_anchor() -> void:
	if element == null:
		return
	for child in get_children():
		if child is LinkAnchor:
			return
	var anchor := LinkAnchor.new()
	anchor.name = &"LinkAnchor"
	anchor.display_name = "vessel"
	anchor.source_path = NodePath("..")  # the anchor's parent is this source
	add_child(anchor)


## The wizard's aim rests on this source: the vessel's coloured rim flares
## (called by SightController as the aimed Sight target changes).
func set_sight_aimed(aimed: bool) -> void:
	if _container_meshes.is_empty():
		return
	if _flare_tween != null and _flare_tween.is_valid():
		_flare_tween.kill()
	_flare_tween = create_tween()
	_flare_tween.tween_method(_set_flare, _flare, 1.0 if aimed else 0.0, 0.15)


func _set_flare(value: float) -> void:
	_flare = value
	_set_essence(&"essence_flare", value)


## The rim's element presence: full and breathing while the vessel holds its
## essence, a thin starved outline once it stands empty.
func _apply_essence_presence() -> void:
	if rim_burn:
		_set_essence(&"essence_amount", EMPTY_RIM if _depleted else 1.0)


## A lit vessel is real in the other world: while this source holds its essence
## the container skips the shadow fade and glows by its own flame; drained, it
## rejoins the theater as a cutout. Refresh keeps this honest mid-squint (the
## wizard feeds and siphons vessels through Sight).
func _apply_container_exemption() -> void:
	if essence_container == null:
		return
	if _depleted:
		essence_container.remove_from_group(&"sight_no_fade")
	else:
		essence_container.add_to_group(&"sight_no_fade")
	SightFade.refresh(essence_container)


func _set_essence(param: StringName, value: Variant) -> void:
	for mesh in _container_meshes:
		if is_instance_valid(mesh):
			mesh.set_instance_shader_parameter(param, value)


func _collect_container_meshes(node: Node) -> void:
	var mesh := node as MeshInstance3D
	if mesh != null:
		_container_meshes.append(mesh)
	for child in node.get_children():
		_collect_container_meshes(child)


## World point the pull streams from. A live source reports its actual position
## (so the stream follows the leaning visual); a depleted one reports its HOME,
## because sources parented under their visual ride along with the suck
## animation and the empty-vessel ring must stay at the brazier, not the hand.
func siphon_point() -> Vector3:
	return _home_point if _depleted else global_position


## False once a one-shot source has been consumed.
func available() -> bool:
	return not _depleted


## Authors a vessel that begins empty (Case Minus One's dark lantern): no
## animation, no signal fanfare beyond consumed - the world starts this way.
func deplete_silently() -> void:
	if _depleted or not one_shot:
		return
	if visual != null:
		_save_visual_base()
		if "light_energy" in visual:
			visual.light_energy = 0.0
		visual.visible = false
	else:
		_home_point = global_position
	_depleted = true
	_apply_essence_presence()
	_apply_container_exemption()
	consumed.emit()


## Optional anticipation hook for interactions that animate a source toward the
## hand before a grab completes.
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


## Movement abandoned: ease the visual back to where it lives.
func release_pull() -> void:
	if _depleted or visual == null or not _visual_base_saved:
		return
	_kill_return_tween()
	_return_tween = create_tween()
	_return_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_return_tween.tween_property(visual, "transform", _visual_base, 0.25)


## Grab completed: the element rips free and is sucked into the left palm.
## One-shot sources deplete immediately and hide once the movement lands.
## Persistent sources simply settle back.
func consume(hand_position: Vector3) -> void:
	if not one_shot:
		release_pull()
		return
	if _depleted:
		return
	if visual == null:
		# Nothing moves this source, so its current position is its home.
		_home_point = global_position
	_depleted = true
	_apply_essence_presence()
	_apply_container_exemption()
	consumed.emit()
	if visual == null:
		return
	_save_visual_base()
	_kill_return_tween()
	_consume_tween = create_tween()
	_consume_tween.set_parallel(true)
	_consume_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_consume_tween.tween_property(visual, "global_position", hand_position, consume_time)
	_consume_tween.tween_property(visual, "scale", Vector3.ONE * 0.02, consume_time)
	# MagicalFlame exposes light_energy; flare once at the instant of the rip,
	# then dim as the flame leaves its wick.
	if "light_energy" in visual:
		_kill_light_tween()
		_light_tween = create_tween()
		_light_tween.tween_property(
			visual, "light_energy", _visual_light_energy * 1.6, 0.07)
		_light_tween.tween_property(
			visual, "light_energy", 0.0, maxf(consume_time - 0.07, 0.05))
	_consume_tween.chain().tween_callback(func() -> void:
		if is_instance_valid(visual):
			visual.visible = false)


## Held essence placed back into the empty vessel: the movement in reverse.
## The visual reappears at the hand, flies home, and rekindles its light.
func restore(from_position: Vector3) -> void:
	if not _depleted:
		return
	_depleted = false
	_apply_essence_presence()
	_apply_container_exemption()
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
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "transform", _visual_base, restore_time)
	# Rekindling over-blooms briefly before settling - the vessel drinks deep.
	if "light_energy" in visual:
		_kill_light_tween()
		_light_tween = create_tween()
		_light_tween.tween_property(
			visual, "light_energy", _visual_light_energy * 1.5, restore_time)
		_light_tween.tween_property(visual, "light_energy", _visual_light_energy, 0.15)


func _save_visual_base() -> void:
	if not _visual_base_saved:
		_visual_base = visual.transform
		_visual_base_saved = true
		# The visual is untouched at this moment, so this is the true home -
		# _ready runs before spawners position the node, making it too early.
		_home_point = global_position
		# Same for the light: capture once, before any flare/dim tween runs.
		# Recapturing mid-restore read the 1.5x over-bloom as the new base and
		# ratcheted the lamp brighter on every fast siphon/feed cycle.
		if "light_energy" in visual:
			_visual_light_energy = visual.light_energy


func _kill_return_tween() -> void:
	if _return_tween != null and _return_tween.is_valid():
		_return_tween.kill()
	_return_tween = null


func _kill_light_tween() -> void:
	if _light_tween != null and _light_tween.is_valid():
		_light_tween.kill()
	_light_tween = null
