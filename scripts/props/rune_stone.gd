class_name RuneStone
extends RigidBody3D

## A physical rune tablet. Pick it up, carry it to a SpellBench, socket it.
## Set rune_id in the inspector (any id from RuneCatalog) and the stone builds
## its own look: glyph, inlay, and glow all come from the rune's definition.

@export var rune_id: String = "fire"

var rune: RuneData
var held := false

var _inlay: MeshInstance3D
var _glyph: Label3D
var _age := 0.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("blastable")
	mass = 2.0
	collision_layer = SpellCast.LAYER_PICKUP
	collision_mask = SpellCast.LAYER_WORLD

	rune = RuneCatalog.get_rune(rune_id)
	if rune == null:
		push_warning("RuneStone: unknown rune id '%s'" % rune_id)
		rune = RuneCatalog.get_rune("fire")

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 0.07, 0.24)
	shape.shape = box
	add_child(shape)

	var slab := MeshInstance3D.new()
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(0.2, 0.07, 0.24)
	slab.mesh = slab_mesh
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.38, 0.36, 0.42)
	stone_mat.roughness = 0.8
	slab.material_override = stone_mat
	add_child(slab)

	_inlay = MeshInstance3D.new()
	var inlay_mesh := CylinderMesh.new()
	inlay_mesh.top_radius = 0.075
	inlay_mesh.bottom_radius = 0.075
	inlay_mesh.height = 0.012
	_inlay.mesh = inlay_mesh
	_inlay.position.y = 0.038
	_inlay.material_override = SpellVisuals.emissive(rune.color, 2.2)
	add_child(_inlay)

	_glyph = Label3D.new()
	_glyph.text = rune.glyph
	_glyph.font_size = 64
	_glyph.pixel_size = 0.0016
	_glyph.modulate = Color(0.06, 0.05, 0.08)
	_glyph.position = Vector3(0.0, 0.046, 0.0)
	_glyph.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	add_child(_glyph)


func _process(delta: float) -> void:
	_age += delta
	if _inlay:
		var mat := _inlay.material_override as StandardMaterial3D
		mat.emission_energy_multiplier = 1.2 + sin(_age * 2.2) * 0.4


# --- Interaction contract (see PlayerInteractor) -----------------------------

func focus_prompt(_player: Node3D, _collider: Object) -> String:
	return "Take %s rune  (%s)" % [rune.display_name, rune.type_name()]


func interact(player: Node3D, _collider: Object) -> void:
	var hands := player.get_node_or_null("%HandAnchor") as WizardHands
	if hands:
		hands.pick_up(self)


## Called by WizardHands and SpellBench when this stone changes custody.
func set_held(now_held: bool) -> void:
	held = now_held
	freeze = now_held
	collision_layer = 0 if now_held else SpellCast.LAYER_PICKUP
	collision_mask = 0 if now_held else SpellCast.LAYER_WORLD
	if not now_held:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
