class_name SpellCast

## Runtime entry point for casting. A SpellScroll calls SpellCast.cast() with
## its definition; this dispatches to the right effect node by shape, applies
## cast-time quirks, and owns the cross-effect plumbing (recast detonation,
## on-death notification, hit application).

## Collision layers used by spell physics queries.
const LAYER_WORLD := 1
const LAYER_PICKUP := 2
const LAYER_TARGET := 4
const LAYER_SHIELD := 8
const HIT_MASK := LAYER_WORLD | LAYER_TARGET | LAYER_SHIELD

## Effects waiting for a "when_recast" word, per caster instance id.
static var _pending_recast: Dictionary = {}
## Effects listening for a death nearby ("on_death" trigger).
static var _death_listeners: Array = []


## Cast a spell from a scroll. Returns false if the cast fizzled (sputter quirk),
## in which case the charge is still spent. `from` is usually the camera transform.
static func cast(def: SpellDefinition, caster: Node3D, from: Transform3D) -> bool:
	var world := caster.get_tree().current_scene
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# A held recast-orb detonates on the next cast instead of spending a new charge;
	# the scroll checks has_pending() before calling us, so reaching here means fire anew.

	if def.has_quirk("sputter") and rng.randf() < 0.15:
		SpellVisuals.spawn_burst(world, from.origin + from.basis * Vector3(0, 0, -0.6),
			Color(0.5, 0.5, 0.5), 10, 1.2)
		return false

	if def.has_quirk("wild_aim"):
		var wobble := deg_to_rad(14.0)
		from.basis = from.basis \
			* Basis(Vector3.UP, rng.randf_range(-wobble, wobble)) \
			* Basis(Vector3.RIGHT, rng.randf_range(-wobble, wobble))

	var kick_body := caster as CharacterBody3D
	if def.has_quirk("kickback") and kick_body:
		kick_body.velocity += from.basis * Vector3(0, 0.2, 1.0) * 5.0

	if def.has_quirk("screamer") and not def.is_silent():
		Screamer.scream_at(world, from.origin + from.basis * Vector3(0, 0.2, -1.0))

	match def.shape_id:
		"orb":
			_spawn_orb(def, caster, world, from)
		"beam":
			SpellBeam.fire(def, caster, world, from)
		"wave":
			SpellWave.sweep(def, caster, world, caster.global_position)
		"trap":
			SpellZone.place_trap(def, caster, world, from)
		"shield":
			SpellShield.raise(def, caster, world)
		"aura":
			SpellZone.attach_aura(def, caster, world)
		"chain":
			SpellChain.lash(def, caster, world, from)
		_:
			push_warning("SpellCast: unknown shape " + def.shape_id)
			return false
	return true


static func _spawn_orb(def: SpellDefinition, caster: Node3D, world: Node, from: Transform3D) -> void:
	var orb := SpellProjectile.new()
	orb.setup(def, caster)
	world.add_child(orb)
	orb.global_transform = Transform3D(from.basis,
		from.origin + from.basis * Vector3(0.25, -0.15, -0.5))
	orb.launch(-from.basis.z)


# --- when_recast plumbing -------------------------------------------------------

static func register_pending(caster: Node3D, effect: Node) -> void:
	var list: Array = _pending_recast.get(caster.get_instance_id(), [])
	list.append(effect)
	_pending_recast[caster.get_instance_id()] = list


static func has_pending(caster: Node3D) -> bool:
	var list: Array = _pending_recast.get(caster.get_instance_id(), [])
	return list.any(func(e: Variant) -> bool: return is_instance_valid(e))


## Detonate everything this caster left waiting. Returns how many fired.
static func detonate_pending(caster: Node3D) -> int:
	var list: Array = _pending_recast.get(caster.get_instance_id(), [])
	_pending_recast.erase(caster.get_instance_id())
	var fired := 0
	for effect: Variant in list:
		if is_instance_valid(effect) and effect.has_method("trigger_now"):
			effect.trigger_now()
			fired += 1
	return fired


# --- on_death plumbing ----------------------------------------------------------

static func listen_for_death(effect: Node) -> void:
	_death_listeners.append(effect)


## Called by anything that dies (e.g. TrainingDummy) so on_death spells can act.
static func notify_death(pos: Vector3, radius: float = 8.0) -> void:
	var still: Array = []
	for effect: Variant in _death_listeners:
		if not is_instance_valid(effect):
			continue
		if effect is Node3D and effect.global_position.distance_to(pos) <= radius:
			if effect.has_method("trigger_now"):
				effect.trigger_now()
		else:
			still.append(effect)
	_death_listeners = still


# --- Hits -------------------------------------------------------------------------

## Apply a spell hit to any object. Targets implement take_spell_hit(hit);
## rigid bodies get shoved; wind shoves everything, including characters.
static func apply_hit(def: SpellDefinition, target: Object, pos: Vector3, dir: Vector3,
		power_scale: float = 1.0) -> void:
	if target == null or not is_instance_valid(target):
		return
	var impulse := dir.normalized() * (2.0 + def.power * 0.25) * power_scale
	if def.element_id == "wind" or def.has_rune_tag("push"):
		impulse *= 2.5
	var hit := {
		"power": def.power * power_scale,
		"element": def.element_id,
		"color": def.primary_color(),
		"position": pos,
		"impulse": impulse,
		"spell_name": def.spell_name,
	}
	if target.has_method("take_spell_hit"):
		target.call("take_spell_hit", hit)
	var rigid := target as RigidBody3D
	var character := target as CharacterBody3D
	if rigid:
		rigid.apply_central_impulse(impulse)
	elif character and impulse.length() > 6.0:
		character.velocity += impulse * 0.6


## Area detonation: damages spell targets and shoves bodies within the radius.
static func explode(def: SpellDefinition, world: Node, pos: Vector3, radius: float,
		power_scale: float = 1.0) -> void:
	SpellVisuals.spawn_flash(world, pos, def.primary_color(), radius * 0.35)
	SpellVisuals.spawn_burst(world, pos, def.primary_color(), 30, radius * 2.2)
	var space := (world as Node3D).get_world_3d().direct_space_state if world is Node3D else null
	if space == null and world.get_tree().current_scene is Node3D:
		space = world.get_tree().current_scene.get_world_3d().direct_space_state
	var hit_ids := {}
	if space:
		var shape := SphereShape3D.new()
		shape.radius = radius
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.transform = Transform3D(Basis.IDENTITY, pos)
		params.collision_mask = LAYER_WORLD | LAYER_TARGET
		for result: Dictionary in space.intersect_shape(params, 24):
			var collider: Object = result["collider"]
			if collider == null or hit_ids.has(collider.get_instance_id()):
				continue
			hit_ids[collider.get_instance_id()] = true
			var collider_3d := collider as Node3D
			var target_pos: Vector3 = collider_3d.global_position if collider_3d else pos
			var falloff := clampf(1.0 - target_pos.distance_to(pos) / maxf(radius, 0.01), 0.25, 1.0)
			apply_hit(def, collider, target_pos, (target_pos - pos).normalized(), power_scale * falloff)
