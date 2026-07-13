class_name RuneMatchResult
extends Resource

var rune: Resource
var template: Resource
var confidence: float = 0.0
var distance: float = INF
var average_point_distance: float = INF
var stroke_count_penalty: float = 0.0
var aspect_penalty: float = 0.0
var accepted: bool = false


func is_match() -> bool:
	return accepted and rune != null and template != null


func rune_id() -> StringName:
	if rune == null:
		return &""
	var value: Variant = rune.get("id")
	if value is StringName:
		return value as StringName
	if value is String:
		return StringName(value as String)
	return &""
