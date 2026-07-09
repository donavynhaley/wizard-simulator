class_name RuneRecognizer
extends Resource

const RuneDefinitionResource := preload("res://scripts/spellcraft/rune_definition.gd")
const RuneMatchResultResource := preload("res://scripts/spellcraft/rune_match_result.gd")

const EPSILON := 0.00001

@export var rune_definitions: Array[Resource] = []
@export_range(8, 256, 1) var sample_point_count: int = 64
@export_range(0.01, 2.0, 0.01) var max_match_distance: float = 0.42
@export_range(0.0, 1.0, 0.01) var minimum_confidence: float = 0.55
@export_range(0.0, 1.0, 0.01) var stroke_count_penalty_per_stroke: float = 0.12
@export_range(0.0, 1.0, 0.01) var aspect_penalty_weight: float = 0.12


func recognize(strokes: Array[PackedVector2Array], category_filter: String = "") -> Resource:
	var result := RuneMatchResultResource.new()
	if _stroke_count(strokes) == 0:
		return result

	var input_points := _normalized_sample_points(strokes)
	if input_points.is_empty():
		return result

	var input_stroke_count := _stroke_count(strokes)
	var input_aspect := _aspect_balance(strokes)

	for rune in rune_definitions:
		if rune == null:
			continue
		if not category_filter.is_empty() and _rune_category(rune) != category_filter:
			continue
		var templates := _templates_for_rune(rune)
		for template in templates:
			var template_strokes := _template_strokes(template)
			if _stroke_count(template_strokes) == 0:
				continue
			var candidate := _score_template(
				rune,
				template,
				input_points,
				input_stroke_count,
				input_aspect,
				template_strokes)
			if candidate.distance < result.distance:
				result = candidate

	result.accepted = result.rune != null and result.confidence >= minimum_confidence
	return result


func load_templates_from_directory(directory_path: String) -> Error:
	rune_definitions.clear()
	var grouped: Dictionary = {}
	var error := _load_templates_recursive(directory_path, grouped)
	if error != OK:
		return error

	for rune_id in grouped.keys():
		var templates: Array = grouped[rune_id]
		if templates.is_empty():
			continue
		var first_template := templates[0] as Resource
		var definition := RuneDefinitionResource.new()
		definition.id = StringName(rune_id as String)
		definition.display_name = _template_display_name(first_template)
		definition.category = _template_category(first_template)
		for template in templates:
			definition.add_template(template as Resource)
		rune_definitions.append(definition)
	return OK


func _load_templates_recursive(directory_path: String, grouped: Dictionary) -> Error:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return DirAccess.get_open_error()

	directory.list_dir_begin()
	while true:
		var entry := directory.get_next()
		if entry.is_empty():
			break
		if entry.begins_with("."):
			continue

		var entry_path := "%s/%s" % [directory_path.trim_suffix("/"), entry]
		if directory.current_is_dir():
			var nested_error := _load_templates_recursive(entry_path, grouped)
			if nested_error != OK:
				directory.list_dir_end()
				return nested_error
		elif entry.get_extension() == "tres" or entry.get_extension() == "res":
			var resource := ResourceLoader.load(entry_path)
			if _is_template_resource(resource):
				var rune_id := String(resource.get("rune_id"))
				if not grouped.has(rune_id):
					grouped[rune_id] = []
				grouped[rune_id].append(resource)
	directory.list_dir_end()
	return OK


func _score_template(
	rune: Resource,
	template: Resource,
	input_points: PackedVector2Array,
	input_stroke_count: int,
	input_aspect: float,
	template_strokes: Array[PackedVector2Array]) -> Resource:
	var result := RuneMatchResultResource.new()
	var template_points := _normalized_sample_points(template_strokes)
	if template_points.is_empty() or template_points.size() != input_points.size():
		return result

	var total_distance := 0.0
	for i in input_points.size():
		total_distance += input_points[i].distance_to(template_points[i])

	result.rune = rune
	result.template = template
	result.average_point_distance = total_distance / float(input_points.size())
	result.stroke_count_penalty = abs(input_stroke_count - _stroke_count(template_strokes)) * stroke_count_penalty_per_stroke
	result.aspect_penalty = abs(input_aspect - _aspect_balance(template_strokes)) * aspect_penalty_weight
	result.distance = result.average_point_distance + result.stroke_count_penalty + result.aspect_penalty
	result.confidence = clampf(1.0 - (result.distance / max_match_distance), 0.0, 1.0)
	return result


func _normalized_sample_points(strokes: Array[PackedVector2Array]) -> PackedVector2Array:
	var samples := _resample_strokes(strokes, sample_point_count)
	if samples.is_empty():
		return samples
	return _normalize_points(samples)


func _resample_strokes(strokes: Array[PackedVector2Array], target_count: int) -> PackedVector2Array:
	var clean_strokes := _clean_strokes(strokes)
	var out := PackedVector2Array()
	if clean_strokes.is_empty() or target_count <= 0:
		return out

	var total_length := _total_stroke_length(clean_strokes)
	if total_length <= EPSILON:
		var point := clean_strokes[0][0]
		for i in target_count:
			out.append(point)
		return out

	if target_count == 1:
		out.append(clean_strokes[0][0])
		return out

	var target_step := total_length / float(target_count - 1)
	var next_distance := 0.0
	var covered_distance := 0.0

	for stroke in clean_strokes:
		if stroke.size() == 1:
			continue
		for i in range(1, stroke.size()):
			var start := stroke[i - 1]
			var end := stroke[i]
			var segment_length := start.distance_to(end)
			if segment_length <= EPSILON:
				continue
			while out.size() < target_count and next_distance <= covered_distance + segment_length + EPSILON:
				var t := clampf((next_distance - covered_distance) / segment_length, 0.0, 1.0)
				out.append(start.lerp(end, t))
				next_distance += target_step
			covered_distance += segment_length

	while out.size() < target_count:
		out.append(clean_strokes[clean_strokes.size() - 1][clean_strokes[clean_strokes.size() - 1].size() - 1])
	return out


func _normalize_points(points: PackedVector2Array) -> PackedVector2Array:
	var bounds := _point_bounds(points)
	var center := bounds.position + bounds.size * 0.5
	var scale := maxf(bounds.size.x, bounds.size.y)
	if scale <= EPSILON:
		scale = 1.0

	var out := PackedVector2Array()
	for point in points:
		out.append((point - center) / scale)
	return out


func _point_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)


func _stroke_bounds(strokes: Array[PackedVector2Array]) -> Rect2:
	var points := PackedVector2Array()
	for stroke in strokes:
		for point in stroke:
			points.append(point)
	return _point_bounds(points)


func _aspect_balance(strokes: Array[PackedVector2Array]) -> float:
	var bounds := _stroke_bounds(strokes)
	var total_size := bounds.size.x + bounds.size.y
	if total_size <= EPSILON:
		return 0.5
	return bounds.size.x / total_size


func _total_stroke_length(strokes: Array[PackedVector2Array]) -> float:
	var total := 0.0
	for stroke in strokes:
		for i in range(1, stroke.size()):
			total += stroke[i - 1].distance_to(stroke[i])
	return total


func _clean_strokes(strokes: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for stroke in strokes:
		var clean_stroke := PackedVector2Array()
		for point in stroke:
			clean_stroke.append(Vector2(clampf(point.x, 0.0, 1.0), clampf(point.y, 0.0, 1.0)))
		if not clean_stroke.is_empty():
			out.append(clean_stroke)
	return out


func _stroke_count(strokes: Array[PackedVector2Array]) -> int:
	var count := 0
	for stroke in strokes:
		if not stroke.is_empty():
			count += 1
	return count


func _templates_for_rune(rune: Resource) -> Array[Resource]:
	var out: Array[Resource] = []
	var value: Variant = rune.get("templates")
	if value is Array:
		for template in value:
			if template is Resource:
				out.append(template as Resource)
	return out


func _rune_category(rune: Resource) -> String:
	var value: Variant = rune.get("category")
	if value is String:
		return value as String
	return ""


func _template_strokes(template: Resource) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if template == null:
		return out

	var value: Variant = template.get("strokes")
	if value is Array:
		for stroke in value:
			if stroke is PackedVector2Array:
				out.append(PackedVector2Array(stroke))
	return out


func _is_template_resource(resource: Resource) -> bool:
	if resource == null:
		return false
	var rune_id: Variant = resource.get("rune_id")
	var strokes: Variant = resource.get("strokes")
	return rune_id is String and not String(rune_id).is_empty() and strokes is Array


func _template_display_name(template: Resource) -> String:
	if template == null:
		return ""
	var value: Variant = template.get("display_name")
	if value is String and not String(value).is_empty():
		return value as String
	var rune_id: Variant = template.get("rune_id")
	if rune_id is String:
		return String(rune_id).capitalize()
	return ""


func _template_category(template: Resource) -> String:
	if template == null:
		return "form"
	var value: Variant = template.get("category")
	if value is String and _is_valid_category(value as String):
		return value as String
	return "form"


func _is_valid_category(category: String) -> bool:
	return category == "form" or category == "effect" or category == "modifier"
