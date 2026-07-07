class_name SpellShield
extends Node3D

## The "shield" shape: a dome around the caster that swats down incoming spells.
## The dome body sits alone on the shield collision layer, so it never trips up
## movement; projectiles and beams check the "shield_owner" meta and die on it.
## The caster's own spells pass freely (rays start inside the dome).
##   linger  - doubles the duration
##   explode - the dome detonates outward when it expires

const DURATION := 6.0

var def: SpellDefinition
var caster: Node3D

var _life := 0.0
var _age := 0.0
var _dome: MeshInstance3D


static func raise(spell: SpellDefinition, from_caster: Node3D, world: Node) -> SpellShield:
	var shield := SpellShield.new()
	shield.def = spell
	shield.caster = from_caster
	world.add_child(shield)
	shield.global_position = from_caster.global_position
	return shield


func _ready() -> void:
	_life = DURATION * (2.0 if def.has_behavior("linger") else 1.0)
	var radius := 1.7 * def.size

	var body := StaticBody3D.new()
	body.collision_layer = SpellCast.LAYER_SHIELD
	body.collision_mask = 0
	body.set_meta("shield_owner", caster.get_instance_id())
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	body.add_child(shape)
	add_child(body)
	body.position.y = 0.9

	_dome = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	_dome.mesh = mesh
	_dome.material_override = SpellVisuals.emissive(def.primary_color(), 1.0, 0.16)
	_dome.position.y = 0.9
	add_child(_dome)
	SpellVisuals.add_light(self, def.primary_color(), 0.8, radius * 2.0)


func _process(delta: float) -> void:
	_age += delta
	_life -= delta
	if is_instance_valid(caster):
		global_position = caster.global_position
	if _dome:
		var pulse := SpellVisuals.personality_scale(def, _age)
		_dome.scale = Vector3.ONE * pulse
		if _life < 1.0:
			_dome.transparency = 1.0 - _life  # polite warning before it drops
	if _life <= 0.0:
		if def.has_behavior("explode"):
			SpellCast.explode(def, get_tree().current_scene,
				global_position + Vector3.UP * 0.9, 2.4 * def.size, 0.8)
		queue_free()
