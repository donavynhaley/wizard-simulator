extends CSGCylinder3D

## Crafting-table socket that holds one element. The player swaps items in and
## out through their hands; spring water is the only element so far.

@export var empty_prompt := "Place an element here"
@export var place_water_prompt := "Place water here"
@export var element_rest_offset := Vector3(0.0, 0.12, 0.0)

var placed_element: Node3D = null


func focus_prompt(player: WizardPlayer, _collider: Object) -> String:
	if player == null or player.hands == null:
		return ""
	var hands := player.hands

	_drop_invalid_element()
	if placed_element != null:
		if hands.held_item == null:
			return "Take %s" % _element_name(placed_element)
		return ""

	if hands.held_item == null:
		return empty_prompt
	if hands.held_item is HeldWater:
		return place_water_prompt
	return ""


func interact(player: WizardPlayer, _collider: Object) -> void:
	if player == null or player.hands == null:
		return
	var hands := player.hands

	_drop_invalid_element()
	if placed_element != null:
		if hands.held_item == null:
			var element := placed_element
			placed_element = null
			hands.pick_up(element)
		return

	var held := hands.held_item
	if not (held is HeldWater):
		return
	hands.release_item(held)
	placed_element = held
	held.reparent(self)
	held.position = element_rest_offset
	held.rotation = Vector3.ZERO


func _drop_invalid_element() -> void:
	if placed_element != null and not is_instance_valid(placed_element):
		placed_element = null


func _element_name(element: Node3D) -> String:
	if element.has_method("get_display_name"):
		return str(element.call("get_display_name"))
	return element.name
