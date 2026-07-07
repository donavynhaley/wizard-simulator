class_name WizardHud
extends CanvasLayer

## Minimal diegetic-ish HUD: crosshair dot, the interaction prompt under it,
## a held-item line, and a toast feed for forge results and discoveries.
## Wires itself to the player's Interactor and HandAnchor (scene-unique names)
## and to the Spellbook autoload.

var _prompt: Label
var _held_line: Label
var _toasts: VBoxContainer


func _ready() -> void:
	add_to_group("wizard_hud")
	_build()

	var interactor := get_node_or_null("%Interactor") as PlayerInteractor
	if interactor:
		interactor.focus_changed.connect(_on_focus_changed)
	var hands := get_node_or_null("%HandAnchor") as WizardHands
	if hands:
		hands.held_changed.connect(_on_held_changed)
	var journal := get_tree().root.get_node_or_null(^"Spellbook")
	if journal:
		if journal.has_signal("toast"):
			journal.toast.connect(show_toast)
		if journal.has_signal("discovery_made"):
			journal.discovery_made.connect(_on_discovery)


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

	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.position = Vector2(-320, 28)
	_prompt.custom_minimum_size = Vector2(640, 30)
	_prompt.add_theme_font_size_override("font_size", 17)
	_prompt.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_prompt.add_theme_constant_override("outline_size", 4)
	root.add_child(_prompt)

	_held_line = Label.new()
	_held_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_held_line.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_held_line.position = Vector2(-620, -46)
	_held_line.custom_minimum_size = Vector2(600, 30)
	_held_line.add_theme_font_size_override("font_size", 16)
	_held_line.add_theme_color_override("font_color", Color(0.85, 0.88, 1.0))
	_held_line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_held_line.add_theme_constant_override("outline_size", 4)
	root.add_child(_held_line)

	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.position = Vector2(-350, 40)
	_toasts.custom_minimum_size = Vector2(700, 0)
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(_toasts)


func _on_focus_changed(prompt: String) -> void:
	_prompt.text = prompt


func _on_held_changed(item: Node3D) -> void:
	if item == null:
		_held_line.text = ""
	elif item.has_method("get_display_name"):
		_held_line.text = "%s  [G release]" % str(item.call("get_display_name"))
	elif item.has_method("cast_from"):
		_held_line.text = "%s  [LMB cast / G drop]" % item.name
	elif item.get("rune") != null:
		_held_line.text = "%s rune  [socket at a bench / G drop]" % item.get("rune").display_name
	else:
		_held_line.text = "%s  [G drop]" % item.name


func _on_discovery(_entry: Dictionary) -> void:
	# The Spellbook already toasts the headline; add the tally underneath.
	var journal := get_tree().root.get_node_or_null(^"Spellbook")
	if journal and journal.has_method("discovered_count"):
		show_toast("Spellbook: %d combinations recorded." % int(journal.call("discovered_count")))


func show_toast(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 5)
	_toasts.add_child(label)
	var tween := label.create_tween()
	tween.tween_interval(3.2)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)
