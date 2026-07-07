class_name SpellProjectile
extends Node3D

## The "orb" shape: a swept-ray projectile that composes behaviors.
##   bounce - reflects off surfaces (3 rebounds); with explode, detonates on the last
##   pierce - passes through up to 4 targets, damaging each
##   home   - steers toward the nearest spell target
##   split  - breaks into 3 lesser orbs when it triggers
##   explode- area detonation instead of a single hit
##   linger - leaves an elemental residue zone behind
## Triggers: on_impact, on_timer (fuse), when_touched (same as impact for orbs),
## when_recast (sticks and waits for the caster), on_death (sticks and listens).

const LIFETIME := 8.0
const BOUNCES := 3
const PIERCES := 4

var def: SpellDefinition
var caster: Node3D
var is_lesser_copy: bool = false

var _velocity := Vector3.ZERO
var _radius := 0.16
var _bounces_left := 0
var _pierces_left := 0
var _age := 0.0
var _fuse := -1.0
var _stuck := false
var _spent := false
var _visual: Node3D
var _rng := RandomNumberGenerator.new()


func setup(spell: SpellDefinition, from_caster: Node3D) -> void:
	def = spell
	caster = from_caster
	_radius = 0.16 * def.size
	_bounces_left = BOUNCES if def.has_behavior("bounce") else 0
	_pierces_left = PIERCES if def.has_behavior("pierce") else 0
	_rng.randomize()


func _ready() -> void:
	_visual = SpellVisuals.orb_node(def, _radius)
	add_child(_visual)
	if def.trigger_id == "on_timer":
		_fuse = 1.6 + (1.2 if def.has_rune_tag("delayed") else 0.0)


func launch(direction: Vector3) -> void:
	_velocity = direction.normalized() * def.speed
	if def.trigger_id == "when_recast":
		SpellCast.register_pending(caster, self)
	elif def.trigger_id == "on_death":
		SpellCast.listen_for_death(self)


func _process(_delta: float) -> void:
	if _visual:
		_visual.scale = Vector3.ONE * SpellVisuals.personality_scale(def, _age)


func _physics_process(delta: float) -> void:
	_age += delta
	if _spent:
		return
	if _age > LIFETIME:
		_fizzle()
		return

	if _fuse > 0.0:
		_fuse -= delta
		if _fuse <= 0.0:
			_trigger_effect(global_position, null)
			return

	if _stuck:
		# Hover in place with a nervous little bob while waiting for its trigger.
		global_position.y += sin(_age * 4.0) * 0.001
		return

	_steer(delta)
	_advance(delta)


func _steer(delta: float) -> void:
	if def.has_behavior("home"):
		var target := _nearest_target(16.0)
		if target:
			var want := (target.global_position + Vector3.UP * 0.8 - global_position).normalized()
			_velocity = _velocity.lerp(want * def.speed, minf(1.0, 5.0 * delta))
	if def.has_rune_tag("wild"):
		_velocity = _velocity.rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6) * delta) \
			.rotated(Vector3.RIGHT, _rng.randf_range(-0.4, 0.4) * delta)


func _advance(delta: float) -> void:
	var from := global_position
	var to := from + _velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to + _velocity.normalized() * _radius,
		SpellCast.HIT_MASK, _excludes())
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		return

	var collider: Object = hit["collider"]
	var pos: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]

	# Shields swat down other people's spells.
	if collider is Node and (collider as Node).has_meta("shield_owner"):
		if (collider as Node).get_meta("shield_owner") != caster.get_instance_id():
			SpellVisuals.spawn_burst(_world(), pos, def.primary_color(), 14, 1.6)
			_die()
			return
		global_position = to
		return

	var is_target: bool = collider != null and (collider.has_method("take_spell_hit")
		or (collider is Node and (collider as Node).is_in_group("spell_target")))

	if is_target and _pierces_left > 0:
		_pierces_left -= 1
		SpellCast.apply_hit(def, collider, pos, _velocity.normalized(), 0.8)
		SpellVisuals.spawn_burst(_world(), pos, def.primary_color(), 8, 1.4)
		global_position = pos + _velocity.normalized() * (_radius + 0.25)
		return

	if not is_target and _bounces_left > 0:
		_bounces_left -= 1
		_velocity = _velocity.bounce(normal) * 0.92
		global_position = pos + normal * (_radius + 0.02)
		SpellVisuals.spawn_burst(_world(), pos, def.primary_color(), 6, 1.0, 0.35)
		return

	match def.trigger_id:
		"when_recast", "on_death":
			_stick(pos + normal * (_radius + 0.03))
		"on_timer":
			if _fuse > 0.0:
				_stick(pos + normal * (_radius + 0.03))
			else:
				_trigger_effect(pos, collider)
		_:
			_trigger_effect(pos, collider)


func _stick(pos: Vector3) -> void:
	_stuck = true
	_velocity = Vector3.ZERO
	global_position = pos


## Called by SpellCast when a recast word or a nearby death sets this off.
func trigger_now() -> void:
	if not _spent:
		_trigger_effect(global_position, null)


func _trigger_effect(pos: Vector3, struck: Object) -> void:
	if _spent:
		return
	if def.has_rune_tag("delayed") and def.trigger_id != "on_timer":
		# The spell holds its breath, then strikes harder (power already scaled).
		_spent = true
		_stuck = true
		_velocity = Vector3.ZERO
		global_position = pos
		var timer := get_tree().create_timer(1.2)
		timer.timeout.connect(_do_effect.bind(pos, struck))
		return
	_spent = true
	_do_effect(pos, struck)


func _do_effect(pos: Vector3, struck: Object) -> void:
	var world := _world()
	if def.has_behavior("explode"):
		SpellCast.explode(def, world, pos, 1.8 * def.size, 0.5 if is_lesser_copy else 1.0)
	elif struck:
		SpellCast.apply_hit(def, struck, pos, _velocity.normalized(),
			0.5 if is_lesser_copy else 1.0)
		SpellVisuals.spawn_burst(world, pos, def.primary_color(), 16, 2.2)
	else:
		SpellVisuals.spawn_burst(world, pos, def.primary_color(), 16, 2.2)

	if def.has_behavior("linger"):
		SpellZone.leave_residue(def, caster, world, pos)

	if def.has_behavior("split") and not is_lesser_copy:
		for i in 3:
			var child := SpellProjectile.new()
			child.setup(def, caster)
			child.is_lesser_copy = true
			child._radius *= 0.6
			world.add_child(child)
			var out := Vector3(sin(i * TAU / 3.0), 1.2, cos(i * TAU / 3.0)).normalized()
			child.global_position = pos + out * 0.3
			child.launch(out)
	_die()


func _fizzle() -> void:
	SpellVisuals.spawn_burst(_world(), global_position, Color(0.6, 0.6, 0.65), 8, 1.0)
	_die()


func _die() -> void:
	_spent = true
	queue_free()


func _nearest_target(max_range: float) -> Node3D:
	var best: Node3D = null
	var best_d := max_range
	for node in get_tree().get_nodes_in_group("spell_target"):
		if node is Node3D and is_instance_valid(node) and not node.get("dead"):
			var d: float = node.global_position.distance_to(global_position)
			if d < best_d:
				best_d = d
				best = node
	return best


func _excludes() -> Array[RID]:
	var out: Array[RID] = []
	if caster is CollisionObject3D:
		out.append((caster as CollisionObject3D).get_rid())
	return out


func _world() -> Node:
	return get_tree().current_scene
