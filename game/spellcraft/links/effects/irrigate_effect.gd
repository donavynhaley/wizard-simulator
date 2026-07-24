class_name IrrigateEffect
extends LinkEffect

## Binds a water fount to a PlantSink and keeps it watered while the fount flows.
## Sever the link or starve the fount and the plant goes dry.
##
## Matching is by type, not by tag: anything carrying a PlantSink component can
## be watered, and the component is what implements set_watered().

const WATER := preload("res://game/spellcraft/elements/water.tres")


func can_apply(a: LinkAnchor, b: LinkAnchor) -> bool:
	var source := source_of(a, b)
	if source == null or not WATER.matches(source.provided_element()):
		return false
	var sink := sink_of(a, b)
	return sink != null and sink.target() is PlantSink


func set_active(link: MagicalLink, active: bool) -> void:
	var plant := _get_sink(link)
	if plant != null:
		plant.set_watered(active)


func effect_name() -> String:
	return "Irrigation"


func describe(_link: MagicalLink) -> String:
	return "Water drawn to the roots; the plant stays green while the fount flows."


func _get_sink(link: MagicalLink) -> PlantSink:
	var sink := link.sink_anchor()
	if sink == null:
		return null
	return sink.target() as PlantSink
