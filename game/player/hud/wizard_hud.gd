class_name WizardHud
extends CanvasLayer

## Minimal diegetic-ish HUD: crosshair dot, the interaction prompt under it,
## and a toast feed. Wires itself to the player's Interactor. Anything in the
## world announces through WizardHud.toast().

const GROUP := &"wizard_hud"
const TEXT_OUTLINE_COLOR := Color(0, 0, 0, 0.8)

var _prompt: Label
var _toasts: VBoxContainer
var _sketching_cursor: TextureRect
var _siphon: SiphonOverlay


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


func configure(interactor: PlayerInteractor) -> void:
	if interactor != null:
		interactor.focus_changed.connect(_on_focus_changed)


func _build() -> void:
	_build_cursor()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_siphon = SiphonOverlay.new()
	_siphon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_siphon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_siphon)

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


func show_toast(text: String) -> void:
	var label := _styled_label(18, Color(1.0, 0.95, 0.75), 5)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toasts.add_child(label)
	var tween := label.create_tween()
	tween.tween_interval(3.2)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)

func _build_cursor() -> void:
	_sketching_cursor = TextureRect.new()
	_sketching_cursor.texture = preload("res://assets/external/sketching_crosshair.png")
	_sketching_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sketching_cursor.visible = false
	add_child(_sketching_cursor)

func show_sketch_cursor(shown: bool) -> void:
	_sketching_cursor.visible = shown

func set_sketch_cursor(pos: Vector2) -> void:
	var cursor_position_centered = pos - _sketching_cursor.texture.get_size() * 0.5
	_sketching_cursor.position = cursor_position_centered


func set_siphon_markers(markers: Array) -> void:
	if _siphon != null:
		_siphon.set_markers(markers)
