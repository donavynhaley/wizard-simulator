class_name PlayerInteractor
extends RayCast3D

## Look-to-focus interaction. Lives under the player camera; whatever the
## crosshair rests on gets focused, and E interacts with it.
##
## Interactable contract (duck-typed, on the collider or any ancestor):
##   focus_prompt(player, collider) -> String   what the HUD shows
##   interact(player, collider)                 do the thing
## The collider is passed through so multi-part props (like the SpellBench's
## sockets) can tell which part was used.

signal focus_changed(prompt: String)

var _player: Node3D
var _focused: Node
var _focused_collider: Object


func _ready() -> void:
	enabled = true
	target_position = Vector3(0.0, 0.0, -2.8)
	collision_mask = SpellCast.LAYER_WORLD | SpellCast.LAYER_PICKUP
	collide_with_areas = false
	_player = owner


func _physics_process(_delta: float) -> void:
	var collider: Object = get_collider() if is_colliding() else null
	var interactable := _find_interactable(collider)
	if interactable != _focused or collider != _focused_collider:
		_focused = interactable
		_focused_collider = collider
		var prompt := ""
		if _focused:
			prompt = str(_focused.call("focus_prompt", _player, collider))
			if prompt != "":
				prompt += "   [E]"
		focus_changed.emit(prompt)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _focused and is_instance_valid(_focused):
		_focused.call("interact", _player, _focused_collider)
		# Prompts usually change after an interaction; force a refresh.
		_focused = null
		_focused_collider = null


func _find_interactable(from: Object) -> Node:
	var node := from as Node
	while node:
		if node.has_method("interact") and node.has_method("focus_prompt"):
			return node
		node = node.get_parent()
	return null
