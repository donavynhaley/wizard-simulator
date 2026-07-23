class_name AwakenedPresence
extends Node3D
## The Wizard Sight signifier of an awakened object. In a theater where
## everything is still, the alive thing moves: the parent object's silhouette
## BREATHES - its lamp rim slowly swells and dims via the shadow-puppet instance
## uniforms, desynced per object so no two things breathe in step.
##
## Drop this node under any awakened prop and it tags the parent's meshes with
## breath. This is the future Animate rune's mark; Silence will one day still it.
## (Marionette strings were tried here and cut - the breath alone is the tell.)

@export var breath_strength := 0.55

var _phase := 0.0


func _ready() -> void:
	# Deterministic desync so two awakened things never breathe in step.
	_phase = fmod(float(get_instance_id() % 97) * 0.37, TAU)
	# Parent transforms may still be settling (the door binds/reparents its
	# imported visual), so tag the body a frame later.
	_setup.call_deferred()


func _setup() -> void:
	var body := get_parent() as Node3D
	if body == null:
		return
	var meshes: Array[MeshInstance3D] = []
	_collect(body, meshes)
	for mesh in meshes:
		mesh.set_instance_shader_parameter(&"breath_amount", breath_strength)
		mesh.set_instance_shader_parameter(&"breath_phase", _phase)


## Walks the awakened body for its silhouette meshes, skipping anything already
## outside the shadow fade.
func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	if node == self or node.is_in_group(&"sight_no_fade"):
		return
	var mesh := node as MeshInstance3D
	if mesh != null:
		out.append(mesh)
	for child in node.get_children():
		_collect(child, out)
