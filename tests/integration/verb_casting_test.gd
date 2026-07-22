extends SceneTree

## End-to-end coverage for the approved two-hand casting model.
## Wizard Sight moves essence without a rune, Hurl consumes carried essence,
## and Fire Hurl airbursts at range with a large self-affecting explosion.

var _fail: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var floor := _build_static_box(Vector3(50.0, 1.0, 50.0))
	root.add_child(floor)
	floor.global_position = Vector3(0.0, -0.5, 0.0)

	var player := (load("res://game/player/player.tscn") as PackedScene).instantiate() as WizardPlayer
	root.add_child(player)
	await process_frame
	await process_frame

	var casting := player.casting
	var sight := player.sight
	var hand := player.element_hand
	_check(casting != null, "player carries a CastingController")
	_check(sight != null, "player carries a SightController")
	_check(hand != null, "player carries an ElementHandController")
	_check(player.health != null, "player carries a HealthComponent")

	var camera := player.get_node(^"Head/Camera3D") as Camera3D
	var fire := load("res://game/spellcraft/elements/fire.tres") as Element
	var water := load("res://game/spellcraft/elements/water.tres") as Element
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
	await process_frame

	# Sight itself now grabs the element without a Draw rune. The grab is a
	# held gesture: essence rips free only after pull_time of commitment.
	Input.action_press(&"sight")
	await process_frame
	await process_frame
	_check(sight.active, "holding Sight activates elemental targeting")
	_check(sight.aimed_source() == source, "Sight aims the centered source")
	await _hold_cast(sight.pull_time + 0.15)
	_check(hand.held_element() == fire, "Sight gathers the source into the left hand")
	_check(not source.available(), "gathering depletes a one-shot source")
	_check(casting.current_state == CastingController.CASTING_STATE.IDLE,
		"gathering essence requires no primed rune")

	# Foreign vessels refuse the carried essence without consuming it.
	var foreign := ElementSource.new()
	foreign.element = water
	foreign.one_shot = true
	root.add_child(foreign)
	foreign.global_position = source.global_position
	foreign.consume(Vector3.ZERO)
	await process_frame
	_check(not foreign.available(), "foreign test vessel starts empty")
	# The foreign vessel temporarily owns the center marker.
	source.remove_from_group(ElementSource.GROUP)
	await process_frame
	await _click_cast()
	_check(hand.held_element() == fire, "foreign placement keeps fire in the hand")
	_check(not foreign.available(), "foreign placement leaves the water vessel empty")

	# Matching placement returns essence directly through Sight - a shorter
	# pour-back hold, because giving is easier than taking.
	foreign.remove_from_group(ElementSource.GROUP)
	source.add_to_group(ElementSource.GROUP)
	await process_frame
	await _hold_cast(sight.push_time + 0.15)
	_check(hand.held_element() == null, "matching placement empties the left hand")
	_check(source.available(), "matching placement restores the source")

	# Hurl remains primed when there is no elemental noun.
	Input.action_release(&"sight")
	await process_frame
	casting.locked_rune_id = &"hurl"
	casting.locked_rune_score = 1.0
	casting._set_state(CastingController.CASTING_STATE.SPELL_HELD)
	await _click_cast()
	_check(casting.current_state == CastingController.CASTING_STATE.SPELL_HELD,
		"empty Hurl refuses to fire and remains primed")

	# A completed rune can coexist with Sight. Sight temporarily owns left click
	# for gathering, then lowering Sight exposes the same held Hurl for firing.
	Input.action_press(&"sight")
	await process_frame
	await process_frame
	_check(sight.active, "Q activates Sight while Hurl remains primed")
	_check(casting.current_state == CastingController.CASTING_STATE.SPELL_HELD,
		"activating Sight leaves the primed Hurl intact")
	await _hold_cast(sight.pull_time + 0.15)
	_check(hand.held_element() == fire, "Sight gathers fire while Hurl remains primed")
	_check(casting.current_state == CastingController.CASTING_STATE.SPELL_HELD,
		"gathering through Sight preserves the primed Hurl")
	Input.action_release(&"sight")
	await process_frame
	await _click_cast()
	_check(hand.held_element() == null, "Hurl atomically consumes carried fire")
	_check(casting.current_state == CastingController.CASTING_STATE.IDLE,
		"firing consumes the Hurl rune")

	var fire_bolt := await _wait_for_group(&"fire_bolt", 240)
	_check(fire_bolt != null, "Fire Hurl launches a small compressed bolt")
	var ranged_explosion := await _wait_for_group(&"fire_explosion", 240)
	_check(ranged_explosion != null, "the fire bolt explodes at maximum range")
	if ranged_explosion is Node3D:
		_check((ranged_explosion as Node3D).global_position.distance_to(player.global_position) > 20.0,
			"the unobstructed fire bolt travels to its long-range airburst")

	# A solid object triggers the same blast immediately instead of letting the
	# bolt pass through or waiting for its range limit.
	if is_instance_valid(ranged_explosion):
		ranged_explosion.queue_free()
	await process_frame
	await process_frame
	var impact_wall := _build_static_box(Vector3(3.0, 4.0, 0.5))
	root.add_child(impact_wall)
	impact_wall.global_position = Vector3(8.0, 1.0, -4.0)
	var collision_bolt := (load(
		"res://game/spellcraft/casting/spells/fire_bolt.tscn") as PackedScene).instantiate() as HurlProjectile
	collision_bolt.element = fire
	collision_bolt.caster = player
	root.add_child(collision_bolt)
	collision_bolt.global_position = Vector3(8.0, 1.0, 0.0)
	collision_bolt.launch(Vector3.FORWARD * 38.0)
	var collision_explosion := await _wait_for_group(&"fire_explosion", 60)
	_check(collision_explosion != null, "the fire bolt explodes when it strikes an object")
	if collision_explosion is Node3D:
		_check(absf((collision_explosion as Node3D).global_position.z + 3.75) < 0.5,
			"the collision blast blooms at the struck surface")

	# The amplified blast affects its caster, including damage and launch force.
	var health_before := player.health.current
	var velocity_before := player.velocity
	var close_blast := (load(
		"res://game/spellcraft/casting/effects/fire_explosion.tscn") as PackedScene).instantiate() as FireExplosion
	close_blast.configure(fire, player)
	root.add_child(close_blast)
	close_blast.global_position = player.global_position + Vector3(0.0, 0.0, -1.0)
	await physics_frame
	await physics_frame
	_check(player.health.current < health_before, "Fire Hurl damages its caster inside the blast")
	_check(player.velocity.distance_to(velocity_before) > 1.0,
		"Fire Hurl launches its caster with radial force")
	_check(is_equal_approx(close_blast.damage_radius, 6.0),
		"Fire Hurl uses the approved six-meter damage radius")
	_check(close_blast.visual_radius >= 10.0,
		"Fire Hurl blooms beyond ten meters visually")

	# Every canonical element selects a distinct Hurl expression.
	var earth := load("res://game/spellcraft/elements/earth.tres") as Element
	var air := load("res://game/spellcraft/elements/air.tres") as Element
	var cast_paths: Dictionary[StringName, String] = {
		fire.id: fire.hurl_cast_scene.resource_path,
		water.id: water.hurl_cast_scene.resource_path,
		earth.id: earth.hurl_cast_scene.resource_path,
		air.id: air.hurl_cast_scene.resource_path,
	}
	_check(cast_paths.size() == 4, "all four elements define Hurl expressions")
	_check(cast_paths.values().duplicate().all(func(path: String) -> bool:
		return not path.is_empty()), "every Hurl expression points to a cast scene")
	var unique_paths: Dictionary[String, bool] = {}
	for path: String in cast_paths.values():
		unique_paths[path] = true
	_check(unique_paths.size() == 4, "each element has a mechanically distinct Hurl scene")

	_check(RuneGlyphs.VERBS.has(&"hurl"), "Hurl belongs to the canonical rune vocabulary")
	var hurl_match := casting._recognizer.evaluate([RuneGlyphs.points(&"hurl")])
	_check(hurl_match["id"] == &"hurl" and float(hurl_match["score"]) >= casting.match_threshold,
		"the Outward Spear recognizes as Hurl through the live casting recognizer")
	_check(not RuneGlyphs.VERBS.has(&"draw") and not RuneGlyphs.VERBS.has(&"pour"),
		"Draw and Pour are absent from the canonical rune vocabulary")

	Input.action_release(&"cast")
	Input.action_release(&"sight")
	if is_instance_valid(close_blast):
		close_blast.queue_free()
	if is_instance_valid(ranged_explosion):
		ranged_explosion.queue_free()
	if is_instance_valid(collision_explosion):
		collision_explosion.queue_free()
	if is_instance_valid(fire_bolt):
		fire_bolt.queue_free()
	if is_instance_valid(collision_bolt):
		collision_bolt.queue_free()
	impact_wall.queue_free()
	player.queue_free()
	source.queue_free()
	foreign.queue_free()
	flame_visual.queue_free()
	floor.queue_free()
	await process_frame
	await process_frame
	if _fail == 0:
		print("WIZARD SIGHT HURL TEST OK")
	quit(_fail)


func _click_cast() -> void:
	await _click_action(&"cast")


## Presses cast, keeps the action held for the pull/push duration, releases.
## Pins the Input action state explicitly so the hold is deterministic in both
## graphical and headless runs.
func _hold_cast(duration: float) -> void:
	var press := InputEventAction.new()
	press.action = &"cast"
	press.pressed = true
	Input.parse_input_event(press)
	Input.action_press(&"cast")
	await create_timer(duration).timeout
	Input.action_release(&"cast")
	var release := InputEventAction.new()
	release.action = &"cast"
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _click_action(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _wait_for_group(group: StringName, maximum_frames: int) -> Node:
	for _frame in maximum_frames:
		var found := get_first_node_in_group(group)
		if found != null:
			return found
		await process_frame
	return null


func _build_static_box(size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
	else:
		push_error("[FAIL] %s" % message)
		_fail = 1
