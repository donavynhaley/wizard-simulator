class_name LinkForge
extends RefCounted

## Resolves what effect a connection between two anchors produces, and builds the
## MagicalLink that carries it. This is the emergent heart of the system: the
## player connects fire to ground and it simply becomes warmth, with no per-object
## wiring - the forge asks each registered effect "can you claim this pair?" and
## the first yes wins.
##
## To add a new kind of link to the whole game, write a LinkEffect subclass and
## append it here. Order matters only for ambiguous pairs; list specific effects
## before general ones.

static var _effects: Array[LinkEffect] = []
static var _registered := false


static func _ensure_registered() -> void:
	if _registered:
		return
	_registered = true
	_effects = [
		HeatEffect.new(),
		IrrigateEffect.new(),
		ArcaneLockEffect.new(),
		PortalEffect.new(),
	]


## The effect a connection between these anchors would produce, or null if
## nothing answers (the two things have no relationship to forge).
static func resolve(a: LinkAnchor, b: LinkAnchor) -> LinkEffect:
	_ensure_registered()
	if a == null or b == null or a == b:
		return null
	for effect in _effects:
		if effect.can_apply(a, b):
			return effect
	return null


## Builds and parents a live MagicalLink between two anchors if any effect
## applies. Returns the new link, or null if nothing answers.
static func forge(a: LinkAnchor, b: LinkAnchor, parent: Node) -> MagicalLink:
	var effect := resolve(a, b)
	if effect == null:
		return null
	var link := MagicalLink.new()
	link.setup_runtime(a, b, effect)
	parent.add_child(link)
	return link
