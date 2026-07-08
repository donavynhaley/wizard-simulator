extends SceneTree

## End-to-end check of the interaction chain in the real tower scene:
## fountain -> hands -> element holder -> take back, plus the spell crafter
## locking and unlocking the player. Run headless:
##   godot --headless --path . -s tools/interaction_test.gd

var _fail := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := (load("res://scenes/levels/wizard_tower.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame

	var player := scene.get_node_or_null("Player") as WizardPlayer
	_check(player != null, "player is a WizardPlayer")
	var hands := player.hands
	_check(hands != null, "player.hands resolves the typed hand anchor")
	_check(player.interactor != null, "player.interactor resolves the typed interactor")

	var fountain := _find_by_type(scene, "FountainOfEndlessSpring") as FountainOfEndlessSpring
	var holder := scene.find_child("ElementHolder", true, false)
	var crafter := scene.find_child("SpellCrafter", true, false)
	_check(fountain != null, "tower has a fountain")
	_check(holder != null, "tower has an element holder")
	_check(crafter != null, "tower has a spell crafter")
	if _fail > 0:
		_finish()
		return

	# Fountain: empty hands -> cup water.
	_check(fountain.focus_prompt(player, null) == fountain.prompt_text,
		"fountain prompts to cup water with empty hands")
	fountain.interact(player, null)
	_check(hands.held_item is HeldWater, "fountain fills the hands with spring water")
	_check(fountain.focus_prompt(player, null) == fountain.refresh_prompt,
		"fountain offers a refresh while holding water")

	# Element holder: place the water, then take it back.
	_check(str(holder.focus_prompt(player, null)) == holder.place_water_prompt,
		"holder prompts to place held water")
	holder.interact(player, null)
	_check(hands.held_item == null, "placing water empties the hands")
	_check(holder.placed_element is HeldWater, "holder keeps the placed water")
	_check(holder.placed_element.get_parent() == holder, "water reparents to the holder")
	_check(str(holder.focus_prompt(player, null)).begins_with("Take"),
		"holder prompts to take the element back")
	holder.interact(player, null)
	_check(hands.held_item is HeldWater, "taking back returns the water to the hands")
	_check(holder.placed_element == null, "holder is empty after take-back")

	# Spell crafter refuses while hands are full, then locks the player.
	_check(str(crafter.focus_prompt(player, null)) == crafter.held_item_prompt,
		"crafter prompts to empty hands first")
	crafter.interact(player, null)
	_check(not crafter._active, "crafter refuses to start with full hands")

	hands.drop()
	await process_frame
	_check(hands.held_item == null, "dropping water empties the hands")

	_check(str(crafter.focus_prompt(player, null)) == crafter.prompt_text,
		"crafter prompts to begin scribing with empty hands")
	crafter.interact(player, null)
	_check(crafter._active, "crafter enters scribing mode")
	_check(not player.is_physics_processing(), "scribing freezes the player")
	var interactor := player.interactor
	_check(not interactor.enabled, "scribing suspends the interactor")

	# The rigged scribe arm follows the quill with IK while drawing.
	var arm := crafter.get_node_or_null("ScribeArm") as ScribeArm
	_check(arm != null, "crafter has a rigged scribe arm")
	_check(arm.visible, "scribe arm shows while scribing")
	var quill := crafter.get_node("Quill") as Node3D
	for i in 5:
		await process_frame
	var grip: Vector3 = quill.global_transform * crafter.hand_grip_offset
	var reach_error: float = arm.hand_position().distance_to(arm._target.global_position)
	_check(reach_error < 0.02, "scribe hand reaches its IK target (err=%.4f m)" % reach_error)
	_check(arm._target.global_position.distance_to(grip) < 0.12,
		"IK target stays at the quill grip (wrist set-back included)")

	crafter._last_cursor_point = Vector2(0.15, 0.2)
	for i in 5:
		await process_frame
	var moved_grip: Vector3 = quill.global_transform * crafter.hand_grip_offset
	_check(moved_grip.distance_to(grip) > 0.05, "quill moves with the cursor")
	var follow_error: float = arm.hand_position().distance_to(arm._target.global_position)
	_check(follow_error < 0.02, "scribe hand follows the quill (err=%.4f m)" % follow_error)
	_check(arm._target.global_position.distance_to(moved_grip) < 0.12,
		"IK target tracks the moved quill")

	crafter._end_scribing(false)
	_check(not crafter._active, "cancelling leaves scribing mode")
	_check(player.is_physics_processing(), "cancelling unfreezes the player")
	_check(interactor.enabled, "cancelling reactivates the interactor")

	_finish()


func _finish() -> void:
	if _fail == 0:
		print("INTERACTION TEST OK")
	else:
		print("INTERACTION TEST FAILURES: ", _fail)
	quit(_fail)


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("[PASS] ", msg)
	else:
		_fail += 1
		push_error("[FAIL] " + msg)


func _find_by_type(node: Node, type_name: String) -> Node:
	if node.get_script() != null and node.get_script().get_global_name() == type_name:
		return node
	for child in node.get_children():
		var found := _find_by_type(child, type_name)
		if found != null:
			return found
	return null
