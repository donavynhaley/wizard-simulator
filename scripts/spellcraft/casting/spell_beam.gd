class_name SpellBeam

## The "beam" shape: an instant lance from the hand.
##   pierce  - burns through up to 4 targets along the line
##   bounce  - mirrors off surfaces up to 2 times
##   explode - detonates at the far end
##   linger  - leaves residue where the beam ends
## Precise beams are thinner and reach further.

const BASE_RANGE := 24.0
const MAX_SEGMENTS := 3


static func fire(def: SpellDefinition, caster: Node3D, world: Node, from: Transform3D) -> void:
	var space := caster.get_world_3d().direct_space_state
	var origin := from.origin + from.basis * Vector3(0.25, -0.2, -0.4)
	var dir := -from.basis.z
	var reach := BASE_RANGE * (1.6 if def.has_rune_tag("precise") else 1.0)
	var thickness := 0.06 * def.size * (1.0 - def.thinness() * 0.6)
	var color := def.primary_color()
	var bounces := 2 if def.has_behavior("bounce") else 0
	var pierces := 4 if def.has_behavior("pierce") else 0
	var excludes: Array[RID] = []
	if caster is CollisionObject3D:
		excludes.append((caster as CollisionObject3D).get_rid())

	var end := origin + dir * reach
	var segments := 0
	while segments < MAX_SEGMENTS + pierces:
		segments += 1
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach,
			SpellCast.HIT_MASK, excludes)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			end = origin + dir * reach
			SpellVisuals.segment(world, origin, end, color, thickness)
			break

		var collider: Object = hit["collider"]
		end = hit["position"]
		SpellVisuals.segment(world, origin, end, color, thickness)

		if collider is Node and (collider as Node).has_meta("shield_owner") \
				and (collider as Node).get_meta("shield_owner") != caster.get_instance_id():
			SpellVisuals.spawn_burst(world, end, color, 12, 1.6)
			break

		var is_target: bool = collider.has_method("take_spell_hit") \
			or (collider is Node and (collider as Node).is_in_group("spell_target"))
		if is_target:
			SpellCast.apply_hit(def, collider, end, dir)
			if pierces > 0:
				pierces -= 1
				if collider is CollisionObject3D:
					excludes.append((collider as CollisionObject3D).get_rid())
				origin = end + dir * 0.05
				continue
			break
		if bounces > 0:
			bounces -= 1
			var normal: Vector3 = hit["normal"]
			dir = dir.bounce(normal)
			origin = end + normal * 0.02
			SpellVisuals.spawn_burst(world, end, color, 6, 1.0, 0.3)
			continue
		break

	if def.has_behavior("explode"):
		SpellCast.explode(def, world, end, 1.6 * def.size, 0.9)
	if def.has_behavior("linger"):
		SpellZone.leave_residue(def, caster, world, end)
	if not def.is_silent():
		SpellVisuals.spawn_flash(world, end, color, 0.3)
