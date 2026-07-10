class_name WizardHud
extends CanvasLayer

## Minimal diegetic-ish HUD: crosshair dot, the interaction prompt under it,
## a held-item line, and a toast feed. Wires itself to the player's Interactor
## and HandAnchor (scene-unique names). Anything in the world announces
## through WizardHud.toast().

const GROUP := &"wizard_hud"
const TEXT_OUTLINE_COLOR := Color(0, 0, 0, 0.8)

var _prompt: Label
var _held_line: Label
var _toasts: VBoxContainer
var _held_item: Node3D


## Canonical way for props and stations to surface a message. `from` is any
## node in the tree, used only to reach the active HUD.
static func toast(from: Node, message: String) -> void:
	if from == null or not from.is_inside_tree():
		return
	var hud := from.get_tree().get_first_node_in_group(GROUP) as WizardHud
	if hud:
		hud.show_toast(message)


func _ready() -> void:
	add_to_group(GROUP)
	_build()

	var interactor := get_node_or_null(^"%Interactor") as PlayerInteractor
	if interactor:
		interactor.focus_changed.connect(_on_focus_changed)
	var hands := get_node_or_null(^"%HandAnchor") as WizardHands
	if hands:
		hands.held_changed.connect(_on_held_changed)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var dot := ColorRect.new()
	dot.color = Color(0.95, 0.93, 0.85, 0.8)
	dot.custom_minimum_size = Vector2(4, 4)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position = Vector2(-2, -2)
	root.add_child(dot)

	_prompt = _styled_label(17, Color(0.95, 0.92, 0.8), 4)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.position = Vector2(-320, 28)
	_prompt.custom_minimum_size = Vector2(640, 30)
	root.add_child(_prompt)

	_held_line = _styled_label(16, Color(0.85, 0.88, 1.0), 4)
	_held_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_held_line.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_held_line.position = Vector2(-620, -46)
	_held_line.custom_minimum_size = Vector2(600, 30)
	root.add_child(_held_line)

	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.position = Vector2(-350, 40)
	_toasts.custom_minimum_size = Vector2(700, 0)
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(_toasts)


func _styled_label(font_size: int, color: Color, outline_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", TEXT_OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", outline_size)
	return label


func _on_focus_changed(prompt: String) -> void:
	_prompt.text = prompt


func _on_held_changed(item: Node3D) -> void:
	_disconnect_held_hint()
	_held_item = item
	if _held_item != null and _held_item.has_signal(&"held_hint_changed"):
		_held_item.connect(&"held_hint_changed", _on_held_hint_changed)
	if item == null:
		_held_line.text = ""
	elif item.has_method("get_held_hint"):
		_held_line.text = str(item.call("get_held_hint"))
	elif item.has_method("cast_from"):
		var display_name: String = str(item.call("get_display_name")) if item.has_method("get_display_name") else item.name
		_held_line.text = "%s  [LMB cast / G drop]" % display_name
	elif item.has_method("get_display_name"):
		_held_line.text = "%s  [G release]" % str(item.call("get_display_name"))
	else:
		_held_line.text = "%s  [G drop]" % item.name


func _on_held_hint_changed(hint: String) -> void:
	_held_line.text = hint


func _disconnect_held_hint() -> void:
	if _held_item == null or not is_instance_valid(_held_item):
		return
	var callable := Callable(self, "_on_held_hint_changed")
	if _held_item.has_signal(&"held_hint_changed") \
		and _held_item.is_connected(&"held_hint_changed", callable):
		_held_item.disconnect(&"held_hint_changed", callable)


func show_toast(text: String) -> void:
	var label := _styled_label(18, Color(1.0, 0.95, 0.75), 5)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toasts.add_child(label)
	var tween := label.create_tween()
	tween.tween_interval(3.2)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)
