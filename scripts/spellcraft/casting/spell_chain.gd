class_name SpellChain

## The "chain" shape: magic that leaps target to target with damage falloff.
##   split   - two extra hops
##   explode - detonation at the final link
##   linger  - residue under every struck target
## The first link follows the aim ray; hops then seek the nearest unvisited
## target within reach. Arcs render as kinked segments, more kinked when raging.

const FIRST_RANGE := 20.0
const HOP_RANGE := 8.0
const BASE_HOPS := 4
const FALLOFF := 0.75


static func lash(def: SpellDefinition, caster: Node3D, world: Node, from: Transform3D) -> void:
	var space := caster.get_world_3d().direct_space_state
	var origin := from.origin + from.basis * Vector3(0.25, -0.2, -0.4)
	var color := def.primary_color()

	var first := _first_target(def, caster, space, from)
	if first == null:
		# Nothing to leap to: a short arc snaps at the air and grounds out.
		var end := origin - from.basis.z * 4.0
		_draw_arc(def, world, origin, end, color)
		SpellVisuals.spawn_burst(world, end, color, 10, 1.6)
		return

	var hops := BASE_HOPS + (2 if def.has_behavior("split") else 0)
	var visited := {}
	var prev := origin
	var target: Node3D = first
	var power := 1.0
	var last_pos := origin
	for i in hops:
		if target == null:
			break
		var pos := target.global_position + Vector3.UP * 0.8
		_draw_arc(def, world, prev, pos, color)
		SpellCast.apply_hit(def, target, pos, (pos - prev).normalized(), power)
		if def.has_behavior("linger"):
			SpellZone.leave_residue(def, caster, world, target.global_position)
		visited[target.get_instance_id()] = true
		last_pos = pos
		prev = pos
		power *= FALLOFF
		target = _next_target(caster, pos, visited)

	if def.has_behavior("explode"):
		SpellCast.explode(def, world, last_pos, 1.4 * def.size, 0.8)


static func _first_target(def: SpellDefinition, caster: Node3D,
		space: PhysicsDirectSpaceState3D, from: Transform3D) -> Node3D:
	var excludes: Array[RID] = []
	if caster is CollisionObject3D:
		excludes.append((caster as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(from.origin,
		from.origin - from.basis.z * FIRST_RANGE, SpellCast.HIT_MASK, excludes)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var collider := hit["collider"] as Node3D
		if collider and (collider.is_in_group("spell_target")
				or collider.has_method("take_spell_hit")):
			return collider
	# Aim ray missed; be generous and grab the nearest target in front of the caster.
	return _next_target(caster, from.origin - from.basis.z * 3.0, {})


static func _next_target(caster: Node3D, pos: Vector3, visited: Dictionary) -> Node3D:
	var best: Node3D = null
	var best_d := HOP_RANGE
	for node in caster.get_tree().get_nodes_in_group("spell_target"):
		if not (node is Node3D) or not is_instance_valid(node):
			continue
		if visited.has(node.get_instance_id()) or node.get("dead"):
			continue
		var d: float = (node as Node3D).global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = node
	return best


static func _draw_arc(def: SpellDefinition, world: Node, from: Vector3, to: Vector3,
		color: Color) -> void:
	var kink := 0.15 + def.jaggedness() * 0.5
	var thickness := 0.035 * def.size * (1.0 - def.thinness() * 0.5)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var points: Array[Vector3] = [from]
	var steps := 4
	for i in range(1, steps):
		var along := from.lerp(to, float(i) / steps)
		points.append(along + Vector3(
			rng.randf_range(-kink, kink),
			rng.randf_range(-kink, kink),
			rng.randf_range(-kink, kink)))
	points.append(to)
	for i in points.size() - 1:
		SpellVisuals.segment(world, points[i], points[i + 1], color, thickness, 0.28)
