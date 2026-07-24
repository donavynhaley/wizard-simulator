extends SceneTree

## End-to-end coverage for the door-to-door portal: binding the cottage door to
## the tower door makes one threshold of the two. Stepping into an open bound
## door delivers you outside the far door, facing away from it, standing on the
## ground; the trip works both ways; a closed door carries nobody; and severing
## the link takes the portal with it.

var _fail := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := (load(
		"res://game/world/levels/wizard_tower.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(level)
	current_scene = level
	await process_frame
	for _frame in 10:
		await physics_frame

	var player := level.get_node(^"Player") as WizardPlayer
	var arch := level.get_node(^"TowerArchitecture") as TowerArchitecture
	var house := level.get_node(^"VillagerHouse") as VillagerHouse
	var tower_door := arch.entry_door
	var cottage_door := house.entry_door
	var tower_anchor := _anchor_of(tower_door)
	var cottage_anchor := _anchor_of(cottage_door)
	player.look_enabled = false

	_check(tower_anchor != null and cottage_anchor != null,
		"both doors carry auto-provided anchors")

	# The forge alone decides that door + door is a portal - no rune, no wiring.
	var resolved := LinkForge.resolve(cottage_anchor, tower_anchor)
	_check(resolved is PortalEffect, "door + door resolves to a Portal effect")
	_check(LinkForge.resolve(cottage_anchor, cottage_anchor) == null,
		"a door cannot be bound to itself")

	# Cast it the way a player does: hold Bind, grab a thread off one door, carry
	# it to the other, press again. No portal-specific input code exists - the
	# existing Bind gesture forges it because the forge now answers door + door.
	var camera := player.get_node(^"Head/Camera3D") as Camera3D
	var casting := player.casting
	var sight := player.sight
	casting.locked_rune_id = &"bind"
	casting.locked_rune_score = 1.0
	casting._set_state(CastingController.CASTING_STATE.SPELL_HELD)
	Input.action_press(&"sight")
	await process_frame
	await process_frame
	_check(sight.active, "Sight activates while a Bind waits in hand")

	# Stand off the cottage door and take hold of its thread.
	_stand_off(player, cottage_door.get_parent() as Node3D, 3.2)
	_aim_player_at(player, camera, cottage_anchor.anchor_point())
	await process_frame
	await process_frame
	_check(sight.aimed_anchor() == cottage_anchor, "Bind aims at the cottage door")
	await _press_cast()
	_check(sight.is_carrying_thread(), "the first press grabs a thread from the door")

	# Carry it to the tower door and attach.
	_stand_off(player, tower_door.get_parent() as Node3D, 3.6)
	_aim_player_at(player, camera, tower_anchor.anchor_point())
	await process_frame
	await process_frame
	_check(sight.aimed_anchor() == tower_anchor, "Bind aims at the tower door")
	await _press_cast()
	await process_frame
	await process_frame
	Input.action_release(&"sight")

	var link := _first_link()
	_check(link != null, "the Bind gesture forges a portal between the two doors")
	if link == null:
		quit(1)
		return
	_check(link.effect is PortalEffect, "the forged link carries the Portal effect")
	_check(not sight.is_carrying_thread(), "forging ends the carry")
	await process_frame
	await process_frame

	var cottage_gate := link.get_node_or_null(^"GateA") as PortalGate
	var tower_gate := link.get_node_or_null(^"GateB") as PortalGate
	_check(cottage_gate != null and tower_gate != null, "the portal opens two gates")
	_check(cottage_gate != null and cottage_gate.far_gate == tower_gate,
		"each gate knows the far mouth")

	# Each gate sits in its own doorway, not on the swinging slab.
	var cottage_frame := cottage_door.get_parent() as Node3D
	_check(cottage_gate != null
		and cottage_gate.global_position.distance_to(cottage_frame.global_position) < 0.05,
		"the gate rides the door frame")

	var tower_frame := tower_door.get_parent() as Node3D

	# A closed door is a closed portal.
	_walk_into_doorway(player, cottage_gate, 1.0)
	for _frame in 6:
		await physics_frame
	_check(player.global_position.distance_to(_doorway_point(cottage_gate)) < 3.0,
		"a closed door carries nobody through")

	# Open the cottage door and walk in: the far ROOM receives us, not the far
	# doorstep. Two bound doorways are one doorway.
	cottage_door.interact(player, cottage_door)
	await create_timer(1.4).timeout
	_check(cottage_door.is_open(), "the cottage door opens")
	_walk_into_doorway(player, cottage_gate, 1.0)
	for _frame in 8:
		await physics_frame
	_check(_side_of(tower_frame, player.global_position) > 0.0,
		"walking into the cottage door puts you inside the tower, not on its step")
	_check(_doorway_distance(tower_frame, player.global_position) < 2.5,
		"the arrival is just through the tower doorway")
	_check(player.global_position.distance_to(_doorway_point(cottage_gate)) > 3.0,
		"the arrival is genuinely across the world, not a nudge")
	_check(_has_roof_overhead(level, player.global_position),
		"the traveller ends up under the tower's roof - properly indoors")

	# Heading survives the threshold: you walked in, so you are still walking in.
	var arrival_forward := -player.global_transform.basis.z
	var tower_inward := tower_frame.global_transform.basis * PortalGate.INWARD
	_check(arrival_forward.normalized().dot(
		Vector3(tower_inward.x, 0.0, tower_inward.z).normalized()) > 0.85,
		"the traveller keeps their heading through the threshold")

	# Standing, not falling or buried: land, then confirm we kept our footing.
	for _frame in 30:
		await physics_frame
	_check(player.is_on_floor(), "the traveller lands on solid ground")

	# Back the other way. The tower door is arcane-locked, so feed the ward the
	# honest way - fire in the lantern - and it swings itself open.
	var lantern := level.get_node(
		^"TowerArchitecture/GroundFloorProps/DoorLantern/MagicalFlame/FireSource") as ElementSource
	lantern.restore(lantern.global_position + Vector3.UP * 0.5)
	await create_timer(1.4).timeout
	_check(tower_door.is_open(), "feeding the ward opens the tower door")
	# Leaving the tower through its own door puts us OUTSIDE the cottage - the
	# crossing is reversible, and direction is what decides which side you land.
	_walk_into_doorway(player, tower_gate, -1.0)
	for _frame in 8:
		await physics_frame
	_check(_side_of(cottage_frame, player.global_position) < 0.0,
		"walking out of the tower door puts you outside the cottage")
	_check(_doorway_distance(cottage_frame, player.global_position) < 2.5,
		"the return arrives just outside the cottage doorway")

	# One doorway, one leaf: with the ward fed, neither door moves alone.
	_check(cottage_door.is_open(),
		"the ward breaking open the tower door opens the bound cottage door too")
	cottage_door.interact(player, cottage_door)
	await create_timer(1.4).timeout
	_check(not cottage_door.is_open() and not tower_door.is_open(),
		"closing one bound door closes the other")
	tower_door.interact(player, tower_door)
	await create_timer(1.4).timeout
	_check(tower_door.is_open() and cottage_door.is_open(),
		"opening one bound door opens the other")

	# Binding brings a mismatched pair into agreement. Sever, part them, re-forge.
	link.sever()
	await process_frame
	cottage_door.interact(player, cottage_door)
	await create_timer(1.4).timeout
	_check(not cottage_door.is_open() and tower_door.is_open(),
		"a severed pair moves independently again")
	var rebound := LinkForge.forge(cottage_anchor, tower_anchor, level)
	await process_frame
	await process_frame
	_check(rebound != null and cottage_door.is_open(),
		"binding a shut door to an open one swings it open to match")
	link = rebound
	cottage_gate = link.get_node_or_null(^"GateA") as PortalGate
	tower_gate = link.get_node_or_null(^"GateB") as PortalGate

	# Severing takes the portal with it - the doors are only doors again.
	link.sever()
	await process_frame
	await process_frame
	_check(not is_instance_valid(cottage_gate) or cottage_gate.is_queued_for_deletion(),
		"severing frees the cottage gate")
	_check(not is_instance_valid(tower_gate) or tower_gate.is_queued_for_deletion(),
		"severing frees the tower gate")
	var parked := _doorway_point_from_door(cottage_door)
	player.global_position = parked
	player.velocity = Vector3.ZERO
	for _frame in 10:
		await physics_frame
	_check(player.global_position.distance_to(parked) < 2.0,
		"a severed portal carries nobody")

	level.queue_free()
	await process_frame
	if _fail == 0:
		print("PORTAL LINK TEST OK")
	quit(_fail)


func _first_link() -> MagicalLink:
	for node in root.get_tree().get_nodes_in_group(MagicalLink.GROUP):
		var link := node as MagicalLink
		if link != null and not link.is_queued_for_deletion() and link.effect is PortalEffect:
			return link
	return null


## Stand outside a door at arm's length, facing it, feet near the ground.
func _stand_off(player: WizardPlayer, frame: Node3D, distance: float) -> void:
	var out := frame.global_transform.basis * PortalGate.OUTWARD
	out.y = 0.0
	out = out.normalized()
	var point := frame.to_global(PortalGate.DOORWAY_OFFSET) + out * distance
	player.global_position = Vector3(point.x, point.y - 0.2, point.z)
	player.velocity = Vector3.ZERO


func _aim_player_at(player: WizardPlayer, camera: Camera3D, point: Vector3) -> void:
	var flat_target := Vector3(point.x, player.global_position.y, point.z)
	if flat_target.distance_to(player.global_position) > 0.01:
		player.look_at(flat_target, Vector3.UP)
	var offset := point - camera.global_position
	player.head.rotation.x = atan2(offset.y, Vector2(offset.x, offset.z).length())


func _press_cast() -> void:
	var press := InputEventAction.new()
	press.action = &"cast"
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventAction.new()
	release.action = &"cast"
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _anchor_of(owner: Node) -> LinkAnchor:
	for child in owner.get_children():
		if child is LinkAnchor:
			return child
	return null


func _doorway_point(gate: PortalGate) -> Vector3:
	return gate.frame().to_global(PortalGate.DOORWAY_OFFSET)


func _doorway_point_from_door(door: Door) -> Vector3:
	var frame := door.get_parent() as Node3D
	return frame.to_global(PortalGate.DOORWAY_OFFSET)


## Put the player in a gate's doorway mid-stride, walking indoors (+1) or out
## (-1), so the gate reads a real crossing direction from their momentum.
func _walk_into_doorway(player: WizardPlayer, gate: PortalGate, direction: float) -> void:
	var frame := gate.frame()
	var heading := frame.global_transform.basis * (PortalGate.INWARD * direction)
	heading.y = 0.0
	heading = heading.normalized()
	var point := _doorway_point(gate)
	player.global_position = Vector3(point.x, point.y - 0.2, point.z)
	player.velocity = heading * 3.0
	player.rotation.y = atan2(-heading.x, -heading.z)


## Which side of a doorway a point is on: positive indoors, negative outdoors.
func _side_of(frame: Node3D, point: Vector3) -> float:
	return frame.to_local(point).z


## Horizontal distance from the doorway centre, ignoring which side.
func _doorway_distance(frame: Node3D, point: Vector3) -> float:
	var local := frame.to_local(point) - PortalGate.DOORWAY_OFFSET
	return Vector2(local.x, local.z).length()


func _has_roof_overhead(level: Node3D, point: Vector3) -> bool:
	var space := level.get_viewport().world_3d.direct_space_state
	var query := PhysicsRayQueryParameters3D.create(point, point + Vector3.UP * 12.0)
	return not space.intersect_ray(query).is_empty()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
	else:
		push_error("[FAIL] %s" % message)
		_fail = 1
