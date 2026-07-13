class_name ScribeCanvas
extends Control

## 2D ink surface the rune-scribing station renders into a SubViewport and projects
## onto the scroll. Owns the strokes, the sparkle feedback, and the seal-hold
## progress bar; knows nothing about the 3D scene.

signal strokes_changed(strokes: Array[PackedVector2Array])

const INK_COLOR := Color(0.12, 0.08, 0.16, 0.92)
const RECOGNIZED_COLOR := Color(0.24, 0.72, 1.0, 0.96)
const RECOGNIZED_GLOW_COLOR := Color(0.18, 0.56, 1.0, 0.34)
const SEGMENT_LINE_COLOR := Color(0.18, 0.1, 0.08, 0.42)
const SEGMENT_LABEL_COLOR := Color(0.18, 0.1, 0.08, 0.38)
const SEGMENT_FILL_RECOGNIZED := Color(0.12, 0.42, 0.78, 0.08)
const MEASUREMENT_MINOR_COLOR := Color(0.18, 0.1, 0.08, 0.08)
const MEASUREMENT_MAJOR_COLOR := Color(0.18, 0.1, 0.08, 0.16)
const MEASUREMENT_LABEL_COLOR := Color(0.18, 0.1, 0.08, 0.34)
const SPARKLE_LIFETIME := 0.42
const SEGMENT_CATEGORIES: Array[String] = ["form", "effect", "modifier"]

@export var show_measurements: bool = true
@export var canvas_size_mm := Vector2(360.0, 290.0)
@export var major_tick_mm: float = 50.0
@export var minor_tick_mm: float = 10.0

var initial_strokes: Array[PackedVector2Array] = []
var total_length := 0.0
var strokes: Array[PackedVector2Array] = []
var stroke_categories: Array[String] = []
var recognized_categories: Array[String] = []
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
	_draw_segments()
	_draw_measurements()

	for i in strokes.size():
		var stroke := strokes[i]
		var category := _category_for_stroke_index(i)
		var is_recognized := recognized_categories.has(category)
		if stroke.size() >= 2:
			if is_recognized:
				draw_polyline(_stroke_to_pixels(stroke), RECOGNIZED_GLOW_COLOR, 14.0, true)
				draw_polyline(_stroke_to_pixels(stroke), RECOGNIZED_COLOR, 6.0, true)
			else:
				draw_polyline(_stroke_to_pixels(stroke), INK_COLOR, 6.0, true)
		elif stroke.size() == 1:
			draw_circle(_point_to_pixel(stroke[0]), 5.0 if is_recognized else 3.0,
				RECOGNIZED_COLOR if is_recognized else INK_COLOR)

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
	var normalized_point := _clamp_normalized(point)
	stroke.append(normalized_point)
	strokes.append(stroke)
	stroke_categories.append(category_for_point(normalized_point))
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


func clear_strokes() -> void:
	strokes.clear()
	stroke_categories.clear()
	recognized_categories.clear()
	sparkles.clear()
	total_length = 0.0
	seal_hold_progress = 0.0
	_drawing = false
	strokes_changed.emit(get_stroke_snapshot())
	queue_redraw()


func undo_last_stroke() -> void:
	if strokes.is_empty():
		return
	strokes.remove_at(strokes.size() - 1)
	if not stroke_categories.is_empty():
		stroke_categories.remove_at(stroke_categories.size() - 1)
	total_length = _stroke_length(strokes)
	strokes_changed.emit(get_stroke_snapshot())
	queue_redraw()


func replace_strokes(source_strokes: Array[PackedVector2Array]) -> void:
	_load_strokes(source_strokes)
	strokes_changed.emit(get_stroke_snapshot())
	queue_redraw()


func get_stroke_snapshot() -> Array[PackedVector2Array]:
	return _normalized_strokes()


func get_segment_categories() -> Array[String]:
	return SEGMENT_CATEGORIES.duplicate()


func category_for_point(point: Vector2) -> String:
	var clamped_point := _clamp_normalized(point)
	var index := clampi(int(floor(clamped_point.x * float(SEGMENT_CATEGORIES.size()))), 0, SEGMENT_CATEGORIES.size() - 1)
	return SEGMENT_CATEGORIES[index]


func get_last_stroke_category() -> String:
	if stroke_categories.is_empty():
		return ""
	return stroke_categories[stroke_categories.size() - 1]


func get_strokes_for_category(category: String) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for i in strokes.size():
		if _category_for_stroke_index(i) == category:
			out.append(PackedVector2Array(strokes[i]))
	return out


func mark_category_recognized(category: String) -> void:
	if category.is_empty() or recognized_categories.has(category):
		return
	recognized_categories.append(category)
	queue_redraw()


func is_category_recognized(category: String) -> bool:
	return recognized_categories.has(category)


func _load_initial_strokes() -> void:
	_load_strokes(initial_strokes)


func _load_strokes(source_strokes: Array[PackedVector2Array]) -> void:
	strokes.clear()
	stroke_categories.clear()
	recognized_categories.clear()
	for normalized_stroke in source_strokes:
		var stroke := PackedVector2Array()
		for point in normalized_stroke:
			stroke.append(_clamp_normalized(point))
		strokes.append(stroke)
		stroke_categories.append(_category_for_stroke(stroke))
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


func _draw_segments() -> void:
	if SEGMENT_CATEGORIES.is_empty():
		return
	var segment_width := size.x / float(SEGMENT_CATEGORIES.size())
	var label_font := get_theme_default_font()
	for i in SEGMENT_CATEGORIES.size():
		var category := SEGMENT_CATEGORIES[i]
		var x := segment_width * float(i)
		var rect := Rect2(Vector2(x, 0.0), Vector2(segment_width, size.y))
		if recognized_categories.has(category):
			draw_rect(rect, SEGMENT_FILL_RECOGNIZED, true)
		if i > 0:
			draw_line(Vector2(x, 0.0), Vector2(x, size.y), SEGMENT_LINE_COLOR, 3.0, true)
			draw_line(Vector2(x + 3.0, 0.0), Vector2(x + 3.0, size.y), Color(0.95, 0.78, 0.45, 0.16), 1.0, true)
		if label_font != null:
			draw_string(
				label_font,
				Vector2(x + 14.0, 24.0),
				category.to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				15,
				SEGMENT_LABEL_COLOR)


func _draw_measurements() -> void:
	if not show_measurements:
		return
	if canvas_size_mm.x <= 0.0 or canvas_size_mm.y <= 0.0:
		return
	if minor_tick_mm <= 0.0 or major_tick_mm <= 0.0:
		return

	var minor_step_x := minor_tick_mm / canvas_size_mm.x * size.x
	var minor_step_y := minor_tick_mm / canvas_size_mm.y * size.y
	if minor_step_x < 1.0 or minor_step_y < 1.0:
		return

	var x_mm := minor_tick_mm
	while x_mm < canvas_size_mm.x:
		var x := _mm_x_to_pixel(x_mm)
		var is_major := _is_major_tick(x_mm)
		draw_line(
			Vector2(x, 0.0),
			Vector2(x, size.y),
			MEASUREMENT_MAJOR_COLOR if is_major else MEASUREMENT_MINOR_COLOR,
			1.5 if is_major else 1.0,
			true)
		x_mm += minor_tick_mm

	var y_mm := minor_tick_mm
	while y_mm < canvas_size_mm.y:
		var y := _mm_y_to_pixel(y_mm)
		var is_major := _is_major_tick(y_mm)
		draw_line(
			Vector2(0.0, y),
			Vector2(size.x, y),
			MEASUREMENT_MAJOR_COLOR if is_major else MEASUREMENT_MINOR_COLOR,
			1.5 if is_major else 1.0,
			true)
		y_mm += minor_tick_mm

	var label_font := get_theme_default_font()
	if label_font == null:
		return

	var label_size := 12
	x_mm = major_tick_mm
	while x_mm < canvas_size_mm.x:
		draw_string(
			label_font,
			Vector2(_mm_x_to_pixel(x_mm) + 3.0, 41.0),
			"%d" % int(roundf(x_mm)),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			label_size,
			MEASUREMENT_LABEL_COLOR)
		x_mm += major_tick_mm

	y_mm = major_tick_mm
	while y_mm < canvas_size_mm.y:
		draw_string(
			label_font,
			Vector2(6.0, _mm_y_to_pixel(y_mm) - 3.0),
			"%d" % int(roundf(y_mm)),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			label_size,
			MEASUREMENT_LABEL_COLOR)
		y_mm += major_tick_mm

	draw_string(
		label_font,
		Vector2(maxf(6.0, size.x - 36.0), 16.0),
		"mm",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		label_size,
		MEASUREMENT_LABEL_COLOR)


func _is_major_tick(value_mm: float) -> bool:
	var ratio := value_mm / major_tick_mm
	return absf(ratio - roundf(ratio)) < 0.001


func _mm_x_to_pixel(value_mm: float) -> float:
	return value_mm / canvas_size_mm.x * size.x


func _mm_y_to_pixel(value_mm: float) -> float:
	return value_mm / canvas_size_mm.y * size.y


func _category_for_stroke_index(index: int) -> String:
	if index >= 0 and index < stroke_categories.size():
		return stroke_categories[index]
	if index >= 0 and index < strokes.size():
		return _category_for_stroke(strokes[index])
	return ""


func _category_for_stroke(stroke: PackedVector2Array) -> String:
	if stroke.is_empty():
		return ""
	var center := Vector2.ZERO
	for point in stroke:
		center += point
	center /= float(stroke.size())
	return category_for_point(center)


func _point_to_pixel(point: Vector2) -> Vector2:
	return Vector2(point.x * size.x, point.y * size.y)


func _clamp_normalized(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, 0.0, 1.0), clampf(point.y, 0.0, 1.0))
