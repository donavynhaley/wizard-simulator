class_name ShapeRecognizer
extends RefCounted

## Order-, direction-, and stroke-count-invariant rune recognition. All strokes
## are flattened, normalized per-axis to their bounding box, and rasterized into
## a grid; the grid is scored against each template with a symmetric distance
## field (chamfer) match. Distance scoring gives partial credit by HOW FAR ink
## strays instead of IoU's binary hit-or-miss, so honest-but-wobbly drawings
## score high, while missing template ink (a partially drawn rune) reads as
## large template-to-input distances and keeps partial shapes from firing.

const GRID_SIZE := 32
const DILATION := 1                 ## cells of ink thickness stamped per line
const FILL_MARGIN := 0.9            ## shrink shapes so they never touch the grid edge
const ASPECT_PENALTY_WEIGHT := 1.0  ## score multiplier strength for aspect mismatch
const DISTANCE_TOLERANCE := 5.0     ## avg cells of drift that drops the score to 0
const EPSILON := 0.00001

var _templates: Array[Dictionary] = []


## Registers a rune exemplar. `strokes` is an Array of PackedVector2Array in any
## consistent space (the bounding-box normalize makes it scale/position free), so
## templates can come from recorded drawings in viewport pixels or hand-authored
## unit-square shapes alike.
func add_template(id: StringName, strokes: Array) -> void:
	var grid := _rasterize(strokes)
	_templates.append({
		"id": id,
		"grid": grid,
		"distance_field": _distance_transform(grid),
		"aspect": _aspect_balance(_all_points(strokes)),
	})


func template_count() -> int:
	return _templates.size()


func has_template(id: StringName) -> bool:
	for t in _templates:
		if t["id"] == id:
			return true
	return false


## Scores live strokes against every template. Returns the best `{id, score}`;
## score is 0..1 and doubles as the match quality for spell stability tiers.
func evaluate(strokes: Array) -> Dictionary:
	var best := {"id": &"", "score": 0.0}
	for candidate in evaluate_detailed(strokes):
		if float(candidate["score"]) > float(best["score"]):
			best = {"id": candidate["id"], "score": candidate["score"]}
	return best


## Full per-template breakdown for tuning and debug logs. `forward` is how far
## the drawn ink strays from the template (sloppiness), `backward` is how far
## template ink is from the drawing (incompleteness), both in average grid
## cells. The final score is driven by the worse of the two, so a clean
## fragment and a complete scribble both land where they should.
func evaluate_detailed(strokes: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if strokes.is_empty():
		return out
	var grid := _rasterize(strokes)
	var input_distance_field := _distance_transform(grid)
	var input_aspect := _aspect_balance(_all_points(strokes))
	for template in _templates:
		var forward := _mean_ink_distance(grid, template["distance_field"] as PackedFloat32Array)
		var backward := _mean_ink_distance(template["grid"] as PackedByteArray, input_distance_field)
		var distance := maxf(forward, backward)
		var aspect_delta: float = absf(input_aspect - float(template["aspect"]))
		var score := clampf(1.0 - distance / DISTANCE_TOLERANCE, 0.0, 1.0) \
			* clampf(1.0 - aspect_delta * ASPECT_PENALTY_WEIGHT, 0.0, 1.0)
		out.append({
			"id": template["id"],
			"score": score,
			"forward": forward,
			"backward": backward,
		})
	return out


## Average distance (in cells) from each inked cell of `ink` to the nearest ink
## of the other drawing, read from that drawing's precomputed distance field.
func _mean_ink_distance(ink: PackedByteArray, distance_field: PackedFloat32Array) -> float:
	var total := 0.0
	var count := 0
	for i in ink.size():
		if ink[i] == 1:
			total += distance_field[i]
			count += 1
	if count == 0:
		return DISTANCE_TOLERANCE
	return total / float(count)


## Two-pass chamfer distance transform: every cell gets its approximate distance
## (in cells) to the nearest inked cell.
func _distance_transform(grid: PackedByteArray) -> PackedFloat32Array:
	var field := PackedFloat32Array()
	field.resize(GRID_SIZE * GRID_SIZE)
	var far := float(GRID_SIZE * 2)
	for i in field.size():
		field[i] = 0.0 if grid[i] == 1 else far

	# Forward pass (top-left to bottom-right neighbours already finalized).
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			var i := y * GRID_SIZE + x
			if x > 0:
				field[i] = minf(field[i], field[i - 1] + 1.0)
			if y > 0:
				field[i] = minf(field[i], field[i - GRID_SIZE] + 1.0)
				if x > 0:
					field[i] = minf(field[i], field[i - GRID_SIZE - 1] + 1.4)
				if x < GRID_SIZE - 1:
					field[i] = minf(field[i], field[i - GRID_SIZE + 1] + 1.4)

	# Backward pass (bottom-right to top-left).
	for y in range(GRID_SIZE - 1, -1, -1):
		for x in range(GRID_SIZE - 1, -1, -1):
			var i := y * GRID_SIZE + x
			if x < GRID_SIZE - 1:
				field[i] = minf(field[i], field[i + 1] + 1.0)
			if y < GRID_SIZE - 1:
				field[i] = minf(field[i], field[i + GRID_SIZE] + 1.0)
				if x < GRID_SIZE - 1:
					field[i] = minf(field[i], field[i + GRID_SIZE + 1] + 1.4)
				if x > 0:
					field[i] = minf(field[i], field[i + GRID_SIZE - 1] + 1.4)
	return field


func _rasterize(strokes: Array) -> PackedByteArray:
	var grid := PackedByteArray()
	grid.resize(GRID_SIZE * GRID_SIZE)  # resize zero-fills

	var points := _all_points(strokes)
	if points.is_empty():
		return grid

	var bounds := _bounds(points)
	var center := bounds.position + bounds.size * 0.5
	# Per-axis normalization: both dimensions fill the grid regardless of the
	# drawing's proportions (the aspect penalty in evaluate() handles those).
	var scale := Vector2(
		bounds.size.x if bounds.size.x > EPSILON else 1.0,
		bounds.size.y if bounds.size.y > EPSILON else 1.0)

	for stroke in strokes:
		var cells := PackedVector2Array()
		for point in (stroke as PackedVector2Array):
			var normalized := (point - center) / scale * FILL_MARGIN  # ~[-0.5, 0.5]
			cells.append(Vector2(
				(normalized.x + 0.5) * float(GRID_SIZE - 1),
				(normalized.y + 0.5) * float(GRID_SIZE - 1)))
		if cells.size() == 1:
			_stamp(grid, int(roundf(cells[0].x)), int(roundf(cells[0].y)))
		else:
			for i in range(1, cells.size()):
				_stamp_line(grid, cells[i - 1], cells[i])
	return grid


## 0..1 measure of how horizontal a drawing's bounds are (0.5 = square), used to
## compare proportions independently of the per-axis shape normalization.
func _aspect_balance(points: PackedVector2Array) -> float:
	if points.is_empty():
		return 0.5
	var bounds := _bounds(points)
	var total := bounds.size.x + bounds.size.y
	if total <= EPSILON:
		return 0.5
	return bounds.size.x / total


func _stamp_line(grid: PackedByteArray, from_cell: Vector2, to_cell: Vector2) -> void:
	var steps := int(ceilf(from_cell.distance_to(to_cell)))
	if steps < 1:
		steps = 1
	for step in steps + 1:
		var point := from_cell.lerp(to_cell, float(step) / float(steps))
		_stamp(grid, int(roundf(point.x)), int(roundf(point.y)))


func _stamp(grid: PackedByteArray, cell_x: int, cell_y: int) -> void:
	for offset_y in range(-DILATION, DILATION + 1):
		for offset_x in range(-DILATION, DILATION + 1):
			var x := cell_x + offset_x
			var y := cell_y + offset_y
			if x >= 0 and x < GRID_SIZE and y >= 0 and y < GRID_SIZE:
				grid[y * GRID_SIZE + x] = 1


func _all_points(strokes: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for stroke in strokes:
		out.append_array(stroke as PackedVector2Array)
	return out


func _bounds(points: PackedVector2Array) -> Rect2:
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)
