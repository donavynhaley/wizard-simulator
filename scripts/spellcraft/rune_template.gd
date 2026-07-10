class_name RuneTemplate
extends Resource

@export var rune_id: String = ""
@export var display_name: String = ""
@export_enum("form", "effect", "modifier") var category: String = "form"
@export_multiline var notes: String = ""
@export var template_version: int = 1
@export var recorded_at_unix_time: int = 0
@export var canvas_size := Vector2i(1024, 768)
@export var canvas_size_mm := Vector2(360.0, 290.0)
@export var strokes: Array[PackedVector2Array] = []


func set_strokes(source_strokes: Array[PackedVector2Array]) -> void:
	strokes.clear()
	for source_stroke in source_strokes:
		var stroke := PackedVector2Array()
		for point in source_stroke:
			stroke.append(Vector2(clampf(point.x, 0.0, 1.0), clampf(point.y, 0.0, 1.0)))
		if not stroke.is_empty():
			strokes.append(stroke)


func get_stroke_snapshot() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for stroke in strokes:
		out.append(PackedVector2Array(stroke))
	return out


func stroke_count() -> int:
	return strokes.size()


func point_count() -> int:
	var count := 0
	for stroke in strokes:
		count += stroke.size()
	return count
