class_name WizardModel

## Shared helpers for the imported wizard character model: skeleton lookup
## and filtering the full-body mesh down to a bone subset. Player-owned models
## are authored directly in player.tscn; ScribeArm uses this factory.

const SCENE := preload("res://assets/third_party/polypizza/Wizardus Maximus.glb")

## A triangle is kept only if all three vertices carry at least this much
## combined weight on the kept bones.
const KEEP_WEIGHT_THRESHOLD := 0.45

## Bones that make up one arm, without the .L/.R side suffix.
const ARM_BONE_STEMS: Array[String] = [
	"DEF-ARM",
	"DEF-FOREARM",
	"DEF-HAND",
	"DEF-THUMB01",
	"DEF-THUMB02",
	"DEF-THUMB03",
	"DEF-FINGER01",
	"DEF-FINGER02",
	"DEF-FINGER03",
]

## The loose hanging sleeve cloth. Separate from the arm proper because its
## bones are unposed outside first person and read as a giant drape up close.
const SLEEVE_BONE_STEMS: Array[String] = [
	"DEF-FOREARM-HANG01",
	"DEF-FOREARM-HANG02",
	"DEF-FOREARM-HANG03",
]


static func instantiate() -> Node3D:
	return SCENE.instantiate()


static func arm_bone_names(
		side_suffix: String,
		include_shoulder: bool,
		include_sleeve: bool = true) -> Array[String]:
	var names: Array[String] = []
	if include_shoulder:
		names.append("DEF-SHOULDER" + side_suffix)
	for stem in ARM_BONE_STEMS:
		names.append(stem + side_suffix)
	if include_sleeve:
		for stem in SLEEVE_BONE_STEMS:
			names.append(stem + side_suffix)
	return names


static func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	var fallback: Skeleton3D
	for child in node.get_children():
		var found := find_skeleton(child)
		if found != null and found.is_inside_tree():
			return found
		if fallback == null:
			fallback = found
	return fallback


static func bone_indices(skeleton: Skeleton3D, bone_names: Array[String]) -> Dictionary:
	var indices := {}
	for bone_name in bone_names:
		var bone := skeleton.find_bone(bone_name)
		if bone != -1:
			indices[bone] = true
	return indices


## Returns every skeleton bone except the named exclusions. This is useful for
## first-person bodies that should retain their silhouette while omitting only
## geometry that would surround the camera.
static func bone_indices_except(skeleton: Skeleton3D, excluded_bone_names: Array[String]) -> Dictionary:
	var excluded := bone_indices(skeleton, excluded_bone_names)
	var indices := {}
	for bone in skeleton.get_bone_count():
		if not excluded.has(bone):
			indices[bone] = true
	return indices


## Replaces every mesh under `node` with a copy containing only the triangles
## skinned to `kept_bones` (a Dictionary of bone index -> true).
static func filter_to_bones(node: Node, kept_bones: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.mesh = _filtered_mesh(mesh_instance.mesh, kept_bones)
	for child in node.get_children():
		filter_to_bones(child, kept_bones)


static func _filtered_mesh(source: Mesh, kept_bones: Dictionary) -> ArrayMesh:
	var filtered := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var source_indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var bones := arrays[Mesh.ARRAY_BONES] as PackedInt32Array
		var weights := arrays[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array
		var kept_indices := PackedInt32Array()

		for i in range(0, source_indices.size(), 3):
			var a := source_indices[i]
			var b := source_indices[i + 1]
			var c := source_indices[i + 2]
			if _bone_weight(a, bones, weights, kept_bones) >= KEEP_WEIGHT_THRESHOLD \
					and _bone_weight(b, bones, weights, kept_bones) >= KEEP_WEIGHT_THRESHOLD \
					and _bone_weight(c, bones, weights, kept_bones) >= KEEP_WEIGHT_THRESHOLD:
				kept_indices.append(a)
				kept_indices.append(b)
				kept_indices.append(c)

		arrays[Mesh.ARRAY_INDEX] = kept_indices
		filtered.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		filtered.surface_set_material(surface, source.surface_get_material(surface))
	return filtered


static func _bone_weight(
		vertex_index: int,
		bones: PackedInt32Array,
		weights: PackedFloat32Array,
		kept_bones: Dictionary) -> float:
	var total := 0.0
	var offset := vertex_index * 4
	for i in 4:
		if kept_bones.has(bones[offset + i]):
			total += weights[offset + i]
	return total
