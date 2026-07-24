class_name ArcaneLockEffect
extends LinkEffect

@export var invert := false


func can_apply(a: LinkAnchor, b: LinkAnchor) -> bool:
	var source := source_of(a, b)
	if source == null:
		return false
	var sink := sink_of(a, b)
	return sink != null and sink.target() is Door


func set_active(link: MagicalLink, active: bool) -> void:
	var door := _get_door(link)
	if door == null:
		return
	var powered_opens := not invert
	door.set_locked(active != powered_opens)

func on_removed(link: MagicalLink) -> void:
	var door := _get_door(link)
	if door != null:
		door.set_locked(false)

func effect_name() -> String:
	return "Arcane Lock"


func describe(link: MagicalLink) -> String:
	var source := link.source_anchor()
	if source == null:
		return "An arcane lock, waiting on a fount to answer it."
	return "An arcane lock bound to %s; feed the vessel and the door yields." \
		% source.label()


func _get_door(link: MagicalLink) -> Door:
	var sink := link.sink_anchor()
	if sink == null:
		return null
	return sink.target() as Door
