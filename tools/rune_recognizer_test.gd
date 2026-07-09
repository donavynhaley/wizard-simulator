extends SceneTree

const RuneTemplateResource := preload("res://scripts/spellcraft/rune_template.gd")
const RuneDefinitionResource := preload("res://scripts/spellcraft/rune_definition.gd")
const RuneRecognizerResource := preload("res://scripts/spellcraft/rune_recognizer.gd")


func _init() -> void:
	_test_best_match_selects_closest_template()
	_test_stroke_count_mismatch_lowers_confidence()
	_test_directory_loading_groups_saved_templates()
	print("RUNE RECOGNIZER TEST OK")
	quit()


func _test_best_match_selects_closest_template() -> void:
	var recognizer := RuneRecognizerResource.new()
	recognizer.rune_definitions = [
		_make_definition(&"bolt", "form", [_make_template("bolt", "form", _bolt_strokes())]),
		_make_definition(&"font", "form", [_make_template("font", "form", _font_strokes())]),
	]

	var result := recognizer.recognize(_jittered_bolt_strokes())
	if not _require(result.is_match(), "Jittered bolt should be accepted."):
		return
	if not _require(result.rune_id() == &"bolt", "Jittered bolt should match Bolt."):
		return
	if not _require(result.confidence > 0.75, "Jittered bolt should have high confidence."):
		return


func _test_stroke_count_mismatch_lowers_confidence() -> void:
	var recognizer := RuneRecognizerResource.new()
	recognizer.rune_definitions = [
		_make_definition(&"bolt", "form", [_make_template("bolt", "form", _bolt_strokes())]),
	]

	var one_stroke_result := recognizer.recognize(_jittered_bolt_strokes())
	var two_stroke_result := recognizer.recognize(_split_bolt_strokes())
	if not _require(one_stroke_result.is_match(), "One-stroke bolt should be accepted."):
		return
	if not _require(two_stroke_result.rune_id() == &"bolt", "Split bolt should still identify Bolt as closest."):
		return
	if not _require(not two_stroke_result.is_match(), "Split bolt should fall below acceptance."):
		return
	if not _require(two_stroke_result.confidence < one_stroke_result.confidence, "Split bolt should have lower confidence."):
		return
	if not _require(two_stroke_result.stroke_count_penalty > 0.0, "Split bolt should receive a stroke penalty."):
		return


func _test_directory_loading_groups_saved_templates() -> void:
	var directory_path := "user://rune_recognizer_templates"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory_path))

	var template := _make_template("mend", "effect", _mend_strokes())
	var save_error := ResourceSaver.save(template, "%s/mend_template_01.tres" % directory_path)
	if not _require(save_error == OK, "Mend template should save."):
		return

	var recognizer := RuneRecognizerResource.new()
	var load_error := recognizer.load_templates_from_directory(directory_path)
	if not _require(load_error == OK, "Recognizer should load the template directory."):
		return
	if not _require(recognizer.rune_definitions.size() == 1, "Loaded templates should group into one rune definition."):
		return

	var result := recognizer.recognize(_mend_strokes())
	if not _require(result.is_match(), "Mend should be accepted after directory load."):
		return
	if not _require(result.rune_id() == &"mend", "Mend should match after directory load."):
		return


func _make_template(rune_id: String, category: String, strokes: Array[PackedVector2Array]) -> Resource:
	var template := RuneTemplateResource.new()
	template.rune_id = rune_id
	template.display_name = rune_id.capitalize()
	template.category = category
	template.set_strokes(strokes)
	return template


func _make_definition(rune_id: StringName, category: String, templates: Array) -> Resource:
	var definition := RuneDefinitionResource.new()
	definition.id = rune_id
	definition.display_name = String(rune_id).capitalize()
	definition.category = category
	for template in templates:
		definition.add_template(template as Resource)
	return definition


func _bolt_strokes() -> Array[PackedVector2Array]:
	return [_stroke([
		Vector2(0.16, 0.48),
		Vector2(0.36, 0.42),
		Vector2(0.62, 0.44),
		Vector2(0.84, 0.36),
	])]


func _jittered_bolt_strokes() -> Array[PackedVector2Array]:
	return [_stroke([
		Vector2(0.14, 0.50),
		Vector2(0.34, 0.43),
		Vector2(0.61, 0.45),
		Vector2(0.86, 0.37),
	])]


func _split_bolt_strokes() -> Array[PackedVector2Array]:
	return [
		_stroke([
			Vector2(0.14, 0.50),
			Vector2(0.34, 0.43),
		]),
		_stroke([
			Vector2(0.61, 0.45),
			Vector2(0.86, 0.37),
		]),
	]


func _font_strokes() -> Array[PackedVector2Array]:
	return [_stroke([
		Vector2(0.50, 0.16),
		Vector2(0.34, 0.30),
		Vector2(0.30, 0.55),
		Vector2(0.50, 0.82),
		Vector2(0.70, 0.55),
		Vector2(0.66, 0.30),
		Vector2(0.50, 0.16),
	])]


func _mend_strokes() -> Array[PackedVector2Array]:
	return [
		_stroke([
			Vector2(0.50, 0.18),
			Vector2(0.50, 0.82),
		]),
		_stroke([
			Vector2(0.22, 0.50),
			Vector2(0.78, 0.50),
		]),
	]


func _stroke(points: Array[Vector2]) -> PackedVector2Array:
	var stroke := PackedVector2Array()
	for point in points:
		stroke.append(point)
	return stroke


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
