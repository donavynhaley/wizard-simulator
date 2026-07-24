extends SceneTree

const LEVEL_SCENE := preload("res://game/world/levels/wizard_tower.tscn")
const ROUTE_EXPECTATIONS := {
	&"path_woods": {"seconds": 30.0, "endpoint": Vector3(110.382, -32.300, 53.928)},
	&"path_farm": {"seconds": 60.0, "endpoint": Vector3(-212.779, -31.905, 129.207)},
	&"path_village": {"seconds": 120.0, "endpoint": Vector3(0.0, -31.704, 491.030)},
}

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := LEVEL_SCENE.instantiate() as Node3D
	root.add_child(level)
	await process_frame
	await physics_frame
	await physics_frame

	var exterior := level.get_node_or_null(^"WorldBlockout")
	_check(exterior != null, "wizard tower composes the homestead exterior asset")
	if exterior == null:
		_finish()
		return
	var world_environment := level.get_node_or_null(^"SkyAndTime/WorldEnvironment") as WorldEnvironment
	_check(world_environment != null, "wizard tower has a world environment")
	if world_environment != null:
		var environment := world_environment.environment
		_check(environment != null and environment.fog_enabled,
			"dark fantasy environment enables depth and height fog")
		_check(environment != null and environment.volumetric_fog_enabled,
			"dark fantasy environment enables volumetric fog")
		_check(environment != null and environment.adjustment_saturation < 0.8,
			"dark fantasy environment uses a desaturated color grade")

	var terrain := exterior.find_child("terrain-ground", true, false)
	_check(terrain is MeshInstance3D, "homestead contains the imported terrain mesh")
	if terrain is MeshInstance3D:
		var terrain_mesh := (terrain as MeshInstance3D).mesh
		_check(terrain_mesh != null, "imported terrain has mesh geometry")
		if terrain_mesh != null:
			_check(terrain_mesh.get_aabb().size.y >= 31.0,
				"tower hill has at least 31 meters of modeled vertical relief")
			var terrain_material := terrain_mesh.surface_get_material(0) as BaseMaterial3D
			_check(terrain_material != null and terrain_material.albedo_texture != null,
				"imported terrain uses a textured dark moss and earth material")
	_check(_count_nodes_of_type(exterior, &"StaticBody3D") >= 13,
		"homestead imports static collision for terrain and destination structures")
	var summit_height := _ground_height(level, Vector2(-12.0, -8.0))
	var lowland_height := _ground_height(level, Vector2(-130.0, -130.0))
	var height_samples_found := not is_nan(summit_height) and not is_nan(lowland_height)
	_check(height_samples_found, "hill height samples hit terrain collision")
	if height_samples_found:
		_check(summit_height - lowland_height >= 30.0,
			"tower summit rises at least 30 meters above the surrounding lowland")
	var forest_trees := exterior.find_children("forest_tree_*", "MeshInstance3D", true, false)
	_check(forest_trees.size() == 360, "forest belt contains 360 reused tree instances")
	var source_tree_models := {
		"tree_1.glb": false,
		"tree_2.glb": false,
		"tree_3.glb": false,
	}
	var corrected_tree_rotations := 0
	var authored_tilted_tree_rotations := 0
	var trees_at_hill_base := 0
	for tree_node in forest_trees:
		var tree := tree_node as MeshInstance3D
		var import_extras := tree.get_meta(&"extras", {}) as Dictionary
		var source_model := import_extras.get("source_tree_model", "") as String
		if source_tree_models.has(source_model):
			source_tree_models[source_model] = true
		if bool(import_extras.get("source_rotation_preserved", false)):
			corrected_tree_rotations += 1
		if source_model != "tree_1.glb":
			var imported_up := tree.global_transform.basis.y.normalized()
			if absf(imported_up.dot(Vector3.UP)) < 0.999:
				authored_tilted_tree_rotations += 1
		var tree_radius := Vector2(tree.global_position.x, tree.global_position.z).length()
		if tree_radius >= 100.0 and tree_radius <= 162.0:
			trees_at_hill_base += 1
	var reused_source_count := 0
	for source_model in source_tree_models:
		if source_tree_models[source_model]:
			reused_source_count += 1
	_check(reused_source_count == 3, "forest belt reuses all three existing tree models")
	_check(corrected_tree_rotations == forest_trees.size(),
		"forest trees preserve their source-model orientation")
	_check(authored_tilted_tree_rotations == 240,
		"crooked tree variants retain their authored non-yaw rotations")
	_check(trees_at_hill_base == forest_trees.size(),
		"forest trees surround the base of the hill")

	for path_name: StringName in ROUTE_EXPECTATIONS:
		var path_node := exterior.find_child(path_name, true, false)
		var expected: Dictionary = ROUTE_EXPECTATIONS[path_name]
		_check(path_node is MeshInstance3D, "%s exists" % path_name)
		if path_node == null:
			continue
		var import_extras := path_node.get_meta(&"extras", {}) as Dictionary
		var measured_seconds := float(import_extras.get("route_length_m", -1.0)) / 4.2
		_check(absf(measured_seconds - float(expected.seconds)) < 0.25,
			"%s matches its target walking time" % path_name)
		_check(_ray_hits_world(level, expected.endpoint),
			"%s endpoint has walkable collision beneath it" % path_name)

	var woods_endpoint: Vector3 = ROUTE_EXPECTATIONS[&"path_woods"].endpoint
	var farm_endpoint: Vector3 = ROUTE_EXPECTATIONS[&"path_farm"].endpoint
	var village_endpoint: Vector3 = ROUTE_EXPECTATIONS[&"path_village"].endpoint
	_check(woods_endpoint.x > 100.0, "woods lie to the right of the tower")
	_check(farm_endpoint.x < -200.0, "farm lies to the left of the tower")
	_check(village_endpoint.z > 490.0, "village lies along the center route")
	# Entrance points are TowerArchitecture-local; the tower moved off the
	# world origin in the 2026-07-21 scene split.
	var entrance_architecture := level.get_node(^"TowerArchitecture") as Node3D
	var entrance_inside: Vector3 = entrance_architecture.to_global(Vector3(0.0, 1.4, 3.8))
	var entrance_outside: Vector3 = entrance_architecture.to_global(Vector3(0.0, 1.4, 7.2))
	_check(_ray_hits_between(level, entrance_inside, entrance_outside),
		"closed tower door blocks the entrance facing the exterior paths")
	# The entrance is warded shut behind a starved Bind; feeding the lantern
	# (Case Minus One's feed_the_ward resolution) swings the door open.
	var ward_source := level.get_node(
		^"TowerArchitecture/GroundFloorProps/DoorLantern/MagicalFlame/FireSource") as ElementSource
	ward_source.restore(ward_source.global_position + Vector3.UP * 0.5)
	for _frame in 150:
		await physics_frame
	_check(not _ray_hits_between(level, entrance_inside, entrance_outside),
		"open tower door clears the entrance facing the exterior paths")

	level.queue_free()
	await process_frame
	_finish()


func _ray_hits_world(level: Node3D, endpoint: Vector3) -> bool:
	var world := level.get_world_3d()
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(endpoint.x, 40.0, endpoint.z),
		Vector3(endpoint.x, -40.0, endpoint.z))
	var result := world.direct_space_state.intersect_ray(query)
	return not result.is_empty()


func _ground_height(level: Node3D, horizontal_position: Vector2) -> float:
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(horizontal_position.x, 40.0, horizontal_position.y),
		Vector3(horizontal_position.x, -40.0, horizontal_position.y))
	var result := level.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return NAN
	return (result.position as Vector3).y


func _ray_hits_between(level: Node3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	return not level.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _count_nodes_of_type(node: Node, type_name: StringName) -> int:
	var count := 1 if node.is_class(type_name) else 0
	for child in node.get_children():
		count += _count_nodes_of_type(child, type_name)
	return count


func _finish() -> void:
	if _failures == 0:
		print("HOMESTEAD ENVIRONMENT TEST OK")
	else:
		print("HOMESTEAD ENVIRONMENT TEST FAILURES: ", _failures)
	quit(_failures)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		_failures += 1
		push_error("[FAIL] " + message)
