class_name ScribingSession
extends RefCounted

## Mutable state for one physical rune-scribing surface.
## The station owns interaction and presentation while this object owns the
## strokes and recognition results that survive until the scroll is sealed.

var saved_strokes: Array[PackedVector2Array] = []

var _recognized_by_category: Dictionary = {}
var _quality_by_category: Dictionary = {}


func reset_recognition() -> void:
	_recognized_by_category.clear()
	_quality_by_category.clear()


func save_strokes(strokes: Array[PackedVector2Array]) -> void:
	saved_strokes = duplicate_strokes(strokes)


func record_recognition(category: String, rune: Resource, quality: float) -> void:
	_recognized_by_category[category] = rune
	_quality_by_category[category] = quality


func has_recognized_runes() -> bool:
	return not _recognized_by_category.is_empty()


func recognized_rune_count() -> int:
	return _recognized_by_category.size()


func recognized_rune_ids(categories: Array[String]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for category in categories:
		var rune := _recognized_by_category.get(category, null) as Resource
		if rune == null:
			continue
		var id: Variant = rune.get("id")
		if id is StringName:
			ids.append(id as StringName)
		elif id is String:
			ids.append(StringName(id as String))
	return ids


func rune_qualities(categories: Array[String]) -> Array[float]:
	var qualities: Array[float] = []
	for category in categories:
		if _quality_by_category.has(category):
			qualities.append(float(_quality_by_category[category]))
	return qualities


func duplicate_strokes(source: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var duplicate: Array[PackedVector2Array] = []
	for stroke in source:
		duplicate.append(PackedVector2Array(stroke))
	return duplicate
