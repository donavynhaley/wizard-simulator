extends SceneTree

## Verb-first casting sentence (game-bible.md): trace the verb, pull the noun
## through held Sight, release at the object. Exercises the reworked
## CastingController + SightController pair headlessly: sight hold/release,
## the essence gate (a primed rune refuses to fire), the Sight pull fueling the
## rune from an ElementSource, the fueled fire, the shake-off dismiss, and the
## sketching time scale.

var _fail := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
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

	# An element source in front of the camera, dead centre, so Sight aims it.
	var camera := player.get_node("Head/Camera3D") as Camera3D
	var source := ElementSource.new()
	var fire := Element.new()
	fire.id = &"fire"
	fire.display_name = "Fire"
	source.element = fire
	root.add_child(source)
	source.global_position = camera.global_position + camera.global_transform.basis * Vector3(0, 0, -3)
	await process_frame

	# Hold Sight: the component activates and finds the centred source.
	Input.action_press("sight")
	await process_frame
	await process_frame
	_check(sight.active, "holding sight activates the overlay state")
	_check(sight.aimed_source() == source, "sight aims the centred element source")

	# Force a primed verb (tracing is exercised by rune_recognizer_test).
	casting.locked_rune_id = &"draw"
	casting.locked_rune_score = 1.0
	casting._set_state(CastingController.CASTING_STATE.SPELL_HELD)
	await process_frame
	_check(casting._current_element == null, "a freshly primed rune holds no essence")

	# Essence gate: firing without a pulled element is refused (sight down, no aim).
	Input.action_release("sight")
	await process_frame
	var refuse := InputEventMouseButton.new()
	refuse.button_index = MOUSE_BUTTON_LEFT
	refuse.pressed = true
	casting._input(refuse)
	await process_frame
	_check(casting.current_state == CastingController.CASTING_STATE.SPELL_HELD,
		"a primed rune without essence refuses to fire")

	# Pull the noun: hold sight + cast on the aimed source until the dwell fuels
	# it. Headless deltas are tiny, so shorten the dwell and bound by frames.
	casting.sight_pull_time = 0.05
	Input.action_press("sight")
	Input.action_press("cast")
	var frames := 0
	while casting._current_element == null and frames < 2000:
		await process_frame
		frames += 1
	Input.action_release("cast")
	_check(casting._current_element == fire, "the sight pull draws the element into the rune")
	_check(sight.aim_progress > 0.0, "the pull dwell fills the aimed ring")
	Input.action_release("sight")
	await process_frame

	# Fueled fire: the sentence completes and the state returns to IDLE.
	var fire_click := InputEventMouseButton.new()
	fire_click.button_index = MOUSE_BUTTON_LEFT
	fire_click.pressed = true
	casting._input(fire_click)
	await process_frame
	_check(casting.current_state == CastingController.CASTING_STATE.IDLE,
		"a fueled rune fires and returns to idle")

	# Dismiss: a re-primed rune shakes off with drop_item, uncast.
	casting.locked_rune_id = &"pour"
	casting._set_state(CastingController.CASTING_STATE.SPELL_HELD)
	await process_frame
	var shake := InputEventKey.new()
	shake.keycode = KEY_G
	shake.pressed = true
	casting._input(shake)
	await process_frame
	_check(casting.current_state == CastingController.CASTING_STATE.IDLE,
		"drop_item shakes off the primed rune")
	_check(casting.locked_rune_id == &"", "dismissal clears the locked rune")

	# Sketching runs at the deliberate time scale and restores on exit.
	casting._set_state(CastingController.CASTING_STATE.SKETCHING)
	_check(absf(Engine.time_scale - casting.sketch_time_scale) < 0.001,
		"sketching slows time to the locked feel decision")
	casting._set_state(CastingController.CASTING_STATE.IDLE)
	_check(absf(Engine.time_scale - 1.0) < 0.001, "leaving the sketch restores time")

	source.queue_free()
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
