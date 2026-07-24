class_name LinkEffect
extends Resource

## The pluggable behaviour a magical link produces. This is the extensibility
## seam of the whole link system: to teach the world a new kind of connection,
## write a LinkEffect subclass and register it in LinkForge. Nothing else changes.
##
## The LinkForge asks every registered effect can_apply() for a proposed pair of
## anchors; the first to answer yes forms the link. Thereafter the link calls
## set_active() whenever its power state flips (the fount fed or siphoned), and
## on_removed() when the link is severed - so an effect both applies and cleanly
## reverses itself.
##
## Effects are order-independent: they inspect BOTH anchors and decide, so the
## player can carry a thread from either end.


## Can this effect bind these two anchors? Match on the TYPE of each anchor's
## target (`sink.target() is HeatSink`) and, for founts, on the element identity
## (`FIRE.matches(source.provided_element())`) - never on string tags. Return
## false to let another effect claim the pair.
func can_apply(_a: LinkAnchor, _b: LinkAnchor) -> bool:
	return false


## The link's power crossed a threshold (fed or starved), or it just formed.
## Apply or reverse the world change. Called with the link's current power.
func set_active(_link: MagicalLink, _active: bool) -> void:
	pass


## The link was severed or freed - undo any lingering world change so the effect
## leaves nothing behind.
func on_removed(link: MagicalLink) -> void:
	set_active(link, false)


## Short label for the reading inscription and journal ("Arcane Lock", "Warmth").
func effect_name() -> String:
	return "Link"


## The line inscribed in the world when the link is read. Defaults to a generic
## sentence built from the anchors; override for authored flavour.
func describe(link: MagicalLink) -> String:
	var source := link.source_anchor()
	var sink := link.sink_anchor()
	if source == null or sink == null:
		return "%s binds two things together." % effect_name()
	return "%s: %s draws from %s." % [effect_name(), sink.label(), source.label()]


## Which of the two anchors is the fount (the element provider), if either.
## Effects that need a directed source/sink use this; symmetric effects ignore it.
func source_of(a: LinkAnchor, b: LinkAnchor) -> LinkAnchor:
	if a != null and a.provides_element():
		return a
	if b != null and b.provides_element():
		return b
	return null


func sink_of(a: LinkAnchor, b: LinkAnchor) -> LinkAnchor:
	var source := source_of(a, b)
	if source == null:
		return null
	return b if source == a else a
