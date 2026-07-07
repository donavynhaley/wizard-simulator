class_name SpellZone
extends Area3D

## Ground-bound magic. One class, three modes:
##   TRAP    - "trap" shape: a patient rune circle that detonates on its trigger
##   AURA    - "aura" shape: a presence that follows the caster and ticks
##   RESIDUE - what the "linger" behavior leaves behind: an elemental patch
## Traps arm after a short grace period and will absolutely trigger on their
## own caster. Wizards learn.

enum Mode { TRAP, AURA, RESIDUE }

const TRAP_ARM_TIME := 1.5
const TICK_TIME := 0.7

var def: SpellDefinition
var caster: Node3D
var mode := Mode.TRAP

var _radius := 1.0
var _life := 0.0
var _age := 0.0
var _armed := false
var _tick := 0.0
var _spent := false
var _ring: MeshInstance3D
var _core: MeshInstance3D


static func place_trap(spell: SpellDefinition, from_caster: Node3D, world: Node,
		from: Transform3D) -> SpellZone:
	# Find the floor: forward from the eyes, then straight down.
	var space := from_caster.get_world_3d().direct_space_state
	var ahead := from.origin - from.basis.z * 3.0
	var query := PhysicsRayQueryParameters3D.create(from.origin, ahead, SpellCast.LAYER_WORLD)
	var hit := space.intersect_ray(query)
	var anchor: Vector3 = hit["position"] if not hit.is_empty() else ahead
	query = PhysicsRayQueryParameters3D.create(anchor + Vector3.UP * 0.1,
		anchor + Vector3.DOWN * 6.0, SpellCast.LAYER_WORLD)
	hit = space.intersect_ray(query)
	if not hit.is_empty():
		anchor = hit["position"]

	var zone := SpellZone.new()
	zone.def = spell
	zone.caster = from_caster
	zone.mode = Mode.TRAP
	world.add_child(zone)
	zone.global_position = anchor + Vector3.UP * 0.03
	return zone


static func attach_aura(spell: SpellDefinition, from_caster: Node3D, world: Node) -> SpellZone:
	var zone := SpellZone.new()
	zone.def = spell
	zone.caster = from_caster
	zone.mode = Mode.AURA
	world.add_child(zone)
	zone.global_position = from_caster.global_position
	return zone


static func leave_residue(spell: SpellDefinition, from_caster: Node3D, world: Node,
		pos: Vector3) -> SpellZone:
	var zone := SpellZone.new()
	zone.def = spell
	zone.caster = from_caster
	zone.mode = Mode.RESIDUE
	world.add_child(zone)
	zone.global_position = pos
	return zone


func _ready() -> void:
	collision_layer = 0
	collision_mask = SpellCast.LAYER_WORLD | SpellCast.LAYER_TARGET
	monitoring = true

	match mode:
		Mode.TRAP:
			_radius = 1.1 * def.size
			_life = 30.0
		Mode.AURA:
			_radius = 2.2 * def.size
			_life = 6.0 * (2.0 if def.has_behavior("linger") else 1.0)
		Mode.RESIDUE:
			_radius = 1.2 * def.size
			_life = 3.5

	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = _radius
	cylinder.height = 1.2
	shape.shape = cylinder
	shape.position.y = 0.5
	add_child(shape)

	_build_visuals()
	if mode == Mode.TRAP:
		match def.trigger_id:
			"when_recast":
				SpellCast.register_pending(caster, self)
			"on_death":
				SpellCast.listen_for_death(self)
			"on_timer":
				var timer := get_tree().create_timer(
					3.0 + (1.2 if def.has_rune_tag("delayed") else 0.0))
				timer.timeout.connect(trigger_now)
		body_entered.connect(_on_body_entered)


func _build_visuals() -> void:
	var color := def.primary_color()
	var faint := mode == Mode.TRAP and def.is_silent()
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = _radius * 0.88
	torus.outer_radius = _radius
	_ring.mesh = torus
	_ring.material_override = SpellVisuals.emissive(color, 0.6 if faint else 1.6,
		0.25 if faint else 0.7)
	add_child(_ring)

	if mode != Mode.TRAP:
		_core = MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = _radius * 0.95
		disc.bottom_radius = _radius * 0.95
		disc.height = 0.05
		_core.mesh = disc
		_core.material_override = SpellVisuals.emissive(color, 0.8, 0.16)
		add_child(_core)
	if not (faint or (mode == Mode.AURA and def.rare_id == "veil_of_the_quiet_dark")):
		SpellVisuals.add_light(self, color, 0.9, _radius * 2.5)


func _process(delta: float) -> void:
	_age += delta
	_life -= delta
	if _life <= 0.0:
		if mode == Mode.TRAP and not _spent:
			_fizzle()
		else:
			queue_free()
		return

	var pulse := SpellVisuals.personality_scale(def, _age)
	if _ring:
		_ring.scale = Vector3(pulse, 1.0, pulse)

	match mode:
		Mode.TRAP:
			if not _armed and _age >= TRAP_ARM_TIME:
				_armed = true
		Mode.AURA:
			if is_instance_valid(caster):
				global_position = caster.global_position + Vector3.UP * 0.1
			_tick_damage(delta, 0.3)
		Mode.RESIDUE:
			_tick_damage(delta, 0.2)


func _tick_damage(delta: float, power_fraction: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK_TIME
	for node in get_tree().get_nodes_in_group("spell_target"):
		if node is Node3D and is_instance_valid(node) and node != caster:
			var flat: Vector3 = node.global_position - global_position
			flat.y = 0.0
			if flat.length() <= _radius + 0.4:
				SpellCast.apply_hit(def, node, node.global_position, flat.normalized(),
					power_fraction)


func _on_body_entered(body: Node3D) -> void:
	if _spent or not _armed or mode != Mode.TRAP:
		return
	# Trigger runes that wait for a touch (or default impact, which for a trap
	# means the same thing). Timer/recast/death traps ignore footsteps.
	if def.trigger_id not in ["when_touched", "on_impact"]:
		return
	if body.is_in_group("spell_target") or body is CharacterBody3D:
		trigger_now()


func trigger_now() -> void:
	if _spent or mode != Mode.TRAP:
		return
	_spent = true
	var world := get_tree().current_scene
	SpellCast.explode(def, world, global_position + Vector3.UP * 0.3, 2.0 * def.size, 1.2)
	if def.has_behavior("linger"):
		SpellZone.leave_residue(def, caster, world, global_position)
	if def.has_behavior("split"):
		for i in 3:
			var orb := SpellProjectile.new()
			orb.setup(def, caster)
			orb.is_lesser_copy = true
			world.add_child(orb)
			var out := Vector3(sin(i * TAU / 3.0), 1.6, cos(i * TAU / 3.0)).normalized()
			orb.global_position = global_position + Vector3.UP * 0.4
			orb.launch(out)
	queue_free()


func _fizzle() -> void:
	_spent = true
	SpellVisuals.spawn_burst(get_tree().current_scene, global_position,
		Color(0.6, 0.6, 0.65), 8, 1.0)
	queue_free()
