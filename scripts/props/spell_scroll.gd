class_name SpellScroll
extends RigidBody3D

## A finished spell. Holding a scroll is the ONLY way to cast; each cast spends
## a charge, and a spent scroll crumbles to ash in your hand. The wax seal and
## charge beads are colored by the spell inside.

signal depleted(scroll: SpellScroll)

var definition: SpellDefinition
var held := false

var _pips: Array[MeshInstance3D] = []
var _seal_mat: StandardMaterial3D
var _age := 0.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("blastable")
	mass = 0.5
	collision_layer = SpellCast.LAYER_PICKUP
	collision_mask = SpellCast.LAYER_WORLD

	if definition == null:
		# Placed by hand in the editor without a forge: default demo spell.
		definition = SpellDefinition.new()
		definition.spell_name = "Apprentice Sparks"

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.34, 0.09, 0.09)
	shape.shape = box
	add_child(shape)
	_build_visuals()


func _build_visuals() -> void:
	var color := definition.primary_color()

	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.82, 0.74, 0.55)
	paper.roughness = 0.95

	var roll := MeshInstance3D.new()
	var roll_mesh := CylinderMesh.new()
	roll_mesh.top_radius = 0.036
	roll_mesh.bottom_radius = 0.036
	roll_mesh.height = 0.32
	roll.mesh = roll_mesh
	roll.rotation_degrees.z = 90.0
	roll.material_override = paper
	add_child(roll)

	for side in [-1.0, 1.0]:
		var cap := MeshInstance3D.new()
		var cap_mesh := CylinderMesh.new()
		cap_mesh.top_radius = 0.045
		cap_mesh.bottom_radius = 0.045
		cap_mesh.height = 0.04
		cap.mesh = cap_mesh
		cap.rotation_degrees.z = 90.0
		cap.position.x = 0.16 * side
		cap.material_override = paper
		add_child(cap)

	var seal := MeshInstance3D.new()
	var seal_mesh := SphereMesh.new()
	seal_mesh.radius = 0.035
	seal_mesh.height = 0.05
	seal.mesh = seal_mesh
	seal.position = Vector3(0.0, 0.045, 0.0)
	_seal_mat = SpellVisuals.emissive(color, 1.2)
	seal.material_override = _seal_mat
	add_child(seal)

	_refresh_pips()


func _refresh_pips() -> void:
	for pip in _pips:
		pip.queue_free()
	_pips.clear()
	var count := definition.charges
	var spacing := 0.28 / maxf(1.0, count)
	for i in count:
		var pip := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.012
		mesh.height = 0.024
		pip.mesh = mesh
		pip.position = Vector3(-0.14 + spacing * (i + 0.5), 0.0, 0.05)
		pip.material_override = SpellVisuals.emissive(definition.primary_color(), 1.8)
		add_child(pip)
		_pips.append(pip)


func _process(delta: float) -> void:
	_age += delta
	if _seal_mat:
		_seal_mat.emission_energy_multiplier = \
			1.0 + SpellVisuals.personality_scale(definition, _age) - 1.0 + sin(_age * 3.0) * 0.3


# --- Interaction contract -----------------------------------------------------

func focus_prompt(_player: Node3D, _collider: Object) -> String:
	return "Take scroll: %s  (%d %s)" % [definition.spell_name, definition.charges,
		"charge" if definition.charges == 1 else "charges"]


func interact(player: Node3D, _collider: Object) -> void:
	var hands := player.get_node_or_null("%HandAnchor") as WizardHands
	if hands:
		hands.pick_up(self)


func set_held(now_held: bool) -> void:
	held = now_held
	freeze = now_held
	collision_layer = 0 if now_held else SpellCast.LAYER_PICKUP
	collision_mask = 0 if now_held else SpellCast.LAYER_WORLD
	if not now_held:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO


## Cast from the player's hand. Returns a short status line for the HUD.
func cast_from(player: Node3D, from: Transform3D) -> String:
	# A recast-triggered spell waiting in the world takes priority over a new cast.
	if definition.trigger_id == "when_recast" and SpellCast.has_pending(player):
		var fired := SpellCast.detonate_pending(player)
		return "The held word is spoken (%d released)." % fired

	var worked := SpellCast.cast(definition, player, from)
	definition.charges -= 1
	if definition.charges <= 0:
		_crumble(player)
		return "The scroll crumbles to ash."
	_refresh_pips()
	return "" if worked else "The spell sputters out. The charge is gone anyway."


func _crumble(player: Node3D) -> void:
	var world := get_tree().current_scene
	SpellVisuals.spawn_burst(world, global_position, Color(0.75, 0.68, 0.5), 20, 1.6)
	SpellVisuals.floating_text(world, global_position, "*poof*", Color(0.8, 0.75, 0.6), 28)
	depleted.emit(self)
	var hands := player.get_node_or_null("%HandAnchor") as WizardHands
	if hands:
		hands.notify_item_gone(self)
	queue_free()
