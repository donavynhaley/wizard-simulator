class_name ScribeCanvas
extends Control

## 2D ink surface the SpellCrafter renders into a SubViewport and projects
## onto the scroll. Owns the strokes, the sparkle feedback, and the seal-hold
## progress bar; knows nothing about the 3D scene.

signal strokes_changed(strokes: Array[PackedVector2Array])

const INK_COLOR := Color(0.12, 0.08, 0.16, 0.92)
const SPARKLE_LIFETIME := 0.42

var initial_strokes: Array[PackedVector2Array] = []
var total_length := 0.0
var strokes: Array[PackedVector2Array] = []
var sparkles: Array[Dictionary] = []
var seal_hold_progress := 0.0
var _drawing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_load_initial_strokes()


func _process(delta: float) -> void:
	for i in range(sparkles.size() - 1, -1, -1):
		sparkles[i]["age"] = float(sparkles[i]["age"]) + delta
		if float(sparkles[i]["age"]) > SPARKLE_LIFETIME:
			sparkles.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for stroke in strokes:
		if stroke.size() >= 2:
			draw_polyline(_stroke_to_pixels(stroke), INK_COLOR, 6.0, true)
		elif stroke.size() == 1:
			draw_circle(_point_to_pixel(stroke[0]), 3.0, INK_COLOR)

	for sparkle in sparkles:
		var age := float(sparkle["age"])
		var point := _point_to_pixel(sparkle["point"] as Vector2)
		var alpha := 1.0 - age / SPARKLE_LIFETIME
		var radius := 3.0 + age * 24.0
		draw_circle(point, radius, Color(0.45, 0.9, 1.0, alpha * 0.7))
		draw_circle(point, 2.0, Color(0.95, 1.0, 1.0, alpha))

	if has_ink():
		var bar_back := Rect2(
			Vector2(size.x * 0.08, size.y - 24.0),
			Vector2(size.x * 0.84, 7.0))
		var bar_rect := Rect2(
			bar_back.position,
			Vector2(bar_back.size.x * seal_hold_progress, bar_back.size.y))
		draw_rect(bar_back, Color(0.12, 0.18, 0.22, 0.55), true)
		draw_rect(bar_rect, Color(0.35, 0.82, 1.0, 0.85), true)


func _begin_stroke(point: Vector2) -> void:
	_drawing = true
	var stroke := PackedVector2Array()
	stroke.append(_clamp_normalized(point))
	strokes.append(stroke)
	_add_sparkle(point)
	strokes_changed.emit(_normalized_strokes())


func _append_point(point: Vector2) -> void:
	if strokes.is_empty():
		_begin_stroke(point)
		return

	var stroke := strokes[strokes.size() - 1]
	var previous := stroke[stroke.size() - 1]
	var normalized_point := _clamp_normalized(point)
	if _point_to_pixel(previous).distance_to(_point_to_pixel(normalized_point)) < 4.0:
		return

	total_length += _point_to_pixel(previous).distance_to(_point_to_pixel(normalized_point))
	stroke.append(normalized_point)
	strokes[strokes.size() - 1] = stroke

	if int(total_length) % 70 < 8:
		_add_sparkle(normalized_point)
	strokes_changed.emit(_normalized_strokes())


func _add_sparkle(point: Vector2) -> void:
	sparkles.append({
		"point": _clamp_normalized(point),
		"age": 0.0,
	})


func has_ink() -> bool:
	return not strokes.is_empty()


func begin_surface_stroke(point: Vector2) -> void:
	_begin_stroke(point)


func append_surface_point(point: Vector2) -> void:
	if _drawing:
		_append_point(point)


func end_surface_stroke() -> void:
	_drawing = false


func _load_initial_strokes() -> void:
	_load_strokes(initial_strokes)


func _load_strokes(source_strokes: Array[PackedVector2Array]) -> void:
	strokes.clear()
	for normalized_stroke in source_strokes:
		var stroke := PackedVector2Array()
		for point in normalized_stroke:
			stroke.append(_clamp_normalized(point))
		strokes.append(stroke)
	total_length = _stroke_length(strokes)


func _normalized_strokes() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for stroke in strokes:
		out.append(PackedVector2Array(stroke))
	return out


func _stroke_length(source_strokes: Array[PackedVector2Array]) -> float:
	var length := 0.0
	for stroke in source_strokes:
		for i in range(1, stroke.size()):
			length += _point_to_pixel(stroke[i - 1]).distance_to(_point_to_pixel(stroke[i]))
	return length


func _stroke_to_pixels(stroke: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in stroke:
		out.append(_point_to_pixel(point))
	return out


func _point_to_pixel(point: Vector2) -> Vector2:
	return Vector2(point.x * size.x, point.y * size.y)


func _clamp_normalized(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, 0.0, 1.0), clampf(point.y, 0.0, 1.0))
