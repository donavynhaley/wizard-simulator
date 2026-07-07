class_name RuneCabinet
extends Node3D

## A supply cabinet holding one stone of every rune in the catalog, arranged in
## shelves by category. Consumed stones quietly grow back after a while, so the
## workshop never runs dry. Drop one in the library floor and experiment away.

@export var restock_seconds: float = 12.0

const RUNE_STONE_SCENE := "res://scenes/props/rune_stone.tscn"

## slot index -> { "rune_id": String, "position": Vector3, "stone": weak instance }
var _slots: Array[Dictionary] = []
var _restock := 0.0


func _ready() -> void:
	var order: Array = [
		RuneData.RuneType.ELEMENT,
		RuneData.RuneType.SHAPE,
		RuneData.RuneType.BEHAVIOR,
		RuneData.RuneType.TRIGGER,
		RuneData.RuneType.MODIFIER,
	]
	var widest := 0
	for rune_type: RuneData.RuneType in order:
		widest = maxi(widest, RuneCatalog.runes_of_type(rune_type).size())
	var width := widest * 0.3 + 0.4

	_build_case(width, order.size())

	for row in order.size():
		var runes := RuneCatalog.runes_of_type(order[row])
		var shelf_y := 0.35 + (order.size() - 1 - row) * 0.42
		var header := Label3D.new()
		header.text = RuneData.TYPE_NAMES[order[row]] + "s"
		header.font_size = 22
		header.pixel_size = 0.003
		header.modulate = Color(0.85, 0.78, 0.6)
		header.position = Vector3(-width * 0.5 + 0.05, shelf_y + 0.24, 0.16)
		add_child(header)
		for i in runes.size():
			var pos := Vector3(-(runes.size() - 1) * 0.15 + i * 0.3, shelf_y + 0.08, 0.0)
			_slots.append({"rune_id": runes[i].id, "position": pos, "stone": null})
			_spawn_stone(_slots.size() - 1)


func _build_case(width: float, rows: int) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.2, 0.13, 0.09)
	wood.roughness = 0.9
	var height := 0.35 + rows * 0.42 + 0.1

	var back := MeshInstance3D.new()
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(width, height, 0.06)
	back.mesh = back_mesh
	back.position = Vector3(0.0, height * 0.5, -0.14)
	back.material_override = wood
	add_child(back)

	for row in rows + 1:
		var shelf := MeshInstance3D.new()
		var shelf_mesh := BoxMesh.new()
		shelf_mesh.size = Vector3(width, 0.05, 0.34)
		shelf.mesh = shelf_mesh
		shelf.position = Vector3(0.0, 0.3 + row * 0.42, 0.0)
		shelf.material_override = wood
		add_child(shelf)

	var body := StaticBody3D.new()
	body.collision_layer = SpellCast.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, 0.1)
	shape.shape = box
	shape.position = Vector3(0.0, height * 0.5, -0.14)
	body.add_child(shape)
	add_child(body)


func _spawn_stone(slot_index: int) -> void:
	var slot := _slots[slot_index]
	var scene: PackedScene = load(RUNE_STONE_SCENE)
	var stone: RuneStone = scene.instantiate()
	stone.rune_id = slot["rune_id"]
	add_child(stone)
	stone.position = slot["position"]
	# Lean back against the case so the glyph face shows to the room.
	stone.rotation_degrees.x = 60.0
	stone.freeze = true  # sits politely on the shelf until taken
	slot["stone"] = stone
	stone.tree_exited.connect(func() -> void:
		if slot["stone"] == stone:
			slot["stone"] = null)


func _process(delta: float) -> void:
	_restock -= delta
	if _restock > 0.0:
		return
	_restock = restock_seconds
	for i in _slots.size():
		var slot := _slots[i]
		var stone: Variant = slot["stone"]
		# Regrow when the old stone is gone (consumed) or was carried away.
		if stone == null or not is_instance_valid(stone) or stone.get_parent() != self:
			if stone != null and is_instance_valid(stone):
				slot["stone"] = null
			_spawn_stone(i)
