extends SceneTree

## Checks the book's data-driven visuals and table reference reading. The
## held/read-in-hand flow is dormant until the custody rework lands. Run:
##   godot --headless --path . -s tests/integration/book_interaction_test.gd

const PLAYER_SCENE := preload("res://game/player/player.tscn")
const BOOK_SCENE := preload("res://game/books/book.tscn")

var _fail := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world

	var player := PLAYER_SCENE.instantiate() as WizardPlayer
	world.add_child(player)
	var book := BOOK_SCENE.instantiate() as Book
	world.add_child(book)
	await process_frame
	_check(InputMap.has_action(&"book_focus"),
		"book focus has a keyboard, mouse, and controller-ready input action")

	var visual_profile := book.book_data.get("visual_profile") as Resource
	var closed_model_socket := book.get_node_or_null(
		"Visual/VisualRoot/MotionRoot/ClosedVisual/ModelSocket") as Node3D
	var open_model_socket := book.get_node_or_null(
		"Visual/VisualRoot/MotionRoot/OpenVisual/ModelSocket") as Node3D
	_check(visual_profile != null, "book content selects a reusable visual profile")
	_check(closed_model_socket != null and closed_model_socket.get_child_count() == 1,
		"book visual instantiates its closed model through a model socket")
	_check(open_model_socket != null and open_model_socket.get_child_count() == 1,
		"book visual instantiates its open model through a model socket")
	var imported_open_meshes := open_model_socket.find_children(
		"*", "MeshInstance3D", true, false)
	var authored_open_mesh := imported_open_meshes[0] as MeshInstance3D \
		if not imported_open_meshes.is_empty() else null
	var authored_detail_meshes := open_model_socket.find_children(
		"JournalDetail_*", "MeshInstance3D", true, false)
	_check(authored_detail_meshes.size() >= 16,
		"open-book model includes authored spine, trim, stitching, and hardware details")
	var center_top := -INF
	var outer_top := -INF
	if authored_open_mesh != null and authored_open_mesh.mesh != null:
		for surface in authored_open_mesh.mesh.get_surface_count():
			var vertices := authored_open_mesh.mesh.surface_get_arrays(
				surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array
			for vertex in vertices:
				var model_point := open_model_socket.to_local(
					authored_open_mesh.to_global(vertex))
				if absf(model_point.x) < 0.01:
					center_top = maxf(center_top, model_point.y)
				elif absf(model_point.x) > 0.17:
					outer_top = maxf(outer_top, model_point.y)
	_check(outer_top - center_top > 0.009,
		"authored open-book model dips with the curved page overlay at the spine " \
		+ "(center=%.4f, outer=%.4f)" % [center_top, outer_top])
	_check(book.get_display_name() == "Bolt Rune Book",
		"rune book display name comes from the rune template")

	# Table reference reading (the crafter-facing flow, no hands involved).
	book.set_stationed(true)
	book.open_for_reference()
	await process_frame
	var closed_visual := book.get_node("Visual/VisualRoot/MotionRoot/ClosedVisual") as Node3D
	var open_visual := book.get_node("Visual/VisualRoot/MotionRoot/OpenVisual") as Node3D
	var page_surface := book.get_node(
		"Visual/VisualRoot/MotionRoot/OpenVisual/PageSurface") as Node3D
	_check(not closed_visual.visible, "closed book model hides for reference reading")
	_check(open_visual.visible, "the reusable open visual shows for table reference reading")
	_check(page_surface.visible, "table page surface shows for reference reading")
	var physical_page_mesh := book.get_node(
		"Visual/VisualRoot/MotionRoot/OpenVisual/PageSurface/LeftPage") as MeshInstance3D
	var physical_page_material := physical_page_mesh.material_override as BaseMaterial3D
	_check(physical_page_material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED,
		"physical world books retain their authored lighting response")

	var left_title := book.get_node("PageRenderer/SpreadRoot/Pages/LeftPage/Margin/Column/LeftTitle") as Label
	var right_title := book.get_node("PageRenderer/SpreadRoot/Pages/RightPage/Margin/Column/RightTitle") as Label
	var rune_view := book.get_node("PageRenderer/SpreadRoot/Pages/RightPage/Margin/Column/RightRuneView") as RuneTemplateView
	var page_viewport := book.get_node("PageRenderer") as SubViewport
	var left_page := book.get_node("PageRenderer/SpreadRoot/Pages/LeftPage") as PanelContainer
	var right_page := book.get_node("PageRenderer/SpreadRoot/Pages/RightPage") as PanelContainer
	var left_paper := left_page.get_theme_stylebox("panel") as StyleBoxFlat
	var right_paper := right_page.get_theme_stylebox("panel") as StyleBoxFlat
	var expected_paper_color := Color(0.77, 0.7, 0.56)
	_check(left_paper.bg_color.is_equal_approx(expected_paper_color)
		and right_paper.bg_color.is_equal_approx(expected_paper_color),
		"both physical book pages use the authored palette paper color")
	_check(left_title.text == "Bolt Rune", "book writes its authored left page title")
	_check(right_title.text == "Scribing Pattern", "book writes its authored right page title")
	_check(rune_view.visible, "rune book shows the rune template on its page")
	_check(bool(rune_view.call("is_playback_active")), "rune page starts stroke playback")
	_check(page_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"book page viewport updates continuously during rune playback")
	_check(book.has_loaded_rune_template(), "rune book loads template strokes")

	# Reference page turning stays gated behind the scribing station toggle.
	book.book_data = book.book_data.duplicate(true) as BookData
	var extra_spread := BookSpreadData.new()
	var extra_left := BookPageData.new()
	extra_left.title = "Second Spread"
	extra_left.body = "second spread left"
	var extra_right := BookPageData.new()
	extra_right.title = "Third Page"
	extra_right.body = "second spread right"
	extra_spread.left_page = extra_left
	extra_spread.right_page = extra_right
	book.book_data.spreads.append(extra_spread)
	book.current_page = 0
	book.call("_update_page_content")
	var move_right_event := InputEventAction.new()
	move_right_event.action = &"move_right"
	move_right_event.pressed = true
	book._input(move_right_event)
	_check(book.current_page == 0, "table book does not turn pages outside scribing")
	book.set_reference_page_turn_enabled(true)
	book._input(move_right_event)
	var visual := book.get_node("Visual") as BookVisual
	var resting_spine := visual._page_vertex(-1, 0.0, 0.0, false, 0.0)
	var resting_outer_edge := visual._page_vertex(-1, 1.0, 0.0, false, 0.0)
	_check(resting_spine.y < resting_outer_edge.y - 0.009,
		"resting pages dip inward into the spine gutter")
	visual._set_book_open_amount(0.0)
	var closed_outer_edge := visual._page_vertex(-1, 1.0, 0.0, false, 0.0)
	visual._set_book_open_amount(1.0)
	_check(absf(closed_outer_edge.x) < absf(resting_outer_edge.x) * 0.25
		and closed_outer_edge.y > resting_outer_edge.y + 0.15,
		"book pages hinge upward around the spine instead of swapping open models")
	var first_left_thickness := visual._page_stack_thickness(-1)
	var first_right_thickness := visual._page_stack_thickness(1)
	_check(first_right_thickness > first_left_thickness + 0.01,
		"first spread has a physically thick right stack and thin left stack")
	var first_right_outer_edge := visual._page_vertex(1, 1.0, 0.0, false, 0.0)
	_check(is_equal_approx(resting_outer_edge.y, first_right_outer_edge.y),
		"opposing readable sheets stay on one plane instead of growing toward the camera")
	var middle_total_thickness := visual._page_stack_thickness_at(-1, 0.5) \
		+ visual._page_stack_thickness_at(1, 0.5)
	_check(is_equal_approx(
		first_left_thickness + first_right_thickness,
		middle_total_thickness),
		"turning pages transfers a constant total paper thickness between sides")
	var left_page_stack := visual.get_node(
		"VisualRoot/MotionRoot/OpenVisual/PageSurface/LeftPageStack") as MeshInstance3D
	var right_page_stack := visual.get_node(
		"VisualRoot/MotionRoot/OpenVisual/PageSurface/RightPageStack") as MeshInstance3D
	var stack_vertices := left_page_stack.mesh.surface_get_arrays(
		0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var right_stack_vertices := right_page_stack.mesh.surface_get_arrays(
		0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var stack_center_top := -INF
	var stack_outer_top := -INF
	var left_outer_bottom := INF
	var right_outer_top := -INF
	var right_outer_bottom := INF
	for vertex in stack_vertices:
		if absf(vertex.x) < 0.01:
			stack_center_top = maxf(stack_center_top, vertex.y)
		elif absf(vertex.x) > 0.17:
			stack_outer_top = maxf(stack_outer_top, vertex.y)
			left_outer_bottom = minf(left_outer_bottom, vertex.y)
	for vertex in right_stack_vertices:
		if absf(vertex.x) > 0.17:
			right_outer_top = maxf(right_outer_top, vertex.y)
			right_outer_bottom = minf(right_outer_bottom, vertex.y)
	_check(stack_center_top < stack_outer_top - 0.009,
		"page stack follows the inward gutter instead of intersecting it")
	_check(is_equal_approx(stack_outer_top, right_outer_top),
		"both page blocks meet the fixed readable page plane")
	_check(right_outer_bottom < left_outer_bottom - 0.01,
		"the thick page block gains depth underneath instead of enlarging its top page")
	var left_page_mesh := visual.get_node(
		"VisualRoot/MotionRoot/OpenVisual/PageSurface/LeftPage") as MeshInstance3D
	var right_page_mesh := visual.get_node(
		"VisualRoot/MotionRoot/OpenVisual/PageSurface/RightPage") as MeshInstance3D
	var turning_page_mesh := visual.get_node(
		"VisualRoot/MotionRoot/OpenVisual/PageSurface/TurningPage") as MeshInstance3D
	await _wait_for_turn_visual(turning_page_mesh)
	_check(left_page_mesh.visible and right_page_mesh.visible and turning_page_mesh.visible,
		"resting pages remain beneath the turning sheet instead of popping in afterward")
	var left_turn_material := left_page_mesh.material_override as StandardMaterial3D
	var right_turn_material := right_page_mesh.material_override as StandardMaterial3D
	_check(left_turn_material.albedo_texture != right_turn_material.albedo_texture,
		"outgoing and destination spreads use independent textures during the turn")
	_check(right_turn_material.albedo_texture == page_viewport.get_texture()
		and visual._turning_back_material.albedo_texture == page_viewport.get_texture(),
		"destination stays on its live texture with no landing-frame handoff")
	var turn_spine := visual._page_vertex(1, 0.0, 0.0, true, 0.5)
	var turn_middle := visual._page_vertex(1, 0.5, 0.0, true, 0.5)
	var turn_edge := visual._page_vertex(1, 1.0, 0.0, true, 0.5)
	var straight_middle := turn_spine.lerp(turn_edge, 0.5)
	_check(turn_middle.distance_to(straight_middle) > 0.005,
		"turning page bends into a curved sheet at mid-turn")
	var landed_turn_edge := visual._page_vertex(1, 0.5, 0.0, true, 1.0)
	var resting_destination_edge := visual._page_vertex(-1, 0.5, 0.0, false, 0.0)
	_check(landed_turn_edge.distance_to(resting_destination_edge) < 0.002,
		"turning sheet lands directly on the stable destination page")
	var front_vertices := turning_page_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] \
		as PackedVector3Array
	var back_vertices := turning_page_mesh.mesh.surface_get_arrays(1)[Mesh.ARRAY_VERTEX] \
		as PackedVector3Array
	_check(front_vertices.size() == visual.get_visual_profile().page_segments * 6
		and back_vertices.size() == visual.get_visual_profile().page_segments * 6,
		"turning sheet authors separate front and back faces for readable page content")
	await _wait_for_page_turn(book)
	_check(book.current_page == 1,
		"table book turns pages when reference page turns are enabled")
	_check(visual._page_stack_thickness(-1) > visual._page_stack_thickness(1) + 0.01,
		"last spread transfers the thick page block to the left side")
	_check(is_equal_approx(
		visual._page_vertex(-1, 1.0, 0.0, false, 0.0).y,
		visual._page_vertex(1, 1.0, 0.0, false, 0.0).y),
		"page transfer does not resize either visible page")
	_check(left_title.text == "Second Spread", "page turn advances to the next authored spread")
	_check(left_turn_material.albedo_texture == right_turn_material.albedo_texture,
		"settled pages share the live destination texture after the turn")

	# Backward turns reverse the page's X direction. The mesh winding must also
	# reverse so the outgoing front remains visible instead of exposing an
	# upside-down destination underside.
	visual._turn_direction = 1
	var forward_start_mesh := visual._build_turning_page_mesh(0.0)
	var expected_front_normals := forward_start_mesh.surface_get_arrays(
		0)[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var forward_landed_mesh := visual._build_turning_page_mesh(1.0)
	var expected_back_normals := forward_landed_mesh.surface_get_arrays(
		1)[Mesh.ARRAY_NORMAL] as PackedVector3Array
	book.turn_to_spread(0)
	await _wait_for_turn_visual(turning_page_mesh)
	visual._set_page_turn_progress(0.0)
	var reverse_front_normals := turning_page_mesh.mesh.surface_get_arrays(
		0)[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var mirrored_front_normal := expected_front_normals[0] * Vector3(-1.0, 1.0, 1.0)
	_check(not reverse_front_normals.is_empty()
		and reverse_front_normals[0].dot(mirrored_front_normal) > 0.99,
		"backward turn starts on the upright outgoing face")
	visual._set_page_turn_progress(1.0)
	var reverse_back_normals := turning_page_mesh.mesh.surface_get_arrays(
		1)[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var mirrored_back_normal := expected_back_normals[0] * Vector3(-1.0, 1.0, 1.0)
	_check(not reverse_back_normals.is_empty()
		and reverse_back_normals[0].dot(mirrored_back_normal) > 0.99,
		"backward turn lands on the upright destination face")
	await _wait_for_page_turn(book)
	_check(book.current_page == 0, "table book completes a backward page turn")

	# Visual profiles rebuild the shared physical book from arbitrary models.
	var visual_scene := load(
		"res://game/books/presentation/default_book_visual.tscn") as PackedScene
	var replacement_visual := visual_scene.instantiate() as BookVisual
	world.add_child(replacement_visual)
	await process_frame
	var replacement_profile := BookVisualProfile.new()
	replacement_profile.closed_model_scene = load(
		"res://assets/models/book_open.glb") as PackedScene
	replacement_profile.open_model_scene = load(
		"res://assets/models/book_closed.glb") as PackedScene
	replacement_profile.closed_model_transform.origin = Vector3(0.03, 0.02, -0.01)
	replacement_profile.spread_size = Vector2(0.48, 0.22)
	replacement_profile.left_hand_grip.origin = Vector3(-0.2, 0.01, 0.08)
	replacement_profile.right_hand_grip.origin = Vector3(0.2, 0.01, 0.08)
	replacement_visual.apply_profile(replacement_profile)
	var replacement_closed := replacement_visual.get_node(
		"VisualRoot/MotionRoot/ClosedVisual/ModelSocket/ClosedModel") as Node3D
	var replacement_left_page := replacement_visual.get_node(
		"VisualRoot/MotionRoot/OpenVisual/PageSurface/LeftPage") as MeshInstance3D
	_check(replacement_closed.scene_file_path == "res://assets/models/book_open.glb"
		and replacement_closed.position.is_equal_approx(Vector3(0.03, 0.02, -0.01)),
		"visual profiles accept arbitrary imported model scenes and alignment")
	_check(is_equal_approx(replacement_left_page.mesh.get_aabb().size.z, 0.22),
		"replacement profile dimensions rebuild the shared physical page geometry")
	var replacement_grips := replacement_visual.get_hand_grip_transforms()
	_check(replacement_grips.size() == 2
		and replacement_visual.to_local(replacement_grips[0].origin).is_equal_approx(
			Vector3(-0.2, 0.01, 0.08))
		and replacement_visual.to_local(replacement_grips[1].origin).is_equal_approx(
			Vector3(0.2, 0.01, 0.08)),
		"replacement profiles carry their own two-hand contact points")
	replacement_visual.queue_free()

	world.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if _fail == 0:
		print("BOOK INTERACTION TEST OK")
	else:
		print("BOOK INTERACTION TEST FAILURES: ", _fail)
	quit(_fail)


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("[PASS] ", msg)
	else:
		_fail += 1
		push_error("[FAIL] " + msg)


func _wait_for_page_turn(book: Book) -> void:
	for frame in 120:
		if not book.is_page_turning():
			return
		await process_frame


func _wait_for_turn_visual(turning_page: MeshInstance3D) -> void:
	for frame in 10:
		if turning_page.visible:
			return
		await process_frame
