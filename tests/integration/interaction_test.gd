extends SceneTree

## End-to-end check of the interaction chain in the real tower scene: the
## look-to-focus player, the crafting-table fixtures, and the rune-scribing
## station locking and unlocking the player. Run headless:
##   godot --headless --path . -s tests/integration/interaction_test.gd

const RuneTemplateResource := preload("res://game/scribing/runes/rune_template.gd")
const RuneDefinitionResource := preload("res://game/scribing/runes/rune_definition.gd")
const RuneRecognizerResource := preload("res://game/scribing/runes/rune_recognizer.gd")

var _fail := 0
var _completed_stroke_count := -1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := (load("res://game/world/levels/wizard_tower.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame

	var player := scene.get_node_or_null("Player") as WizardPlayer
	_check(player != null, "player is a WizardPlayer")
	_check(player.interactor != null, "player.interactor resolves the typed interactor")
	var viewmodel := player.viewmodel
	_check(viewmodel.get_node_or_null("WizardHat") != null,
		"viewmodel wears the wizard hat")
	_check(viewmodel.get_node_or_null("WizardArms") != null,
		"viewmodel keeps the wizard arms in camera view")
	var camera := player.get_node("Head/Camera3D") as Camera3D
	_check(camera.near <= 0.03, "camera keeps a tight near plane for the viewmodel")

	var crafter := scene.find_child("RuneScribingStation", true, false)
	var burner := scene.find_child("Burner", true, false)
	var flask := scene.find_child("Flask", true, false) as Flask
	var book := _find_by_type(scene, "Book") as Book
	_check(crafter != null, "tower has a rune-scribing station")
	var scribe_surface := crafter.get_node_or_null("Scroll/ScribeInkSurface") as MeshInstance3D if crafter else null
	_check(scribe_surface != null and is_equal_approx(scribe_surface.rotation_degrees.y, -90.0),
		"crafting-table ink overlay turns clockwise across the imported scroll")
	var scribe_surface_mesh := scribe_surface.mesh as PlaneMesh if scribe_surface else null
	_check(scribe_surface_mesh != null and scribe_surface_mesh.size.is_equal_approx(Vector2(0.6, 0.3)),
		"crafting-table ink overlay measures 600 mm wide by 300 mm tall")
	_check(crafter._scribe_canvas.canvas_size_mm.is_equal_approx(Vector2(600.0, 300.0)),
		"scribe measurements match the physical overlay dimensions")
	_check(burner != null, "tower has a burner")
	_check(flask != null, "tower has a flask")
	_check(book != null, "tower has a readable book")
	if _fail > 0:
		_finish()
		return

	_check(str(crafter.focus_prompt(player, null)) == crafter.prompt_text,
		"crafter prompts to begin scribing")
	var mouse_mode_before_scribing := Input.mouse_mode
	crafter.interact(player, null)
	_check(crafter._active, "crafter enters scribing mode")
	_check(not player.is_physics_processing(), "scribing freezes the player")
	_check(not player._control_enabled,
		"scribing prevents player focus events from recapturing the mouse")
	var interactor := player.interactor
	_check(not interactor.enabled, "scribing suspends the interactor")

	var scribe_camera := crafter.get_node_or_null("ScribeCamera") as Camera3D
	var scroll_camera_pose := crafter.get_node_or_null("ScrollCameraPose") as Marker3D
	var book_camera_pose := crafter.get_node_or_null("BookCameraPose") as Marker3D
	_check(scribe_camera != null and scroll_camera_pose != null and book_camera_pose != null,
		"crafting table authors both scribing camera poses in its scene")
	if scribe_camera != null and scroll_camera_pose != null and book_camera_pose != null:
		_check(_transform_matches(scribe_camera.transform, scroll_camera_pose.transform, 0.01),
			"scribing starts focused on the scroll")
		crafter._unhandled_input(_action_event(&"move_forward"))
		for frame in 60:
			await process_frame
		_check(_transform_matches(scribe_camera.transform, book_camera_pose.transform, 0.01),
			"W rotates the scribing camera up to the reference book")
		crafter._unhandled_input(_action_event(&"move_backward"))
		for frame in 60:
			await process_frame
		_check(_transform_matches(scribe_camera.transform, scroll_camera_pose.transform, 0.01),
			"S rotates the scribing camera back down to the scroll")

	# The authored quill replaces the system cursor while drawing.
	_check(crafter.get_node_or_null("ScribeArm") == null,
		"scribing no longer depends on a hand or arm rig")
	if DisplayServer.get_name() == "headless":
		print("[SKIP] system cursor hiding requires a graphical display")
	else:
		_check(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN,
			"scribing hides the system cursor so the quill becomes the pointer")
	var quill := crafter.get_node("Quill") as Node3D
	var quill_model := quill.get_node_or_null("ModelFacing/AxisConversion/Model") as Node3D
	var quill_tip := quill.get_node_or_null("WritingTip") as Marker3D
	var quill_scribe_pose := crafter.get_node_or_null("QuillScribePose") as Marker3D
	_check(quill_model != null
		and quill_model.scene_file_path == "res://assets/models/quill.glb",
		"scribing uses the authored quill model instead of placeholder geometry")
	_check(quill_tip != null, "authored quill tip drives mouse alignment")
	_check(quill_scribe_pose != null
		and is_equal_approx(quill_scribe_pose.rotation_degrees.y, -36.0),
		"scene-authored quill pose points the nib toward the left side of the scroll")
	for i in 5:
		await process_frame
	var cursor_global: Vector3 = crafter._scribe_surface.to_global(
		crafter._scribe_surface_point(crafter._last_cursor_point))
	var quill_surface_normal: Vector3 = (
		crafter._scribe_surface.global_transform.basis.y.normalized())
	_check(quill_tip.global_position.distance_to(
		cursor_global + quill_surface_normal * crafter.quill_hover_lift) < 0.002,
		"authored quill nib tracks the scroll cursor")

	# Disable mouse polling so it cannot overwrite the corner samples.
	crafter.set_process(false)
	var original_tip_position := quill_tip.global_position
	crafter._set_cursor_point(Vector2(0.35, 0.35))
	crafter._update_scribe_props(1.0)
	_check(quill_tip.global_position.distance_to(original_tip_position) > 0.05,
		"quill moves directly with the cursor")
	var max_corner_tip_error := 0.0
	for corner: Vector2 in [
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
	]:
		crafter._set_cursor_point(corner)
		crafter._update_scribe_props(1.0)
		var surface_point: Vector3 = crafter._scribe_surface.to_global(
			crafter._scribe_surface_point(corner))
		var expected_tip: Vector3 = (
			surface_point + quill_surface_normal * crafter.quill_hover_lift)
		max_corner_tip_error = maxf(
			max_corner_tip_error,
			quill_tip.global_position.distance_to(expected_tip))
	crafter.set_process(true)
	_check(max_corner_tip_error < 0.002,
		"quill nib reaches every scroll corner (max err=%.4f m)" % max_corner_tip_error)

	var recognizer := RuneRecognizerResource.new()
	recognizer.rune_definitions = [
		_make_rune_definition(&"font", "form", [_make_rune_template("font", "form", _font_strokes())]),
		_make_rune_definition(&"mend", "effect", [_make_rune_template("mend", "effect", _mend_strokes())]),
	]
	crafter._rune_recognizer = recognizer
	crafter._scribe_canvas.replace_strokes(_scribed_rune_strokes_on_scroll())
	var rune_result: Resource = crafter._try_auto_recognize_category("form")
	_check(rune_result != null and bool(rune_result.call("is_match")),
		"crafter auto-recognizes a completed form rune segment")
	rune_result = crafter._try_auto_recognize_category("effect")
	_check(rune_result != null and bool(rune_result.call("is_match")),
		"crafter auto-recognizes a completed effect rune segment")
	_check(crafter.get_recognized_rune_ids() == [&"font", &"mend"],
		"crafter stores the recognized rune ids")
	_check(crafter.get_rune_qualities().size() == 2 and crafter.get_rune_qualities()[0] > 0.75,
		"crafter stores recognized rune quality")
	_check(crafter._scribe_canvas.has_ink(),
		"recognized rune remains on the scroll")
	_check(crafter._scribe_canvas.is_category_recognized("form"),
		"recognized form segment is marked for blue glow")
	_check(crafter._scribe_canvas.is_category_recognized("effect"),
		"recognized effect segment is marked for blue glow")

	_completed_stroke_count = -1
	crafter.scribing_completed.connect(_on_scribing_completed, CONNECT_ONE_SHOT)
	crafter._end_scribing(true, 2)
	_check(not crafter._active, "sealing leaves scribing mode")
	_check(Input.mouse_mode == mouse_mode_before_scribing,
		"leaving scribing restores the previous system cursor mode")
	_check(player.is_physics_processing(), "sealing unfreezes the player")
	_check(player._control_enabled, "sealing restores player mouse capture handling")
	_check(interactor.enabled, "sealing reactivates the interactor")
	_check(crafter._sealed, "sealing preserves the finished physical scroll")
	_check(crafter._scribe_canvas.has_ink(), "sealing preserves authored rune ink")
	_check(_completed_stroke_count == 2, "sealing emits neutral scribing completion")
	_check(crafter.get_recognized_rune_ids() == [&"font", &"mend"],
		"sealing preserves recognized rune ids for a future spell design")
	_check(scene.find_child("FontArea", true, false) == null,
		"sealing does not create a spell delivery")

	_finish()


func _finish() -> void:
	if _fail == 0:
		print("INTERACTION TEST OK")
	else:
		print("INTERACTION TEST FAILURES: ", _fail)
	quit(_fail)


func _on_scribing_completed(stroke_count: int) -> void:
	_completed_stroke_count = stroke_count


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("[PASS] ", msg)
	else:
		_fail += 1
		push_error("[FAIL] " + msg)


func _find_by_type(node: Node, type_name: String) -> Node:
	if node.get_script() != null and node.get_script().get_global_name() == type_name:
		return node
	for child in node.get_children():
		var found := _find_by_type(child, type_name)
		if found != null:
			return found
	return null


func _basis_matches(left: Basis, right: Basis, tolerance: float) -> bool:
	return left.x.normalized().distance_to(right.x.normalized()) <= tolerance \
		and left.y.normalized().distance_to(right.y.normalized()) <= tolerance \
		and left.z.normalized().distance_to(right.z.normalized()) <= tolerance


func _transform_matches(left: Transform3D, right: Transform3D, tolerance: float) -> bool:
	return left.origin.distance_to(right.origin) <= tolerance \
		and _basis_matches(left.basis, right.basis, tolerance)


func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _make_rune_template(rune_id: String, category: String, strokes: Array[PackedVector2Array]) -> Resource:
	var template := RuneTemplateResource.new()
	template.rune_id = rune_id
	template.display_name = rune_id.capitalize()
	template.category = category
	template.set_strokes(strokes)
	return template


func _make_rune_definition(rune_id: StringName, category: String, templates: Array) -> Resource:
	var definition := RuneDefinitionResource.new()
	definition.id = rune_id
	definition.display_name = String(rune_id).capitalize()
	definition.category = category
	for template in templates:
		definition.add_template(template as Resource)
	return definition


func _font_strokes() -> Array[PackedVector2Array]:
	return [_stroke([
		Vector2(0.04, 0.48),
		Vector2(0.11, 0.42),
		Vector2(0.20, 0.44),
		Vector2(0.29, 0.36),
	])]


func _mend_strokes() -> Array[PackedVector2Array]:
	return [_stroke([
		Vector2(0.38, 0.74),
		Vector2(0.44, 0.58),
		Vector2(0.51, 0.70),
		Vector2(0.59, 0.42),
	])]


func _scribed_rune_strokes_on_scroll() -> Array[PackedVector2Array]:
	return [
		_stroke([
			Vector2(0.04, 0.48),
			Vector2(0.11, 0.42),
			Vector2(0.20, 0.44),
			Vector2(0.29, 0.36),
		]),
		_stroke([
			Vector2(0.38, 0.74),
			Vector2(0.44, 0.58),
			Vector2(0.51, 0.70),
			Vector2(0.59, 0.42),
		]),
	]


func _stroke(points: Array[Vector2]) -> PackedVector2Array:
	var stroke := PackedVector2Array()
	for point in points:
		stroke.append(point)
	return stroke
