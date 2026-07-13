extends SceneTree

## End-to-end check of the interaction chain in the real tower scene:
## fountain -> hands -> element holder -> take back, plus the rune-scribing station
## locking and unlocking the player. Run headless:
##   godot --headless --path . -s tests/integration/interaction_test.gd

const RuneTemplateResource := preload("res://game/scribing/runes/rune_template.gd")
const RuneDefinitionResource := preload("res://game/scribing/runes/rune_definition.gd")
const RuneRecognizerResource := preload("res://game/scribing/runes/rune_recognizer.gd")

var _fail := 0
var _completed_stroke_count := -1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := (load("res://game/world/levels/wizard_tower.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame

	var player := scene.get_node_or_null("Player") as WizardPlayer
	_check(player != null, "player is a WizardPlayer")
	var hands := player.hands
	_check(hands != null, "player.hands resolves the typed hand anchor")
	_check(player.interactor != null, "player.interactor resolves the typed interactor")
	var grab_presentation := hands.get_grab_presentation() if hands != null else null
	var body_rig := player.get_node_or_null("BodyRig") as WizardBodyRig
	var first_person_rig := body_rig.get_first_person_rig() if body_rig else null
	var grasp_animation_player := first_person_rig.get_grasp_animation_player() if first_person_rig else null
	var right_arm_pose := first_person_rig.get_right_arm_pose() if first_person_rig else null
	var wrist_control := first_person_rig.get_hand_control(&"Wrist") if first_person_rig else null
	var beard := first_person_rig.get_beard() if first_person_rig else null
	var wizard_model := body_rig.get_node_or_null("WizardModel") as Node3D if body_rig else null
	_check(grab_presentation != null, "player has a reusable magical grab presentation")
	_check(body_rig != null, "player has a viewmodel body rig for grasp posing")
	_check(first_person_rig != null and right_arm_pose != null and wrist_control != null,
		"player composes an editor-visible first-person arm rig with spatial pose controls")
	_check(beard != null
		and first_person_rig.scene_file_path.is_empty()
		and beard.scene_file_path.is_empty()
		and body_rig.get_node_or_null("WorldBodyModel") == null
		and wizard_model != null
		and wizard_model.get_parent() == body_rig,
		"player scene owns one first-person wizard model and its beard authoring")
	var arm_models := first_person_rig.get_node("ArmModels") if first_person_rig else null
	_check(first_person_rig.get_arm_model_count() == 1
		and arm_models.get_node_or_null("LeftArmModel") == null
		and arm_models.get_node_or_null("RightArmModel") == null
		and not player.get_node("Head/Camera3D").is_ancestor_of(wizard_model),
		"one body-anchored wizard model supplies both first-person arms")
	var wizard_skeleton := WizardModel.find_skeleton(wizard_model) if wizard_model else null
	_check(wizard_skeleton != null
		and wizard_skeleton.find_bone("DEF-HAT01") != -1
		and FirstPersonWizardRig.CAMERA_INTERSECTION_BONES.has("DEF-HEAD")
		and FirstPersonWizardRig.CAMERA_INTERSECTION_BONES.has("DEF-NECK"),
		"first-person body retains its hat while removing camera intersection geometry")
	var camera := player.get_node("Head/Camera3D") as Camera3D
	_check(camera.near <= 0.03
		and is_equal_approx(wizard_model.position.y, -0.88)
		and is_equal_approx(wizard_model.position.z, 0.21),
		"camera and body use the authored eye alignment with a tight near plane")
	_check(grasp_animation_player != null
		and grasp_animation_player.has_animation(&"idle")
		and grasp_animation_player.has_animation(&"grab")
		and grasp_animation_player.has_animation(&"hold")
		and grasp_animation_player.has_animation(&"release"),
		"viewmodel arm authors separate idle, grab, hold, and release clips")
	if grasp_animation_player != null:
		var idle_animation := grasp_animation_player.get_animation(&"idle")
		var grab_animation := grasp_animation_player.get_animation(&"grab")
		_check(grasp_animation_player.current_animation == &"idle"
			and idle_animation.loop_mode == Animation.LOOP_LINEAR
			and idle_animation.find_track(
				NodePath("ArmModels/LeftArmPose:rotation"), Animation.TYPE_VALUE) != -1
			and idle_animation.find_track(
				NodePath("ArmModels/RightArmPose:rotation"), Animation.TYPE_VALUE) != -1,
			"idle clip loops both visible hands in the lower frame")
		_check(grab_animation.find_track(
			NodePath("ArmModels/RightArmPose:position"), Animation.TYPE_VALUE) != -1
			and grab_animation.find_track(
				NodePath("HandControls/Wrist:rotation"), Animation.TYPE_VALUE) != -1,
			"grab clip directly keys visible spatial rig controls")
	_check(beard != null
		and beard.animation_player.has_animation(&"lift")
		and beard.animation_player.has_animation(&"lower")
		and beard.get_node_or_null("BeardRoot/Segment01") is MeshInstance3D
		and beard.get_node_or_null("BeardRoot/Joint02/Joint03/Joint04/Segment04") is MeshInstance3D
		and beard.get_inventory_anchor().get_child_count() == 3,
		"first-person rig includes a visible flexible beard with lift clips and inventory slots")
	if beard != null:
		_check(beard.visible
			and beard.get_parent().get_parent() == body_rig
			and not player.get_node("Head/Camera3D").is_ancestor_of(beard),
			"beard stays physically mounted to the player instead of toggling with the camera")
		player.head.rotation.x = deg_to_rad(-40.0)
		await process_frame
		_check(beard.visible, "looking down keeps the physical beard rendered")
		var beard_root := beard.get_node("BeardRoot") as Node3D
		var beard_rest_position := beard_root.position
		var left_arm_pose := first_person_rig.get_node("ArmModels/LeftArmPose") as Node3D
		var left_arm_rest_position := left_arm_pose.position
		var beard_input := InputEventAction.new()
		beard_input.action = &"check_beard_inventory"
		beard_input.pressed = true
		first_person_rig._unhandled_input(beard_input)
		for frame in 70:
			await process_frame
		_check(beard.lifted
			and beard_root.position.distance_to(beard_rest_position) > 0.15
			and left_arm_pose.position.distance_to(left_arm_rest_position) > 0.25,
			"holding the beard inventory action lifts the beard and the visible left hand")
		beard_input.pressed = false
		first_person_rig._unhandled_input(beard_input)
		for frame in 70:
			await process_frame
		_check(not beard.lifted
			and beard_root.position.distance_to(beard_rest_position) < 0.01
			and left_arm_pose.position.distance_to(left_arm_rest_position) < 0.01,
			"releasing the beard inventory action lowers the beard and hand to rest")
		player.head.rotation.x = 0.0
		await process_frame
		_check(beard.visible, "looking forward does not visibility-toggle the physical beard")

	var fountain := _find_by_type(scene, "FountainOfEndlessSpring") as FountainOfEndlessSpring
	var torch := _find_by_type(scene, "TorchOfEternalFlame")
	if torch == null:
		torch = scene.find_child("TorchOfEternalFlame", true, false)
	var holder := scene.find_child("ElementHolder", true, false)
	var crafter := scene.find_child("RuneScribingStation", true, false)
	var burner := scene.find_child("Burner", true, false)
	var flask := scene.find_child("Flask", true, false) as Flask
	var book := _find_by_type(scene, "Book") as Book
	_check(fountain != null, "tower has a fountain")
	_check(torch != null, "tower has the Torch of Eternal Flame")
	_check(holder != null, "tower has an element holder")
	_check(crafter != null, "tower has a rune-scribing station")
	var scribe_surface := crafter.get_node_or_null("Scroll/ScribeInkSurface") as MeshInstance3D if crafter else null
	_check(scribe_surface != null and is_equal_approx(scribe_surface.rotation_degrees.y, -90.0),
		"crafting-table ink overlay turns clockwise across the imported scroll")
	var scribe_surface_mesh := scribe_surface.mesh as PlaneMesh if scribe_surface else null
	_check(scribe_surface_mesh != null and scribe_surface_mesh.size.is_equal_approx(Vector2(0.6, 0.3)),
		"crafting-table ink overlay measures 600 mm wide by 300 mm tall")
	_check(crafter._scribe_canvas.canvas_size_mm.is_equal_approx(Vector2(600.0, 300.0)),
		"scribe measurements match the physical overlay dimensions")
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
	_check(bool(grab_presentation.get("active")), "pickup starts the magical levitation presentation")
	_check(grab_presentation.has_item_aura(), "pickup applies the aura shader directly to the item")
	_check(hands.held_item.get_parent() == grab_presentation.call("get_item_anchor"),
		"held item floats from the presentation anchor")
	for frame in 60:
		await process_frame
	_check(grab_presentation.has_magic_stream(), "visible shader stream rises from the hand toward the item")
	_check(first_person_rig.get_grasp_amount() > 0.95,
		"pickup moves the visible arm rig into its spell-manipulation pose")
	for frame in 60:
		if grasp_animation_player.current_animation == &"hold":
			break
		await process_frame
	_check(grasp_animation_player.current_animation == &"hold",
		"completed grab clip transitions into the looping hold clip")
	var float_anchor := grab_presentation.get_item_anchor()
	var bob_position := float_anchor.position
	var arm_hold_position := right_arm_pose.position
	for frame in 36:
		await process_frame
	_check(float_anchor.position.distance_to(bob_position) > 0.004,
		"held item gently bobs and sways through the authored holding animation")
	_check(right_arm_pose.position.distance_to(arm_hold_position) > 0.002,
		"looping hold clip directly moves the visible viewmodel arm node")
	_check(fountain.focus_prompt(player, null) == fountain.refresh_prompt,
		"fountain offers a refresh while holding water")

	# Element holder: place the water, then take it back.
	_check(str(holder.focus_prompt(player, null)) == holder.place_water_prompt,
		"holder prompts to place held water")
	holder.interact(player, null)
	_check(hands.held_item == null, "placing water empties the hands")
	for frame in 60:
		await process_frame
	_check(not bool(grab_presentation.get("active")), "placing an item dismisses the levitation presentation")
	_check(not grab_presentation.has_item_aura(), "placing an item removes its temporary aura shader")
	_check(first_person_rig.get_grasp_amount() < 0.05, "placing an item relaxes the viewmodel hand")
	_check(wrist_control.rotation.length() < 0.001,
		"release clip restores the spatial hand controls to their reset pose")
	_check(grasp_animation_player.current_animation == &"idle",
		"release clip returns to the looping visible-hand idle")
	_check(holder.placed_element is HeldWater, "holder keeps the placed water")
	_check(holder.placed_element.get_parent() == holder, "water reparents to the holder")
	_check(str(holder.focus_prompt(player, null)).begins_with("Take"),
		"holder prompts to take the element back")
	holder.interact(player, null)
	_check(hands.held_item is HeldWater, "taking back returns the water to the hands")
	_check(bool(grab_presentation.get("active")), "taking an item back restores levitation")
	_check(grab_presentation.has_item_aura(), "taking an item back restores its aura shader")
	_check(holder.placed_element == null, "holder is empty after take-back")

	# Spell crafter refuses while hands are full, then locks the player.
	_check(str(crafter.focus_prompt(player, null)) == crafter.held_item_prompt,
		"crafter prompts to empty hands first")
	crafter.interact(player, null)
	_check(not crafter._active, "crafter refuses to start with full hands")

	hands.drop()
	for frame in 60:
		await process_frame
	_check(hands.held_item == null, "dropping water empties the hands")
	_check(not bool(grab_presentation.get("active")), "dropping an item dismisses levitation")
	_check(not grab_presentation.has_item_aura(), "dropping an item removes its temporary aura shader")
	_check(first_person_rig.get_grasp_amount() < 0.05, "dropping an item relaxes the grasp pose")

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
	var mouse_mode_before_scribing := Input.mouse_mode
	crafter.interact(player, null)
	_check(crafter._active, "crafter enters scribing mode")
	_check(not player.is_physics_processing(), "scribing freezes the player")
	_check(not player._control_enabled,
		"scribing prevents player focus events from recapturing the mouse")
	var interactor := player.interactor
	_check(not interactor.enabled, "scribing suspends the interactor")

	# The authored quill replaces the system cursor while drawing.
	_check(crafter.get_node_or_null("ScribeArm") == null,
		"scribing no longer depends on a hand or arm rig")
	if DisplayServer.get_name() == "headless":
		print("[SKIP] system cursor hiding requires a graphical display")
	else:
		_check(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN,
			"scribing hides the system cursor so the quill becomes the pointer")
	var quill := crafter.get_node("Quill") as Node3D
	var quill_model := quill.get_node_or_null("ModelFacing/AxisConversion/Model") as Node3D
	var quill_tip := quill.get_node_or_null("WritingTip") as Marker3D
	var quill_scribe_pose := crafter.get_node_or_null("QuillScribePose") as Marker3D
	_check(quill_model != null
		and quill_model.scene_file_path == "res://assets/models/quill.glb",
		"scribing uses the authored quill model instead of placeholder geometry")
	_check(quill_tip != null, "authored quill tip drives mouse alignment")
	_check(quill_scribe_pose != null
		and is_equal_approx(quill_scribe_pose.rotation_degrees.y, -36.0),
		"scene-authored quill pose points the nib toward the left side of the scroll")
	for i in 5:
		await process_frame
	var cursor_global: Vector3 = crafter._scribe_surface.to_global(
		crafter._scribe_surface_point(crafter._last_cursor_point))
	var quill_surface_normal: Vector3 = (
		crafter._scribe_surface.global_transform.basis.y.normalized())
	_check(quill_tip.global_position.distance_to(
		cursor_global + quill_surface_normal * crafter.quill_hover_lift) < 0.002,
		"authored quill nib tracks the scroll cursor")

	# Disable mouse polling so it cannot overwrite the corner samples.
	crafter.set_process(false)
	var original_tip_position := quill_tip.global_position
	crafter._set_cursor_point(Vector2(0.35, 0.35))
	crafter._update_scribe_props(1.0)
	_check(quill_tip.global_position.distance_to(original_tip_position) > 0.05,
		"quill moves directly with the cursor")
	var max_corner_tip_error := 0.0
	for corner: Vector2 in [
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
	]:
		crafter._set_cursor_point(corner)
		crafter._update_scribe_props(1.0)
		var surface_point: Vector3 = crafter._scribe_surface.to_global(
			crafter._scribe_surface_point(corner))
		var expected_tip: Vector3 = (
			surface_point + quill_surface_normal * crafter.quill_hover_lift)
		max_corner_tip_error = maxf(
			max_corner_tip_error,
			quill_tip.global_position.distance_to(expected_tip))
	crafter.set_process(true)
	_check(max_corner_tip_error < 0.002,
		"quill nib reaches every scroll corner (max err=%.4f m)" % max_corner_tip_error)

	var recognizer := RuneRecognizerResource.new()
	recognizer.rune_definitions = [
		_make_rune_definition(&"font", "form", [_make_rune_template("font", "form", _font_strokes())]),
		_make_rune_definition(&"mend", "effect", [_make_rune_template("mend", "effect", _mend_strokes())]),
	]
	crafter._rune_recognizer = recognizer
	crafter._scribe_canvas.replace_strokes(_scribed_rune_strokes_on_scroll())
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

	_completed_stroke_count = -1
	crafter.scribing_completed.connect(_on_scribing_completed, CONNECT_ONE_SHOT)
	crafter._end_scribing(true, 2)
	_check(not crafter._active, "sealing leaves scribing mode")
	_check(Input.mouse_mode == mouse_mode_before_scribing,
		"leaving scribing restores the previous system cursor mode")
	_check(player.is_physics_processing(), "sealing unfreezes the player")
	_check(player._control_enabled, "sealing restores player mouse capture handling")
	_check(interactor.enabled, "sealing reactivates the interactor")
	_check(crafter._sealed, "sealing preserves the finished physical scroll")
	_check(crafter._scribe_canvas.has_ink(), "sealing preserves authored rune ink")
	_check(_completed_stroke_count == 2, "sealing emits neutral scribing completion")
	_check(crafter.get_recognized_rune_ids() == [&"font", &"mend"],
		"sealing preserves recognized rune ids for a future spell design")
	_check(hands.held_item == null, "sealing does not create an inventory spell")
	_check(scene.find_child("FontArea", true, false) == null,
		"sealing does not create a spell delivery")

	_finish()


func _finish() -> void:
	if _fail == 0:
		print("INTERACTION TEST OK")
	else:
		print("INTERACTION TEST FAILURES: ", _fail)
	quit(_fail)


func _on_scribing_completed(stroke_count: int) -> void:
	_completed_stroke_count = stroke_count


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


func _scribed_rune_strokes_on_scroll() -> Array[PackedVector2Array]:
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
