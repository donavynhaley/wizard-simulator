class_name RuneTemplateView
extends Control

const PAPER_COLOR := Color(0.74, 0.64, 0.45, 0.96)
const BORDER_COLOR := Color(0.24, 0.15, 0.08, 0.72)
const GRID_COLOR := Color(0.22, 0.14, 0.08, 0.12)
const STROKE_GLOW := Color(0.22, 0.68, 1.0, 0.28)
const STROKE_COLOR := Color(0.06, 0.16, 0.24, 0.92)
const STROKE_GHOST := Color(0.06, 0.16, 0.24, 0.2)
const ACTIVE_GLOW := Color(0.12, 0.62, 1.0, 0.42)
const ACTIVE_COLOR := Color(0.02, 0.42, 0.92, 1.0)
const TIP_COLOR := Color(0.82, 0.95, 1.0, 1.0)

@export_group("Playback")
@export var playback_enabled := false:
	set(value):
		playback_enabled = value
		set_process(playback_enabled)
		if playback_enabled:
			_playback_time = 0.0
		queue_redraw()
@export var playback_loop := true
@export_range(0.1, 3.0, 0.05) var playback_seconds_per_stroke := 0.85
@export_range(0.0, 1.0, 0.05) var playback_pause_between_strokes := 0.18
@export_range(0.0, 2.0, 0.05) var playback_loop_pause := 0.65

var strokes: Array[PackedVector2Array] = []
var _playback_time := 0.0


func set_strokes(value: Array[PackedVector2Array]) -> void:
	strokes.clear()
	for stroke in value:
		strokes.append(PackedVector2Array(stroke))
	if playback_enabled:
		_playback_time = 0.0
	queue_redraw()


func _ready() -> void:
	set_process(playback_enabled)


func _process(delta: float) -> void:
	if not playback_enabled or strokes.is_empty():
		return
	_playback_time += delta
	var duration := _playback_cycle_duration()
	if playback_loop and duration > 0.0:
		_playback_time = fmod(_playback_time, duration)
	elif duration > 0.0 and _playback_time > duration:
		_playback_time = duration
		set_process(false)
	queue_redraw()


func restart_playback() -> void:
	_playback_time = 0.0
	playback_enabled = true


func stop_playback(show_complete: bool = true) -> void:
	playback_enabled = false
	_playback_time = _playback_cycle_duration() if show_complete else 0.0
	queue_redraw()


func is_playback_active() -> bool:
	return playback_enabled and is_processing()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, PAPER_COLOR, true)
	draw_rect(rect, BORDER_COLOR, false, 2.0)
	_draw_grid()
	if playback_enabled:
		_draw_playback_strokes()
	else:
		_draw_strokes()


func _draw_grid() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	for i in range(1, 4):
		var x := size.x * float(i) / 4.0
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), GRID_COLOR, 1.0)
		var y := size.y * float(i) / 4.0
		draw_line(Vector2(0.0, y), Vector2(size.x, y), GRID_COLOR, 1.0)


func _draw_strokes() -> void:
	var bounds := _stroke_bounds()
	if bounds.size.x <= 0.0001 or bounds.size.y <= 0.0001:
		return
	for stroke in strokes:
		if stroke.size() >= 2:
			var points := _layout_stroke(stroke, bounds)
			draw_polyline(points, STROKE_GLOW, 12.0, true)
			draw_polyline(points, STROKE_COLOR, 5.0, true)
		elif stroke.size() == 1:
			draw_circle(_layout_point(stroke[0], bounds), 4.0, STROKE_COLOR)


func _draw_playback_strokes() -> void:
	var bounds := _stroke_bounds()
	if bounds.size.x <= 0.0001 or bounds.size.y <= 0.0001:
		return

	for stroke in strokes:
		if stroke.size() >= 2:
			draw_polyline(_layout_stroke(stroke, bounds), STROKE_GHOST, 4.0, true)

	var stroke_duration := maxf(playback_seconds_per_stroke, 0.01)
	var step_duration := stroke_duration + playback_pause_between_strokes
	for i in strokes.size():
		var stroke := strokes[i]
		if stroke.is_empty():
			continue
		var stroke_start := float(i) * step_duration
		var stroke_end := stroke_start + stroke_duration
		if _playback_time < stroke_start:
			continue
		var full_points := _layout_stroke(stroke, bounds)
		if _playback_time >= stroke_end:
			_draw_ordered_stroke(full_points, i, true)
			continue
		var progress := clampf((_playback_time - stroke_start) / stroke_duration, 0.0, 1.0)
		var partial := _partial_polyline(full_points, progress)
		_draw_ordered_stroke(partial, i, false)


func _draw_ordered_stroke(points: PackedVector2Array, index: int, complete: bool) -> void:
	if points.is_empty():
		return
	if points.size() >= 2:
		draw_polyline(points, ACTIVE_GLOW, 13.0, true)
		draw_polyline(points, ACTIVE_COLOR, 5.0, true)
	var tip := points[points.size() - 1]
	draw_circle(tip, 7.0 if complete else 9.0, TIP_COLOR if not complete else ACTIVE_COLOR)
	draw_circle(tip, 3.5, ACTIVE_COLOR if not complete else TIP_COLOR)
	if points.size() > 0:
		var start := points[0]
		draw_circle(start, 11.0, Color(0.93, 0.86, 0.62, 0.9))
		draw_circle(start, 9.0, Color(0.16, 0.095, 0.04, 0.92))
		draw_string(ThemeDB.fallback_font, start + Vector2(-4.0, 5.0), str(index + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13.0, Color(0.93, 0.86, 0.62, 1.0))


func _layout_stroke(stroke: PackedVector2Array, bounds: Rect2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in stroke:
		points.append(_layout_point(point, bounds))
	return points


func _layout_point(point: Vector2, bounds: Rect2) -> Vector2:
	var available := size * 0.78
	var scale := minf(available.x / bounds.size.x, available.y / bounds.size.y)
	var offset := size * 0.5 - (bounds.position + bounds.size * 0.5) * scale
	return point * scale + offset


func _partial_polyline(points: PackedVector2Array, progress: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if points.is_empty():
		return out
	out.append(points[0])
	if points.size() == 1 or progress <= 0.0:
		return out

	var total := _polyline_length(points)
	if total <= 0.0001:
		return out
	var target := total * clampf(progress, 0.0, 1.0)
	var walked := 0.0
	for i in range(1, points.size()):
		var previous := points[i - 1]
		var current := points[i]
		var segment := previous.distance_to(current)
		if walked + segment < target:
			out.append(current)
			walked += segment
			continue
		var remaining := target - walked
		var segment_progress := 0.0 if segment <= 0.0001 else remaining / segment
		out.append(previous.lerp(current, clampf(segment_progress, 0.0, 1.0)))
		return out
	return points


func _polyline_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


func _playback_cycle_duration() -> float:
	if strokes.is_empty():
		return 0.0
	var stroke_duration := maxf(playback_seconds_per_stroke, 0.01)
	var total := float(strokes.size()) * stroke_duration
	total += float(maxi(strokes.size() - 1, 0)) * playback_pause_between_strokes
	total += playback_loop_pause
	return total


func _stroke_bounds() -> Rect2:
	var has_point := false
	var min_point := Vector2.ZERO
	var max_point := Vector2.ZERO
	for stroke in strokes:
		for point in stroke:
			if not has_point:
				min_point = point
				max_point = point
				has_point = true
			else:
				min_point.x = minf(min_point.x, point.x)
				min_point.y = minf(min_point.y, point.y)
				max_point.x = maxf(max_point.x, point.x)
				max_point.y = maxf(max_point.y, point.y)
	if not has_point:
		return Rect2()
	return Rect2(min_point, max_point - min_point)
