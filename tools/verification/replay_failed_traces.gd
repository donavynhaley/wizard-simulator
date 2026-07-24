extends SceneTree

## Replays every refused lift the game dumped to user://trace_debug through the
## production recognizer setup and prints per-verb score breakdowns. This is
## how recognition gets tuned against a real hand instead of a noise model:
##   1. play, trace, let lifts fail (the controller dumps each refusal)
##   2. godot --headless --path . -s tools/verification/replay_failed_traces.gd
##   3. read which penalty term (stray/missing/spread) is eating the score

const TRACE_DEBUG_DIR := "user://trace_debug"
const PERSONAL_TEMPLATE_DIR := "user://runes/air"
const AIR_TEMPLATE_DIR := "res://content/runes/air"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var recognizer := ShapeRecognizer.new()
	_load_template_dir(recognizer, AIR_TEMPLATE_DIR)
	_load_template_dir(recognizer, PERSONAL_TEMPLATE_DIR)
	for id in RuneGlyphs.VERBS:
		for strokes: Array in RuneGlyphs.exemplar_strokes(id):
			recognizer.add_template(id, strokes)

	var dir := DirAccess.open(TRACE_DEBUG_DIR)
	if dir == null:
		print("No dumped traces at ", TRACE_DEBUG_DIR,
			" - trace in game first; every refused lift is saved there.")
		quit(1)
		return
	var files: Array[String] = []
	for file_name in dir.get_files():
		if file_name.get_extension() == "json":
			files.append(file_name)
	files.sort()
	print(files.size(), " dumped traces\n")

	for file_name in files:
		var file := FileAccess.open(TRACE_DEBUG_DIR + "/" + file_name, FileAccess.READ)
		if file == null:
			continue
		var data: Variant = JSON.parse_string(file.get_as_text())
		if not (data is Dictionary and data.has("strokes")):
			continue
		var strokes := _parse_strokes(data["strokes"] as Array)
		var point_total := 0
		for stroke in strokes:
			point_total += (stroke as PackedVector2Array).size()
		var detailed := recognizer.evaluate_detailed(strokes)
		detailed.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return float(a["score"]) > float(b["score"]))
		var line := "%s (%d strokes, %d pts):" % [file_name, strokes.size(), point_total]
		for i in mini(4, detailed.size()):
			var c: Dictionary = detailed[i]
			line += "  %s=%.2f(stray %.1f, missing %.1f, spread_def %.2f)" % [
				c["id"], c["score"], c["forward"], c["backward"], c["spread_deficit"]]
		print(line)
	quit(0)


func _load_template_dir(recognizer: ShapeRecognizer, path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name in dir.get_files():
		if file_name.get_extension() != "json":
			continue
		var file := FileAccess.open(path + "/" + file_name, FileAccess.READ)
		if file == null:
			continue
		var data: Variant = JSON.parse_string(file.get_as_text())
		if data is Dictionary and data.has("id") and data.has("strokes"):
			recognizer.add_template(
				StringName(String(data["id"])), _parse_strokes(data["strokes"] as Array))


func _parse_strokes(stroke_data: Array) -> Array:
	var strokes: Array = []
	for entry in stroke_data:
		var stroke := PackedVector2Array()
		for point_data in (entry as Array):
			stroke.append(Vector2(float(point_data[0]), float(point_data[1])))
		strokes.append(stroke)
	return strokes
