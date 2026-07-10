extends SceneTree

const RECORDER_SCENE := preload("res://scenes/content_tools/rune_template_recorder.tscn")
const RuneTemplateResource := preload("res://scripts/spellcraft/rune_template.gd")


func _init() -> void:
	var recorder := RECORDER_SCENE.instantiate()
	root.add_child(recorder)
	await process_frame

	var canvas := recorder.get_node("%ScribeCanvas") as ScribeCanvas
	if not _require(canvas != null, "Recorder should contain a ScribeCanvas."):
		return
	if not _require(canvas.canvas_size_mm == recorder.recorder_canvas_size_mm, "Recorder should configure canvas measurements."):
		return
	canvas.begin_surface_stroke(Vector2(0.1, 0.2))
	canvas.append_surface_point(Vector2(0.35, 0.5))
	canvas.append_surface_point(Vector2(0.8, 0.75))
	canvas.end_surface_stroke()
	recorder.call("_add_constructed_stroke", recorder.call("_line_points", Vector2(0.15, 0.15), Vector2(0.85, 0.15)))
	var construction_points: Array[Vector2] = [Vector2(0.25, 0.25)]
	recorder.set("_construction_points", construction_points)
	var horizontal_lock := recorder.call("_axis_locked_point", Vector2(0.9, 0.35)) as Vector2
	if not _require(horizontal_lock == Vector2(0.9, 0.25), "Shift lock should preserve the anchor y for horizontal lines."):
		return
	var vertical_lock := recorder.call("_axis_locked_point", Vector2(0.35, 0.9)) as Vector2
	if not _require(vertical_lock == Vector2(0.25, 0.9), "Shift lock should preserve the anchor x for vertical lines."):
		return
	var diagonal_lock := recorder.call("_axis_locked_point", Vector2(0.65, 0.55)) as Vector2
	var diagonal_distance_mm := maxf(
		absf((0.65 - 0.25) * recorder.recorder_canvas_size_mm.x),
		absf((0.55 - 0.25) * recorder.recorder_canvas_size_mm.y))
	var diagonal_expected := Vector2(
		0.25 + diagonal_distance_mm / recorder.recorder_canvas_size_mm.x,
		0.25 + diagonal_distance_mm / recorder.recorder_canvas_size_mm.y)
	if not _require(_point_near(diagonal_lock, diagonal_expected), "Shift lock should snap straight lines to 45 physical degrees."):
		return
	var empty_construction_points: Array[Vector2] = []
	recorder.set("_construction_points", empty_construction_points)
	recorder.call("_add_constructed_stroke", recorder.call(
		"_quadratic_curve_points",
		Vector2(0.15, 0.8),
		Vector2(0.5, 0.45),
		Vector2(0.85, 0.8)))

	var template := RuneTemplateResource.new()
	template.rune_id = "test_rune"
	template.display_name = "Test Rune"
	template.category = "form"
	template.canvas_size_mm = canvas.canvas_size_mm
	template.set_strokes(canvas.get_stroke_snapshot())
	if not _require(template.stroke_count() == 3, "Template should store freehand, line, and curve strokes."):
		return
	if not _require(template.point_count() >= 20, "Template should store constructed curve points."):
		return

	var save_path := "user://test_rune_template.tres"
	var save_error := ResourceSaver.save(template, save_path)
	if not _require(save_error == OK, "Template should save."):
		return

	var loaded := ResourceLoader.load(save_path)
	if not _require(loaded != null, "Template should load."):
		return
	if not _require(loaded.rune_id == "test_rune", "Loaded template should keep rune id."):
		return
	if not _require(loaded.call("stroke_count") == 3, "Loaded template should keep stroke count."):
		return
	if not _require(loaded.call("point_count") >= 20, "Loaded template should keep points."):
		return
	if not _require(loaded.canvas_size_mm == canvas.canvas_size_mm, "Loaded template should keep canvas measurements."):
		return

	print("RUNE TEMPLATE RECORDER TEST OK")
	quit()


func _point_near(actual: Vector2, expected: Vector2, epsilon: float = 0.001) -> bool:
	return actual.distance_to(expected) <= epsilon


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
