extends SceneTree

## The villager house is the second real door in the world - the test bed for
## door-to-door link spells. It must carry the same warded door rig as the
## tower: an imported hinge/visual bound to the shared Door scene, a walkable
## threshold, and an auto-provided LinkAnchor so a link can be forged between
## the cottage door and the tower door.

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
	var house := level.get_node_or_null(^"VillagerHouse") as VillagerHouse
	_check(house != null, "the world places a villager house")
	if house == null:
		quit(1)
		return

	var door := house.entry_door
	_check(door != null, "the house exposes its entry door")
	var hinge := house.find_child("house_entry_door_hinge", true, false) as Node3D
	_check(hinge != null, "the imported model carries the door hinge")
	_check(hinge != null and door.get_parent() == hinge,
		"binding reparents the Door body onto the imported hinge")
	_check(door.find_child("house_entry_door", true, false) != null,
		"the imported door visual rides the Door body")

	# The same warded door as the tower: swings, prompts, and animates.
	_check(not door.is_open(), "the cottage door starts closed")
	_check(not door.is_locked(), "no arcane lock holds the cottage door")
	_check(door.focus_prompt(player, door) == "Open cottage door",
		"the focus prompt names the cottage door")
	door.interact(player, door)
	await create_timer(1.4).timeout
	_check(door.is_open(), "interacting swings the cottage door open")
	_check(door.focus_prompt(player, door) == "Close cottage door",
		"the open door offers to close")
	_check(absf(door.rotation.y - deg_to_rad(door.open_angle_degrees)) < 0.05,
		"the open door reaches its authored swing angle")
	door.interact(player, door)
	await create_timer(1.4).timeout
	_check(not door.is_open(), "interacting again closes the cottage door")

	# Both real doors auto-provide LinkAnchors - the door-link spell's endpoints.
	var house_anchor := _anchor_owned_by(door)
	var tower_arch := level.get_node(^"TowerArchitecture") as TowerArchitecture
	var tower_anchor := _anchor_owned_by(tower_arch.entry_door)
	_check(house_anchor != null, "the cottage door auto-provides a LinkAnchor")
	_check(tower_anchor != null, "the tower door still auto-provides a LinkAnchor")
	_check(house_anchor != null and house_anchor.kind == &"door",
		"the cottage anchor is a door anchor")

	# The threshold is walkable: flat-ish ground just outside the door.
	var space := level.get_viewport().world_3d.direct_space_state
	var outside := door.global_position + door.global_transform.basis.z * 1.2
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(outside.x, door.global_position.y + 2.0, outside.z),
		Vector3(outside.x, door.global_position.y - 4.0, outside.z))
	query.exclude = [door.get_rid(), player.get_rid()]
	var hit := space.intersect_ray(query)
	_check(not hit.is_empty(), "ground exists outside the cottage door")
	if not hit.is_empty():
		var drop: float = door.global_position.y - 1.2 - hit.position.y
		_check(absf(drop) < 0.55,
			"the cottage threshold sits near ground level (drop %.2f m)" % drop)

	# The walls collide - the house is a real obstacle, not a prop shell.
	var inside := house.global_position + Vector3(0.0, 1.4, 0.0)
	var wall_probe := PhysicsRayQueryParameters3D.create(
		inside, inside + house.global_transform.basis.x * 6.0)
	var wall_hit := space.intersect_ray(wall_probe)
	_check(not wall_hit.is_empty(), "the house walls carry collision")

	level.queue_free()
	await process_frame
	if _fail == 0:
		print("VILLAGER HOUSE TEST OK")
	quit(_fail)


func _anchor_owned_by(owner: Node) -> LinkAnchor:
	if owner == null:
		return null
	for child in owner.get_children():
		if child is LinkAnchor:
			return child
	return null


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
	else:
		push_error("[FAIL] %s" % message)
		_fail = 1
