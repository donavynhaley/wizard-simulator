class_name PortalGate
extends Node3D

## One mouth of a portal link: the shimmer that fills a bound door's frame, and
## the trigger that carries whoever steps through it to the far door.
##
## The gate rides the door's FRAME - the hinge the Door body is bound to - not
## the swinging slab, so the opening stays put while the door itself moves.
##
## A gate only carries while its own door stands open, which gives the mechanic
## its rules for free: a closed door is a closed portal, and an arcane lock
## cannot be opened at all, so a locked door seals its portal from that side.

const PORTAL_SHADER := preload("res://game/spellcraft/links/portal_surface.gdshader")
const BURST_SCENE := preload("res://game/spellcraft/elements/siphon_burst.tscn")
const ARRIVAL_STREAM := preload("res://assets/sounds/siphon_place.wav")
const PORTAL_TINT := Color(0.25, 0.55, 0.95)

## Doorway centre in frame-local space: the slab hangs off the hinge along +X,
## so the middle of the opening is half a door away. Matches the offset the
## shared door scene gives its collision box.
const DOORWAY_OFFSET := Vector3(0.73, 0.0, 0.0)
const DOORWAY_SIZE := Vector2(1.46, 2.58)
## Frame-local -Z is outdoors for every door in the game (measured against both
## the tower and the cottage: only the +Z side has a roof over it).
const OUTWARD := Vector3(0.0, 0.0, -1.0)
## How far beyond the frame an arrival lands. Must clear this gate's own trigger
## box, or stepping out would bounce you straight back.
const EXIT_DISTANCE := 1.35
## The player body origin sits at its capsule centre; feet are half of the 1.7 m
## capsule below that. A little extra lets them settle down onto the ground.
const PLAYER_FEET_OFFSET := 0.95
const TRIGGER_SIZE := Vector3(1.5, 2.5, 0.7)
const TRAVEL_COOLDOWN := 0.4

## The door this mouth sits in. Assign before adding the gate to the tree.
var door: Door
## The mouth on the other side. Assigned once both gates exist.
var far_gate: PortalGate

var _area: Area3D
var _surface: MeshInstance3D
var _cooldown := 0.0
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	_build_surface()
	_build_trigger()
	snap_to_frame()


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


func _build_surface() -> void:
	var quad := QuadMesh.new()
	quad.size = DOORWAY_SIZE
	_surface = MeshInstance3D.new()
	_surface.name = &"Surface"
	_surface.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = PORTAL_SHADER
	_surface.material_override = material
	_surface.position = DOORWAY_OFFSET
	_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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


## Polled rather than driven by body_entered: a door can open around a player who
## is already standing in the doorway, and that fires no enter signal at all.
func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	var open := door != null and is_instance_valid(door) and door.is_open()
	if _surface != null:
		_surface.visible = open
	if not open or _cooldown > 0.0:
		return
	if far_gate == null or not is_instance_valid(far_gate):
		return
	for body in _area.get_overlapping_bodies():
		var traveller := body as WizardPlayer
		if traveller != null:
			_cooldown = TRAVEL_COOLDOWN
			far_gate.receive(traveller)
			return


## Take delivery of someone stepping in at the far mouth.
func receive(traveller: WizardPlayer) -> void:
	if traveller == null:
		return
	# Arriving must not immediately re-trigger this mouth on the way back.
	_cooldown = TRAVEL_COOLDOWN
	var exit := exit_transform(traveller)
	# Deferred: the poll runs inside the physics step, and moving a
	# CharacterBody3D mid-step fights the move_and_slide already in flight.
	_place.call_deferred(traveller, exit)
	_play_arrival(exit.origin)


## Where an arrival lands: a stride outside the frame, on the ground, facing
## away from the door.
func exit_transform(traveller: WizardPlayer = null) -> Transform3D:
	var anchor := frame()
	if anchor == null:
		return Transform3D.IDENTITY
	var out := anchor.global_transform.basis * OUTWARD
	out.y = 0.0
	if out.length_squared() < 0.0001:
		out = Vector3.FORWARD
	out = out.normalized()
	var centre := anchor.to_global(DOORWAY_OFFSET)
	var spot := centre + out * EXIT_DISTANCE
	spot.y = _ground_height(spot, centre.y, traveller) + PLAYER_FEET_OFFSET
	# The body's forward is -Z, so aim -Z along the outward direction.
	return Transform3D(Basis(Vector3.UP, atan2(-out.x, -out.z)), spot)


## Ground under the exit spot. Both doors are excluded: an open slab swings out
## over this very patch, and landing on top of a door would be worse than
## falling through the floor.
func _ground_height(spot: Vector3, fallback_y: float, traveller: WizardPlayer) -> float:
	var space := get_world_3d().direct_space_state
	if space == null:
		return fallback_y - 1.2
	var from := Vector3(spot.x, fallback_y + 2.0, spot.z)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 8.0)
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
		return fallback_y - 1.2
	return hit.position.y


func _place(traveller: WizardPlayer, exit: Transform3D) -> void:
	if traveller == null or not is_instance_valid(traveller):
		return
	traveller.global_transform = exit
	traveller.velocity = Vector3.ZERO
	# Level the view: arriving mid-glance at the floor is disorienting.
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
