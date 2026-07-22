class_name ArcaneLockEffect
extends LinkEffect

## Binds a light-bearing fount to a door: the classic Arcane Lock. While the
## fount holds its element the door yields; starve it and the lock takes hold.
## Set invert to flip that - a door that a lit vessel LOCKS instead of frees.
##
## This is what the tower's entrance is: an empty lantern bound to the door,
## so the door stays arcane-locked until fire is placed in the vessel.

## When true, a powered fount LOCKS the door and starving it opens the way.
@export var invert := false


func can_apply(a: LinkAnchor, b: LinkAnchor) -> bool:
	var source := source_of(a, b)
	if source == null:
		return false
	var sink := sink_of(a, b)
	return sink != null and sink.kind == &"door"


func set_active(link: MagicalLink, active: bool) -> void:
	var door := _door(link)
	if door == null or not door.has_method(&"set_locked"):
		return
	var powered_opens := not invert
	door.call(&"set_locked", active != powered_opens)


func effect_name() -> String:
	return "Arcane Lock"


func describe(link: MagicalLink) -> String:
	var source := link.source_anchor()
	if source == null:
		return "An arcane lock, waiting on a fount to answer it."
	return "An arcane lock bound to %s; feed the vessel and the door yields." \
		% source.label()


func _door(link: MagicalLink) -> Node:
	var sink := link.sink_anchor()
	return sink.target() if sink != null else null
