class_name HeatEffect
extends LinkEffect

## Binds a fire fount to a patch of ground and keeps it hot while the fount
## burns. Sever the link or starve the fount and the ground cools. The sink
## target must expose set_hot(bool).

func can_apply(a: LinkAnchor, b: LinkAnchor) -> bool:
	var source := source_of(a, b)
	if source == null or _element_id(source) != &"fire":
		return false
	var sink := sink_of(a, b)
	return sink != null and sink.kind == &"ground"


func set_active(link: MagicalLink, active: bool) -> void:
	var sink := link.sink_anchor()
	if sink == null:
		return
	var target := sink.target()
	if target != null and target.has_method(&"set_hot"):
		target.call(&"set_hot", active)


func effect_name() -> String:
	return "Warmth"


func describe(link: MagicalLink) -> String:
	return "Warmth drawn from fire; the ground stays hot while the fount burns."


func _element_id(anchor: LinkAnchor) -> StringName:
	var element := anchor.provided_element()
	return element.id if element != null else &""
