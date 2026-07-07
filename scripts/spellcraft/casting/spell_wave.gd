class_name SpellWave
extends Node3D

## The "wave" shape: a ring that sweeps outward from the caster along the ground.
##   split  - a second, weaker ring follows half a second later
##   explode- small detonations on each target the front passes over
##   linger - leaves residue at the caster's feet
## Triggers: on_timer delays the sweep; when_recast / on_death arm the wave and
## wait; anything else sweeps immediately.

const SWEEP_TIME := 0.9

var def: SpellDefinition
var caster: Node3D
var is_echo := false

var _max_radius := 6.0
var _radius := 0.2
var _sweeping := false
var _delay := 0.0
var _hit_ids := {}
var _ring: MeshInstance3D
var _age := 0.0


static func sweep(spell: SpellDefinition, from_caster: Node3D, world: Node,
		pos: Vector3, echo: bool = false) -> SpellWave:
	var wave := SpellWave.new()
	wave.def = spell
	wave.caster = from_caster
	wave.is_echo = echo
	world.add_child(wave)
	wave.global_position = pos + Vector3.UP * 0.25
	return wave


func _ready() -> void:
	_max_radius = 6.0 * def.size
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.75
	torus.outer_radius = 1.0 - def.thinness() * 0.15
	_ring.mesh = torus
	_ring.material_override = SpellVisuals.emissive(def.primary_color(), 2.2, 0.8)
	_ring.scale = Vector3.ONE * _radius
	add_child(_ring)
	SpellVisuals.add_light(self, def.primary_color(), 1.2, 5.0)

	match def.trigger_id:
		"on_timer":
			_delay = 1.6 + (1.2 if def.has_rune_tag("delayed") else 0.0)
		"when_recast":
			if not is_echo:
				SpellCast.register_pending(caster, self)
		"on_death":
			if not is_echo:
				SpellCast.listen_for_death(self)
		_:
			_sweeping = true

	if def.has_behavior("linger") and not is_echo:
		SpellZone.leave_residue(def, caster, get_tree().current_scene, global_position)


func trigger_now() -> void:
	_sweeping = true


func _process(delta: float) -> void:
	_age += delta
	var pulse := SpellVisuals.personality_scale(def, _age)
	if not _sweeping:
		if _delay > 0.0:
			_delay -= delta
			if _delay <= 0.0:
				_sweeping = true
		_ring.scale = Vector3(pulse, 0.4, pulse) * maxf(_radius, 0.35)
		return

	_radius += (_max_radius / SWEEP_TIME) * delta
	_ring.scale = Vector3(_radius * pulse, 0.5, _radius * pulse)
	_sweep_front()

	if _radius >= _max_radius:
		if def.has_behavior("split") and not is_echo:
			var echo_wave := SpellWave.sweep(def, caster, get_tree().current_scene,
				global_position - Vector3.UP * 0.25, true)
			echo_wave._sweeping = true
		queue_free()


func _sweep_front() -> void:
	for node in get_tree().get_nodes_in_group("spell_target"):
		if not (node is Node3D) or not is_instance_valid(node):
			continue
		if _hit_ids.has(node.get_instance_id()):
			continue
		var flat: Vector3 = node.global_position - global_position
		flat.y = 0.0
		if absf(flat.length() - _radius) <= 0.6:
			_hit_ids[node.get_instance_id()] = true
			var power_scale := 0.5 if is_echo else 1.0
			SpellCast.apply_hit(def, node, node.global_position, flat.normalized(), power_scale)
			if def.has_behavior("explode"):
				SpellCast.explode(def, get_tree().current_scene, node.global_position,
					1.0 * def.size, 0.5 * power_scale)
			else:
				SpellVisuals.spawn_burst(get_tree().current_scene, node.global_position,
					def.primary_color(), 12, 2.0)
