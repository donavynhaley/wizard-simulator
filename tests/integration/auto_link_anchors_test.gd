extends SceneTree

## Every ElementSource and every Door auto-provides a LinkAnchor, so tethering
## (Bind) works project-wide with no hand-authored anchors. The tower scene now
## authors only the DoorWard link between the lantern source and the door - the
## anchors it binds are the auto-provided ones, resolved from the referenced
## props through the reparent the door does on ready.

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

	var arch := level.get_node(^"TowerArchitecture") as TowerArchitecture

	# A source that authors NO anchor (the approach torch) auto-provides one.
	var torch_source := level.get_node(
		^"TowerArchitecture/ApproachTorch/MagicalFlame/FireSource") as ElementSource
	var torch_anchor := _anchor_owned_by(torch_source)
	_check(torch_anchor != null, "an unauthored source auto-provides a fount anchor")
	_check(torch_anchor != null and torch_anchor.provides_element(),
		"the auto fount anchor carries the source's element")
	_check(torch_anchor != null and torch_anchor.is_in_group(LinkAnchor.GROUP),
		"the auto fount anchor is discoverable for Bind aiming")

	# The door auto-provides a sink anchor whose target resolves back to the Door.
	var door := arch.entry_door
	var door_anchor := _first_child_anchor(door)
	_check(door_anchor != null, "the door auto-provides a link-sink anchor")
	_check(door_anchor != null and door_anchor.target() is Door,
		"the door anchor's target resolves to the Door")

	# The authored DoorWard resolved its anchors from the props it references
	# (the FireSource and the EntryDoor), not hand-placed anchor nodes - and it
	# survives the door reparenting itself into the imported model on ready.
	var ward := level.get_node(^"TowerArchitecture/DoorWard") as MagicalLink
	var lantern_source := level.get_node(
		^"TowerArchitecture/GroundFloorProps/DoorLantern/MagicalFlame/FireSource") as ElementSource
	_check(ward.source_anchor() != null and ward.source_anchor().source() == lantern_source,
		"the ward resolved its fount to the lantern source via the auto anchor")
	_check(ward.sink_anchor() != null and ward.sink_anchor().target() == door,
		"the ward resolved its sink to the door via the auto anchor")

	# Emergent proof: the forge resolves an arcane lock between the approach torch
	# and the door using only auto-provided anchors - no per-prop wiring at all.
	_check(LinkForge.resolve(torch_anchor, door_anchor) is ArcaneLockEffect,
		"a bare torch and a bare door forge an arcane lock through their auto anchors")

	level.queue_free()
	await process_frame
	if _fail == 0:
		print("AUTO LINK ANCHORS TEST OK")
	quit(_fail)


func _anchor_owned_by(source: ElementSource) -> LinkAnchor:
	for node in get_nodes_in_group(LinkAnchor.GROUP):
		var anchor := node as LinkAnchor
		if anchor != null and anchor.source() == source:
			return anchor
	return null


func _first_child_anchor(node: Node) -> LinkAnchor:
	for child in node.get_children():
		if child is LinkAnchor:
			return child as LinkAnchor
	return null


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
	else:
		push_error("[FAIL] %s" % message)
		_fail = 1
