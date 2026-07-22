class_name IrrigateEffect
extends LinkEffect

## Binds a water fount to a plant and keeps it watered while the fount flows.
## Sever the link or starve the fount and the plant goes dry. The sink target
## must expose set_watered(bool).

func can_apply(a: LinkAnchor, b: LinkAnchor) -> bool:
	var source := source_of(a, b)
	if source == null or _element_id(source) != &"water":
		return false
	var sink := sink_of(a, b)
	return sink != null and sink.kind == &"plant"


func set_active(link: MagicalLink, active: bool) -> void:
	var sink := link.sink_anchor()
	if sink == null:
		return
	var target := sink.target()
	if target != null and target.has_method(&"set_watered"):
		target.call(&"set_watered", active)


func effect_name() -> String:
	return "Irrigation"


func describe(link: MagicalLink) -> String:
	return "Water drawn to the roots; the plant stays green while the fount flows."


func _element_id(anchor: LinkAnchor) -> StringName:
	var element := anchor.provided_element()
	return element.id if element != null else &""
