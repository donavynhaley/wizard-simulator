class_name PortalEffect
extends LinkEffect

## Binds one door to another so that stepping through either arrives at the far
## one. Two doors on opposite sides of the valley become one threshold.
##
## Symmetric and fountless: no element powers it, so the link is live for as long
## as it exists, and either end can be the one you carried the thread from.
## Matching is by type - two distinct Doors - so every door in the world is
## portal-ready with no per-door wiring.
##
## The mouths that do the carrying are PortalGate children of the link itself,
## which is what makes severing clean: the link frees its own children. This
## effect instance is SHARED across every portal in the game (LinkForge holds one
## of each), so it must hold no per-link state - the gates are found by name.

const GATE_A := &"GateA"
const GATE_B := &"GateB"


func can_apply(a: LinkAnchor, b: LinkAnchor) -> bool:
	if a == null or b == null:
		return false
	var door_a := _door_of(a)
	var door_b := _door_of(b)
	return door_a != null and door_b != null and door_a != door_b


func set_active(link: MagicalLink, active: bool) -> void:
	if active:
		_open_gates(link)
	else:
		_close_gates(link)


func effect_name() -> String:
	return "Portal"


func describe(link: MagicalLink) -> String:
	var a := link.anchor_a()
	var b := link.anchor_b()
	if a == null or b == null:
		return "A portal, waiting on a second door to answer it."
	return "A portal binds %s to %s; step through one and arrive at the other." \
		% [a.label(), b.label()]


func _open_gates(link: MagicalLink) -> void:
	var door_a := _door_of(link.anchor_a())
	var door_b := _door_of(link.anchor_b())
	if door_a == null or door_b == null:
		return
	var gate_a := _ensure_gate(link, GATE_A, door_a)
	var gate_b := _ensure_gate(link, GATE_B, door_b)
	gate_a.far_gate = gate_b
	gate_b.far_gate = gate_a


func _close_gates(link: MagicalLink) -> void:
	for gate_name in [GATE_A, GATE_B]:
		var gate := link.get_node_or_null(NodePath(String(gate_name)))
		if gate != null:
			gate.queue_free()


func _ensure_gate(link: MagicalLink, gate_name: StringName, near_door: Door) -> PortalGate:
	var existing := link.get_node_or_null(NodePath(String(gate_name))) as PortalGate
	if existing != null:
		return existing
	var gate := PortalGate.new()
	gate.name = gate_name
	# Set before entering the tree: the gate snaps to its frame on ready.
	gate.door = near_door
	link.add_child(gate)
	return gate


func _door_of(anchor: LinkAnchor) -> Door:
	return anchor.target() as Door if anchor != null else null
