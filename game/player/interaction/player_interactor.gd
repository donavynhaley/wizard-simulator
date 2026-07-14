class_name PlayerInteractor
extends RayCast3D

## Look-to-focus interaction. Lives under the player camera; whatever the
## crosshair rests on gets focused, and E interacts with it.
##
## Interactable contract (dispatched by method name, on the collider, an
## ancestor, or a direct component child of either):
##   focus_prompt(player: WizardPlayer, collider) -> String   what the HUD shows
##   interact(player: WizardPlayer, collider)                 do the thing
## The player is the typed WizardPlayer, so implementers get player.hands
## autocompletion. The collider is passed through so multi-part props (like
## the crafting table's element holder) can tell which part was used.

signal focus_changed(prompt: String)

const LAYER_WORLD := 1
const LAYER_PICKUP := 2

var _player: WizardPlayer
var _focused: Node
var _focused_collider: Object


func _ready() -> void:
	enabled = true
	target_position = Vector3(0.0, 0.0, -2.8)
	collision_mask = LAYER_WORLD | LAYER_PICKUP
	collide_with_areas = false
	_player = owner as WizardPlayer


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


## Suspends or resumes the whole look-to-focus loop. Deactivating also clears
## the HUD prompt.
func set_active(active: bool) -> void:
	enabled = active
	set_physics_process(active)
	set_process_unhandled_input(active)
	if not active:
		clear_focus()


func clear_focus() -> void:
	_focused = null
	_focused_collider = null
	focus_changed.emit("")


func _find_interactable(from: Object) -> Node:
	var node := from as Node
	while node:
		var interactable := _interaction_target_on(node)
		if interactable != null:
			return interactable
		node = node.get_parent()
	return null


func _interaction_target_on(node: Node) -> Node:
	if node.has_method("interact") and node.has_method("focus_prompt"):
		return node
	for child in node.get_children():
		if child.has_method("interact") and child.has_method("focus_prompt"):
			return child
	return null
