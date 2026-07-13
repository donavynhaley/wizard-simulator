extends SceneTree

# Prints the axis-aligned bounding box of curated runtime Kenney pieces.
# Run with: godot --headless --path . -s tools/inspection/inspect_assets.gd

const PIECES := [
	"res://assets/third_party/kenney/fantasy_town/pillar-wood.glb",
	"res://assets/third_party/kenney/fantasy_town/planks.glb",
	"res://assets/third_party/kenney/fantasy_town/overhang.glb",
	"res://assets/third_party/kenney/fantasy_town/chimney-base.glb",
	"res://assets/third_party/kenney/fantasy_town/fountain-square-detail.glb",
]


func _init() -> void:
	for path in PIECES:
		if not ResourceLoader.exists(path):
			print("MISSING: ", path)
			continue
		var packed := load(path) as PackedScene
		var inst := packed.instantiate()
		var aabb := _merged_aabb(inst, Transform3D.IDENTITY)
		var s := aabb.size
		var p := aabb.position
		print("%-52s size=(%5.2f,%5.2f,%5.2f) min=(%5.2f,%5.2f,%5.2f)" % [
			path.get_file(), s.x, s.y, s.z, p.x, p.y, p.z])
		inst.free()
	quit()


func _merged_aabb(node: Node, xform: Transform3D) -> AABB:
	var result := AABB()
	var has_any := false
	if node is Node3D:
		xform = xform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh:
			var local := mesh.get_aabb()
			var world := xform * local
			result = world
			has_any = true
	for child in node.get_children():
		var child_aabb := _merged_aabb(child, xform)
		if child_aabb.size != Vector3.ZERO or child_aabb.position != Vector3.ZERO:
			if has_any:
				result = result.merge(child_aabb)
			else:
				result = child_aabb
				has_any = true
	return result
