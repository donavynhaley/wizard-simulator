class_name ShapeRecognizer
extends RefCounted

## Order-, direction-, and stroke-count-invariant rune recognition. All strokes
## are flattened, normalized per-axis to their bounding box, and rasterized into
## a grid. Root-mean-square chamfer distance makes localized missing ink matter,
## while a secondary-axis spread signature distinguishes a complete branching
## shape from its straight backbone.

const GRID_SIZE := 32
const DILATION := 1                 ## cells of ink thickness stamped per line
const FILL_MARGIN := 0.9            ## shrink shapes so they never touch the grid edge
const ASPECT_PENALTY_WEIGHT := 1.0  ## score multiplier strength for aspect mismatch
## Missing secondary-axis spread is judged as a FRACTION of the template's own
## spread: losing most of Hurl's small barb-spread is a missing feature (a bare
## shaft must not fire), while a slightly under-drawn ring loses only a sliver
## of Seal's large spread and stays competitive (wobble is not a missing
## branch). Up to the tolerance fraction is hand noise; beyond it the penalty
## ramps linearly to full rejection at the reject fraction.
const SHAPE_SPREAD_TOLERANCE_FRACTION := 0.2
const SHAPE_SPREAD_REJECT_FRACTION := 0.6
const STRAY_DISTANCE_TOLERANCE := 8.0    ## generous room for broad hand-drawn ink
const MISSING_DISTANCE_TOLERANCE := 5.0  ## strict requirement for template features
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
		"shape_spread": _secondary_axis_spread(grid),
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


## Relative-margin resolution: the best verb wins when it clears a low quality
## floor AND decisively beats the best OTHER verb. With a small closed
## vocabulary, ambiguity between verbs is the failure that matters; absolute
## polish is not, so a sloppy-but-unmistakable trace still lands.
## Returns {id, score, second_id, second_score, decisive}.
func resolve(strokes: Array, score_floor: float, margin: float) -> Dictionary:
	var out := {
		"id": &"", "score": 0.0,
		"second_id": &"", "second_score": 0.0,
		"decisive": false,
	}
	var candidates := evaluate_detailed(strokes)
	if candidates.is_empty():
		return out
	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["score"]) > float(b["score"]))
	out["id"] = candidates[0]["id"]
	out["score"] = candidates[0]["score"]
	# The runner-up must be a DIFFERENT verb: multiple exemplars of the same
	# rune (canon glyph + recorded + personal) reinforce each other rather
	# than compete for the margin.
	for candidate in candidates.slice(1):
		if candidate["id"] != out["id"]:
			out["second_id"] = candidate["id"]
			out["second_score"] = candidate["score"]
			break
	out["decisive"] = float(out["score"]) >= score_floor \
		and float(out["score"]) - float(out["second_score"]) >= margin
	return out


## Full per-template breakdown for tuning and debug logs. `forward` is how far
## the drawn ink strays from the template (sloppiness), `backward` is how far
## template ink is from the drawing (incompleteness), both in root-mean-square
## grid cells. The final score is driven by the worse distance, aspect mismatch,
## and missing secondary-axis spread. Extra spread is tolerated because a broad
## hand-drawn branch is evidence of completeness, not a missing feature.
func evaluate_detailed(strokes: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if strokes.is_empty():
		return out
	var grid := _rasterize(strokes)
	var input_distance_field := _distance_transform(grid)
	var input_aspect := _aspect_balance(_all_points(strokes))
	var input_shape_spread := _secondary_axis_spread(grid)
	for template in _templates:
		var forward := _root_mean_square_ink_distance(
			grid, template["distance_field"] as PackedFloat32Array)
		var backward := _root_mean_square_ink_distance(
			template["grid"] as PackedByteArray, input_distance_field)
		var distance_score := minf(
			clampf(1.0 - forward / STRAY_DISTANCE_TOLERANCE, 0.0, 1.0),
			clampf(1.0 - backward / MISSING_DISTANCE_TOLERANCE, 0.0, 1.0))
		var aspect_delta: float = absf(input_aspect - float(template["aspect"]))
		var template_spread := float(template["shape_spread"])
		var spread_deficit: float = maxf(template_spread - input_shape_spread, 0.0)
		var spread_fraction_missing := 0.0
		if template_spread > EPSILON:
			spread_fraction_missing = spread_deficit / template_spread
		var spread_penalty := clampf(
			1.0 - maxf(spread_fraction_missing - SHAPE_SPREAD_TOLERANCE_FRACTION, 0.0)
				/ (SHAPE_SPREAD_REJECT_FRACTION - SHAPE_SPREAD_TOLERANCE_FRACTION),
			0.0, 1.0)
		var score := distance_score \
			* clampf(1.0 - aspect_delta * ASPECT_PENALTY_WEIGHT, 0.0, 1.0) \
			* spread_penalty
		out.append({
			"id": template["id"],
			"score": score,
			"forward": forward,
			"backward": backward,
			"spread_deficit": spread_deficit,
		})
	return out


## Root-mean-square distance from each inked cell to the nearest ink of the other
## drawing. Squaring makes a missing branch matter more than many nearby cells.
func _root_mean_square_ink_distance(
	ink: PackedByteArray,
	distance_field: PackedFloat32Array,
) -> float:
	var total_squared := 0.0
	var count := 0
	for i in ink.size():
		if ink[i] == 1:
			total_squared += distance_field[i] * distance_field[i]
			count += 1
	if count == 0:
		return maxf(STRAY_DISTANCE_TOLERANCE, MISSING_DISTANCE_TOLERANCE)
	return sqrt(total_squared / float(count))


## Minor-to-major covariance ratio of rasterized ink. A straight line is near
## zero; branches, turns, and loops spread ink across the secondary axis. The
## signature ignores traversal direction and how geometry is split into strokes.
func _secondary_axis_spread(grid: PackedByteArray) -> float:
	var mean := Vector2.ZERO
	var count := 0.0
	for i in grid.size():
		if grid[i] == 1:
			mean += Vector2(i % GRID_SIZE, i / GRID_SIZE)
			count += 1.0
	if count <= 0.0:
		return 0.0
	mean /= count

	var covariance_xx := 0.0
	var covariance_xy := 0.0
	var covariance_yy := 0.0
	for i in grid.size():
		if grid[i] != 1:
			continue
		var delta := Vector2(i % GRID_SIZE, i / GRID_SIZE) - mean
		covariance_xx += delta.x * delta.x
		covariance_xy += delta.x * delta.y
		covariance_yy += delta.y * delta.y
	covariance_xx /= count
	covariance_xy /= count
	covariance_yy /= count

	var half_trace := (covariance_xx + covariance_yy) * 0.5
	var eigen_split := sqrt(maxf(
		(covariance_xx - covariance_yy) * (covariance_xx - covariance_yy) * 0.25
			+ covariance_xy * covariance_xy,
		0.0))
	var major_axis := half_trace + eigen_split
	var minor_axis := half_trace - eigen_split
	if major_axis <= EPSILON:
		return 0.0
	return clampf(minor_axis / major_axis, 0.0, 1.0)


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
