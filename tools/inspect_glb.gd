extends SceneTree

# Prints the node tree, mesh AABBs, and rig/animation info of a GLB so it can be
# mounted correctly. Edit PATH and run headless:
#   godot --headless --path . -s tools/inspect_glb.gd

const DEFAULT_PATH := "res://assets/external/polypizza/fps_arms.glb"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if not args.is_empty() else DEFAULT_PATH
	if not ResourceLoader.exists(path):
		print("MISSING: ", path)
		quit()
		return
	var inst := (load(path) as PackedScene).instantiate()
	print("=== node tree ===")
	_walk(inst, 0)
	var aabb := _merged_aabb(inst, Transform3D.IDENTITY)
	print("=== merged AABB size=(%.3f,%.3f,%.3f) min=(%.3f,%.3f,%.3f) ===" % [aabb.size.x, aabb.size.y, aabb.size.z, aabb.position.x, aabb.position.y, aabb.position.z])
	inst.free()
	quit()


func _walk(node: Node, depth: int) -> void:
	var extra := ""
	if node is MeshInstance3D and node.mesh:
		extra = "  mesh surfaces=%d aabb=%s" % [node.mesh.get_surface_count(), str(node.mesh.get_aabb().size)]
		if node.skin:
			extra += "  [SKINNED]"
	if node is Skeleton3D:
		extra = "  bones=%d" % node.get_bone_count()
	if node is AnimationPlayer:
		extra = "  anims=%s" % str(node.get_animation_list())
	print("%s- %s (%s)%s" % ["  ".repeat(depth), node.name, node.get_class(), extra])
	for c in node.get_children():
		_walk(c, depth + 1)


func _merged_aabb(node: Node, xform: Transform3D) -> AABB:
	var result := AABB()
	var has_any := false
	if node is Node3D:
		xform = xform * (node as Node3D).transform
	if node is MeshInstance3D and node.mesh:
		result = xform * node.mesh.get_aabb()
		has_any = true
	for child in node.get_children():
		var c := _merged_aabb(child, xform)
		if c.size != Vector3.ZERO:
			result = result.merge(c) if has_any else c
			has_any = true
	return result
