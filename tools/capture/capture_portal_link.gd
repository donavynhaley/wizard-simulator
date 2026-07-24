extends SceneTree

const LEVEL_SCENE := preload("res://game/world/levels/wizard_tower.tscn")
const COTTAGE_OUT := "/tmp/portal_cottage_mouth.png"
const COTTAGE_WIDE_OUT := "/tmp/portal_cottage_wide.png"
const TOWER_OUT := "/tmp/portal_tower_mouth.png"
const STRAND_OUT := "/tmp/portal_strand.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1400, 1000)
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var level := LEVEL_SCENE.instantiate() as Node3D
	viewport.add_child(level)
	await _settle()

	var player := level.get_node(^"Player") as WizardPlayer
	var arch := level.get_node(^"TowerArchitecture") as TowerArchitecture
	var house := level.get_node(^"VillagerHouse") as VillagerHouse
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.visible = false
	player.hud.visible = false

	var tower_door := arch.entry_door
	var cottage_door := house.entry_door
	var link := LinkForge.forge(
		_anchor_of(cottage_door), _anchor_of(tower_door), level)
	print("forged=", link)
	await _settle()

	# Open both mouths: the cottage by hand, the tower by feeding its ward.
	cottage_door.interact(player, cottage_door)
	var lantern := level.get_node(
		^"TowerArchitecture/GroundFloorProps/DoorLantern/MagicalFlame/FireSource") as ElementSource
	lantern.restore(lantern.global_position + Vector3.UP * 0.5)
	await create_timer(1.6).timeout
	await _settle()

	var camera := Camera3D.new()
	level.add_child(camera)
	camera.current = true
	camera.fov = 62.0

	var cottage_gate := link.get_node(^"GateA") as PortalGate
	var tower_gate := link.get_node(^"GateB") as PortalGate

	# Straight into the cottage mouth from outside.
	_frame_gate(camera, cottage_gate, 3.1, 0.25)
	await _settle()
	_save(viewport, COTTAGE_OUT)

	# Wider, so the cottage and the shimmer read together.
	_frame_gate(camera, cottage_gate, 6.5, 1.6)
	await _settle()
	_save(viewport, COTTAGE_WIDE_OUT)

	# The tower mouth.
	_frame_gate(camera, tower_gate, 3.6, 0.35, 2.2)
	await _settle()
	_save(viewport, TOWER_OUT)

	# Both doors and the strand between them, seen in Sight.
	camera.position = Vector3(4.6, 3.0, 21.0)
	camera.look_at(Vector3(4.0, 1.2, 12.0), Vector3.UP)
	await _settle()
	_save(viewport, STRAND_OUT)

	quit(0)


## Frame a mouth from outside. The lateral offset steps around the open slab,
## which swings out across the straight-on view.
func _frame_gate(camera: Camera3D, gate: PortalGate, distance: float, height: float,
		lateral: float = 0.0) -> void:
	var frame := gate.frame()
	var out := frame.global_transform.basis * PortalGate.OUTWARD
	out.y = 0.0
	out = out.normalized()
	var side := Vector3.UP.cross(out).normalized()
	var centre := frame.to_global(PortalGate.DOORWAY_OFFSET)
	camera.position = centre + out * distance + side * lateral + Vector3.UP * height
	camera.look_at(centre, Vector3.UP)


func _anchor_of(owner: Node) -> LinkAnchor:
	for child in owner.get_children():
		if child is LinkAnchor:
			return child
	return null


func _save(viewport: SubViewport, path: String) -> void:
	var capture_error := viewport.get_texture().get_image().save_png(path)
	print("saved=", path, " err=", capture_error)


func _settle() -> void:
	for _frame in 14:
		await process_frame
