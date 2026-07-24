extends SceneTree

## Covers the 2026-07-23 rune recognition rework: relative-margin resolution,
## the hooked Open glyph breaking the Seal subset pair, stability-tier quality
## flowing into casts, and the practice slate's personal template persistence.

const TEST_PERSONAL_DIR := "user://test_runes_air"

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_run_recognizer_checks()
	await _run_lab_checks()
	_finish()


func _run_recognizer_checks() -> void:
	# Mirror the controller's canon registration: upright plus tilted copies.
	var recognizer := ShapeRecognizer.new()
	for id in RuneGlyphs.VERBS:
		for strokes: Array in RuneGlyphs.exemplar_strokes(id):
			recognizer.add_template(id, strokes)

	var hurl := recognizer.resolve([RuneGlyphs.points(&"hurl")], 0.45, 0.15)
	_check(hurl["id"] == &"hurl" and bool(hurl["decisive"]),
		"canonical Hurl resolves decisively under the margin rule")

	# The Donavyn report of 2026-07-23: a naturally tilted figure-eight (air
	# traces have no horizon) must still read as Bind.
	var tilted_eight := PackedVector2Array()
	for i in 65:
		var a := TAU * float(i) / 64.0
		var p := Vector2(0.3 * sin(2.0 * a), 0.45 * cos(a)).rotated(deg_to_rad(12.0))
		tilted_eight.append(Vector2(0.5, 0.5) + p)
	var tilted_bind := recognizer.resolve([tilted_eight], 0.45, 0.15)
	_check(tilted_bind["id"] == &"bind" and bool(tilted_bind["decisive"]),
		"a 12-degree tilted figure-eight resolves decisively as Bind")

	var seal := recognizer.resolve([RuneGlyphs._ring(1.0)], 0.45, 0.15)
	_check(seal["id"] == &"seal" and bool(seal["decisive"]),
		"a full ring resolves decisively as Seal")

	var open := recognizer.resolve([RuneGlyphs.points(&"open")], 0.45, 0.15)
	_check(open["id"] == &"open" and bool(open["decisive"]),
		"the hooked broken ring resolves decisively as Open")

	# The old failure mode: an under-drawn Seal is NOT the Open glyph anymore,
	# because Open now carries hook ink a plain arc never has.
	var lazy_ring := recognizer.resolve([RuneGlyphs._ring(0.85)], 0.45, 0.15)
	var misread_as_open: bool = lazy_ring["id"] == &"open" and bool(lazy_ring["decisive"])
	_check(not misread_as_open,
		"an under-drawn plain ring no longer resolves decisively as Open")

	# Multiple exemplars of the same verb must reinforce, not compete: with two
	# Seal templates both scoring high, the runner-up for the margin has to be
	# the best OTHER verb, or Seal could never beat "itself" decisively.
	recognizer.add_template(&"seal", [RuneGlyphs._ring(0.98)])
	var seal_two := recognizer.resolve([RuneGlyphs._ring(1.0)], 0.45, 0.15)
	_check(seal_two["id"] == &"seal" and bool(seal_two["decisive"]),
		"a second Seal exemplar does not steal Seal's own margin")
	_check(seal_two["second_id"] != &"seal",
		"the margin runner-up is always a different verb")


func _run_lab_checks() -> void:
	var level := (load(
		"res://game/spellcraft/spellcraft_lab.tscn") as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	await physics_frame

	var player := level.get_node(^"Player") as WizardPlayer
	var slate := level.get_node_or_null(^"Props/PracticeSlate") as PracticeSlate
	var casting := player.casting
	_check(player != null and casting != null, "the lab composes the real player")
	_check(slate != null, "the lab places a practice slate")
	if player == null or casting == null or slate == null:
		level.queue_free()
		await process_frame
		return

	# Rebuild the recognizer against an isolated personal dir so a developer's
	# real user:// exemplars can never influence this test.
	_remove_dir_recursive(TEST_PERSONAL_DIR)
	casting.personal_template_dir = TEST_PERSONAL_DIR
	casting._configure_recognizer()
	var baseline_templates: int = casting._recognizer.template_count()

	# The slate cycles the verb the controller listens for.
	_check(slate.focus_prompt(player, slate) == "Practice your hand at the slate",
		"an idle slate invites practice")
	slate.interact(player, slate)
	_check(casting.practice_verb == RuneGlyphs.VERBS[0],
		"interacting with the slate arms the first verb")
	_check(slate.focus_prompt(player, slate).contains(
		RuneGlyphs.display_name(RuneGlyphs.VERBS[0])),
		"the slate prompt names the awaited verb")

	# A decisive practice trace persists a personal exemplar and reloads.
	var recorded: Array[StringName] = []
	casting.practice_recorded.connect(func(id: StringName) -> void:
		recorded.append(id))
	casting._save_personal_template(&"hurl", [RuneGlyphs.points(&"hurl")])
	_check(recorded == [&"hurl" as StringName],
		"a personal exemplar emits practice_recorded")
	_check(casting._recognizer.template_count() == baseline_templates + 1,
		"the live recognizer gains the personal exemplar immediately")
	var personal_files := _personal_files()
	_check(personal_files.size() == 1 and personal_files[0].begins_with("hurl_"),
		"the exemplar is written under the personal template dir")
	casting._configure_recognizer()
	_check(casting._recognizer.template_count() == baseline_templates + 1,
		"personal exemplars load from disk on recognizer setup")

	# The disk store keeps only the newest exemplars per verb.
	for extra in 4:
		casting._save_personal_template(&"hurl", [RuneGlyphs.points(&"hurl")])
	_check(_personal_files().size() == casting.PERSONAL_TEMPLATE_LIMIT,
		"personal exemplars on disk are pruned to the per-verb limit")

	# Cycling the slate past the last verb rests it and clears the controller.
	for _hop in RuneGlyphs.VERBS.size():
		slate.interact(player, slate)
	_check(casting.practice_verb == &"", "cycling past the last verb rests the slate")

	# Trace quality flows into the cast: a wavering hand launches a projectile
	# that knows its own instability.
	var fire := load("res://game/spellcraft/elements/fire.tres") as Element
	var cast := (fire.hurl_cast_scene as PackedScene).instantiate() as SpellCast
	cast.element = fire
	cast.quality = 0.5
	root.add_child(cast)
	cast.begin(null, null, root, null)
	cast.cast()
	cast.resolve()
	await process_frame
	var projectile: Node = null
	for child in root.get_children():
		if child is HurlProjectile:
			projectile = child
			break
	_check(projectile != null, "a wavering Hurl still launches its projectile")
	if projectile != null:
		_check(is_equal_approx(float(projectile.get(&"stability")), 0.5),
			"the projectile carries the trace stability")
		projectile.queue_free()
	cast.queue_free()

	_remove_dir_recursive(TEST_PERSONAL_DIR)
	level.queue_free()
	await process_frame
	await process_frame


func _personal_files() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(TEST_PERSONAL_DIR)
	if dir == null:
		return out
	for file_name in dir.get_files():
		out.append(file_name)
	out.sort()
	return out


func _remove_dir_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)
	DirAccess.remove_absolute(path)


func _finish() -> void:
	if _failures == 0:
		print("RUNE PRACTICE TEST OK")
	else:
		print("RUNE PRACTICE TEST FAILURES: ", _failures)
	quit(_failures)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		_failures += 1
		push_error("[FAIL] " + message)
