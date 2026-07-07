extends SceneTree

# Prints the axis-aligned bounding box of key Kenney GLB pieces so the tower can
# be tiled to the correct module grid. Run headless:
#   godot --headless --path . -s tools/inspect_assets.gd

const PIECES := [
	"res://assets/external/kenney/modular-dungeon-kit/Models/GLB format/template-floor.glb",
	"res://assets/external/kenney/modular-dungeon-kit/Models/GLB format/template-floor-big.glb",
	"res://assets/external/kenney/modular-dungeon-kit/Models/GLB format/template-wall.glb",
	"res://assets/external/kenney/modular-dungeon-kit/Models/GLB format/template-wall-half.glb",
	"res://assets/external/kenney/modular-dungeon-kit/Models/GLB format/template-wall-corner.glb",
	"res://assets/external/kenney/modular-dungeon-kit/Models/GLB format/room-large.glb",
	"res://assets/external/kenney/modular-dungeon-kit/Models/GLB format/room-wide.glb",
	"res://assets/external/kenney/modular-dungeon-kit/Models/GLB format/stairs.glb",
	"res://assets/external/kenney/modular-dungeon-kit/Models/GLB format/stairs-wide.glb",
	"res://assets/external/kenney/modular-dungeon-kit/Models/GLB format/wall.glb",
	"res://assets/external/kenney/modular-dungeon-kit/Models/GLB format/wall-half.glb",
	"res://assets/external/kenney/modular-dungeon-kit/Models/GLB format/floor.glb",
	"res://assets/external/kenney/modular-dungeon-kit/Models/GLB format/column.glb",
	"res://assets/external/kenney/modular-dungeon-kit/Models/GLB format/gate.glb",
	"res://assets/external/kenney/modular-dungeon-kit/Models/GLB format/gate-door-window.glb",
	"res://assets/external/kenney/fantasy-town-kit/Models/GLB format/stairs-stone.glb",
	"res://assets/external/kenney/fantasy-town-kit/Models/GLB format/wall-window-glass.glb",
	"res://assets/external/kenney/fantasy-town-kit/Models/GLB format/wall-window-stone.glb",
	"res://assets/external/kenney/retro-fantasy-kit/Models/GLB format/floor.glb",
	"res://assets/external/kenney/retro-fantasy-kit/Models/GLB format/tower-base.glb",
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
