extends Control

## Content authoring tool for creating RuneTemplate resources.

const CATEGORIES: Array[String] = ["form", "effect", "modifier"]
const RuneTemplateResource := preload("res://scripts/spellcraft/rune_template.gd")
const CURVE_SAMPLE_COUNT := 24

@export_dir var output_directory: String = "res://data/runes/templates"
@export var default_canvas_size := Vector2i(1024, 768)
@export_group("Measurements")
@export var recorder_canvas_size_mm := Vector2(360.0, 290.0)
@export var show_measurements: bool = true
@export var major_tick_mm: float = 50.0
@export var minor_tick_mm: float = 10.0

@onready var rune_id_line_edit: LineEdit = %RuneIdLineEdit
@onready var display_name_line_edit: LineEdit = %DisplayNameLineEdit
@onready var notes_edit: TextEdit = %NotesEdit
@onready var category_option: OptionButton = %CategoryOption
@onready var status_label: Label = %StatusLabel
@onready var drawing_surface: Control = %DrawingSurface
@onready var scribe_canvas: ScribeCanvas = %ScribeCanvas
@onready var mode_option: OptionButton = %ModeOption
@onready var save_button: Button = %SaveButton
@onready var undo_button: Button = %UndoButton
@onready var clear_button: Button = %ClearButton

var _is_drawing := false
var _construction_points: Array[Vector2] = []


func _ready() -> void:
	_configure_measurements()
	_populate_categories()
	_populate_modes()
	drawing_surface.gui_input.connect(_on_drawing_surface_gui_input)
	save_button.pressed.connect(_save_template)
	undo_button.pressed.connect(_undo_last_stroke)
	clear_button.pressed.connect(_clear_strokes)
	scribe_canvas.strokes_changed.connect(_on_strokes_changed)
	_update_status()
	rune_id_line_edit.grab_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_finish_stroke()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_construction_points.clear()
		_finish_stroke()
	if event.is_action_pressed("ui_text_delete"):
		_clear_strokes()


func _populate_categories() -> void:
	category_option.clear()
	for category in CATEGORIES:
		category_option.add_item(category)


func _populate_modes() -> void:
	mode_option.clear()
	mode_option.add_item("Draw")
	mode_option.add_item("Line")
	mode_option.add_item("Curve")


func _on_drawing_surface_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index != MOUSE_BUTTON_LEFT:
			return
		_handle_mouse_button(button_event)
		accept_event()
	elif event is InputEventMouseMotion and _is_drawing:
		var motion_event := event as InputEventMouseMotion
		scribe_canvas.append_surface_point(_event_to_canvas_point(motion_event.position))
		accept_event()


func _handle_mouse_button(button_event: InputEventMouseButton) -> void:
	var mode := mode_option.get_item_text(mode_option.selected)
	if mode == "Draw":
		if button_event.pressed:
			var point := _event_to_canvas_point(button_event.position)
			scribe_canvas.begin_surface_stroke(point)
			_is_drawing = true
		else:
			_finish_stroke()
		return
	if not button_event.pressed:
		return

	var point := _event_to_canvas_point(button_event.position)
	if button_event.shift_pressed:
		point = _axis_locked_point(point)
	if mode == "Line":
		_add_line_point(point)
	elif mode == "Curve":
		_add_curve_point(point)


func _add_line_point(point: Vector2) -> void:
	_construction_points.append(point)
	if _construction_points.size() < 2:
		_set_status("Line: click the end point.", false)
		return
	_add_constructed_stroke(_line_points(_construction_points[0], _construction_points[1]))
	_construction_points.clear()


func _add_curve_point(point: Vector2) -> void:
	_construction_points.append(point)
	if _construction_points.size() == 1:
		_set_status("Curve: click the control point.", false)
		return
	if _construction_points.size() == 2:
		_set_status("Curve: click the end point.", false)
		return
	_add_constructed_stroke(_quadratic_curve_points(
		_construction_points[0],
		_construction_points[1],
		_construction_points[2]))
	_construction_points.clear()


func _add_constructed_stroke(points: PackedVector2Array) -> void:
	if points.is_empty():
		return
	scribe_canvas.begin_surface_stroke(points[0])
	for i in range(1, points.size()):
		scribe_canvas.append_surface_point(points[i])
	scribe_canvas.end_surface_stroke()


func _line_points(start: Vector2, end: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(start)
	points.append(end)
	return points


func _quadratic_curve_points(start: Vector2, control: Vector2, end: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in CURVE_SAMPLE_COUNT:
		var t := float(i) / float(CURVE_SAMPLE_COUNT - 1)
		points.append(start.lerp(control, t).lerp(control.lerp(end, t), t))
	return points


func _axis_locked_point(point: Vector2) -> Vector2:
	if _construction_points.is_empty():
		return point
	var anchor := _construction_points[_construction_points.size() - 1]
	var delta := point - anchor
	if delta.length_squared() <= 0.000001:
		return point

	if recorder_canvas_size_mm.x <= 0.0 or recorder_canvas_size_mm.y <= 0.0:
		return point

	var delta_mm := Vector2(
		delta.x * recorder_canvas_size_mm.x,
		delta.y * recorder_canvas_size_mm.y)
	var angle_step := PI / 4.0
	var snapped_angle := roundf(delta_mm.angle() / angle_step) * angle_step
	var direction := Vector2.RIGHT.rotated(snapped_angle)
	if absf(direction.y) < 0.5:
		return Vector2(point.x, anchor.y)
	if absf(direction.x) < 0.5:
		return Vector2(anchor.x, point.y)

	var distance_mm := maxf(absf(delta_mm.x), absf(delta_mm.y))
	var x_sign := 1.0 if direction.x >= 0.0 else -1.0
	var y_sign := 1.0 if direction.y >= 0.0 else -1.0
	return Vector2(
		clampf(anchor.x + x_sign * distance_mm / recorder_canvas_size_mm.x, 0.0, 1.0),
		clampf(anchor.y + y_sign * distance_mm / recorder_canvas_size_mm.y, 0.0, 1.0))


func _configure_measurements() -> void:
	scribe_canvas.show_measurements = show_measurements
	scribe_canvas.canvas_size_mm = recorder_canvas_size_mm
	scribe_canvas.major_tick_mm = major_tick_mm
	scribe_canvas.minor_tick_mm = minor_tick_mm


func _finish_stroke() -> void:
	if not _is_drawing:
		return
	_is_drawing = false
	scribe_canvas.end_surface_stroke()


func _event_to_canvas_point(position: Vector2) -> Vector2:
	var canvas_position := scribe_canvas.position
	var canvas_size := scribe_canvas.size
	if canvas_size.x <= 0.0 or canvas_size.y <= 0.0:
		return Vector2.ZERO
	var local_position := position - canvas_position
	return Vector2(
		clampf(local_position.x / canvas_size.x, 0.0, 1.0),
		clampf(local_position.y / canvas_size.y, 0.0, 1.0))


func _save_template() -> void:
	_finish_stroke()
	var rune_id := _sanitize_id(rune_id_line_edit.text)
	if rune_id.is_empty():
		_set_status("Enter a rune id before saving.", true)
		return
	if not scribe_canvas.has_ink():
		_set_status("Draw at least one stroke before saving.", true)
		return

	var template := RuneTemplateResource.new()
	template.rune_id = rune_id
	template.display_name = display_name_line_edit.text.strip_edges()
	if template.display_name.is_empty():
		template.display_name = rune_id.capitalize()
	template.category = category_option.get_item_text(category_option.selected)
	template.notes = notes_edit.text
	template.recorded_at_unix_time = int(Time.get_unix_time_from_system())
	template.canvas_size = default_canvas_size
	template.canvas_size_mm = recorder_canvas_size_mm
	template.set_strokes(scribe_canvas.get_stroke_snapshot())

	var directory_error := _ensure_output_directory(_template_directory(rune_id))
	if directory_error != OK:
		_set_status("Could not create output directory: %s" % error_string(directory_error), true)
		return

	var path := _next_template_path(rune_id)
	var save_error := ResourceSaver.save(template, path)
	if save_error != OK:
		_set_status("Save failed: %s" % error_string(save_error), true)
		return

	_set_status("Saved %s with %d stroke(s)." % [path, template.stroke_count()], false)


func _ensure_output_directory(path: String) -> Error:
	if path.begins_with("res://") or path.begins_with("user://"):
		return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	return DirAccess.make_dir_recursive_absolute(path)


func _template_directory(rune_id: String) -> String:
	return "%s/%s" % [output_directory.trim_suffix("/"), rune_id]


func _next_template_path(rune_id: String) -> String:
	var directory := _template_directory(rune_id)
	var index := 1
	while true:
		var path := "%s/%s_template_%02d.tres" % [directory, rune_id, index]
		if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
			return path
		index += 1
	return "%s/%s_template_%02d.tres" % [directory, rune_id, index]


func _undo_last_stroke() -> void:
	_finish_stroke()
	_construction_points.clear()
	scribe_canvas.undo_last_stroke()
	_update_status()


func _clear_strokes() -> void:
	_finish_stroke()
	_construction_points.clear()
	scribe_canvas.clear_strokes()
	_update_status()


func _on_strokes_changed(_strokes: Array[PackedVector2Array]) -> void:
	_update_status()


func _update_status() -> void:
	var strokes := scribe_canvas.get_stroke_snapshot()
	var point_count := 0
	for stroke in strokes:
		point_count += stroke.size()
	_set_status("%d stroke(s), %d point(s)" % [strokes.size(), point_count], false)


func _set_status(message: String, is_error: bool) -> void:
	status_label.text = message
	status_label.modulate = Color(1.0, 0.45, 0.35) if is_error else Color(0.82, 0.9, 1.0)


func _sanitize_id(raw_id: String) -> String:
	var stripped := raw_id.strip_edges().to_lower()
	var out := ""
	var previous_was_separator := false
	for i in stripped.length():
		var character := stripped[i]
		var is_valid := (character >= "a" and character <= "z") or (character >= "0" and character <= "9")
		if is_valid:
			out += character
			previous_was_separator = false
		elif not previous_was_separator:
			out += "_"
			previous_was_separator = true
	return out.trim_prefix("_").trim_suffix("_")
