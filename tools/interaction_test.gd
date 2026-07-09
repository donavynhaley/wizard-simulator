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
	_check(fountain != null, "tower has a fountain")
	_check(torch != null, "tower has the Torch of Eternal Flame")
	_check(holder != null, "tower has an element holder")
	_check(crafter != null, "tower has a spell crafter")
	_check(burner != null, "tower has a burner")
	_check(flask != null, "tower has a flask")
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
		_make_rune_definition(&"bolt", "form", [_make_rune_template("bolt", "form", _bolt_strokes())]),
	]
	crafter._rune_recognizer = recognizer
	crafter._scribe_canvas.replace_strokes(_bolt_strokes_in_form_segment())
	var rune_result: Resource = crafter._try_auto_recognize_category("form")
	_check(rune_result != null and bool(rune_result.call("is_match")),
		"crafter auto-recognizes a completed rune segment")
	_check(crafter.get_recognized_rune_ids() == [&"bolt"],
		"crafter stores the recognized rune id")
	_check(crafter.get_rune_qualities().size() == 1 and crafter.get_rune_qualities()[0] > 0.75,
		"crafter stores recognized rune quality")
	_check(crafter._scribe_canvas.has_ink(),
		"recognized rune remains on the scroll")
	_check(crafter._scribe_canvas.is_category_recognized("form"),
		"recognized rune segment is marked for blue glow")

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


func _bolt_strokes() -> Array[PackedVector2Array]:
	return [_stroke([
		Vector2(0.16, 0.48),
		Vector2(0.36, 0.42),
		Vector2(0.62, 0.44),
		Vector2(0.84, 0.36),
	])]


func _bolt_strokes_in_form_segment() -> Array[PackedVector2Array]:
	return [_stroke([
		Vector2(0.04, 0.48),
		Vector2(0.11, 0.42),
		Vector2(0.20, 0.44),
		Vector2(0.29, 0.36),
	])]


func _stroke(points: Array[Vector2]) -> PackedVector2Array:
	var stroke := PackedVector2Array()
	for point in points:
		stroke.append(point)
	return stroke
