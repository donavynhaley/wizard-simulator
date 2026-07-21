class_name BookPagePatina
extends Control

@export var texture_seed := 7241

var _fibers: Array[Dictionary] = []
var _spots: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_marks()
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	for inset in 12:
		var alpha := 0.012 + float(12 - inset) * 0.0015
		draw_rect(
			Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2.0),
			Color(0.19, 0.075, 0.025, alpha),
			false,
			1.0)
	for fiber in _fibers:
		var start := Vector2(fiber["x"] as float, fiber["y"] as float) * size
		var length := (fiber["length"] as float) * size.x
		draw_line(
			start,
			start + Vector2(length, fiber["slope"] as float),
			Color(0.22, 0.11, 0.035, fiber["alpha"] as float),
			0.65,
			true)
	for spot in _spots:
		var center := Vector2(spot["x"] as float, spot["y"] as float) * size
		var radius := (spot["radius"] as float) * minf(size.x, size.y)
		draw_circle(
			center,
			radius,
			Color(0.24, 0.105, 0.035, spot["alpha"] as float))


func _build_marks() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = texture_seed
	_fibers.clear()
	_spots.clear()
	for index in 115:
		_fibers.append({
			"x": random.randf_range(0.02, 0.98),
			"y": random.randf_range(0.02, 0.98),
			"length": random.randf_range(0.006, 0.035),
			"slope": random.randf_range(-1.4, 1.4),
			"alpha": random.randf_range(0.012, 0.032),
		})
	for index in 34:
		var near_edge := random.randf() < 0.72
		var x := random.randf_range(0.01, 0.11) \
			if near_edge and random.randf() < 0.5 \
			else random.randf_range(0.89, 0.99) if near_edge \
			else random.randf_range(0.08, 0.92)
		var y := random.randf_range(0.02, 0.98)
		_spots.append({
			"x": x,
			"y": y,
			"radius": random.randf_range(0.0015, 0.007),
			"alpha": random.randf_range(0.007, 0.022),
		})
