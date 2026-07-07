extends SceneTree

# Headless test of the spell crafting mechanic, end to end:
#   forge logic (named recipes, rares, quirks, deterministic backfires)
#   the physical bench flow (socket stones -> channel -> scroll pops out)
#   scroll casting (orb hits a dummy, charges deplete, scroll crumbles)
#   the spellbook discovery journal
#   godot --headless --path . -s tools/spellcraft_test.gd

var _fail := 0
var _journal: SpellbookJournal


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# The Spellbook autoload is live even under -s; only the compile-time
	# identifier is unavailable, so grab it through the finder.
	_journal = SpellbookJournal.find(self)
	_check(_journal != null, "Spellbook autoload is up")

	_forge_tests()
	await _scene_tests()
	if _fail == 0:
		print("SPELLCRAFT TEST OK")
	else:
		print("SPELLCRAFT TEST FAILURES: ", _fail)
	quit(_fail)


func _runes(ids: Array) -> Array[RuneData]:
	var out: Array[RuneData] = []
	for id: String in ids:
		var rune := RuneCatalog.get_rune(id)
		_check(rune != null, "catalog has rune '%s'" % id)
		out.append(rune)
	return out


func _forge_tests() -> void:
	_check(RuneCatalog.all_runes().size() >= 30, "catalog has a full rune set (%d)"
		% RuneCatalog.all_runes().size())

	# The canonical example: Fire + Orb + Bounce + Explode.
	var result := SpellForge.forge(_runes(["fire", "orb", "bounce", "explode", "on_impact"]))
	_check(result["ok"], "bouncing detonator forges")
	if result["ok"]:
		var def: SpellDefinition = result["definition"]
		_check(def.spell_name == "Bouncing Detonator", "named recipe hit (got '%s')" % def.spell_name)
		_check(def.charges == 5, "orb scroll has 5 charges (got %d)" % def.charges)
		_check(def.instability < SpellForge.QUIRK_THRESHOLD, "clean forge has no quirk zone (%.2f)" % def.instability)
		_check(def.quirks.is_empty(), "no quirks on a stable spell")

	# Determinism: same runes, same spell.
	var again := SpellForge.forge(_runes(["fire", "orb", "bounce", "explode", "on_impact"]))
	_check(again["ok"] and again["definition"].spell_name == "Bouncing Detonator",
		"forge is deterministic for the same combo")

	# Hidden rare recipe.
	var rare := SpellForge.forge(_runes(["shadow", "aura", "linger", "silent", "on_impact"]))
	_check(rare["ok"], "rare combo forges")
	if rare["ok"]:
		_check(rare["definition"].rare_id == "veil_of_the_quiet_dark",
			"rare recipe found (got '%s')" % rare["definition"].rare_id)

	# Quirk zone: works, but with personality.
	var quirky := SpellForge.forge(_runes(["lightning", "orb", "unstable", "on_impact"]))
	_check(quirky["ok"], "quirky combo still forges")
	if quirky["ok"]:
		var qdef: SpellDefinition = quirky["definition"]
		_check(qdef.instability >= SpellForge.QUIRK_THRESHOLD, "overload puts it in the quirk zone (%.2f)" % qdef.instability)
		_check(qdef.quirks.size() >= 1, "quirks assigned (%s)" % ", ".join(qdef.quirks))
		var quirky2 := SpellForge.forge(_runes(["lightning", "orb", "unstable", "on_impact"]))
		_check(quirky2["ok"] and quirky2["definition"].quirks == qdef.quirks,
			"quirks are deterministic per combo")

	# Guaranteed backfire: everything cranked past the red line.
	var doomed := SpellForge.forge(_runes(
		["lightning", "chain", "split", "home", "unstable", "raging", "on_death"]))
	_check(not doomed["ok"], "overloaded combo always backfires")
	if not doomed["ok"]:
		_check(doomed["backfire"] in SpellForge.BACKFIRE_POOL,
			"backfire kind valid ('%s')" % doomed["backfire"])
		_check(doomed.get("deterministic", false), "backfire is the always-fires kind")

	# Validation.
	var invalid := SpellForge.forge(_runes(["fire", "ice", "orb"]))
	_check(not invalid["ok"] and invalid["backfire"] == "", "two elements refuse to forge")


func _scene_tests() -> void:
	var scene := (load("res://scenes/levels/spellcraft_playground.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	await physics_frame

	var player: Node3D = scene.get_node("Player")
	var hands := player.get_node_or_null("%HandAnchor") as WizardHands
	var interactor := player.get_node_or_null("%Interactor") as PlayerInteractor
	_check(hands != null, "player has WizardHands")
	_check(interactor != null, "player has PlayerInteractor")

	var bench: SpellBench = null
	var cabinet: RuneCabinet = null
	var dummies: Array[TrainingDummy] = []
	for child in scene.get_children():
		if child is SpellBench:
			bench = child
		elif child is RuneCabinet:
			cabinet = child
		elif child is TrainingDummy:
			dummies.append(child)
	_check(bench != null, "playground has a spell bench")
	_check(cabinet != null, "playground has a rune cabinet")
	_check(dummies.size() == 3, "playground has 3 training dummies")
	var stones := 0
	for child in cabinet.get_children():
		if child is RuneStone:
			stones += 1
	_check(stones >= 30, "cabinet stocked one stone per rune (%d)" % stones)

	# --- Physical bench flow: socket fire + orb, channel, scroll pops out.
	_journal.entries.clear()
	var fire_stone := _grab_stone(cabinet, hands, "fire")
	bench._interact_socket(player, 0)
	_check(bench._socket_stones[0] == fire_stone, "fire stone socketed in Element slot")
	var orb_stone := _grab_stone(cabinet, hands, "orb")
	bench._interact_socket(player, 1)
	_check(bench._socket_stones[1] == orb_stone, "orb stone socketed in Shape slot")
	_check(hands.held_item == null, "hands empty after socketing")

	var forged_def: Array = []
	bench.spell_forged.connect(func(def: SpellDefinition) -> void: forged_def.append(def))
	bench._channel(player)
	await create_timer(SpellBench.CHANNEL_TIME + 0.4).timeout
	await physics_frame
	_check(forged_def.size() == 1, "bench forged a spell")
	var bench_scroll: SpellScroll = null
	for child in scene.get_children():
		if child is SpellScroll:
			bench_scroll = child
	_check(bench_scroll != null, "a scroll popped onto the bench")
	if bench_scroll:
		_check(bench_scroll.definition.spell_name == forged_def[0].spell_name,
			"scroll carries the forged spell ('%s')" % bench_scroll.definition.spell_name)
	_check(_journal.discovered_count() == 1, "spellbook logged the discovery (count %d, keys %s)"
		% [_journal.discovered_count(), _journal.entries.keys()])
	var key := SpellDefinition.make_combo_key(["fire", "orb", "on_impact"])
	_check(_journal.is_known(key), "journal key matches the combo")

	# --- Casting: a precise fire beam hits a dummy instantly.
	var dummy := dummies[0]
	var start_hp := dummy.health
	var beam_def: SpellDefinition = SpellForge.forge(
		_runes(["fire", "beam", "precise", "on_impact"]))["definition"]
	_check(beam_def.spell_name == "Ember Lance", "ember lance recipe named")
	var aim := _aim_at(player, dummy.global_position + Vector3.UP * 1.2)
	SpellCast.cast(beam_def, player, aim)
	await physics_frame
	_check(dummy.health < start_hp, "beam damaged the dummy (%.1f -> %.1f)" % [start_hp, dummy.health])

	# --- Casting: an orb flies across the room and connects.
	start_hp = dummy.health
	var orb_def: SpellDefinition = SpellForge.forge(
		_runes(["ice", "orb", "on_impact"]))["definition"]
	SpellCast.cast(orb_def, player, _aim_at(player, dummy.global_position + Vector3.UP * 1.0))
	var waited := 0
	while dummy.health >= start_hp and waited < 240:
		waited += 1
		await physics_frame
	_check(dummy.health < start_hp, "orb projectile hit the dummy after %d frames" % waited)

	# --- Scroll charges deplete and the scroll crumbles.
	var scroll_def: SpellDefinition = SpellForge.forge(
		_runes(["wind", "wave", "on_impact"]))["definition"]
	scroll_def.charges = 2
	var scroll: SpellScroll = (load("res://scenes/props/spell_scroll.tscn") as PackedScene).instantiate()
	scroll.definition = scroll_def
	scene.add_child(scroll)
	scroll.global_position = player.global_position + Vector3.UP
	hands.pick_up(scroll)
	_check(hands.held_item == scroll, "scroll picked up")
	scroll.cast_from(player, _aim_at(player, dummies[1].global_position))
	_check(scroll.definition.charges == 1, "first cast spent a charge")
	scroll.cast_from(player, _aim_at(player, dummies[1].global_position))
	await physics_frame
	_check(hands.held_item == null, "spent scroll crumbled out of the hand")

	# --- Dummy death notifies, dummy respawns.
	var kill_def: SpellDefinition = SpellForge.forge(
		_runes(["fire", "beam", "on_impact"]))["definition"]
	kill_def.power = 1000.0
	var victim := dummies[2]
	SpellCast.cast(kill_def, player, _aim_at(player, victim.global_position + Vector3.UP * 1.2))
	await physics_frame
	_check(victim.dead, "overkill beam unstuffed the dummy")
	await create_timer(victim.respawn_seconds + 0.5).timeout
	_check(not victim.dead and victim.health == victim.max_health, "dummy respawned")

	# --- Backfire path: frog curse applies and reverts speed later (spot check apply).
	var old_speed: float = player.get("move_speed")
	SpellBackfires.run("frog", player, scene, player.global_position)
	await process_frame
	_check(player.get("move_speed") < old_speed, "frog curse slows the caster")
	_check(player.get_node_or_null("FrogCurse") != null, "frog curse attached")

	# --- Tiny demon spawns and wanders without crashing.
	SpellBackfires.run("demon", player, scene, player.global_position + Vector3(1, 0, 1))
	await physics_frame
	var demon_found := false
	for child in scene.get_children():
		if child is TinyDemon:
			demon_found = true
	_check(demon_found, "tiny useless demon reported for duty")
	for i in 30:
		await physics_frame


func _grab_stone(cabinet: RuneCabinet, hands: WizardHands, rune_id: String) -> RuneStone:
	for child in cabinet.get_children():
		var stone := child as RuneStone
		if stone and stone.rune_id == rune_id:
			hands.pick_up(stone)
			return stone
	_check(false, "found a '%s' stone in the cabinet" % rune_id)
	return null


func _aim_at(player: Node3D, target: Vector3) -> Transform3D:
	var eye: Vector3 = player.global_position + Vector3.UP * 0.72
	return Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)


func _check(cond: bool, label: String) -> void:
	print(("[PASS] " if cond else "[FAIL] ") + label)
	if not cond:
		_fail += 1
