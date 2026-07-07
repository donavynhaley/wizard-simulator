extends Node3D

## Temporary workshop room for exercising the spellcraft assets while the real
## tower is built by hand. Everything here is one of the drop-in props:
## SpellBench, RuneCabinet, TrainingDummy, plus the player. Swap the main scene
## back to the tower whenever it is ready; nothing in here is load-bearing.

const BENCH := preload("res://scenes/props/spell_bench.tscn")
const CABINET := preload("res://scenes/props/rune_cabinet.tscn")
const DUMMY := preload("res://scenes/props/training_dummy.tscn")

const ROOM := 18.0
const WALL_H := 5.0


func _ready() -> void:
	_build_room()
	_build_lighting()
	_place_props()


func _build_room() -> void:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.28, 0.26, 0.3)
	floor_mat.roughness = 0.95
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.36, 0.31, 0.28)
	wall_mat.roughness = 0.9

	_slab("Floor", Vector3(ROOM, 0.4, ROOM), Vector3(0, -0.2, 0), floor_mat)
	_slab("WallN", Vector3(ROOM, WALL_H, 0.4), Vector3(0, WALL_H * 0.5, -ROOM * 0.5), wall_mat)
	_slab("WallS", Vector3(ROOM, WALL_H, 0.4), Vector3(0, WALL_H * 0.5, ROOM * 0.5), wall_mat)
	_slab("WallE", Vector3(0.4, WALL_H, ROOM), Vector3(ROOM * 0.5, WALL_H * 0.5, 0), wall_mat)
	_slab("WallW", Vector3(0.4, WALL_H, ROOM), Vector3(-ROOM * 0.5, WALL_H * 0.5, 0), wall_mat)


func _slab(slab_name: String, size: Vector3, pos: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.name = slab_name
	body.collision_layer = SpellCast.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)
	body.position = pos


func _build_lighting() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.045, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.42, 0.55)
	env.ambient_light_energy = 0.7
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.1, 0.16)
	env.fog_density = 0.012
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	key.light_color = Color(1.0, 0.92, 0.78)
	key.light_energy = 0.95
	add_child(key)

	var warm := OmniLight3D.new()
	warm.position = Vector3(0, 3.6, 0)
	warm.light_color = Color(1.0, 0.75, 0.45)
	warm.light_energy = 1.6
	warm.omni_range = 14.0
	add_child(warm)


func _place_props() -> void:
	var bench := BENCH.instantiate()
	add_child(bench)
	bench.position = Vector3(0, 0, -1.5)

	var cabinet := CABINET.instantiate()
	add_child(cabinet)
	cabinet.position = Vector3(0, 0, -8.5)

	for i in 3:
		var dummy := DUMMY.instantiate()
		add_child(dummy)
		dummy.position = Vector3(5.5 + (i % 2) * 1.5, 0, -3.0 + i * 2.6)
		dummy.rotation.y = -PI * 0.5
