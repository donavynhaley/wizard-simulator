class_name PortalGate
extends Node3D

## One mouth of a portal link: a window onto the far door's room, and the
## trigger that carries whoever walks through.
##
## The two bound doorways become ONE doorway. Cross a threshold heading indoors
## and you step into the far building; cross it heading out and you come out of
## the far one. Your heading and your offset through the frame are preserved, so
## it reads as walking through a door rather than as being teleported.
##
## The gate rides the door's FRAME - the hinge the Door body is bound to - not
## the swinging slab, so the opening stays put while the door moves.
##
## A gate only works while its own door stands open, which gives the mechanic its
## rules for free: a closed door is a closed portal, and an arcane lock cannot be
## opened, so a lock seals its portal from that side.

const PORTAL_SHADER := preload("res://game/spellcraft/links/portal_surface.gdshader")
const BURST_SCENE := preload("res://game/spellcraft/elements/siphon_burst.tscn")
const ARRIVAL_STREAM := preload("res://assets/sounds/siphon_place.wav")
const PORTAL_TINT := Color(0.25, 0.55, 0.95)

## Doorway centre in frame-local space: the slab hangs off the hinge along +X,
## so the middle of the opening is half a door away. Matches the offset the
## shared door scene gives its collision box.
const DOORWAY_OFFSET := Vector3(0.73, 0.0, 0.0)
const DOORWAY_SIZE := Vector2(1.46, 2.58)
## Frame-local -Z is outdoors for every door in the game, +Z the room behind it
## (measured against both the tower and the cottage: only +Z has a roof).
const OUTWARD := Vector3(0.0, 0.0, -1.0)
const INWARD := Vector3(0.0, 0.0, 1.0)
## How far past the far frame a crossing carries. Must clear that gate's own
## trigger box, or arriving would immediately count as another crossing.
const CROSSING_STRIDE := 1.45
## The player body origin sits at its capsule centre; feet are half of the 1.7 m
## capsule below that. A little extra lets them settle down onto the floor.
const PLAYER_FEET_OFFSET := 0.95
const TRIGGER_SIZE := Vector3(1.5, 2.5, 0.7)
const TRAVEL_COOLDOWN := 0.4
## Portal surfaces live on their own visual layer so the portal cameras can cull
## them: a mouth that rendered other mouths would recurse.
const PORTAL_VISUAL_LAYER := 20

## The door this mouth sits in. Assign before adding the gate to the tree.
var door: Door
## The mouth on the other side. Assigned once both gates exist.
var far_gate: PortalGate

var _area: Area3D
var _surface: MeshInstance3D
var _material: ShaderMaterial
var _viewport: SubViewport
var _camera: Camera3D
var _notifier: VisibleOnScreenNotifier3D
var _cooldown := 0.0
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	_build_surface()
	_build_trigger()
	_build_view()
	snap_to_frame()
	if door != null and is_instance_valid(door):
		door.open_state_changed.connect(_on_door_swung)


## The fixed doorway transform. A bound Door is reparented onto the imported
## hinge, so the parent carries the frame; an unbound door stands in for itself.
func frame() -> Node3D:
	if door == null or not is_instance_valid(door):
		return null
	var hinge := door.get_parent() as Node3D
	return hinge if hinge != null else door


func snap_to_frame() -> void:
	var anchor := frame()
	if anchor != null:
		global_transform = anchor.global_transform


func is_open() -> bool:
	return door != null and is_instance_valid(door) and door.is_open()


## One doorway, so one leaf: what this door does, the far one does. Door only
## announces real changes, so the answering swing raises no further echo.
func _on_door_swung(is_door_open: bool) -> void:
	if far_gate == null or not is_instance_valid(far_gate):
		return
	if far_gate.door != null and is_instance_valid(far_gate.door):
		far_gate.door.set_open(is_door_open)


## Bring a freshly bound pair into agreement. Open wins: a portal you can walk
## through is the point of building one. An arcane lock still refuses, and a
## warded door simply stays shut until its ward is fed.
func agree_with_far() -> void:
	if far_gate == null or not is_instance_valid(far_gate):
		return
	var theirs := far_gate.door
	if door == null or theirs == null:
		return
	if door.is_open() or theirs.is_open():
		door.set_open(true)
		theirs.set_open(true)


func _build_surface() -> void:
	var quad := QuadMesh.new()
	quad.size = DOORWAY_SIZE
	_surface = MeshInstance3D.new()
	_surface.name = &"Surface"
	_surface.mesh = quad
	_material = ShaderMaterial.new()
	_material.shader = PORTAL_SHADER
	_surface.material_override = _material
	_surface.position = DOORWAY_OFFSET
	_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_surface.layers = 1 << (PORTAL_VISUAL_LAYER - 1)
	_surface.visible = false
	add_child(_surface)


func _build_trigger() -> void:
	var box := BoxShape3D.new()
	box.size = TRIGGER_SIZE
	var shape := CollisionShape3D.new()
	shape.shape = box
	_area = Area3D.new()
	_area.name = &"Threshold"
	_area.monitorable = false
	_area.position = DOORWAY_OFFSET
	_area.add_child(shape)
	add_child(_area)


## The see-through view: a second camera standing where the viewer would be if
## this doorway were the far one, rendered into the surface.
func _build_view() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_viewport = SubViewport.new()
	_viewport.name = &"View"
	# own_world_3d stays false so this renders the real world, not an empty one.
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.size = Vector2i(1024, 1024)
	_camera = Camera3D.new()
	_camera.name = &"Eye"
	# Cull other portal surfaces: a mouth rendering a mouth would recurse.
	_camera.cull_mask = 0xFFFFF & ~(1 << (PORTAL_VISUAL_LAYER - 1))
	_camera.current = true
	_viewport.add_child(_camera)
	add_child(_viewport)
	_material.set_shader_parameter(&"portal_view", _viewport.get_texture())

	# Rendering a mouth means drawing the whole world a second time, so only pay
	# for it while the opening is actually on screen.
	_notifier = VisibleOnScreenNotifier3D.new()
	_notifier.name = &"OnScreen"
	_notifier.aabb = AABB(
		DOORWAY_OFFSET - Vector3(DOORWAY_SIZE.x * 0.5, DOORWAY_SIZE.y * 0.5, 0.2),
		Vector3(DOORWAY_SIZE.x, DOORWAY_SIZE.y, 0.4))
	add_child(_notifier)


## Polled rather than driven by body_entered: a door can open around a player who
## is already standing in the doorway, and that fires no enter signal at all.
func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	var open := is_open()
	if _surface != null:
		_surface.visible = open
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS \
			if open and _showing() else SubViewport.UPDATE_DISABLED
	if not open or _cooldown > 0.0:
		return
	if far_gate == null or not is_instance_valid(far_gate):
		return
	for body in _area.get_overlapping_bodies():
		var traveller := body as WizardPlayer
		if traveller != null:
			_carry(traveller)
			return


## Keep the far eye where the viewer's eye would be if this doorway were the far
## one. Runs in _process so it lands after the frame's movement, before drawing.
## Whether the opening is on screen for anyone. The notifier needs a frame in the
## tree before it reports, so an unset notifier counts as showing.
func _showing() -> bool:
	return _notifier == null or _notifier.is_on_screen()


func _process(_delta: float) -> void:
	if _viewport == null or not is_open() or not _showing():
		return
	if far_gate == null or not is_instance_valid(far_gate):
		return
	var viewer := get_viewport().get_camera_3d()
	var near_frame := frame()
	var far_frame := far_gate.frame()
	if viewer == null or near_frame == null or far_frame == null:
		return
	_match_view_size()
	# The same offset from the far doorway that the viewer has from this one, so
	# looking through the opening looks through the far opening.
	var relative := near_frame.global_transform.affine_inverse() * viewer.global_transform
	_camera.global_transform = far_frame.global_transform * relative
	_camera.fov = viewer.fov
	_camera.far = viewer.far
	# Clip everything nearer than the far doorway - its outside wall and the
	# ground in front of it sit between this eye and the room we want to show.
	var normal := far_frame.global_transform.basis.z.normalized()
	var to_plane := far_frame.to_global(DOORWAY_OFFSET) - _camera.global_position
	_camera.near = clampf(absf(to_plane.dot(normal)), 0.05, 200.0)


func _match_view_size() -> void:
	var host := get_viewport()
	if host == null:
		return
	var wanted := Vector2i(host.get_visible_rect().size)
	if wanted.x > 0 and wanted.y > 0 and _viewport.size != wanted:
		_viewport.size = wanted


## Carry a traveller through this doorway and out of the far one, keeping their
## heading and their offset through the frame.
func _carry(traveller: WizardPlayer) -> void:
	var near_frame := frame()
	var far_frame := far_gate.frame()
	if near_frame == null or far_frame == null:
		return
	_cooldown = TRAVEL_COOLDOWN
	far_gate._cooldown = TRAVEL_COOLDOWN

	var direction := _crossing_direction(traveller, near_frame)
	var local := near_frame.to_local(traveller.global_position)
	# Keep how far off-centre they walked through, but never wide enough to
	# arrive inside the far wall.
	var lateral := clampf(local.x - DOORWAY_OFFSET.x, -0.45, 0.45)
	var target := Vector3(DOORWAY_OFFSET.x + lateral, 0.0, direction * CROSSING_STRIDE)
	var spot := far_frame.to_global(target)
	spot.y = far_gate._floor_height(spot, far_frame.global_position.y, traveller) \
		+ PLAYER_FEET_OFFSET

	# Preserve their heading relative to the threshold, flattened to a yaw: you
	# walk out of the far door aimed exactly as you walked into this one.
	var relative_basis := near_frame.global_transform.basis.inverse() \
		* traveller.global_transform.basis
	var heading := (far_frame.global_transform.basis * relative_basis) * Vector3.FORWARD
	heading.y = 0.0
	if heading.length_squared() < 0.0001:
		heading = far_frame.global_transform.basis * (INWARD * direction)
		heading.y = 0.0
	heading = heading.normalized()
	var basis := Basis(Vector3.UP, atan2(-heading.x, -heading.z))

	far_gate.deliver(traveller, Transform3D(basis, spot))


## Which way through the frame the traveller is moving: +1 indoors, -1 outdoors.
## Momentum decides it; a standing traveller falls back on where they face.
func _crossing_direction(traveller: WizardPlayer, near_frame: Node3D) -> float:
	var inward := near_frame.global_transform.basis * INWARD
	inward.y = 0.0
	inward = inward.normalized()
	var motion := traveller.velocity
	motion.y = 0.0
	var along := motion.dot(inward) if motion.length() > 0.15 \
		else (-traveller.global_transform.basis.z).dot(inward)
	return -1.0 if along < 0.0 else 1.0


## Take delivery of someone crossing at the far mouth.
func deliver(traveller: WizardPlayer, arrival: Transform3D) -> void:
	if traveller == null:
		return
	_cooldown = TRAVEL_COOLDOWN
	# Deferred: the poll runs inside the physics step, and moving a
	# CharacterBody3D mid-step fights the move_and_slide already in flight.
	_place.call_deferred(traveller, arrival)
	_play_arrival(arrival.origin)


## Floor under an arrival. Both door slabs are excluded - an open one swings out
## across this very patch, and landing on top of a door is worse than falling
## through the floor. The probe starts barely above the doorway so that indoors
## it stays under the ceiling instead of finding the roof.
func _floor_height(spot: Vector3, doorway_y: float, traveller: WizardPlayer) -> float:
	var space := get_world_3d().direct_space_state
	if space == null:
		return doorway_y - 1.2
	var from := Vector3(spot.x, doorway_y + 0.6, spot.z)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 10.0)
	var excluded: Array[RID] = []
	if door != null and is_instance_valid(door):
		excluded.append(door.get_rid())
	if far_gate != null and is_instance_valid(far_gate) \
			and far_gate.door != null and is_instance_valid(far_gate.door):
		excluded.append(far_gate.door.get_rid())
	if traveller != null:
		excluded.append(traveller.get_rid())
	query.exclude = excluded
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return doorway_y - 1.2
	return hit.position.y


func _place(traveller: WizardPlayer, arrival: Transform3D) -> void:
	if traveller == null or not is_instance_valid(traveller):
		return
	var carried := traveller.velocity.length()
	traveller.global_transform = arrival
	# Keep walking: momentum carries through the threshold in the new heading.
	traveller.velocity = -arrival.basis.z * carried
	if traveller.head != null:
		traveller.head.rotation.x = 0.0


func _play_arrival(point: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var burst := BURST_SCENE.instantiate() as SiphonBurst
	if burst != null:
		add_child(burst)
		burst.global_position = point
		burst.set_color(PORTAL_TINT)
	if _audio == null:
		_audio = AudioStreamPlayer3D.new()
		_audio.stream = ARRIVAL_STREAM
		_audio.pitch_scale = 0.7
		_audio.bus = &"SpellCast"
		add_child(_audio)
	_audio.global_position = point
	_audio.play()
