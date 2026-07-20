extends SceneTree

## Two-hands casting sentence (game-bible.md): the right hand speaks the verb,
## the left hand carries the noun, and each traced rune is consumed by its use.
## Exercises the CastingController + SightController pair headlessly:
## Draw pulls a source's essence into the left hand and is spent; Pour returns
## it to an empty vessel or pushes it out as the cast and is spent; essence
## survives traces and dismissals; refusals guard every wrong combination.

var _fail := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# A floor first: without one the player free-falls all test long and the
	# world-anchored sources drift out of the screen-centre aim radius.
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(50.0, 1.0, 50.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	floor_body.global_position = Vector3(0.0, -0.5, 0.0)

	var player := (load("res://game/player/player.tscn") as PackedScene).instantiate() as WizardPlayer
	root.add_child(player)
	await process_frame
	await process_frame

	var casting := player.get_node_or_null("Components/CastingController") as CastingController
	var sight := player.get_node_or_null("Components/SightController") as SightController
	_check(casting != null, "player carries a CastingController")
	_check(sight != null, "player carries a SightController")
	if casting == null or sight == null:
		_finish(player)
		return
	_check(casting._sight == sight, "casting controller resolved its Sight sibling")

	# A one-shot source with a visual, dead centre in front of the camera.
	var camera := player.get_node("Head/Camera3D") as Camera3D
	var fire := Element.new()
	fire.id = &"fire"
	fire.display_name = "Fire"
	var flame_visual := Node3D.new()
	root.add_child(flame_visual)
	var source := ElementSource.new()
	source.element = fire
	source.one_shot = true
	source.consume_time = 0.05
	source.visual = flame_visual
	root.add_child(source)
	source.global_position = camera.global_position + camera.global_transform.basis * Vector3(0, 0, -3)
	flame_visual.global_position = source.global_position
	casting.sight_pull_time = 0.05
	await process_frame

	# Hold Sight: the component activates and finds the centred source.
	Input.action_press("sight")
	await process_frame
	await process_frame
	_check(sight.active, "holding sight activates the overlay state")
	_check(sight.aimed_source() == source, "sight aims the centred element source")
	Input.action_release("sight")
	await process_frame

	# Draw with nothing aimed refuses but keeps the verb.
	casting.locked_rune_id = &"draw"
	casting.locked_rune_score = 1.0
	casting._set_state(CastingController.CASTING_STATE.SPELL_HELD)
	await process_frame
	_check(casting._held_element == null, "the left hand starts empty")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	casting._input(press)
	await process_frame
	_check(casting.current_state == CastingController.CASTING_STATE.SPELL_HELD,
		"draw with nothing aimed keeps the verb in hand")

	# The pull: sight + cast dwell drains the source into the LEFT hand and
	# spends the Draw rune.
	Input.action_press("sight")
	Input.action_press("cast")
	var frames := 0
	var peak_progress := 0.0
	while casting._held_element == null and frames < 2000:
		await process_frame
		peak_progress = maxf(peak_progress, sight.aim_progress)
		frames += 1
	Input.action_release("cast")
	Input.action_release("sight")
	_check(casting._held_element == fire, "the pull lands the essence in the left hand")
	_check(peak_progress > 0.0, "the pull dwell fills the aimed ring")
	_check(casting.current_state == CastingController.CASTING_STATE.IDLE,
		"a completed pull spends the Draw rune")
	_check(casting._left_hand_effect != null, "carried essence shows in the off hand")
	_check(casting._left_anchor != null
		and String(casting._left_anchor.get_path()).contains("LeftHandAttachment"),
		"the essence orb rides the skeleton's left wrist attachment")
	_check(casting._left_arm_anim != null and casting._left_arm_anim.is_playing()
		and String(casting._left_arm_anim.current_animation).ends_with("_left"),
		"the left arm raises into its mirrored hold")
	_check(not source.available(), "a completed pull depletes a one-shot source")
	_check(source.is_in_group(ElementSource.GROUP), "a depleted source stays listed as an empty vessel")
	frames = 0
	while flame_visual.visible and frames < 2000:
		await process_frame
		frames += 1
	_check(not flame_visual.visible, "the consumed visual is sucked away and hidden")

	# Essence survives a fresh trace: the left hand keeps its fire.
	casting._set_state(CastingController.CASTING_STATE.SKETCHING)
	_check(casting._held_element == fire, "sketching keeps the left hand's essence")
	_check(absf(Engine.time_scale - casting.sketch_time_scale) < 0.001,
		"sketching slows time to the locked feel decision")
	casting._set_state(CastingController.CASTING_STATE.IDLE)
	_check(absf(Engine.time_scale - 1.0) < 0.001, "leaving the sketch restores time")

	# Draw at an empty vessel refuses; dismissal drops the verb, not the essence.
	casting.locked_rune_id = &"draw"
	casting._set_state(CastingController.CASTING_STATE.SPELL_HELD)
	Input.action_press("sight")
	await process_frame
	await process_frame
	_check(sight.aimed_source() == source, "sight aims the empty vessel")
	casting._input(press)
	await process_frame
	_check(casting.current_state == CastingController.CASTING_STATE.SPELL_HELD,
		"draw at an empty vessel refuses and keeps the verb")
	var shake := InputEventKey.new()
	shake.keycode = KEY_G
	shake.pressed = true
	casting._input(shake)
	await process_frame
	_check(casting.current_state == CastingController.CASTING_STATE.IDLE,
		"drop_item shakes off the held verb")
	_check(casting._held_element == fire, "dismissal keeps the left hand's essence")

	# Pour at the empty vessel: the essence flows home, the Pour rune is spent.
	casting.locked_rune_id = &"pour"
	casting._set_state(CastingController.CASTING_STATE.SPELL_HELD)
	await process_frame
	casting._input(press)
	await process_frame
	_check(source.available(), "poured essence restores the depleted source")
	_check(casting._held_element == null, "pouring empties the left hand")
	_check(casting._left_hand_effect == null, "the off-hand orb clears when poured")
	_check(flame_visual.visible, "the restored visual reappears")
	_check(casting.current_state == CastingController.CASTING_STATE.IDLE,
		"a completed pour spends the Pour rune")
	Input.action_release("sight")
	await process_frame

	# Pour with an empty left hand refuses.
	casting.locked_rune_id = &"pour"
	casting._set_state(CastingController.CASTING_STATE.SPELL_HELD)
	await process_frame
	casting._input(press)
	await process_frame
	_check(casting.current_state == CastingController.CASTING_STATE.SPELL_HELD,
		"pour with an empty left hand refuses")
	casting._input(shake)
	await process_frame

	# Draw again, then Pour with nothing aimed pushes the essence out as the cast.
	casting.locked_rune_id = &"draw"
	casting._set_state(CastingController.CASTING_STATE.SPELL_HELD)
	Input.action_press("sight")
	Input.action_press("cast")
	frames = 0
	while casting._held_element == null and frames < 2000:
		await process_frame
		frames += 1
	Input.action_release("cast")
	Input.action_release("sight")
	_check(casting._held_element == fire, "the restored source can be drawn again")
	casting.locked_rune_id = &"pour"
	casting._set_state(CastingController.CASTING_STATE.SPELL_HELD)
	await process_frame
	casting._input(press)
	await process_frame
	_check(casting.current_state == CastingController.CASTING_STATE.IDLE,
		"pour with nothing aimed pushes the essence out as the cast")
	_check(casting._held_element == null, "the pushed essence leaves the left hand")

	source.queue_free()
	flame_visual.queue_free()
	_finish(player)


func _finish(player: Node) -> void:
	if player != null:
		player.queue_free()
	await process_frame
	await process_frame
	if _fail == 0:
		print("VERB CASTING TEST OK")
	quit(_fail)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
	else:
		push_error("[FAIL] %s" % message)
		_fail = 1
