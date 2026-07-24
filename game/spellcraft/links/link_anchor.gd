class_name LinkAnchor
extends Node3D

## Marks a world object as something a magical link can attach to. A link binds
## two anchors; the LinkForge inspects each anchor's kind and provided element to
## decide what effect the connection produces, and effects act on target().
##
## An anchor that carries an ElementSource is a fount: its element flows through
## any link and its availability is that link's power. An anchor with no source
## is a pure sink (a door, a patch of ground, a plant) that receives an effect.

const GROUP := &"link_anchor"

## What this object is, for effect matching: &"door", &"ground", &"plant",
## &"vessel", &"fount"... Extensible - effects match on these tags.
@export var kind: StringName = &""
## Optional ElementSource that powers links from this anchor (a lit vessel, a
## spring). Its element is what flows; its availability is the link's power.
@export var source_path: NodePath
## The node effects manipulate (a door, a ground patch, a plant). Defaults to
## the anchor's parent.
@export var target_path: NodePath
## Local offset of the strand attach point from this node.
@export var attach_offset := Vector3.ZERO
## Radius of the Sight knotwork - the luminous loops a link laces around the
## anchored object (a bound thing looks tied; Bind is a knot).
@export var knot_radius := 0.22
## Local axis the knot loops wrap around.
@export var knot_axis := Vector3.UP
## Human label for prompts and inscriptions ("the lantern", "the north door").
@export var display_name: String = ""

var _source: ElementSource


func _ready() -> void:
	add_to_group(GROUP)
	_source = get_node_or_null(source_path) as ElementSource


func source() -> ElementSource:
	return _source


## The element this anchor provides into a link, or null (a pure sink).
func provided_element() -> Element:
	return _source.element if _source != null else null


func provides_element() -> bool:
	return _source != null and _source.element != null


## Stable strand attach point - the fount's home when its element is siphoned
## away, so the strand stays on the vessel instead of riding the departing flame.
func anchor_point() -> Vector3:
	if _source != null:
		return _source.siphon_point() + attach_offset
	return to_global(attach_offset)


func target() -> Node:
	if not target_path.is_empty():
		return get_node_or_null(target_path)
	return get_parent()


func label() -> String:
	return display_name if not display_name.is_empty() else String(kind)
