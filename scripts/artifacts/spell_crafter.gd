extends Node3D

## Scribing station on the crafting table. Interacting with empty hands takes
## over the camera (ScribeCamera), locks the player through
## WizardPlayer.set_control_enabled(), and lets the player draw strokes onto
## the scroll via a ScribeCanvas rendered to a SubViewport.

signal scribing_started
signal scribing_completed(stroke_count: int)
signal scribing_cancelled
signal rune_recognized(result: Resource)
signal rune_rejected(result: Resource)
signal spell_scroll_created(scroll: SpellScrollData)

const RuneRecognizerResource := preload("res://scripts/spellcraft/rune_recognizer.gd")
const SpellScrollDataResource := preload("res://systems/spells/resources/spell_scroll_data.gd")
const SpellCompilerResource := preload("res://systems/spells/compiler/spell_compiler.gd")
const DEFAULT_SPELL_SCROLL_SCENE := preload("res://scenes/artifacts/spell_scroll_item.tscn")

@export var prompt_text := "Begin scribing"
@export var held_item_prompt := "Empty your hands first"
@export var active_prompt := "Scribing - draw runes / hold Space to seal"
@export var sealed_prompt := "Spell sealed"

@export_group("Scribing")
## Input action the player holds to seal a spell after drawing at least one mark.
@export var seal_action: StringName = &"jump"
## Seconds the seal action must be held before the spell completes.
@export var seal_hold_time: float = 0.8
## Width of the physical ink mesh drawn back onto the table scroll.
@export var ink_width: float = 0.007
## Small vertical offset that keeps physical ink from z-fighting with the scroll.
@export var ink_lift: float = 0.001
## Pixel size of the render texture that is projected onto the scroll surface.
@export var scribe_texture_size := Vector2i(1024, 768)
## Draws the scroll's millimeter ruler/grid into the projected scribe texture.
@export var show_scroll_measurements: bool = true
## Major ruler interval in millimeters.
@export var measurement_major_tick_mm: float = 50.0
## Minor ruler interval in millimeters.
@export var measurement_minor_tick_mm: float = 10.0

@export_group("Rune Recognition")
@export_dir var rune_template_directory: String = "res://data/runes/templates"
@export var load_rune_templates_on_ready: bool = true

@export_group("Spell Crafting")
@export var default_element_id: StringName = &"water"
@export var default_ink_id: StringName = &"gilded"
@export var default_seal_id: StringName = &"cast_on_use"
@export var spell_scroll_scene: PackedScene = DEFAULT_SPELL_SCROLL_SCENE
@export var reference_book_position := Vector3(-0.36, 0.12, 0.18)
@export var reference_book_rotation_degrees := Vector3(0.0, 24.0, 0.0)

@export_group("Table Camera")
@export_multiline var table_camera_notes := "Scribing requires this Camera3D. Move, rotate, and tune its FOV directly in the crafting table scene for exact composition."
## Required Camera3D in the crafting table scene. Move this camera in the editor for exact scribing composition.
@export_node_path("Camera3D") var scribe_camera_path: NodePath = ^"ScribeCamera"

@export_group("Scribe Props")
## Existing quill node moved during scribing. Leave as Quill for the current crafting table scene.
@export_node_path("Node3D") var quill_path: NodePath = ^"Quill"
## 0 locks directly to the mouse. Higher values add catch-up smoothing.
@export var prop_follow_speed: float = 0.0
## How far above the scroll surface the quill body rides while the tip follows the cursor.
@export var quill_hover_lift: float = 0.002
## Local offset from the quill origin to the writing tip.
@export var quill_tip_local_offset := Vector3(0.0, -0.038, 0.0)
## How much the quill leans forward over the scroll.
@export var quill_pitch_degrees: float = -54.0
## Rotates the quill around the scroll surface normal.
@export var quill_yaw_degrees: float = -36.0

@export_group("Scribe Arm")
## Shoulder anchor of the drawing arm, in SpellCrafter space. The ScribeArm
## node's origin is the shoulder joint; the whole scroll must stay within
## roughly 0.5 m (the wizard's arm reach) of this point.
@export var arm_shoulder_position := Vector3(0.38, 1.18, -0.38)
## Orientation of the arm anchor. Tune with the shoulder position for composition.
@export var arm_rotation_degrees := Vector3.ZERO
## Where the hand grips, relative to the quill origin (quill space).
@export var hand_grip_offset := Vector3(0.0, 0.005, 0.0)
## How far the wrist sits back from the grip toward the shoulder, so the
## fingers (not the wrist joint) land on the quill.
@export var wrist_back_distance: float = 0.06

@onready var scroll: Node3D = $Scroll
@onready var quill: Node3D = get_node_or_null(quill_path) as Node3D

var _active := false
var _sealed := false
var _player: WizardPlayer
var _original_camera: Camera3D
var _scribe_camera: Camera3D
var _scribe_viewport: SubViewport
var _scribe_surface: MeshInstance3D
var _scribe_canvas: ScribeCanvas
var _saved_strokes: Array[PackedVector2Array] = []
var _rune_recognizer: Resource
var _recognized_by_category: Dictionary = {}
var _quality_by_category: Dictionary = {}
var _spell_compiler := SpellCompilerResource.new()
var _last_created_scroll: SpellScrollData
var _reference_book: Book
var _seal_hold_elapsed := 0.0
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _scribe_arm: ScribeArm
var _quill_rest_transform := Transform3D.IDENTITY
var _last_cursor_point := Vector2(0.5, 0.5)
var _has_cursor_point := false


func _ready() -> void:
	_configure_rune_recognizer()
	if quill:
		_quill_rest_transform = quill.transform
	_create_scribe_surface()
	_create_scribe_arm()
	_ensure_quill_tip()


func interact(player: WizardPlayer, _collider: Object) -> void:
	if _active:
		return
	if _sealed:
		WizardHud.toast(self, sealed_prompt)
		return

	if player == null or player.hands == null:
		return
	if player.hands.held_item is Book and _reference_book == null:
		_place_reference_book(player.hands.held_item as Book, player)
		return
	if player.hands.held_item == null and _reference_book != null:
		_take_reference_book(player)
		return
	if player.hands.held_item != null:
		WizardHud.toast(self, held_item_prompt)
		return

	_begin_scribing(player)


func focus_prompt(player: WizardPlayer, _collider: Object) -> String:
	if _active:
		return ""
	if _sealed:
		return sealed_prompt

	if player == null or player.hands == null:
		return ""
	if player.hands.held_item is Book and _reference_book == null:
		return "Place book reference"
	if player.hands.held_item == null and _reference_book != null:
		return "Take book reference"
	if player.hands.held_item != null:
		return held_item_prompt
	return prompt_text


func _place_reference_book(book: Book, player: WizardPlayer) -> void:
	if book == null or player == null or player.hands == null:
		return
	player.hands.release_item(book)
	_reference_book = book
	book.reparent(self)
	book.position = reference_book_position
	book.rotation_degrees = reference_book_rotation_degrees
	book.scale = Vector3.ONE
	book.set_stationed(true)
	book.open_for_reference()


func _take_reference_book(player: WizardPlayer) -> void:
	if _reference_book == null or player == null or player.hands == null:
		return
	var book := _reference_book
	_reference_book = null
	book.set_stationed(false)
	player.hands.pick_up(book)


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_cancel"):
		_end_scribing(false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index == MOUSE_BUTTON_LEFT:
			var point: Variant = _scroll_point_from_screen(button_event.position)
			if button_event.pressed and point != null:
				var stroke_point := point as Vector2
				var category := _scribe_canvas.category_for_point(stroke_point)
				if _scribe_canvas.is_category_recognized(category):
					WizardHud.toast(self, "%s rune already set" % category.capitalize())
				else:
					_scribe_canvas.begin_surface_stroke(stroke_point)
					_set_cursor_point(stroke_point)
				get_viewport().set_input_as_handled()
			elif not button_event.pressed:
				_scribe_canvas.end_surface_stroke()
				_try_auto_recognize_category(_scribe_canvas.get_last_stroke_category())
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var point: Variant = _scroll_point_from_screen(motion.position)
		if point != null:
			_set_cursor_point(point as Vector2)
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_scribe_canvas.append_surface_point(point as Vector2)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _active or _scribe_canvas == null:
		return

	var point: Variant = _scroll_point_from_screen(get_viewport().get_mouse_position())
	if point != null:
		_set_cursor_point(point as Vector2)
	_update_scribe_props(delta)

	if (_scribe_canvas.has_ink() or not _recognized_by_category.is_empty()) and Input.is_action_pressed(seal_action):
		_seal_hold_elapsed = minf(_seal_hold_elapsed + delta, seal_hold_time)
		_scribe_canvas.seal_hold_progress = _seal_hold_elapsed / maxf(seal_hold_time, 0.001)
		if _seal_hold_elapsed >= seal_hold_time:
			_end_scribing(true, max(_recognized_by_category.size(), _scribe_canvas.strokes.size()))
	else:
		_seal_hold_elapsed = 0.0
		_scribe_canvas.seal_hold_progress = 0.0


func _try_auto_recognize_category(category: String) -> Resource:
	if _scribe_canvas == null or not _scribe_canvas.has_ink():
		return null
	if category.is_empty() or _scribe_canvas.is_category_recognized(category):
		return null
	if _rune_recognizer == null:
		WizardHud.toast(self, "Rune recognizer is unavailable")
		return null
	if _rune_recognizer.get("rune_definitions").is_empty():
		WizardHud.toast(self, "No rune templates recorded")
		return null

	_scribe_canvas.end_surface_stroke()
	var category_strokes := _scribe_canvas.get_strokes_for_category(category)
	var result := _rune_recognizer.call("recognize", category_strokes, category) as Resource
	if result == null:
		WizardHud.toast(self, "Rune did not resolve")
		return null

	if bool(result.call("is_match")):
		_recognized_by_category[category] = result.get("rune") as Resource
		_quality_by_category[category] = float(result.get("confidence"))
		_scribe_canvas.mark_category_recognized(category)
		WizardHud.toast(self, "%s recognized (%d%%)" % [
			_result_rune_name(result),
			int(roundf(float(result.get("confidence")) * 100.0)),
		])
		rune_recognized.emit(result)
	else:
		WizardHud.toast(self, "Unknown rune (%d%%)" % int(roundf(float(result.get("confidence")) * 100.0)))
		rune_rejected.emit(result)
	return result


func get_recognized_rune_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for category in _scribe_canvas.get_segment_categories():
		var rune := _recognized_by_category.get(category, null) as Resource
		if rune == null:
			continue
		var id: Variant = rune.get("id")
		if id is StringName:
			ids.append(id as StringName)
		elif id is String:
			ids.append(StringName(id as String))
	return ids


func get_rune_qualities() -> Array[float]:
	var qualities: Array[float] = []
	for category in _scribe_canvas.get_segment_categories():
		if _quality_by_category.has(category):
			qualities.append(float(_quality_by_category[category]))
	return qualities


func _begin_scribing(player: WizardPlayer) -> void:
	_active = true
	_player = player
	_recognized_by_category.clear()
	_quality_by_category.clear()
	_seal_hold_elapsed = 0.0
	_previous_mouse_mode = Input.mouse_mode
	_original_camera = get_viewport().get_camera_3d()
	_last_cursor_point = Vector2(0.5, 0.5)
	_has_cursor_point = true

	if not _activate_scribe_camera():
		_active = false
		return
	player.set_control_enabled(false)
	if _scribe_arm:
		_scribe_arm.set_active(true)
	_create_scribe_surface()
	_update_scribe_props(1.0)
	if _reference_book != null:
		_reference_book.set_reference_page_turn_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	scribing_started.emit()


func _end_scribing(completed: bool, stroke_count: int = 0) -> void:
	if not _active:
		return

	_active = false
	if _reference_book != null:
		_reference_book.set_reference_page_turn_enabled(false)
	if _original_camera and is_instance_valid(_original_camera):
		_original_camera.make_current()

	_scribe_camera = null
	Input.mouse_mode = _previous_mouse_mode

	if _player and is_instance_valid(_player):
		_player.set_control_enabled(true)
		if _scribe_arm:
			_scribe_arm.set_active(false)
		if quill:
			quill.transform = _quill_rest_transform
		if completed:
			var crafted_scroll := _craft_spell_scroll()
			if crafted_scroll == null:
				WizardHud.toast(self, "The scroll needs a form and effect rune.")
				scribing_cancelled.emit()
			else:
				_sealed = true
				_finish_scroll_visual()
				_give_scroll_to_player(crafted_scroll)
				WizardHud.toast(self, "Created %s" % crafted_scroll.display_name)
				scribing_completed.emit(stroke_count)
		else:
			scribing_cancelled.emit()

	_player = null
	_original_camera = null


func _craft_spell_scroll() -> SpellScrollData:
	var form_id := _rune_id_for_category("form")
	var effect_id := _rune_id_for_category("effect")
	if form_id == &"" or effect_id == &"":
		return null

	var scroll := SpellScrollDataResource.new() as SpellScrollData
	scroll.element_id = default_element_id
	scroll.form_rune_ids = [form_id]
	scroll.effect_rune_ids = [effect_id]
	var modifier_id := _rune_id_for_category("modifier")
	if modifier_id != &"":
		scroll.modifier_rune_ids = [modifier_id]
	scroll.ink_id = default_ink_id
	scroll.seal_id = default_seal_id
	scroll.quality = _average_rune_quality()
	if _spell_compiler.compile_scroll(scroll) == null:
		return null
	_last_created_scroll = scroll
	spell_scroll_created.emit(scroll)
	return scroll


func _give_scroll_to_player(scroll_data: SpellScrollData) -> void:
	if _player == null or _player.hands == null or spell_scroll_scene == null:
		return
	var item := spell_scroll_scene.instantiate() as Node3D
	if item == null:
		return
	get_tree().current_scene.add_child(item)
	item.global_position = global_position + Vector3.UP * 0.5
	if item.has_method("set_scroll_data"):
		item.call("set_scroll_data", scroll_data)
	else:
		item.set("scroll_data", scroll_data)
	_player.hands.pick_up(item)


func _rune_id_for_category(category: String) -> StringName:
	var rune := _recognized_by_category.get(category, null) as Resource
	if rune == null:
		return &""
	var id: Variant = rune.get("id")
	if id is StringName:
		return id as StringName
	if id is String:
		return StringName(id as String)
	return &""


func _average_rune_quality() -> float:
	if _quality_by_category.is_empty():
		return 1.0
	var total := 0.0
	var count := 0
	for category in _quality_by_category.keys():
		total += float(_quality_by_category[category])
		count += 1
	return clampf(total / maxf(float(count), 1.0), 0.0, 1.0)


func get_last_created_scroll() -> SpellScrollData:
	return _last_created_scroll


func _activate_scribe_camera() -> bool:
	_scribe_camera = get_node_or_null(scribe_camera_path) as Camera3D
	if _scribe_camera == null:
		push_error("SpellCrafter requires a Camera3D at scribe_camera_path.")
		return false
	_scribe_camera.make_current()
	return true


func _configure_rune_recognizer() -> void:
	_rune_recognizer = RuneRecognizerResource.new()
	if not load_rune_templates_on_ready:
		return
	var error := _rune_recognizer.call("load_templates_from_directory", rune_template_directory) as Error
	if error != OK and error != ERR_FILE_NOT_FOUND and error != ERR_DOES_NOT_EXIST:
		push_warning("Could not load rune templates from %s: %s" % [rune_template_directory, error_string(error)])


func _create_scribe_surface() -> void:
	if _scribe_viewport != null and _scribe_canvas != null and _scribe_surface != null:
		return

	_scribe_viewport = SubViewport.new()
	_scribe_viewport.name = "ScribeInkViewport"
	_scribe_viewport.transparent_bg = true
	_scribe_viewport.disable_3d = true
	_scribe_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_scribe_viewport.size = scribe_texture_size
	add_child(_scribe_viewport)

	var scroll_size := _scroll_size()
	_scribe_canvas = ScribeCanvas.new()
	_scribe_canvas.name = "ScribeCanvas"
	_scribe_canvas.initial_strokes = _duplicate_strokes(_saved_strokes)
	_scribe_canvas.show_measurements = show_scroll_measurements
	_scribe_canvas.canvas_size_mm = Vector2(scroll_size.x * 1000.0, scroll_size.z * 1000.0)
	_scribe_canvas.major_tick_mm = measurement_major_tick_mm
	_scribe_canvas.minor_tick_mm = measurement_minor_tick_mm
	_scribe_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scribe_canvas.strokes_changed.connect(_on_canvas_strokes_changed)
	_scribe_viewport.add_child(_scribe_canvas)

	_scribe_surface = MeshInstance3D.new()
	_scribe_surface.name = "ScribeInkSurface"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(scroll_size.x, scroll_size.z)
	_scribe_surface.mesh = mesh
	_scribe_surface.position = Vector3(0.0, scroll_size.y * 0.5 + ink_lift, 0.0)
	_scribe_surface.material_override = _scribe_surface_material()
	scroll.add_child(_scribe_surface)


func _on_canvas_strokes_changed(strokes: Array[PackedVector2Array]) -> void:
	_saved_strokes = _duplicate_strokes(strokes)


func _set_cursor_point(point: Vector2) -> void:
	_last_cursor_point = point
	_has_cursor_point = true


func _finish_scroll_visual() -> void:
	if scroll is GeometryInstance3D:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.82, 0.72, 0.52)
		material.emission_enabled = true
		material.emission = Color(0.25, 0.72, 1.0)
		material.emission_energy_multiplier = 0.35
		(scroll as GeometryInstance3D).material_override = material


func _result_rune_name(result: Resource) -> String:
	var rune := result.get("rune") as Resource
	if rune == null:
		return "rune"
	var display_name: Variant = rune.get("display_name")
	if display_name is String and not String(display_name).is_empty():
		return display_name as String
	var id: Variant = rune.get("id")
	if id is StringName:
		return String(id).capitalize()
	if id is String:
		return String(id).capitalize()
	return "rune"


func _create_scribe_arm() -> void:
	if _scribe_arm:
		return
	_scribe_arm = ScribeArm.new()
	_scribe_arm.name = "ScribeArm"
	_scribe_arm.position = arm_shoulder_position
	_scribe_arm.rotation_degrees = arm_rotation_degrees
	add_child(_scribe_arm)


func _ensure_quill_tip() -> void:
	if quill == null or quill.get_node_or_null("WritingTip") != null:
		return

	var tip_material := StandardMaterial3D.new()
	tip_material.albedo_color = Color(0.04, 0.025, 0.035)
	tip_material.roughness = 0.38

	var tip_mesh := CylinderMesh.new()
	tip_mesh.bottom_radius = 0.009
	tip_mesh.top_radius = 0.0
	tip_mesh.height = 0.03
	var tip := MeshInstance3D.new()
	tip.name = "WritingTip"
	tip.mesh = tip_mesh
	tip.material_override = tip_material
	tip.position = quill_tip_local_offset
	tip.rotation_degrees = Vector3(180.0, 0.0, 0.0)
	quill.add_child(tip)


func _update_scribe_props(delta: float) -> void:
	if not _has_cursor_point:
		return

	var scroll_size := _scroll_size()
	var top_y := scroll_size.y * 0.5 + ink_lift
	var cursor_local := _scroll_point(_last_cursor_point, scroll_size, top_y)
	var cursor_global := scroll.to_global(cursor_local)
	var prop_basis := _scribe_prop_basis()
	var surface_normal := scroll.global_transform.basis.y.normalized()
	var desired_origin := cursor_global + surface_normal * quill_hover_lift - prop_basis * quill_tip_local_offset
	var weight := 1.0 if prop_follow_speed <= 0.0 else clampf(prop_follow_speed * delta, 0.0, 1.0)

	if quill:
		var current_origin := quill.global_position
		quill.global_transform = Transform3D(prop_basis, current_origin.lerp(desired_origin, weight))
		if _scribe_arm:
			var grip: Vector3 = quill.global_transform * hand_grip_offset
			var toward_shoulder := (_scribe_arm.global_position - grip).normalized()
			_scribe_arm.track(grip + toward_shoulder * wrist_back_distance)


func _scribe_prop_basis() -> Basis:
	var prop_basis := scroll.global_transform.basis.orthonormalized()
	prop_basis = prop_basis.rotated(scroll.global_transform.basis.y.normalized(), deg_to_rad(quill_yaw_degrees))
	prop_basis = prop_basis.rotated(prop_basis.x.normalized(), deg_to_rad(quill_pitch_degrees))
	return prop_basis.orthonormalized()


func _scroll_point(point: Vector2, scroll_size: Vector3, top_y: float) -> Vector3:
	return Vector3(
		(point.x - 0.5) * scroll_size.x,
		top_y,
		(point.y - 0.5) * scroll_size.z)


func _scroll_point_from_screen(screen_position: Vector2) -> Variant:
	if _scribe_camera == null:
		return null

	var scroll_size := _scroll_size()
	var top_y := scroll_size.y * 0.5 + ink_lift
	var plane_point := scroll.to_global(Vector3(0.0, top_y, 0.0))
	var plane_normal := scroll.global_transform.basis.y.normalized()
	var plane := Plane(plane_normal, plane_point)
	var ray_origin := _scribe_camera.project_ray_origin(screen_position)
	var ray_direction := _scribe_camera.project_ray_normal(screen_position)
	var intersection = plane.intersects_ray(ray_origin, ray_direction)
	if intersection == null:
		return null

	var local_point := scroll.to_local(intersection)
	var width := scroll_size.x 
	var height := scroll_size.z
	var point := Vector2(local_point.x / width + 0.5, local_point.z / height + 0.5)
	if point.x < 0.0 or point.x > 1.0 or point.y < 0.0 or point.y > 1.0:
		return null
	return point


func _scroll_size() -> Vector3:
	var size = scroll.get("size")
	if size is Vector3:
		return size as Vector3
	return Vector3(0.36, 0.02, 0.29)


func _scribe_surface_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.albedo_texture = _scribe_viewport.get_texture()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _duplicate_strokes(source: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for stroke in source:
		out.append(PackedVector2Array(stroke))
	return out
