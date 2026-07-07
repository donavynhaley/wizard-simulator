extends Node3D

# Wizard Simulator - vertical round tower.
#
# Premise: the wizard has lost his memories and is trapped in his own tower. The
# front door is arcane-locked. Five circular themed floors are stacked and joined
# by a central spiral staircase - walk up it to move between floors.

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const MOOD_LIGHT_SCRIPT := preload("res://scripts/components/mood_light.gd")
const SKELETON_SCENE := preload("res://assets/external/kenney/graveyard-kit/Models/GLB format/character-skeleton.glb")
const CASTLE_TOWER_SCENE := preload("res://assets/external/kenney/retro-fantasy-kit/Models/GLB format/tower.glb")
const CASTLE_TOWER_TOP_SCENE := preload("res://assets/external/kenney/retro-fantasy-kit/Models/GLB format/tower-top.glb")
const CASTLE_WALL_SCENE := preload("res://assets/external/kenney/retro-fantasy-kit/Models/GLB format/wall-fortified.glb")
const TOWN_ROOF_SCENE := preload("res://assets/external/kenney/fantasy-town-kit/Models/GLB format/roof-gable.glb")
const TOWN_TREE_SCENE := preload("res://assets/external/kenney/fantasy-town-kit/Models/GLB format/tree.glb")

const FLOOR_COUNT := 5
const WALL_RADIUS := 6.5        # interior radius to the wall face
const RING_INNER := 2.6         # inner edge of the walkable ring (stairwell shaft)
const FLOOR_GAP := 4.7          # floor-to-floor height
const STAIR_RADIUS := 1.55      # radius of the spiral treads about the tower axis
const NEWEL_RADIUS := 0.42
const STAIR_STEPS := 18         # steps per full turn (one turn per floor)
const STAIR_ANGLE0 := 0.0       # angle where the stair meets each floor (+X side)

const FLOOR_NAMES := [
	"I  -  Entry Hall",
	"II  -  Skully's Room",
	"III  -  Potion Chamber",
	"IV  -  Library & Spellcraft",
	"V  -  Scrying Room",
]

var _materials: Dictionary = {}
var _player: CharacterBody3D
var _camera: Camera3D
var _current_floor: int = 0
var _floor_label: Label
var _interact_label: Label

var _interactables: Array = []
var _focused: Dictionary = {}
var _dialogue_active: bool = false
var _dialogue_lines: Array = []
var _dialogue_index: int = 0
var _dlg_panel: PanelContainer
var _dlg_speaker: Label
var _dlg_text: Label


func _ready() -> void:
	seed(7)
	_make_materials()
	_setup_environment()
	_build_outer_wall()
	for i in FLOOR_COUNT:
		_build_floor(i)
	for g in FLOOR_COUNT - 1:
		_build_spiral(g)
	_build_hud()
	_spawn_player()


func _base_y(floor_index: int) -> float:
	return floor_index * FLOOR_GAP


func _build_floor(floor_index: int) -> void:
	_build_floor_shell(floor_index)
	match floor_index:
		0:
			_build_entry_hall(floor_index)
		1:
			_build_skully_room(floor_index)
		2:
			_build_potion_chamber(floor_index)
		3:
			_build_library(floor_index)
		4:
			_build_scrying_room(floor_index)


# ---------------------------------------------------------------------------
# Circular shell
# ---------------------------------------------------------------------------

func _build_outer_wall() -> void:
	# One tall cylindrical stone wall for the whole tower, built from segments.
	var height := FLOOR_COUNT * FLOOR_GAP
	var segs := 30
	var seg_w := TAU * WALL_RADIUS / segs + 0.25
	for k in segs:
		var a := TAU * float(k) / segs
		var pos := Vector3(cos(a) * (WALL_RADIUS + 0.25), height * 0.5 - 0.3, sin(a) * (WALL_RADIUS + 0.25))
		var seg := _box("WallSeg%d" % k, Vector3(0.5, height, seg_w), pos, _materials.stone)
		seg.get_parent().rotation.y = -a
		# Faint masonry banding on the inner face.
		var band := _vbox("WallBand%d" % k, Vector3(0.06, height, seg_w * 0.92), pos - Vector3(cos(a) * 0.28, 0.0, sin(a) * 0.28), _materials.stone_dark)
		band.rotation.y = -a


func _build_floor_shell(floor_index: int) -> void:
	var base := _base_y(floor_index)
	var prefix := "F%d_" % floor_index
	# Floor 0 is a full disc; upper floors are rings around the central shaft.
	_build_ring_floor(prefix + "Floor", base, (0.0 if floor_index == 0 else RING_INNER), WALL_RADIUS + 0.2, _materials.floor_stone)
	# Top floor gets a ceiling cap; lower floors are capped by the floor above.
	if floor_index == FLOOR_COUNT - 1:
		_build_ring_floor(prefix + "Ceiling", base + FLOOR_GAP - 0.3, RING_INNER, WALL_RADIUS + 0.2, _materials.stone_dark)
	# Railing around the shaft (skip the arc where the stair connects).
	if floor_index > 0:
		_build_shaft_railing(prefix, base)
	# Practical + fill lighting.
	for k in 4:
		var a := STAIR_ANGLE0 + PI * 0.5 + TAU * float(k) / 4.0
		_candle(prefix + "Sconce%d" % k, Vector3(cos(a) * (WALL_RADIUS - 0.5), base + 2.5, sin(a) * (WALL_RADIUS - 0.5)))
	_fill_light(prefix + "Fill", Vector3(0.0, base + FLOOR_GAP - 0.9, 0.0), Color(1.0, 0.92, 0.8), 1.9, WALL_RADIUS * 3.2)
	_fill_light(prefix + "FillLow", Vector3(0.0, base + 1.8, 0.0), Color(0.55, 0.58, 0.9), 1.1, WALL_RADIUS * 3.2)


func _build_ring_floor(node_name: String, top_y: float, inner_r: float, outer_r: float, material: Material) -> void:
	# Tiles the annulus (or disc) with stone boxes, clipped to the circle and the shaft.
	var tile := 1.7
	var n := int(ceil(outer_r / tile)) + 1
	var idx := 0
	for ix in range(-n, n + 1):
		for iz in range(-n, n + 1):
			var x := ix * tile
			var z := iz * tile
			var d := Vector2(x, z).length()
			if d > outer_r + 0.1 or d < inner_r - 0.2:
				continue
			_box("%s_%d" % [node_name, idx], Vector3(tile + 0.06, 0.4, tile + 0.06), Vector3(x, top_y - 0.2, z), material)
			idx += 1


func _build_shaft_railing(prefix: String, base: float) -> void:
	var r := RING_INNER - 0.15
	var posts := 16
	for k in posts:
		var a := TAU * float(k) / posts
		# Leave a gap where the stair arrives.
		if abs(angle_diff(a, STAIR_ANGLE0)) < 0.5:
			continue
		_vcylinder(prefix + "RailPost%d" % k, 0.06, 1.0, Vector3(cos(a) * r, base + 0.5, sin(a) * r), _materials.wood_light, 6)
		var a2 := TAU * float(k + 1) / posts
		if abs(angle_diff(a2, STAIR_ANGLE0)) < 0.5:
			continue
		var mid := Vector3((cos(a) + cos(a2)) * 0.5 * r, base + 0.95, (sin(a) + sin(a2)) * 0.5 * r)
		var rail := _vbox(prefix + "Rail%d" % k, Vector3(0.08, 0.08, TAU * r / posts), mid, _materials.wood_light)
		rail.rotation.y = -(a + a2) * 0.5


func angle_diff(a: float, b: float) -> float:
	var d := fmod(a - b + PI, TAU) - PI
	return d


# ---------------------------------------------------------------------------
# Central spiral staircase
# ---------------------------------------------------------------------------

func _build_spiral(gap_index: int) -> void:
	var base := _base_y(gap_index)
	# Central newel post spanning this floor gap.
	_cylinder("Newel%d" % gap_index, NEWEL_RADIUS, FLOOR_GAP + 0.4, Vector3(0.0, base + FLOOR_GAP * 0.5, 0.0), _materials.stone_dark, 12)
	# One full turn of ramp-segment steps.
	for i in STAIR_STEPS:
		var a0 := STAIR_ANGLE0 + TAU * float(i) / STAIR_STEPS
		var a1 := STAIR_ANGLE0 + TAU * float(i + 1) / STAIR_STEPS
		var y0 := base + FLOOR_GAP * float(i) / STAIR_STEPS
		var y1 := base + FLOOR_GAP * float(i + 1) / STAIR_STEPS
		var a_pt := Vector3(cos(a0) * STAIR_RADIUS, y0, sin(a0) * STAIR_RADIUS)
		var b_pt := Vector3(cos(a1) * STAIR_RADIUS, y1, sin(a1) * STAIR_RADIUS)
		_stair_ramp("Step%d_%d" % [gap_index, i], 1.9, a_pt, b_pt, _materials.stone)
		# Outer railing post + rail following the helix.
		var ro := STAIR_RADIUS + 0.85
		var post := _vcylinder("StairPost%d_%d" % [gap_index, i], 0.05, 0.95, Vector3(cos(a0) * ro, y0 + 0.5, sin(a0) * ro), _materials.wood_light, 6)
		if i < STAIR_STEPS - 1:
			var b_ro := Vector3(cos(a1) * ro, y1, sin(a1) * ro)
			var a_ro := Vector3(cos(a0) * ro, y0, sin(a0) * ro)
			_stair_ramp("StairRail%d_%d" % [gap_index, i], 0.08, a_ro + Vector3(0, 0.95, 0), b_ro + Vector3(0, 0.95, 0), _materials.wood_light)
	# Landing wedge bridging the ring floor to the stair foot at each floor level.
	_build_landing(gap_index, base)
	if gap_index == FLOOR_COUNT - 2:
		_build_landing(gap_index, base + FLOOR_GAP)  # top arrival


func _build_landing(tag: int, y: float) -> void:
	var a := STAIR_ANGLE0
	var mid_r := (STAIR_RADIUS + RING_INNER + 0.4) * 0.5
	var pos := Vector3(cos(a) * mid_r, y - 0.15, sin(a) * mid_r)
	var landing := _box("Landing%d_%d" % [tag, int(y)], Vector3(RING_INNER + 0.6, 0.4, 1.9), pos, _materials.floor_stone)
	landing.get_parent().rotation.y = -a


func _stair_ramp(node_name: String, width: float, a_point: Vector3, b_point: Vector3, material: Material) -> StaticBody3D:
	# A short box oriented along a->b, forming one tread of the spiral ramp. The
	# chained segments give the stepless controller a continuous walkable surface.
	var body := StaticBody3D.new()
	body.name = node_name + "Body"
	var center := (a_point + b_point) * 0.5
	var diff := b_point - a_point
	var length := diff.length()
	var zax := diff / length
	var xax := Vector3.UP.cross(zax).normalized()
	var yax := zax.cross(xax).normalized()
	body.transform = Transform3D(Basis(xax, yax, zax), center)
	add_child(body)
	var size := Vector3(width, 0.3, length + 0.22)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	return body


# ---------------------------------------------------------------------------
# Ring placement helpers
# ---------------------------------------------------------------------------

func _ring_pos(base: float, angle_deg: float, radius: float, y_off: float = 0.0) -> Vector3:
	var a := deg_to_rad(angle_deg)
	return Vector3(cos(a) * radius, base + y_off, sin(a) * radius)


# ---------------------------------------------------------------------------
# Floor 1 - Entry Hall
# ---------------------------------------------------------------------------

func _build_entry_hall(floor_index: int) -> void:
	var base := _base_y(floor_index)
	var wr := WALL_RADIUS
	# Arcane-locked front door on the wall at 180 degrees (-X).
	var da := deg_to_rad(180.0)
	var dpos := Vector3(cos(da) * (wr - 0.35), base + 1.9, sin(da) * (wr - 0.35))
	_box("EntryDoorLeft", Vector3(0.3, 3.6, 1.2), dpos + Vector3(0.0, 0.0, -0.72), _materials.wood)
	_box("EntryDoorRight", Vector3(0.3, 3.6, 1.2), dpos + Vector3(0.0, 0.0, 0.72), _materials.wood)
	_vbox("EntryDoorFrame", Vector3(0.7, 4.3, 3.3), dpos + Vector3(0.1, 0.25, 0.0), _materials.wood_dark)
	# Arcane lock sigil on the room-facing (+X) side: a glowing rim + dark runed centre.
	_vcylinder("ArcaneLockRing", 0.92, 0.06, dpos + Vector3(0.45, 0.2, 0.0), _materials.glow_seal, 28).rotation_degrees.z = 90.0
	_vcylinder("ArcaneLockFace", 0.74, 0.08, dpos + Vector3(0.5, 0.2, 0.0), _materials.stone_dark, 28).rotation_degrees.z = 90.0
	_vcylinder("ArcaneLockMid", 0.42, 0.05, dpos + Vector3(0.54, 0.2, 0.0), _materials.glow_seal, 24).rotation_degrees.z = 90.0
	_vcylinder("ArcaneLockMidFace", 0.3, 0.06, dpos + Vector3(0.57, 0.2, 0.0), _materials.stone_dark, 24).rotation_degrees.z = 90.0
	for i in 6:
		var ga := TAU * float(i) / 6.0
		_vbox("ArcaneLockGlyph%d" % i, Vector3(0.05, 0.14, 0.14), dpos + Vector3(0.55, 0.2 + sin(ga) * 0.58, cos(ga) * 0.58), _materials.glow_seal)
	var lock_light := _add_mood_light("ArcaneLockLight", dpos + Vector3(1.0, 0.2, 0.0), Color(0.7, 0.3, 1.0), 1.4, 5.0, 0.18, 6.0)
	lock_light.light_volumetric_fog_energy = 2.0
	_interactable("EntryDoor_Interact", dpos + Vector3(1.4, -0.5, 0.0))

	# Talking carpet running from the door inward.
	_vbox("EntryCarpet", Vector3(4.6, 0.04, 2.2), Vector3(-2.9, base + 0.03, 0.0), _materials.carpet)
	_vbox("EntryCarpetTrim", Vector3(4.8, 0.03, 2.4), Vector3(-2.9, base + 0.02, 0.0), _materials.carpet_dark)
	for i in 3:
		_vbox("EntryCarpetMotif%d" % i, Vector3(0.5, 0.05, 0.5), Vector3(-4.2 + i * 1.3, base + 0.05, 0.0), _materials.gold_cloth).rotation_degrees.y = 45.0
	_interactable("EntryCarpet_Interact", Vector3(-3.4, base + 0.4, 0.0))

	# Staff in a glass case on a pedestal (ring, ~120 degrees).
	var spos := _ring_pos(base, 125.0, 4.6)
	_box("StaffPedestal", Vector3(1.1, 1.0, 1.1), spos + Vector3(0.0, 0.5, 0.0), _materials.stone)
	_vbox("StaffCaseGlass", Vector3(0.9, 1.7, 0.9), spos + Vector3(0.0, 1.85, 0.0), _materials.glass)
	_vbox("StaffCaseRimTop", Vector3(0.98, 0.06, 0.98), spos + Vector3(0.0, 2.7, 0.0), _materials.brass)
	_vcylinder("YoungStaffShaft", 0.05, 1.5, spos + Vector3(0.0, 1.85, 0.0), _materials.wood_light, 8)
	_vcylinder("YoungStaffCrystal", 0.16, 0.3, spos + Vector3(0.0, 2.55, 0.0), _materials.glow_blue, 6)
	_interactable("StaffCase_Interact", spos + Vector3(0.0, 1.2, -1.0) + (Vector3(0, 0, 0)))

	# Trinket shelf against the wall (~230 degrees).
	var tpos := _ring_pos(base, 232.0, wr - 0.6)
	var ta := deg_to_rad(232.0)
	var shelf := _box("TrinketShelf", Vector3(0.5, 1.8, 3.0), tpos + Vector3(0.0, 0.9, 0.0), _materials.wood)
	shelf.get_parent().rotation.y = -ta
	_vcylinder("TrinketOrb", 0.16, 0.3, tpos + Vector3(0.0, 1.35, 0.0) - Vector3(cos(ta), 0, sin(ta)) * 0.3, _materials.glow_green, 8)
	_interactable("TrinketShelf_Interact", tpos - Vector3(cos(ta), 0, sin(ta)) * 1.0 + Vector3(0, 1.2, 0))

	_add_mood_light("EntryHearth", Vector3(-2.0, base + 2.6, 2.5), Color(1.0, 0.56, 0.24), 1.4, 7.0, 0.15, 2.4)


# ---------------------------------------------------------------------------
# Floor 2 - Skully's Room
# ---------------------------------------------------------------------------

func _build_skully_room(floor_index: int) -> void:
	var base := _base_y(floor_index)
	var wr := WALL_RADIUS
	var ang := 150.0
	var ppos := _ring_pos(base, ang, wr - 1.2)
	_box("SkullyPlinth", Vector3(1.4, 1.2, 1.2), ppos + Vector3(0.0, 0.6, 0.0), _materials.stone_dark)
	_vbox("SkullyPlinthCap", Vector3(1.6, 0.12, 1.4), ppos + Vector3(0.0, 1.26, 0.0), _materials.stone)
	_build_skull("Skully", ppos + Vector3(0.0, 1.75, 0.0), 1.0)
	_interactable("Skully_Interact", ppos + Vector3(1.4, 0.9, 0.0))
	var sl := _add_mood_light("SkullyGlow", ppos + Vector3(0.7, 1.4, 0.0), Color(0.4, 1.0, 0.62), 1.2, 5.0, 0.22, 4.4)
	sl.light_volumetric_fog_energy = 1.6

	var skel := _place_glb(SKELETON_SCENE, "CornerSkeleton", _ring_pos(base, 250.0, wr - 1.2), Vector3(0.0, 35.0, 0.0), Vector3.ONE)
	skel.rotation_degrees.z = 6.0
	_candle("SkullyCandleA", ppos + Vector3(0.0, 1.4, -0.8))
	_candle("SkullyCandleB", ppos + Vector3(0.0, 1.4, 0.8))
	_box("OldArmchair", Vector3(1.3, 0.5, 1.3), _ring_pos(base, 300.0, wr - 1.6) + Vector3(0.0, 0.45, 0.0), _materials.leather)
	_vbox("SkullyRug", Vector3(3.2, 0.03, 3.0), _ring_pos(base, 210.0, 4.2) + Vector3(0.0, 0.03, 0.0), _materials.carpet_dark)


# ---------------------------------------------------------------------------
# Floor 3 - Potion Chamber
# ---------------------------------------------------------------------------

func _build_potion_chamber(floor_index: int) -> void:
	var base := _base_y(floor_index)
	var wr := WALL_RADIUS

	# Ingredient shelving curved along the wall (three arcs away from the stair).
	for ang in [130.0, 180.0, 230.0]:
		_curved_shelf(base, ang, wr)

	# Giant cauldron with a fire, on the ring toward -X.
	var cpos := _ring_pos(base, 200.0, 3.4)
	_cylinder("BigCauldronPot", 1.3, 1.4, cpos + Vector3(0.0, 1.15, 0.0), _materials.iron, 12)
	_vcylinder("BigCauldronRim", 1.4, 0.16, cpos + Vector3(0.0, 1.85, 0.0), _materials.iron, 14)
	_vcylinder("BigCauldronBrew", 1.15, 0.1, cpos + Vector3(0.0, 1.82, 0.0), _materials.glow_green, 14)
	for i in 3:
		var a := TAU * float(i) / 3.0
		_vcylinder("BigCauldronFoot%d" % i, 0.14, 0.6, cpos + Vector3(cos(a) * 0.85, 0.3, sin(a) * 0.85), _materials.iron, 6)
	_build_fire("CauldronFire", cpos + Vector3(0.0, 0.1, 0.0))
	var brew_light := _add_mood_light("BrewGlow", cpos + Vector3(0.0, 2.4, 0.0), Color(0.4, 1.0, 0.5), 1.2, 6.0, 0.24, 3.6)
	brew_light.light_volumetric_fog_energy = 1.6
	_interactable("BigCauldron_Interact", cpos + Vector3(1.7, 0.9, 0.0))

	# Brewing bench (ring, ~280 degrees).
	var bpos := _ring_pos(base, 285.0, 4.4)
	var ba := deg_to_rad(285.0)
	var bench := _box("BrewBench", Vector3(3.0, 0.24, 1.0), bpos + Vector3(0.0, 0.95, 0.0), _materials.wood)
	bench.get_parent().rotation.y = -ba
	_cylinder("BrewMortar", 0.24, 0.24, bpos + Vector3(0.0, 1.2, 0.0), _materials.stone, 10)
	_vcylinder("BrewBeakerA", 0.16, 0.34, bpos + Vector3(0.3, 1.24, 0.4), _materials.glow_blue, 8)
	_vcylinder("BrewBeakerB", 0.13, 0.28, bpos + Vector3(-0.4, 1.21, -0.3), _materials.glow_amber, 8)


func _curved_shelf(base: float, angle_deg: float, wr: float) -> void:
	var tag := int(angle_deg)
	var a := deg_to_rad(angle_deg)
	var inward := Vector3(cos(a), 0.0, sin(a))
	var pos := Vector3(cos(a) * (wr - 0.45), base, sin(a) * (wr - 0.45))
	var shelf := _box("IngShelf_%d" % tag, Vector3(0.45, 3.2, 2.6), pos + Vector3(0.0, 1.6, 0.0), _materials.wood)
	shelf.get_parent().rotation.y = -a
	for row in 4:
		var board := _vbox("IngBoard_%d_%d" % [tag, row], Vector3(0.5, 0.06, 2.5), pos + Vector3(0.0, 0.6 + row * 0.8, 0.0), _materials.wood_light)
		board.rotation.y = -a
	# Bottles.
	var tangent := Vector3(-sin(a), 0.0, cos(a))
	for i in 16:
		var row := i % 4
		var f := float(i / 4) - 1.5
		var bp := pos + Vector3(0.0, 0.9 + row * 0.8, 0.0) + tangent * (f * 0.55) - inward * 0.1
		var mat: Material = [_materials.glow_green, _materials.glow_blue, _materials.glow_amber, _materials.glow_purple][i % 4]
		_vcylinder("IngBottle_%d_%d" % [tag, i], randf_range(0.07, 0.1), randf_range(0.22, 0.32), bp, mat, 7)


# ---------------------------------------------------------------------------
# Floor 4 - Library & Spellcraft
# ---------------------------------------------------------------------------

func _build_library(floor_index: int) -> void:
	var base := _base_y(floor_index)
	var wr := WALL_RADIUS
	# Tall bookcases curved along the wall (away from the stair).
	for ang in [110.0, 150.0, 190.0, 230.0, 270.0]:
		_curved_bookcase(base, ang, wr)

	# Training dummy on the ring.
	_build_training_dummy("TrainingDummy", _ring_pos(base, 315.0, 3.8))
	_interactable("TrainingDummy_Interact", _ring_pos(base, 315.0, 3.8) + Vector3(0.0, 1.2, 0.0) + _ring_pos(0, 315.0, 1.0))

	# Spellcraft table on the ring.
	var tpos := _ring_pos(base, 190.0, 3.6)
	var tang := deg_to_rad(190.0)
	var table := _box("SpellTable", Vector3(2.4, 0.24, 1.1), tpos + Vector3(0.0, 0.95, 0.0), _materials.wood)
	table.get_parent().rotation.y = -tang
	_vbox("SpellLedger", Vector3(0.8, 0.06, 0.6), tpos + Vector3(0.0, 1.1, 0.0), _materials.paper).rotation.y = -tang
	_vcylinder("SpellFocus", 0.14, 0.4, tpos + Vector3(0.0, 1.3, 0.5), _materials.glow_blue, 6)
	_interactable("SpellTable_Interact", tpos + Vector3(0.0, 1.2, 0.0) - Vector3(cos(tang), 0, sin(tang)) * 1.2)

	var lib_light := _add_mood_light("LibraryGlow", Vector3(0.0, base + 3.2, 0.0), Color(0.5, 0.72, 0.95), 1.1, 12.0, 0.12, 3.0)
	lib_light.light_volumetric_fog_energy = 1.0


func _curved_bookcase(base: float, angle_deg: float, wr: float) -> void:
	var tag := int(angle_deg)
	var a := deg_to_rad(angle_deg)
	var pos := Vector3(cos(a) * (wr - 0.4), base, sin(a) * (wr - 0.4))
	var case := _box("Bookcase_%d" % tag, Vector3(0.45, 3.6, 2.0), pos + Vector3(0.0, 1.8, 0.0), _materials.wood_dark)
	case.get_parent().rotation.y = -a
	var tangent := Vector3(-sin(a), 0.0, cos(a))
	for row in 4:
		var board := _vbox("BookBoard_%d_%d" % [tag, row], Vector3(0.5, 0.06, 1.9), pos + Vector3(0.0, 0.7 + row * 0.82, 0.0), _materials.wood_light)
		board.rotation.y = -a
		for b in 9:
			var bh := randf_range(0.3, 0.55)
			var bp := pos + Vector3(0.0, 0.75 + row * 0.82 + bh * 0.5, 0.0) + tangent * ((b - 4) * 0.19)
			var col := Color(randf_range(0.15, 0.5), randf_range(0.08, 0.28), randf_range(0.06, 0.2))
			var book := _vbox("LibBook_%d_%d_%d" % [tag, row, b], Vector3(0.18, bh, 0.16), bp, _mat(col, 0.95))
			book.rotation.y = -a


func _build_training_dummy(node_name: String, foot: Vector3) -> void:
	_cylinder(node_name + "Post", 0.12, 2.0, foot + Vector3(0.0, 1.0, 0.0), _materials.wood, 8)
	_cylinder(node_name + "Body", 0.42, 1.0, foot + Vector3(0.0, 1.5, 0.0), _materials.burlap, 10)
	_vcylinder(node_name + "Head", 0.28, 0.4, foot + Vector3(0.0, 2.25, 0.0), _materials.burlap, 10)
	_vbox(node_name + "ArmL", Vector3(0.7, 0.16, 0.16), foot + Vector3(-0.5, 1.7, 0.0), _materials.burlap)
	_vbox(node_name + "ArmR", Vector3(0.7, 0.16, 0.16), foot + Vector3(0.5, 1.7, 0.0), _materials.burlap)
	_vbox(node_name + "Base", Vector3(0.9, 0.2, 0.9), foot + Vector3(0.0, 0.1, 0.0), _materials.wood_dark)
	_vcylinder(node_name + "Target", 0.22, 0.02, foot + Vector3(0.0, 1.55, 0.44), _materials.glow_seal, 12).rotation_degrees.x = 90.0


# ---------------------------------------------------------------------------
# Floor 5 - Scrying Room
# ---------------------------------------------------------------------------

func _build_scrying_room(floor_index: int) -> void:
	var base := _base_y(floor_index)
	var wr := WALL_RADIUS

	# Scrying orb on a stand (ring toward -X, off the central shaft).
	var opos := _ring_pos(base, 200.0, 3.6)
	_cylinder("ScryStand", 0.7, 1.0, opos + Vector3(0.0, 0.5, 0.0), _materials.stone_dark, 10)
	_vcylinder("ScryStandCup", 0.75, 0.24, opos + Vector3(0.0, 1.05, 0.0), _materials.brass, 12)
	_sphere("ScryOrb", 0.62, opos + Vector3(0.0, 1.75, 0.0), _materials.glow_scry)
	var orb_light := _add_mood_light("ScryOrbGlow", opos + Vector3(0.0, 1.9, 0.0), Color(0.5, 0.72, 1.0), 1.6, 6.5, 0.2, 2.6)
	orb_light.light_volumetric_fog_energy = 1.8
	_interactable("ScryOrb_Interact", opos + Vector3(1.6, 0.9, 0.0))

	# Kingdom window on the wall (~135 degrees).
	var wa := deg_to_rad(135.0)
	var wpos := Vector3(cos(wa) * (wr - 0.2), base + 2.4, sin(wa) * (wr - 0.2))
	var glow := _vbox("KingdomWindowGlow", Vector3(0.1, 3.0, 4.2), wpos, _materials.night_sky)
	glow.rotation.y = -wa
	var sill := _vbox("KingdomWindowSill", Vector3(0.7, 0.3, 4.6), wpos + Vector3(0.0, -1.5, 0.0), _materials.stone_dark)
	sill.rotation.y = -wa
	var arch := _vbox("KingdomWindowArchTop", Vector3(0.7, 0.4, 4.6), wpos + Vector3(0.0, 1.6, 0.0), _materials.stone_dark)
	arch.rotation.y = -wa
	_build_kingdom_vista(base, wa)
	_interactable("KingdomWindow_Interact", wpos + Vector3(0.0, -0.9, 0.0) - Vector3(cos(wa), 0, sin(wa)) * 1.2)

	# Empty courier cage near the window.
	var cpos := _ring_pos(base, 100.0, 4.4)
	_box("QuestCageBase", Vector3(1.2, 0.2, 1.2), cpos + Vector3(0.0, 0.6, 0.0), _materials.wood_dark)
	for i in 8:
		var a := TAU * float(i) / 8.0
		_vcylinder("QuestCageBar%d" % i, 0.03, 1.7, cpos + Vector3(cos(a) * 0.55, 1.55, sin(a) * 0.55), _materials.iron, 6)
	_vcylinder("QuestCageTop", 0.6, 0.16, cpos + Vector3(0.0, 2.45, 0.0), _materials.iron, 8)
	_vbox("QuestCagePerch", Vector3(0.7, 0.05, 0.05), cpos + Vector3(0.0, 1.4, 0.0), _materials.wood_light)
	_interactable("QuestCage_Interact", cpos + Vector3(0.0, 1.2, -1.2))


func _build_kingdom_vista(base: float, wall_angle: float) -> void:
	var vista := Node3D.new()
	vista.name = "KingdomVista"
	vista.position = Vector3(cos(wall_angle) * (WALL_RADIUS + 16.0), base - 6.0, sin(wall_angle) * (WALL_RADIUS + 16.0))
	add_child(vista)
	_place_glb_to(vista, CASTLE_WALL_SCENE, "KVWall", Vector3(-3.0, 0.0, -2.0), Vector3.ZERO, Vector3.ONE * 1.6)
	_place_glb_to(vista, CASTLE_TOWER_SCENE, "KVTower", Vector3(0.0, 0.0, 0.0), Vector3.ZERO, Vector3.ONE * 2.0)
	_place_glb_to(vista, CASTLE_TOWER_TOP_SCENE, "KVTowerTop", Vector3(0.0, 5.4, 0.0), Vector3.ZERO, Vector3.ONE * 2.0)
	_place_glb_to(vista, CASTLE_TOWER_SCENE, "KVTower2", Vector3(5.5, 0.0, -3.0), Vector3.ZERO, Vector3.ONE * 1.6)
	_place_glb_to(vista, TOWN_ROOF_SCENE, "KVRoofA", Vector3(-6.0, 0.0, 2.0), Vector3.ZERO, Vector3.ONE * 1.4)
	_place_glb_to(vista, TOWN_TREE_SCENE, "KVTree", Vector3(-8.0, 0.0, 4.0), Vector3.ZERO, Vector3.ONE * 1.5)


# ---------------------------------------------------------------------------
# Shared prop builders
# ---------------------------------------------------------------------------

func _build_skull(node_name: String, center: Vector3, s: float) -> void:
	_sphere(node_name + "Cranium", 0.34 * s, center + Vector3(0.0, 0.08 * s, 0.0), _materials.bone)
	_vbox(node_name + "Jaw", Vector3(0.5 * s, 0.18 * s, 0.42 * s), center + Vector3(0.0, -0.24 * s, 0.06 * s), _materials.bone)
	_vsphere(node_name + "EyeL", 0.11 * s, center + Vector3(-0.14 * s, 0.05 * s, 0.28 * s), _materials.glow_green)
	_vsphere(node_name + "EyeR", 0.11 * s, center + Vector3(0.14 * s, 0.05 * s, 0.28 * s), _materials.glow_green)


func _build_fire(node_name: String, base_pos: Vector3) -> void:
	for i in 6:
		var a := TAU * float(i) / 6.0
		_vbox(node_name + "Log%d" % i, Vector3(0.16, 0.16, 0.7), base_pos + Vector3(cos(a) * 0.35, 0.1, sin(a) * 0.35), _materials.wood_dark).rotation_degrees.y = rad_to_deg(a)
	for i in 5:
		var a := randf_range(0.0, TAU)
		var r := randf_range(0.0, 0.4)
		var h := randf_range(0.4, 0.9)
		_vcylinder(node_name + "Flame%d" % i, 0.14, h, base_pos + Vector3(cos(a) * r, 0.3 + h * 0.4, sin(a) * r), _materials.glow_fire, 5)
	var fl := _add_mood_light(node_name + "Light", base_pos + Vector3(0.0, 0.6, 0.0), Color(1.0, 0.5, 0.16), 2.2, 5.5, 0.4, 8.0)
	fl.light_volumetric_fog_energy = 2.0


func _candle(node_name: String, position: Vector3) -> void:
	_vcylinder(node_name + "Stick", 0.06, 0.34, position, _materials.wax, 7)
	_vcylinder(node_name + "Flame", 0.045, 0.13, position + Vector3(0.0, 0.24, 0.0), _materials.glow_fire, 5)
	var cl := _add_mood_light(node_name + "Light", position + Vector3(0.0, 0.3, 0.0), Color(1.0, 0.6, 0.24), 0.7, 3.4, 0.3, 6.5)
	cl.light_volumetric_fog_energy = 1.4


func _interact_content(node_name: String) -> Dictionary:
	match node_name:
		"EntryDoor_Interact":
			return {"prompt": "Examine the door", "lines": [
				{"who": "", "say": "The great door will not move. A sigil of binding crawls across the frame, pulsing when you touch it."},
				{"who": "(memory)", "say": "The hand that drew this seal was yours. You locked yourself IN. You just cannot remember why."},
			]}
		"EntryCarpet_Interact":
			return {"prompt": "Talk to the carpet", "lines": [
				{"who": "Carpet", "say": "Oh. You're awake. Do you have any idea how long I've endured your feet?"},
				{"who": "Carpet", "say": "Decades. DECADES of stinky old wizard feet. Not one 'thank you, carpet.' Not one wash."},
				{"who": "Carpet", "say": "...You don't remember me at all, do you. Huh. That's new. Bit rude, honestly."},
			]}
		"StaffCase_Interact":
			return {"prompt": "Examine the staff", "lines": [
				{"who": "", "say": "A traveling staff sealed under dusty glass, its crystal long gone dark."},
				{"who": "(memory)", "say": "You remember rain. A road. A younger man who had not yet decided to vanish into a tower. That was you, before all this."},
			]}
		"TrinketShelf_Interact":
			return {"prompt": "Examine the trinkets", "lines": [
				{"who": "", "say": "A cracked focus, a bottled spark, a locket you cannot place. Small pieces of a life just out of reach."},
			]}
		"Skully_Interact":
			return {"prompt": "Talk to Skully", "lines": [
				{"who": "Skully", "say": "Well, well. The great sorcerer, risen from his nap. You look terrible. And confused. More than usual."},
				{"who": "Skully", "say": "A hint? Fine, since you're pathetic about it. The door's sealed from the INSIDE, genius. You did it. Work out why and maybe it opens."},
				{"who": "Skully", "say": "That's your lot. I'm a skull, not a charity."},
			]}
		"BigCauldron_Interact":
			return {"prompt": "Examine the cauldron", "lines": [
				{"who": "", "say": "Cold iron and old smoke. Yet your hands already know the stir and the pour, even if the names are gone."},
			]}
		"TrainingDummy_Interact":
			return {"prompt": "Examine the dummy", "lines": [
				{"who": "", "say": "A straw dummy, scorched in a dozen places. Something in you itches to test a spell on it again."},
			]}
		"SpellTable_Interact":
			return {"prompt": "Examine the spell table", "lines": [
				{"who": "", "say": "A ledger of half-finished spellwork. The ink is fresh - your own handwriting."},
				{"who": "(memory)", "say": "You were building toward something in the days before you forgot. Or hiding from it."},
			]}
		"ScryOrb_Interact":
			return {"prompt": "Gaze into the orb", "lines": [
				{"who": "", "say": "The orb clouds, then clears. For a heartbeat you glimpse torch-lit walls far below - the kingdom. Then it goes dark. Not yet."},
			]}
		"KingdomWindow_Interact":
			return {"prompt": "Look out the window", "lines": [
				{"who": "", "say": "Beyond the glass the kingdom sprawls under a bruised sky. You should know its name. You don't."},
			]}
		"QuestCage_Interact":
			return {"prompt": "Examine the cage", "lines": [
				{"who": "", "say": "An empty cage by the window, its perch worn smooth. Something used to land here bearing letters. Work, perhaps. It will come."},
			]}
	return {"prompt": "Examine", "lines": [{"who": "", "say": "Nothing of note."}]}


func _interactable(node_name: String, position: Vector3) -> void:
	var content := _interact_content(node_name)
	_interactables.append({
		"name": node_name,
		"pos": position,
		"prompt": content.get("prompt", "Examine"),
		"lines": content.get("lines", []),
	})


# ---------------------------------------------------------------------------
# Environment / lighting
# ---------------------------------------------------------------------------

func _setup_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	# Mystical, luminous mood: deep-indigo base, bright violet ambient, vivid grade.
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.09, 0.08, 0.16)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.34, 0.32, 0.5)
	environment.ambient_light_energy = 1.25
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 1.2
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.08
	environment.adjustment_contrast = 1.0
	environment.adjustment_saturation = 1.14
	environment.glow_enabled = true
	environment.glow_intensity = 0.65
	environment.glow_strength = 0.95
	environment.glow_bloom = 0.15
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	environment.glow_hdr_threshold = 1.15
	environment.set_glow_level(2, 1.0)
	environment.set_glow_level(3, 1.0)
	environment.set_glow_level(4, 0.7)
	environment.set_glow_level(5, 0.4)
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.42, 0.4, 0.66)
	environment.fog_light_energy = 0.28
	environment.fog_density = 0.006
	environment.volumetric_fog_enabled = false
	environment.ssao_enabled = true
	environment.ssao_radius = 0.6
	environment.ssao_intensity = 1.6
	world_environment.environment = environment
	add_child(world_environment)


func _fill_light(node_name: String, position: Vector3, color: Color, energy: float, range_value: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.omni_attenuation = 1.0
	light.shadow_enabled = false
	add_child(light)
	return light


func _add_mood_light(node_name: String, position: Vector3, color: Color, energy: float, range_value: float, flicker_strength: float, flicker_speed: float) -> OmniLight3D:
	var light := MOOD_LIGHT_SCRIPT.new() as OmniLight3D
	light.name = node_name
	light.position = position
	light.light_color = color
	light.base_energy = energy
	light.light_energy = energy
	light.omni_range = range_value
	light.flicker_strength = flicker_strength
	light.flicker_speed = flicker_speed
	light.pulse_offset = randf_range(0.0, TAU)
	light.shadow_enabled = true
	add_child(light)
	return light


# ---------------------------------------------------------------------------
# HUD + interaction
# ---------------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)

	_floor_label = Label.new()
	_floor_label.name = "FloorLabel"
	_floor_label.position = Vector2(24, 20)
	_floor_label.add_theme_font_size_override("font_size", 22)
	_floor_label.add_theme_color_override("font_color", Color(0.8, 0.78, 0.95))
	_floor_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_floor_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_floor_label)

	_interact_label = Label.new()
	_interact_label.name = "InteractLabel"
	_interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_label.anchor_left = 0.0
	_interact_label.anchor_right = 1.0
	_interact_label.anchor_top = 0.6
	_interact_label.add_theme_font_size_override("font_size", 22)
	_interact_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	_interact_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_interact_label.add_theme_constant_override("outline_size", 6)
	_interact_label.text = ""
	layer.add_child(_interact_label)

	_build_dialogue_panel(layer)


func _build_dialogue_panel(layer: CanvasLayer) -> void:
	_dlg_panel = PanelContainer.new()
	_dlg_panel.name = "DialoguePanel"
	_dlg_panel.anchor_left = 0.1
	_dlg_panel.anchor_right = 0.9
	_dlg_panel.anchor_top = 0.74
	_dlg_panel.anchor_bottom = 0.93
	_dlg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.9)
	style.border_color = Color(0.5, 0.42, 0.8, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	_dlg_panel.add_theme_stylebox_override("panel", style)
	layer.add_child(_dlg_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_dlg_panel.add_child(vbox)

	_dlg_speaker = Label.new()
	_dlg_speaker.add_theme_font_size_override("font_size", 20)
	_dlg_speaker.add_theme_color_override("font_color", Color(0.75, 0.68, 1.0))
	vbox.add_child(_dlg_speaker)

	_dlg_text = Label.new()
	_dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dlg_text.custom_minimum_size = Vector2(0, 70)
	_dlg_text.add_theme_font_size_override("font_size", 19)
	_dlg_text.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
	vbox.add_child(_dlg_text)

	var hint := Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.text = "[ E ]  continue"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.58, 0.72))
	vbox.add_child(hint)


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate()
	_player.name = "WizardPlayer"
	_player.position = Vector3(-2.0, 1.0, 0.0)
	_player.rotation_degrees.y = 90.0  # face the front door (-X)
	add_child(_player)
	_camera = _player.get_node("Head/Camera3D") as Camera3D


func _physics_process(_delta: float) -> void:
	if not _player:
		return
	_current_floor = clampi(int(round((_player.global_position.y - 1.0) / FLOOR_GAP)), 0, FLOOR_COUNT - 1)
	_focused = _find_focused_interactable()
	if _floor_label:
		_floor_label.text = "Floor  " + FLOOR_NAMES[_current_floor]
	if _interact_label:
		_interact_label.text = "" if (_dialogue_active or _focused.is_empty()) else "[ E ]  %s" % _focused.get("prompt", "Examine")


func _find_focused_interactable() -> Dictionary:
	if not _camera or _dialogue_active:
		return {}
	var eye := _camera.global_position
	var fwd := -_camera.global_transform.basis.z
	var best := {}
	var best_dot := 0.72
	for it in _interactables:
		var to: Vector3 = it["pos"] - eye
		var dist := to.length()
		if dist > 3.4 or dist < 0.05:
			continue
		var dot := (to / dist).dot(fwd)
		if dot > best_dot:
			best_dot = dot
			best = it
	return best


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_E:
		if _dialogue_active:
			_advance_dialogue()
		elif not _focused.is_empty():
			_start_dialogue(_focused)


func _start_dialogue(interactable: Dictionary) -> void:
	_dialogue_lines = interactable.get("lines", [])
	if _dialogue_lines.is_empty():
		return
	_dialogue_active = true
	_dialogue_index = 0
	_dlg_panel.visible = true
	_show_dialogue_line()


func _advance_dialogue() -> void:
	_dialogue_index += 1
	if _dialogue_index >= _dialogue_lines.size():
		_dialogue_active = false
		_dlg_panel.visible = false
		return
	_show_dialogue_line()


func _show_dialogue_line() -> void:
	var line: Dictionary = _dialogue_lines[_dialogue_index]
	var who: String = line.get("who", "")
	if who == "(memory)":
		_dlg_speaker.text = "a memory surfaces..."
		_dlg_speaker.add_theme_color_override("font_color", Color(0.55, 0.8, 1.0))
		_dlg_text.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	elif who == "":
		_dlg_speaker.text = ""
		_dlg_text.add_theme_color_override("font_color", Color(0.88, 0.88, 0.85))
	else:
		_dlg_speaker.text = who
		_dlg_speaker.add_theme_color_override("font_color", Color(0.75, 0.68, 1.0))
		_dlg_text.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
	_dlg_text.text = line.get("say", "")


# ---------------------------------------------------------------------------
# Materials + primitive helpers
# ---------------------------------------------------------------------------

func _make_materials() -> void:
	_materials.stone = _mat(Color(0.28, 0.28, 0.34), 0.95)
	_materials.stone_dark = _mat(Color(0.14, 0.14, 0.18), 1.0)
	_materials.floor_stone = _mat(Color(0.22, 0.21, 0.26), 0.92)
	_materials.wood = _mat(Color(0.2, 0.12, 0.07), 0.9)
	_materials.wood_light = _mat(Color(0.32, 0.2, 0.11), 0.85)
	_materials.wood_dark = _mat(Color(0.12, 0.07, 0.04), 0.92)
	_materials.paper = _mat(Color(0.6, 0.52, 0.37), 0.97)
	_materials.wax = _mat(Color(0.78, 0.55, 0.28), 0.7)
	_materials.brass = _mat(Color(0.62, 0.45, 0.2), 0.5, 0.6)
	_materials.iron = _mat(Color(0.09, 0.095, 0.1), 0.6, 0.7)
	_materials.leather = _mat(Color(0.22, 0.1, 0.05), 0.9)
	_materials.bone = _mat(Color(0.78, 0.74, 0.62), 0.85)
	_materials.burlap = _mat(Color(0.5, 0.4, 0.24), 0.98)
	_materials.carpet = _mat(Color(0.36, 0.08, 0.12), 0.98)
	_materials.carpet_dark = _mat(Color(0.18, 0.04, 0.08), 0.98)
	_materials.gold_cloth = _mat(Color(0.6, 0.46, 0.18), 0.8, 0.3)
	_materials.glass = _glass_mat(Color(0.6, 0.75, 0.85, 0.16))
	_materials.night_sky = _emissive_mat(Color(0.18, 0.24, 0.44), 0.7)
	_materials.glow_seal = _emissive_mat(Color(0.85, 0.35, 1.0), 0.8)
	_materials.glow_green = _emissive_mat(Color(0.35, 0.95, 0.54), 1.3)
	_materials.glow_blue = _emissive_mat(Color(0.3, 0.55, 0.98), 1.3)
	_materials.glow_amber = _emissive_mat(Color(1.0, 0.62, 0.2), 1.3)
	_materials.glow_purple = _emissive_mat(Color(0.7, 0.35, 0.95), 1.3)
	_materials.glow_fire = _emissive_mat(Color(1.0, 0.5, 0.16), 1.9)
	_materials.glow_scry = _emissive_mat(Color(0.5, 0.72, 1.0), 1.3)


func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var v := randf_range(-0.02, 0.02)
	m.albedo_color = Color(clampf(color.r + v, 0, 1), clampf(color.g + v, 0, 1), clampf(color.b + v, 0, 1), color.a)
	m.roughness = roughness
	m.metallic = metallic
	return m


func _emissive_mat(color: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(color, 0.5)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _glass_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.0
	return m


func _place_glb(scene: PackedScene, node_name: String, position: Vector3, rot: Vector3, scale: Vector3) -> Node3D:
	return _place_glb_to(self, scene, node_name, position, rot, scale)


func _place_glb_to(parent: Node, scene: PackedScene, node_name: String, position: Vector3, rot: Vector3, scale: Vector3) -> Node3D:
	var inst := scene.instantiate() as Node3D
	inst.name = node_name
	inst.position = position
	inst.rotation_degrees = rot
	inst.scale = scale
	parent.add_child(inst)
	return inst


func _box(node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var body := StaticBody3D.new()
	body.name = node_name + "Body"
	body.position = position
	add_child(body)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	return mi


func _cylinder(node_name: String, radius: float, height: float, position: Vector3, material: Material, sides: int) -> MeshInstance3D:
	var body := StaticBody3D.new()
	body.name = node_name + "Body"
	body.position = position
	add_child(body)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = material
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	body.add_child(col)
	return mi


func _vbox(node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = position
	mi.material_override = material
	add_child(mi)
	return mi


func _vcylinder(node_name: String, radius: float, height: float, position: Vector3, material: Material, sides: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	mi.mesh = mesh
	mi.position = position
	mi.material_override = material
	add_child(mi)
	return mi


func _sphere(node_name: String, radius: float, position: Vector3, material: Material) -> MeshInstance3D:
	var body := StaticBody3D.new()
	body.name = node_name + "Body"
	body.position = position
	add_child(body)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mi.mesh = mesh
	mi.material_override = material
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	col.shape = shape
	body.add_child(col)
	return mi


func _vsphere(node_name: String, radius: float, position: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mi.mesh = mesh
	mi.position = position
	mi.material_override = material
	add_child(mi)
	return mi
