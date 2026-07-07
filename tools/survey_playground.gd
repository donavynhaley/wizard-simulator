extends SceneTree

# Visual survey of the spellcraft playground. Needs a display (not --headless):
#   godot --path . -s tools/survey_playground.gd
# Renders to user://playground_<name>.png:
#   overview  - the room: bench, cabinet, dummies
#   bench     - close-up with runes socketed and the crystal lit
#   effects   - spells staged mid-flight: raging fire orb, ice shield dome,
#               shadow trap circle, lightning chain arcs

var _cam: Camera3D
var _scene: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_scene = (load("res://scenes/levels/spellcraft_playground.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	current_scene = _scene
	await process_frame
	await physics_frame

	# The HUD veils beauty shots; drop it for the survey.
	var hud := _scene.get_node_or_null("Player/WizardHud")
	if hud:
		hud.queue_free()

	_cam = Camera3D.new()
	_cam.fov = 65.0
	_scene.add_child(_cam)
	_cam.make_current()

	await _shot(Vector3(7.0, 5.0, 7.5), Vector3(0, 1.0, -2.0), "overview")

	# Socket a couple of stones so the bench reads as mid-craft.
	var bench: SpellBench = null
	var cabinet: RuneCabinet = null
	for child in _scene.get_children():
		if child is SpellBench:
			bench = child
		elif child is RuneCabinet:
			cabinet = child
	var player: Node3D = _scene.get_node("Player")
	var hands := player.get_node_or_null("%HandAnchor") as WizardHands
	for id in ["fire", "orb", "explode"]:
		for child in cabinet.get_children():
			var stone := child as RuneStone
			if stone and stone.rune_id == id:
				hands.pick_up(stone)
				break
		match id:
			"fire": bench._interact_socket(player, 0)
			"orb": bench._interact_socket(player, 1)
			"explode": bench._interact_socket(player, 2)
	await _shot(Vector3(1.6, 2.0, 1.4), Vector3(0, 1.35, -1.7), "bench")

	# Stage live effects near the dummies.
	var runes := func(ids: Array) -> Array[RuneData]:
		var out: Array[RuneData] = []
		for id: String in ids:
			out.append(RuneCatalog.get_rune(id))
		return out
	var orb_def: SpellDefinition = SpellForge.forge(runes.call(
		["fire", "orb", "raging", "on_impact"]))["definition"]
	var orb := SpellProjectile.new()
	orb.setup(orb_def, player)
	_scene.add_child(orb)
	orb.global_position = Vector3(3.4, 1.6, -1.4)
	orb._velocity = Vector3.ZERO

	var shield_def: SpellDefinition = SpellForge.forge(runes.call(
		["ice", "shield", "on_impact"]))["definition"]
	SpellShield.raise(shield_def, player, _scene)

	var trap_def: SpellDefinition = SpellForge.forge(runes.call(
		["shadow", "trap", "when_touched"]))["definition"]
	var trap := SpellZone.new()
	trap.def = trap_def
	trap.caster = player
	trap.mode = SpellZone.Mode.TRAP
	_scene.add_child(trap)
	trap.global_position = Vector3(3.0, 0.05, 1.5)

	var chain_def: SpellDefinition = SpellForge.forge(runes.call(
		["lightning", "chain", "on_impact"]))["definition"]
	var eye := player.global_position + Vector3.UP * 0.72
	var aim := Transform3D(Basis.looking_at(Vector3(5.5, 1.2, -3.0) - eye, Vector3.UP), eye)
	SpellChain.lash(chain_def, player, _scene, aim)

	await _shot(Vector3(1.0, 2.6, 3.2), Vector3(4.0, 1.0, -1.5), "effects")

	print("SURVEY OK")
	quit(0)


func _shot(cam_pos: Vector3, look_at: Vector3, shot_name: String) -> void:
	_cam.global_position = cam_pos
	_cam.look_at_from_position(cam_pos, look_at, Vector3.UP)
	for i in 8:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	var path := "user://playground_%s.png" % shot_name
	img.save_png(path)
	print("saved ", path)
