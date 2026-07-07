class_name SpellBench
extends Node3D

## The physical spell crafting bench. Crafting is done in the world, not a menu:
## carry rune stones to the floating sockets (one element, one shape, up to two
## behaviors, one trigger, two modifiers), then channel the focus crystal.
## Sound combinations roll a scroll onto the tray; unstable ones may croak,
## blast, summon, or scatter your runes across the room.

signal spell_forged(definition: SpellDefinition)
signal forge_backfired(kind: String)

const SCROLL_SCENE := "res://scenes/props/spell_scroll.tscn"
const CHANNEL_TIME := 1.4

## Socket layout: category and label for each floating slot, left to right.
const SLOTS := [
	{"type": RuneData.RuneType.ELEMENT, "label": "Element"},
	{"type": RuneData.RuneType.SHAPE, "label": "Shape"},
	{"type": RuneData.RuneType.BEHAVIOR, "label": "Behavior"},
	{"type": RuneData.RuneType.BEHAVIOR, "label": "Behavior"},
	{"type": RuneData.RuneType.TRIGGER, "label": "Trigger"},
	{"type": RuneData.RuneType.MODIFIER, "label": "Modifier"},
	{"type": RuneData.RuneType.MODIFIER, "label": "Modifier"},
]

var _sockets: Array[StaticBody3D] = []
var _socket_stones: Array = []  # RuneStone or null, parallel to _sockets
var _socket_rings: Array[MeshInstance3D] = []
var _crystal: MeshInstance3D
var _crystal_mat: StandardMaterial3D
var _crystal_body: StaticBody3D
var _channeling := false
var _age := 0.0


func _ready() -> void:
	add_to_group("interactable")
	_build_table()
	_build_sockets()
	_build_crystal()
	for i in SLOTS.size():
		_socket_stones.append(null)


func _build_table() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.24, 0.16, 0.1)
	wood.roughness = 0.9
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color(0.45, 0.35, 0.16)
	trim.metallic = 0.4
	trim.roughness = 0.5

	var top := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(2.2, 0.12, 1.1)
	top.mesh = top_mesh
	top.position.y = 0.95
	top.material_override = wood
	add_child(top)

	var apron := MeshInstance3D.new()
	var apron_mesh := BoxMesh.new()
	apron_mesh.size = Vector3(2.24, 0.05, 1.14)
	apron.mesh = apron_mesh
	apron.position.y = 0.87
	apron.material_override = trim
	add_child(apron)

	for corner in [Vector3(-1.0, 0.45, -0.45), Vector3(1.0, 0.45, -0.45),
			Vector3(-1.0, 0.45, 0.45), Vector3(1.0, 0.45, 0.45)]:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.12, 0.9, 0.12)
		leg.mesh = leg_mesh
		leg.position = corner
		leg.material_override = wood
		add_child(leg)

	var body := StaticBody3D.new()
	body.collision_layer = SpellCast.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 1.02, 1.1)
	shape.shape = box
	shape.position.y = 0.51
	body.add_child(shape)
	add_child(body)


func _build_sockets() -> void:
	for i in SLOTS.size():
		var slot: Dictionary = SLOTS[i]
		var x := -0.9 + 0.3 * i
		var pos := Vector3(x, 1.55 + sin(i * 1.1) * 0.04, -0.32)

		var socket := StaticBody3D.new()
		socket.collision_layer = SpellCast.LAYER_PICKUP
		socket.collision_mask = 0
		socket.set_meta("socket_index", i)
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.13
		shape.shape = sphere
		socket.add_child(shape)
		socket.position = pos
		add_child(socket)
		_sockets.append(socket)

		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.085
		torus.outer_radius = 0.11
		ring.mesh = torus
		ring.material_override = SpellVisuals.emissive(_slot_color(slot["type"]), 0.7, 0.5)
		ring.position = pos
		add_child(ring)
		_socket_rings.append(ring)

		var caption := Label3D.new()
		caption.text = slot["label"]
		caption.font_size = 20
		caption.pixel_size = 0.0035
		caption.modulate = _slot_color(slot["type"]).lightened(0.3)
		caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		caption.position = pos + Vector3(0.0, 0.17, 0.0)
		add_child(caption)


func _build_crystal() -> void:
	var pedestal := MeshInstance3D.new()
	var ped_mesh := CylinderMesh.new()
	ped_mesh.top_radius = 0.1
	ped_mesh.bottom_radius = 0.14
	ped_mesh.height = 0.25
	pedestal.mesh = ped_mesh
	pedestal.position = Vector3(0.0, 1.13, 0.15)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.2, 0.19, 0.24)
	pedestal.material_override = stone
	add_child(pedestal)

	_crystal = MeshInstance3D.new()
	var crystal_mesh := BoxMesh.new()
	crystal_mesh.size = Vector3(0.14, 0.3, 0.14)
	_crystal.mesh = crystal_mesh
	_crystal.position = Vector3(0.0, 1.48, 0.15)
	_crystal.rotation_degrees = Vector3(35.0, 45.0, 20.0)
	_crystal_mat = SpellVisuals.emissive(Color(0.65, 0.75, 1.0), 1.0, 0.85)
	_crystal.material_override = _crystal_mat
	add_child(_crystal)
	SpellVisuals.add_light(_crystal, Color(0.65, 0.75, 1.0), 0.8, 2.5)

	_crystal_body = StaticBody3D.new()
	_crystal_body.collision_layer = SpellCast.LAYER_PICKUP
	_crystal_body.collision_mask = 0
	_crystal_body.set_meta("bench_crystal", true)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.24
	shape.shape = sphere
	_crystal_body.add_child(shape)
	_crystal_body.position = Vector3(0.0, 1.48, 0.15)
	add_child(_crystal_body)


func _slot_color(rune_type: RuneData.RuneType) -> Color:
	match rune_type:
		RuneData.RuneType.ELEMENT: return Color(1.0, 0.6, 0.4)
		RuneData.RuneType.SHAPE: return Color(0.75, 0.7, 1.0)
		RuneData.RuneType.BEHAVIOR: return Color(0.6, 0.95, 0.7)
		RuneData.RuneType.TRIGGER: return Color(1.0, 0.9, 0.55)
		_: return Color(0.95, 0.65, 0.9)


func _process(delta: float) -> void:
	_age += delta
	# Socketed stones hover, bob, and slowly spin. The crystal breathes.
	for i in _sockets.size():
		var stone: Variant = _socket_stones[i]
		if stone != null and is_instance_valid(stone):
			var base: Vector3 = _sockets[i].position
			stone.position = base + Vector3(0.0, sin(_age * 2.0 + i) * 0.02, 0.0)
			stone.rotation.y += delta * 0.8
	if _crystal and not _channeling:
		_crystal.rotation.y += delta * 0.4
		_crystal_mat.emission_energy_multiplier = 1.0 + sin(_age * 1.6) * 0.3


# --- Interaction contract -----------------------------------------------------

func focus_prompt(player: Node3D, collider: Object) -> String:
	if _channeling:
		return "The bench is busy."
	if collider is Node and (collider as Node).has_meta("socket_index"):
		return _socket_prompt(player, (collider as Node).get_meta("socket_index"))
	if collider is Node and (collider as Node).has_meta("bench_crystal"):
		var runes := _collect_runes()
		if runes.is_empty():
			return "Focus crystal: socket some runes first"
		var problem := _readiness_problem()
		if problem != "":
			return "Focus crystal: " + problem
		return "Channel the spell  (%d runes set)" % runes.size()
	return "Spell bench: socket runes above, then channel the crystal"


func _socket_prompt(player: Node3D, i: int) -> String:
	var slot: Dictionary = SLOTS[i]
	var type_name: String = slot["label"]
	var stone: Variant = _socket_stones[i]
	if stone != null and is_instance_valid(stone):
		return "Take back %s rune" % stone.rune.display_name
	var held := _held_stone(player)
	if held == null:
		return "%s slot: empty" % type_name
	if held.rune.rune_type != slot["type"]:
		return "%s slot: '%s' does not fit here" % [type_name, held.rune.display_name]
	return "Socket %s rune" % held.rune.display_name


func interact(player: Node3D, collider: Object) -> void:
	if _channeling:
		return
	if collider is Node and (collider as Node).has_meta("socket_index"):
		_interact_socket(player, (collider as Node).get_meta("socket_index"))
	elif collider is Node and (collider as Node).has_meta("bench_crystal"):
		_channel(player)


func _interact_socket(player: Node3D, i: int) -> void:
	var stone: Variant = _socket_stones[i]
	var hands := player.get_node_or_null("%HandAnchor") as WizardHands
	if stone != null and is_instance_valid(stone):
		# Give it back to the player (or drop it on the bench if hands are full).
		_socket_stones[i] = null
		if hands:
			stone.reparent(get_tree().current_scene)
			hands.pick_up(stone)
		return
	var held := _held_stone(player)
	if held == null or held.rune.rune_type != SLOTS[i]["type"]:
		return
	if hands:
		hands.release_item(held)
	held.set_held(true)
	held.reparent(self)
	held.position = _sockets[i].position
	held.rotation = Vector3.ZERO
	_socket_stones[i] = held


func _held_stone(player: Node3D) -> RuneStone:
	var hands := player.get_node_or_null("%HandAnchor") as WizardHands
	if hands == null:
		return null
	return hands.held_item as RuneStone


func _collect_runes() -> Array[RuneData]:
	var runes: Array[RuneData] = []
	for stone: Variant in _socket_stones:
		if stone != null and is_instance_valid(stone):
			runes.append(stone.rune)
	return runes


func _readiness_problem() -> String:
	var has_element := false
	var has_shape := false
	for rune in _collect_runes():
		has_element = has_element or rune.rune_type == RuneData.RuneType.ELEMENT
		has_shape = has_shape or rune.rune_type == RuneData.RuneType.SHAPE
	if not has_element:
		return "needs an Element rune"
	if not has_shape:
		return "needs a Shape rune"
	return ""


func _channel(player: Node3D) -> void:
	if _readiness_problem() != "":
		_announce("The crystal stays dark: " + _readiness_problem() + ".")
		return
	_channeling = true

	# The runes spiral into the crystal while it flares.
	var tween := create_tween()
	tween.set_parallel(true)
	for i in _socket_stones.size():
		var stone: Variant = _socket_stones[i]
		if stone != null and is_instance_valid(stone):
			tween.tween_property(stone, "position", _crystal.position, CHANNEL_TIME) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(stone, "scale", Vector3.ONE * 0.25, CHANNEL_TIME) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_crystal_mat, "emission_energy_multiplier", 4.0, CHANNEL_TIME)
	tween.chain().tween_callback(_resolve_forge.bind(player))


func _resolve_forge(player: Node3D) -> void:
	var runes := _collect_runes()
	var result := SpellForge.forge(runes)
	var combo_key := SpellDefinition.make_combo_key(_rune_ids_with_default_trigger(runes))
	var journal := SpellbookJournal.find(get_tree())
	if journal:
		journal.record_forge(combo_key, result)
	var world := get_tree().current_scene

	if result["ok"]:
		var def: SpellDefinition = result["definition"]
		_consume_stones()
		_spawn_scroll(def)
		SpellVisuals.spawn_flash(world, _crystal.global_position, def.primary_color(), 0.6)
		_announce("Forged: %s  (%d charges, %.0f%% instability)" %
			[def.spell_name, def.charges, def.instability * 100.0])
		spell_forged.emit(def)
	else:
		var kind: String = result["backfire"]
		_announce(result["message"])
		if result.get("keep_runes", false):
			_scatter_stones()
		else:
			_consume_stones()
			SpellBackfires.run(kind, player, world, global_position)
		forge_backfired.emit(kind)

	_crystal_mat.emission_energy_multiplier = 1.0
	_channeling = false


func _announce(text: String) -> void:
	var journal := SpellbookJournal.find(get_tree())
	if journal:
		journal.announce(text)


## The forge treats a missing trigger as on_impact; log the combo the same way
## so the journal matches what the scroll actually does.
func _rune_ids_with_default_trigger(runes: Array[RuneData]) -> PackedStringArray:
	var ids := PackedStringArray()
	var has_trigger := false
	for rune in runes:
		ids.append(rune.id)
		has_trigger = has_trigger or rune.rune_type == RuneData.RuneType.TRIGGER
	if not has_trigger:
		ids.append("on_impact")
	return ids


func _consume_stones() -> void:
	for i in _socket_stones.size():
		var stone: Variant = _socket_stones[i]
		if stone != null and is_instance_valid(stone):
			stone.queue_free()
		_socket_stones[i] = null


func _scatter_stones() -> void:
	var world := get_tree().current_scene
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in _socket_stones.size():
		var stone: Variant = _socket_stones[i]
		if stone != null and is_instance_valid(stone):
			stone.reparent(world)
			stone.scale = Vector3.ONE
			stone.set_held(false)
			stone.apply_central_impulse(Vector3(
				rng.randf_range(-3.0, 3.0), rng.randf_range(3.0, 5.0),
				rng.randf_range(-3.0, 3.0)))
			stone.apply_torque_impulse(Vector3(rng.randf(), rng.randf(), rng.randf()))
		_socket_stones[i] = null


func _spawn_scroll(def: SpellDefinition) -> void:
	var scene: PackedScene = load(SCROLL_SCENE)
	var scroll: SpellScroll = scene.instantiate()
	scroll.definition = def
	get_tree().current_scene.add_child(scroll)
	scroll.global_position = to_global(Vector3(0.0, 1.3, 0.45))
	scroll.apply_central_impulse(global_transform.basis * Vector3(0.0, 1.2, 1.6))
