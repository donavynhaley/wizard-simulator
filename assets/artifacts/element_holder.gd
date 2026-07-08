extends CSGCylinder3D

var placed_element: Node3D = null

func focus_prompt(player: Node3D, _collider: Object) -> String:
	var hands = player.get_node_or_null("%HandAnchor")
	if hands == null and placed_element.has_method("get_display_name") and placed_element.call("get_display_name") == "Spring water":
		return "Cold spring water gathers in your hands."
	if hands == null:
		return ""
	
	if placed_element != null:
		return ""
	
	var held = hands.held_item
	if held != null and held.has_method("get_display_name") and held.call("get_display_name") == "Spring water":
		return "Place water here"
		
	return "Place an element here"
	
func interact(player: Node3D, _collider: Object) -> void:
	var hands = player.get_node_or_null("%HandAnchor")
	if hands.held_item == null and placed_element != null:
		hands.pick_up(placed_element)
		placed_element = null
		return 
		
	if hands == null or placed_element != null:
		return
	var held = hands.held_item
	if held == null:
		return
	if not held.has_method("get_display_name"):
		return
	if held.call("get_display_name") != "Spring water":
		return
	hands.release_item(held)
	placed_element = held
	held.reparent(self)
	held.position = Vector3(0, 0.12, 0)
	held.rotation = Vector3.ZERO
