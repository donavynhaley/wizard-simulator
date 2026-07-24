class_name FireExplosion
extends Node3D

signal exploded(position: Vector3, radius: float)

@export_group("Blast")
@export_range(0.5, 30.0, 0.25) var damage_radius: float = 6.0
@export_range(0.0, 1000.0, 1.0) var center_damage: float = 100.0
@export_range(0.0, 1000.0, 1.0) var edge_damage: float = 20.0
@export_range(0.0, 100.0, 0.5) var impulse_strength: float = 22.0
@export_range(0.5, 30.0, 0.25) var visual_radius: float = 11.0
@export_range(0.1, 5.0, 0.05) var lifetime: float = 1.4

var element: Element
var caster: Node3D
var _blast_applied: bool = false

@onready var _burst: ArcaneBurst = $ArcaneBurst
@onready var _light: OmniLight3D = $BlastLight
@onready var _audio: AudioStreamPlayer3D = $BlastAudio


func configure(p_element: Element, p_caster: Node3D) -> void:
	element = p_element
	caster = p_caster


func _ready() -> void:
	if _burst != null:
		_burst.max_radius = visual_radius
		_burst.duration = 0.72
		_burst.start_energy = 12.0
		if element != null:
			element.apply_to(_burst)
	if _light != null:
		if element != null:
			_light.light_color = element.color
		var light_fade := create_tween()
		light_fade.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		light_fade.tween_property(_light, ^"light_energy", 0.0, 0.7)
	if _audio != null and DisplayServer.get_name() != "headless":
		_audio.play()
	var cleanup := create_tween()
	cleanup.tween_interval(lifetime)
	cleanup.tween_callback(queue_free)


func _exit_tree() -> void:
	if _audio != null:
		_audio.stop()
		_audio.stream = null


func _physics_process(_delta: float) -> void:
	if _blast_applied:
		return
	_blast_applied = true
	_apply_blast()
	_apply_camera_trauma()
	exploded.emit(global_position, damage_radius)


func _apply_blast() -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = damage_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var results := get_world_3d().direct_space_state.intersect_shape(query, 128)
	var affected: Dictionary[int, bool] = {}
	for result: Dictionary in results:
		var target := result.get("collider") as Node
		if target == null or affected.has(target.get_instance_id()):
			continue
		affected[target.get_instance_id()] = true
		_deliver_to(target)


func _deliver_to(target: Node) -> void:
	var target_node := target as Node3D
	if target_node == null:
		return
	var offset := target_node.global_position - global_position
	var distance := offset.length()
	var falloff := 1.0 - clampf(distance / damage_radius, 0.0, 1.0)
	var direction := offset.normalized() if distance > 0.05 else Vector3.UP
	direction = (direction + Vector3.UP * 0.22).normalized()
	var impact := SpellImpact.new()
	impact.element = element
	impact.damage = lerpf(edge_damage, center_damage, falloff)
	impact.impulse = direction * impulse_strength * lerpf(0.25, 1.0, falloff)
	impact.position = global_position
	impact.direction = direction
	impact.caster = caster
	impact.tags = [&"fire", &"explosion", &"ignite"]
	SpellImpact.deliver(target, impact)


func _apply_camera_trauma() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not camera.has_method(&"add_trauma"):
		return
	var distance := camera.global_position.distance_to(global_position)
	var amount := clampf(1.15 - distance / 30.0, 0.0, 1.0)
	camera.call(&"add_trauma", amount)
