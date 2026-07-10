extends SceneTree

## End-to-end check of the interaction chain in the real tower scene:
## fountain -> hands -> element holder -> take back, plus the spell crafter
## locking and unlocking the player. Run headless:
##   godot --headless --path . -s tools/interaction_test.gd

const RuneTemplateResource := preload("res://scripts/spellcraft/rune_template.gd")
const RuneDefinitionResource := preload("res://scripts/spellcraft/rune_definition.gd")
const RuneRecognizerResource := preload("res://scripts/spellcraft/rune_recognizer.gd")

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
	var torch := _find_by_type(scene, "TorchOfEternalFlame")
	if torch == null:
		torch = scene.find_child("TorchOfEternalFlame", true, false)
	var holder := scene.find_child("ElementHolder", true, false)
	var crafter := scene.find_child("SpellCrafter", true, false)
	var burner := scene.find_child("Burner", true, false)
	var flask := scene.find_child("Flask", true, false) as Flask
	var book := _find_by_type(scene, "Book") as Book
	_check(fountain != null, "tower has a fountain")
	_check(torch != null, "tower has the Torch of Eternal Flame")
	_check(holder != null, "tower has an element holder")
	_check(crafter != null, "tower has a spell crafter")
	_check(burner != null, "tower has a burner")
	_check(flask != null, "tower has a flask")
	_check(book != null, "tower has a readable book")
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

	book.interact(player, null)
	_check(hands.held_item == book, "player picks up a rune book")
	_check(str(crafter.focus_prompt(player, null)) == "Place book reference",
		"crafter prompts to place a held book reference")
	crafter.interact(player, null)
	_check(hands.held_item == null, "placing book reference empties the hands")
	_check(crafter._reference_book == book, "crafter keeps the reference book")
	_check((book.get_node("Visual/VisualRoot/OpenVisual") as Node3D).visible,
		"reference book is open on the table")
	var book_anchor := scene.find_child("OpenBookPlacement", true, false) as Node3D
	var book_anchor_shape := book_anchor.get_node_or_null("StaticBody3D/CollisionShape3D") as Node3D if book_anchor else null
	_check(book_anchor_shape != null, "tower has a reference book placement marker")
	if book_anchor_shape != null:
		_check(book.global_position.distance_to(book_anchor_shape.global_position) < 0.01,
			"reference book is placed at the open book marker")
		_check(_basis_matches(book.global_transform.basis, book_anchor_shape.global_transform.basis, 0.01),
			"reference book matches the open book marker rotation")
	_check(str(crafter.focus_prompt(player, null)) == crafter.prompt_text,
		"crafter offers scribing while the table book stays open")
	crafter.interact(player, null)
	_check(crafter._active, "player can begin scribing with a placed reference book")
	_check(not player.is_physics_processing(), "reference-book scribing freezes the player")
	var scribe_camera := crafter.get_node_or_null("ScribeCamera") as Camera3D
	var scroll_camera_pose := crafter.get_node_or_null("ScrollCameraPose") as Marker3D
	var book_camera_pose := crafter.get_node_or_null("BookCameraPose") as Marker3D
	_check(scribe_camera != null and scroll_camera_pose != null and book_camera_pose != null,
		"crafting table authors both scribing camera poses in its scene")
	if scribe_camera != null and scroll_camera_pose != null and book_camera_pose != null:
		_check(_transform_matches(scribe_camera.transform, scroll_camera_pose.transform, 0.01),
			"scribing starts focused on the scroll")
		crafter._unhandled_input(_action_event(&"move_forward"))
		for frame in 60:
			await process_frame
		_check(_transform_matches(scribe_camera.transform, book_camera_pose.transform, 0.01),
			"W rotates the scribing camera up to the reference book")
		crafter._unhandled_input(_action_event(&"move_backward"))
		for frame in 60:
			await process_frame
		_check(_transform_matches(scribe_camera.transform, scroll_camera_pose.transform, 0.01),
			"S rotates the scribing camera back down to the scroll")
	crafter._end_scribing(false)
	_check(player.is_physics_processing(), "leaving reference-book scribing restores movement")
	if book_anchor != null:
		book_anchor.interact(player, null)
	_check(hands.held_item == book, "player retrieves the reference book from its placement")
	if book_anchor != null and book_anchor_shape != null:
		book_anchor.interact(player, null)
		_check(hands.held_item == null, "book placement accepts a held book directly")
		_check(crafter._reference_book == book, "crafter tracks a book placed through the placement node")
		_check((book.get_node("Visual/VisualRoot/OpenVisual") as Node3D).visible,
			"directly placed book opens on the table")
		_check(book.global_position.distance_to(book_anchor_shape.global_position) < 0.01,
			"directly placed book uses the open book marker position")
		book_anchor.interact(player, null)
		_check(hands.held_item == book, "book placement returns the reference book")
		_check(crafter._reference_book == null, "crafter clears a book taken through the placement node")
	hands.drop()
	await process_frame
	_check(hands.held_item == null, "dropping book empties the hands")

	# Alchemy heat chain: torch -> burner fire slot -> flask with contents -> cooked flask.
	_check(str(torch.call("focus_prompt", player, null)) == str(torch.get("prompt_text")),
		"torch prompts to gather fire with empty hands")
	torch.call("interact", player, null)
	_check(hands.held_item is HeldFire, "torch places eternal flame in the hands")
	_check(str(torch.call("focus_prompt", player, null)) == str(torch.get("refresh_prompt")),
		"torch offers to refresh held fire")

	_check(str(burner.call("focus_prompt", player, null)) == str(burner.get("fire_prompt")),
		"burner prompts to place held fire")
	burner.call("interact", player, null)
	_check(hands.held_item == null, "placing fire empties the hands")
	var placed_fire := burner.get("placed_fire") as HeldFire
	_check(placed_fire != null, "burner keeps the placed fire")
	_check(placed_fire.get_parent() == burner, "fire reparents to the burner")

	flask.interact(player, null)
	_check(hands.held_item == flask, "player picks up the flask")
	_check(str(burner.call("focus_prompt", player, null)) == str(burner.get("prompt_text")),
		"burner prompts to place held flask")
	burner.call("interact", player, null)
	_check(hands.held_item == null, "placing flask empties the hands")
	_check(burner.get("placed_flask") == flask, "burner keeps the placed flask")
	_check(not flask.is_cooked, "empty flask does not cook over placed fire")

	burner.call("interact", player, null)
	_check(hands.held_item == flask, "player retrieves the uncooked empty flask")
	var reagent := Reagent.new()
	reagent.name = "test potion"
	flask.item_in_flask = reagent
	burner.call("interact", player, null)
	_check(hands.held_item == null, "placing filled flask empties the hands")
	_check(burner.get("placed_flask") == flask, "burner keeps the filled flask")
	_check(flask.is_cooked, "burner cooks the placed flask")
	_check(burner.get("placed_fire") == placed_fire, "fire remains on the burner after cooking")
	_check(burner.get("placed_flask") == flask, "cooked flask remains on the burner")
	_check(str(burner.call("focus_prompt", player, null)) == str(burner.get("remove_prompt")),
		"burner prompts to retrieve cooked flask")
	burner.call("interact", player, null)
	_check(hands.held_item == flask, "player picks cooked flask back up")
	_check(burner.get("placed_flask") == null, "burner is empty after cooked flask pickup")
	for i in 20:
		await process_frame
	hands.drop()
	for i in 180:
		if not is_instance_valid(flask):
			break
		await physics_frame
	_check(hands.held_item == null, "dropping cooked flask empties the hands")
	_check(not is_instance_valid(flask), "dropped cooked flask breaks on impact")
	var break_audio := scene.find_child("GlassBreakAudio", true, false)
	_check(break_audio != null, "glass break sound plays")
	if break_audio != null:
		break_audio.queue_free()
		await process_frame

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

	crafter._last_cursor_point = Vector2(0.35, 0.35)
	for i in 5:
		await process_frame
	var moved_grip: Vector3 = quill.global_transform * crafter.hand_grip_offset
	_check(moved_grip.distance_to(grip) > 0.05, "quill moves with the cursor")
	var follow_error: float = arm.hand_position().distance_to(arm._target.global_position)
	_check(follow_error < 0.02, "scribe hand follows the quill (err=%.4f m)" % follow_error)
	_check(arm._target.global_position.distance_to(moved_grip) < 0.12,
		"IK target tracks the moved quill")

	var recognizer := RuneRecognizerResource.new()
	recognizer.rune_definitions = [
		_make_rune_definition(&"font", "form", [_make_rune_template("font", "form", _font_strokes())]),
		_make_rune_definition(&"mend", "effect", [_make_rune_template("mend", "effect", _mend_strokes())]),
	]
	crafter._rune_recognizer = recognizer
	crafter._scribe_canvas.replace_strokes(_spell_recipe_strokes_on_scroll())
	var rune_result: Resource = crafter._try_auto_recognize_category("form")
	_check(rune_result != null and bool(rune_result.call("is_match")),
		"crafter auto-recognizes a completed form rune segment")
	rune_result = crafter._try_auto_recognize_category("effect")
	_check(rune_result != null and bool(rune_result.call("is_match")),
		"crafter auto-recognizes a completed effect rune segment")
	_check(crafter.get_recognized_rune_ids() == [&"font", &"mend"],
		"crafter stores the recognized rune ids")
	_check(crafter.get_rune_qualities().size() == 2 and crafter.get_rune_qualities()[0] > 0.75,
		"crafter stores recognized rune quality")
	_check(crafter._scribe_canvas.has_ink(),
		"recognized rune remains on the scroll")
	_check(crafter._scribe_canvas.is_category_recognized("form"),
		"recognized form segment is marked for blue glow")
	_check(crafter._scribe_canvas.is_category_recognized("effect"),
		"recognized effect segment is marked for blue glow")

	crafter._end_scribing(true, 2)
	_check(not crafter._active, "sealing leaves scribing mode")
	_check(player.is_physics_processing(), "sealing unfreezes the player")
	_check(interactor.enabled, "sealing reactivates the interactor")
	_check(hands.held_item is SpellScrollItem, "sealing gives the player a spell scroll")
	var scroll_item := hands.held_item as SpellScrollItem
	_check(scroll_item != null and scroll_item.scroll_data != null,
		"crafted scroll item has scroll data")
	if scroll_item != null and scroll_item.scroll_data != null:
		_check(scroll_item.scroll_data.display_name == "Gilded Healing Spring Scroll",
			"crafted scroll is the gilded healing spring")
		_check(scroll_item.scroll_data.compiled_spell != null and scroll_item.scroll_data.compiled_spell.spell_id == &"healing_spring",
			"crafted scroll stores the compiled healing spring spell")
		var cast_status := scroll_item.cast_from(player, Transform3D(Basis(), Vector3(0.0, 1.6, 0.0)))
		_check(cast_status.begins_with("Cast Healing Spring"), "crafted scroll casts through the held item path")
		await process_frame
		_check(hands.held_item == null, "single-charge scroll is consumed after casting")
		_check(scene.find_child("FontArea", true, false) != null,
			"casting the healing spring spawns a font delivery")

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


func _basis_matches(left: Basis, right: Basis, tolerance: float) -> bool:
	return left.x.normalized().distance_to(right.x.normalized()) <= tolerance \
		and left.y.normalized().distance_to(right.y.normalized()) <= tolerance \
		and left.z.normalized().distance_to(right.z.normalized()) <= tolerance


func _transform_matches(left: Transform3D, right: Transform3D, tolerance: float) -> bool:
	return left.origin.distance_to(right.origin) <= tolerance \
		and _basis_matches(left.basis, right.basis, tolerance)


func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _make_rune_template(rune_id: String, category: String, strokes: Array[PackedVector2Array]) -> Resource:
	var template := RuneTemplateResource.new()
	template.rune_id = rune_id
	template.display_name = rune_id.capitalize()
	template.category = category
	template.set_strokes(strokes)
	return template


func _make_rune_definition(rune_id: StringName, category: String, templates: Array) -> Resource:
	var definition := RuneDefinitionResource.new()
	definition.id = rune_id
	definition.display_name = String(rune_id).capitalize()
	definition.category = category
	for template in templates:
		definition.add_template(template as Resource)
	return definition


func _font_strokes() -> Array[PackedVector2Array]:
	return [_stroke([
		Vector2(0.04, 0.48),
		Vector2(0.11, 0.42),
		Vector2(0.20, 0.44),
		Vector2(0.29, 0.36),
	])]


func _mend_strokes() -> Array[PackedVector2Array]:
	return [_stroke([
		Vector2(0.38, 0.74),
		Vector2(0.44, 0.58),
		Vector2(0.51, 0.70),
		Vector2(0.59, 0.42),
	])]


func _spell_recipe_strokes_on_scroll() -> Array[PackedVector2Array]:
	return [
		_stroke([
			Vector2(0.04, 0.48),
			Vector2(0.11, 0.42),
			Vector2(0.20, 0.44),
			Vector2(0.29, 0.36),
		]),
		_stroke([
			Vector2(0.38, 0.74),
			Vector2(0.44, 0.58),
			Vector2(0.51, 0.70),
			Vector2(0.59, 0.42),
		]),
	]


func _stroke(points: Array[Vector2]) -> PackedVector2Array:
	var stroke := PackedVector2Array()
	for point in points:
		stroke.append(point)
	return stroke
