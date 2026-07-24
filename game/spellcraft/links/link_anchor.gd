class_name LinkAnchor
extends Node3D

## Marks a world object as something a magical link can attach to. A link binds
## two anchors; the LinkForge inspects each anchor's TARGET TYPE and provided
## element to decide what effect the connection produces, and effects act on
## target().
##
## An anchor that carries an ElementSource is a fount: its element flows through
## any link and its availability is that link's power. An anchor with no source
## is a pure sink (a Door, a HeatSink, a PlantSink) that receives an effect.
##
## Deliberately NO `kind` tag: what a thing IS is its class, and effects match
## with `target() is Door`. A parallel string tag can contradict the object it
## labels and a typo fails silently; a misspelled class name fails to compile.
## Make something linkable by giving it the component that implements the
## behaviour - the component is both the mark and the implementation.

const GROUP := &"link_anchor"

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


## Human label for inscriptions. Falls back to the target's class name ("Door" ->
## "door", "HeatSink" -> "heat sink") so an unlabelled anchor still reads.
func label() -> String:
	if not display_name.is_empty():
		return display_name
	var node := target()
	if node == null:
		return "something"
	var script := node.get_script() as Script
	if script != null and script.get_global_name() != &"":
		return String(script.get_global_name()).capitalize().to_lower()
	return node.name
