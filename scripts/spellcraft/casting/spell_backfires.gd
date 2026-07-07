class_name SpellBackfires

## The forge's comedic failure modes. Failure should be entertaining:
##   frog    - the caster spends 10 seconds low, slow, and hoppy
##   blast   - everyone near the bench is launched backward
##   demon   - a tiny useless demon is summoned
##   scatter - the runes fling themselves off the bench (handled by the bench)

const FROG_TIME := 10.0

const TINY_DEMON_SCENE := "res://scenes/props/tiny_demon.tscn"


static func run(kind: String, caster: Node3D, world: Node, pos: Vector3) -> void:
	match kind:
		"frog":
			frog(caster, world)
		"blast":
			blast(world, pos)
		"demon":
			demon(world, pos)
		_:
			pass  # "scatter" is physical and lives in SpellBench.


static func frog(caster: Node3D, world: Node) -> void:
	if caster.get_node_or_null("FrogCurse"):
		return  # already a frog; deeply a frog
	var curse := FrogCurse.new()
	curse.name = "FrogCurse"
	caster.add_child(curse)
	SpellVisuals.spawn_burst(world, caster.global_position + Vector3.UP * 0.8,
		Color(0.4, 0.85, 0.3), 26, 2.6)
	SpellVisuals.floating_text(world, caster.global_position + Vector3.UP * 1.4,
		"ribbit.", Color(0.5, 1.0, 0.4))


static func blast(world: Node, pos: Vector3) -> void:
	SpellVisuals.spawn_flash(world, pos + Vector3.UP * 0.8, Color(1.0, 0.6, 0.9), 1.2)
	SpellVisuals.spawn_burst(world, pos + Vector3.UP * 0.8, Color(1.0, 0.6, 0.9), 36, 5.0)
	for node: Variant in world.get_tree().get_nodes_in_group("blastable") + \
			[world.get_tree().get_first_node_in_group("player")]:
		if node == null or not (node is Node3D) or not is_instance_valid(node):
			continue
		var away: Vector3 = node.global_position - pos
		if away.length() > 6.0:
			continue
		var shove := (away.normalized() + Vector3.UP * 0.8).normalized() * 9.0
		if node is CharacterBody3D:
			node.velocity += shove
		elif node is RigidBody3D:
			node.apply_central_impulse(shove * 2.0)


static func demon(world: Node, pos: Vector3) -> void:
	var scene: PackedScene = load(TINY_DEMON_SCENE)
	if scene == null:
		return
	var imp := scene.instantiate()
	world.add_child(imp)
	if imp is Node3D:
		imp.global_position = pos + Vector3.UP * 0.6
	SpellVisuals.spawn_burst(world, pos + Vector3.UP * 0.6, Color(0.9, 0.2, 0.2), 20, 2.4)


## Attached to the caster for the duration of the frog curse. Squashes the view
## down to frog height, halves speed, makes jumps hoppy, croaks periodically,
## then puts everything back the way it was.
class FrogCurse:
	extends Node

	var _time_left := FROG_TIME
	var _croak := 1.2
	var _old_speed: Variant
	var _old_jump: Variant
	var _old_head_y: Variant

	func _ready() -> void:
		var caster := get_parent()
		_old_speed = caster.get("move_speed")
		_old_jump = caster.get("jump_velocity")
		if _old_speed != null:
			caster.set("move_speed", float(_old_speed) * 0.45)
		if _old_jump != null:
			caster.set("jump_velocity", float(_old_jump) * 1.3)
		var head := caster.get_node_or_null("Head") as Node3D
		if head:
			_old_head_y = head.position.y
			head.position.y = float(_old_head_y) * 0.3

	func _process(delta: float) -> void:
		_time_left -= delta
		_croak -= delta
		var caster := get_parent() as Node3D
		if _croak <= 0.0 and caster:
			_croak = 1.4
			SpellVisuals.floating_text(get_tree().current_scene,
				caster.global_position + Vector3.UP * 0.7, "ribbit",
				Color(0.5, 1.0, 0.4), 28)
		if _time_left <= 0.0:
			_lift()

	func _lift() -> void:
		var caster := get_parent()
		if _old_speed != null:
			caster.set("move_speed", _old_speed)
		if _old_jump != null:
			caster.set("jump_velocity", _old_jump)
		var head := caster.get_node_or_null("Head") as Node3D
		if head and _old_head_y != null:
			head.position.y = _old_head_y
		var caster_3d := caster as Node3D
		if caster_3d:
			SpellVisuals.spawn_burst(get_tree().current_scene,
				caster_3d.global_position + Vector3.UP * 0.8, Color(0.4, 0.85, 0.3), 18, 2.0)
		queue_free()
