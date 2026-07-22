class_name MagicalBinding
extends Node3D

## A Bind between two subjects, rendered in Wizard Sight as a hanging strand.
## The strand is a real aimable object with an identity - Sever can only target
## a thread Sight renders (game-bible.md, "The casting sentence") - not a
## particle effect.
##
## The strand runs from anchor A (the fed end - usually an ElementSource) to
## anchor B (the consumer). While powered it glows in the element's color with
## a pulse travelling A to B, reading as "B drinks from A". Starved, it hangs
## ashen. Solid where visible, a faint dashed ghost through geometry, so long
## threads can be followed behind walls but reward the chase.
##
## Reading is the resonance attunement minigame: begin attunement, then strike
## (cast press) as the bright read-pulse crosses the window at the midpoint.
## Enough clean beats and the working yields its fact, which inks itself into
## JournalFacts and materialises as an inscription IN THE WORLD beside the
## strand - the way all Wizard Sight information is read. requires_fact gates
## whether Sight renders the strand at all - every thread on screen was earned.

const GROUP := &"magical_binding"
const SEGMENTS := 20
const ASHEN := Color(0.5, 0.52, 0.58)
const INSCRIPTION_FONT := "res://assets/fonts/alegreya/Alegreya-Variable.ttf"
const HIT_SOUND := "res://assets/sounds/attune_hit.wav"
const MISS_SOUND := "res://assets/sounds/attune_miss.wav"

enum StrikeResult { MISS, HIT, COMPLETED }

signal powered_changed(powered: bool)
signal analyzed(binding: MagicalBinding)

@export var anchor_a: NodePath
@export var anchor_a_offset := Vector3.ZERO
@export var anchor_b: NodePath
@export var anchor_b_offset := Vector3.ZERO
## Optional ElementSource whose fullness powers the binding (often anchor A).
## With no power source the binding is intrinsically powered.
@export var power_source: NodePath
## Optional node held sealed - must expose set_sealed(bool).
@export var sealed_target: NodePath
## When true the starving bind holds its target sealed and feeding the power
## source opens the way (the tower door). When false the powered bind seals.
@export var sealed_while_starved := true
## Author the power source empty at ready (Case Minus One's dark lantern).
@export var drain_source_on_ready := false
@export var element: Element
## Journal fact granted when the strand is read.
@export var fact_id: StringName = &""
## Journal fact required before Sight renders this strand at all.
@export var requires_fact: StringName = &""
## Journal text inscribed in the world when the strand is read.
@export_multiline var description := ""
## How hard the strand sags, as a fraction of its span.
@export var sag := 0.16

@export_group("Attunement")
## Seconds the read-pulse takes to travel the strand once.
@export var attune_period := 1.4
## Where along the strand (0-1) the resonance window sits.
@export var attune_window_center := 0.55
## Width of the resonance window in strand-phase units.
@export var attune_window_width := 0.16
## Clean beats required to read the working.
@export var attune_beats_needed := 3

var _node_a: Node3D
var _node_b: Node3D
var _source: ElementSource
var _sealed_node: Node
var _fade := 0.0
var _fade_target := 0.0
var _ash := 0.0
var _ash_tween: Tween
var _time := 0.0
var _locally_analyzed := false
var _solid_mesh: ImmediateMesh
var _ghost_mesh: ImmediateMesh
var _attuning := false
var _attune_phase := 0.0
var _attune_hits := 0
var _label: Label3D
var _label_alpha := 0.0
var _label_hold := 0.0
var _aimed_in_sight := false
var _beat_audio: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group(GROUP)
	_node_a = get_node_or_null(anchor_a) as Node3D
	_node_b = get_node_or_null(anchor_b) as Node3D
	_source = get_node_or_null(power_source) as ElementSource
	_sealed_node = get_node_or_null(sealed_target)
	if _source != null and drain_source_on_ready:
		_source.deplete_silently()
	if _source != null:
		_source.consumed.connect(_on_starved)
		_source.restored.connect(_on_rekindled)
	_ash = 0.0 if is_powered() else 1.0
	_build_strand_meshes()
	_build_label()
	# The door may bind its imported visual after us; seal once the tree settles.
	_apply_seal.call_deferred()


func is_powered() -> bool:
	return _source == null or _source.available()


func is_analyzed() -> bool:
	if fact_id != &"":
		return JournalFacts.knows(fact_id)
	return _locally_analyzed


## True when Sight is allowed to render and aim this strand.
func sight_relevant() -> bool:
	return JournalFacts.satisfied(requires_fact)


func endpoint_a() -> Vector3:
	return _node_a.to_global(anchor_a_offset) if _node_a != null else global_position


func endpoint_b() -> Vector3:
	return _node_b.to_global(anchor_b_offset) if _node_b != null else global_position


## The Sight aim point: the strand's visual centre, sag included.
func midpoint() -> Vector3:
	var from := endpoint_a()
	var to := endpoint_b()
	return _bezier(from, _control_point(from, to), to, 0.5)


func marker_color() -> Color:
	if is_powered() and element != null:
		return element.color
	return ASHEN


## Sight broadcasts its hold state; the strand fades with the grade.
func set_sight_visible(visible_in_sight: bool) -> void:
	_fade_target = 1.0 if visible_in_sight and sight_relevant() else 0.0
	if not visible_in_sight:
		end_attunement()
		_aimed_in_sight = false


## Sight reports whether this strand is the aimed target (drives the
## inscription's visibility once the working has been read).
func set_aimed(aimed: bool) -> void:
	_aimed_in_sight = aimed


## --- Reading: the resonance attunement minigame ---

func begin_attunement() -> void:
	if is_analyzed() or _attuning:
		return
	_attuning = true
	_attune_phase = 0.0
	_attune_hits = 0


func end_attunement() -> void:
	_attuning = false
	_attune_hits = 0


func is_attuning() -> bool:
	return _attuning


func attunement_phase() -> float:
	return _attune_phase


func attunement_progress() -> float:
	return float(_attune_hits) / maxf(float(attune_beats_needed), 1.0)


func is_phase_in_window() -> bool:
	return absf(_attune_phase - attune_window_center) <= attune_window_width * 0.5


## A cast press during attunement. Strike as the read-pulse crosses the
## resonance window; a miss loses the rhythm and the streak resets.
func strike() -> StrikeResult:
	if not _attuning:
		return StrikeResult.MISS
	if is_phase_in_window():
		_attune_hits += 1
		_play_beat(true)
		if _attune_hits >= attune_beats_needed:
			end_attunement()
			analyze()
			return StrikeResult.COMPLETED
		return StrikeResult.HIT
	_attune_hits = 0
	_play_beat(false)
	return StrikeResult.MISS


## The working yields: ink the fact and raise the world inscription.
func analyze() -> void:
	if is_analyzed():
		return
	_locally_analyzed = true
	JournalFacts.learn(fact_id)
	_reveal_inscription()
	analyzed.emit(self)


func _on_starved() -> void:
	powered_changed.emit(false)
	# Ash spreads from the dead source toward the consumer; the seal state
	# only flips when the last of the flame gutters out at the far end.
	_tween_ash(1.0, 0.5, _apply_seal)


func _on_rekindled() -> void:
	powered_changed.emit(true)
	# Feeding is the payoff beat: flame races down the strand, then the way
	# answers - ignite first, flip the seal when the light arrives.
	_tween_ash(0.0, 0.4, _apply_seal)


func _tween_ash(target: float, duration: float, finished: Callable) -> void:
	if _ash_tween != null and _ash_tween.is_valid():
		_ash_tween.kill()
	_ash_tween = create_tween()
	_ash_tween.tween_property(self, "_ash", target, duration)
	if not finished.is_null():
		_ash_tween.tween_callback(finished)


func _apply_seal() -> void:
	if _sealed_node == null or not _sealed_node.has_method(&"set_sealed"):
		return
	var sealed := not is_powered() if sealed_while_starved else is_powered()
	_sealed_node.call(&"set_sealed", sealed)


func _play_beat(hit: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _beat_audio == null:
		_beat_audio = AudioStreamPlayer3D.new()
		_beat_audio.bus = &"SpellCast"
		add_child(_beat_audio)
	_beat_audio.global_position = midpoint()
	_beat_audio.stream = load(HIT_SOUND if hit else MISS_SOUND)
	_beat_audio.pitch_scale = 1.0 + 0.12 * float(_attune_hits) if hit else 1.0
	_beat_audio.play()


## --- The world inscription: how Sight information is read ---

func _build_label() -> void:
	_label = Label3D.new()
	_label.text = description
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = false
	_label.pixel_size = 0.0011
	_label.font = load(INSCRIPTION_FONT)
	_label.font_size = 40
	_label.outline_size = 14
	_label.modulate = Color(0.93, 0.87, 0.72, 0.0)
	_label.outline_modulate = Color(0.05, 0.03, 0.02, 0.0)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.width = 340.0
	_label.top_level = true
	add_child(_label)


func _reveal_inscription() -> void:
	if _label == null:
		return
	_label.text = ""
	_label_hold = 4.5
	# Label3D has no visible_ratio; ink the text in character by character.
	var ink := create_tween()
	ink.tween_method(_set_ink_progress, 0.0, 1.0, 1.2)


func _set_ink_progress(progress: float) -> void:
	if _label != null:
		_label.text = description.substr(0, int(round(description.length() * progress)))


func _update_label(delta: float) -> void:
	if _label == null:
		return
	var show := false
	if _label_hold > 0.0:
		_label_hold -= delta
		show = true
	elif is_analyzed() and _aimed_in_sight and _fade > 0.3:
		show = true
		_label.text = description
	_label_alpha = move_toward(_label_alpha, 1.0 if show else 0.0, delta / 0.25)
	_label.visible = _label_alpha > 0.01
	if not _label.visible:
		return
	_label.modulate.a = _label_alpha * 0.95
	_label.outline_modulate.a = _label_alpha * 0.9
	var camera := get_viewport().get_camera_3d()
	var beside := Vector3.UP * 0.12
	if camera != null:
		beside += camera.global_transform.basis.x * 0.55
	_label.global_position = midpoint() + beside


func _build_strand_meshes() -> void:
	_solid_mesh = ImmediateMesh.new()
	_ghost_mesh = ImmediateMesh.new()
	for config: Array in [[_solid_mesh, false], [_ghost_mesh, true]]:
		var instance := MeshInstance3D.new()
		instance.mesh = config[0]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.disable_receive_shadows = true
		material.no_depth_test = config[1]
		instance.material_override = material
		add_child(instance)
		instance.top_level = true
		instance.global_transform = Transform3D.IDENTITY


func _process(delta: float) -> void:
	_time += delta
	if _attuning:
		_attune_phase = fmod(_attune_phase + delta / maxf(attune_period, 0.05), 1.0)
	_fade = move_toward(_fade, _fade_target, delta / 0.18)
	_update_label(delta)
	if _fade <= 0.005:
		_solid_mesh.clear_surfaces()
		_ghost_mesh.clear_surfaces()
		return
	var from := endpoint_a()
	var to := endpoint_b()
	if from.distance_to(to) < 0.05:
		return
	var control := _control_point(from, to)
	_rebuild(_solid_mesh, from, control, to, 1.0, false)
	_rebuild(_ghost_mesh, from, control, to, 0.16, true)


func _control_point(from: Vector3, to: Vector3) -> Vector3:
	var span := to - from
	return (from + to) * 0.5 + Vector3.DOWN * clampf(span.length() * sag, 0.05, 0.9)


func _rebuild(
	mesh: ImmediateMesh,
	from: Vector3,
	control: Vector3,
	to: Vector3,
	alpha_scale: float,
	dashed: bool,
) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var powered := is_powered()
	var base := element.color if element != null else Color.WHITE
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in SEGMENTS + 1:
		var t := float(index) / SEGMENTS
		var point := _bezier(from, control, to, t)
		var tangent := _bezier(from, control, to, minf(t + 0.05, 1.0)) - point
		var view := camera.global_position - point
		var across := tangent.cross(view)
		across = across.normalized() if across.length() > 0.001 else Vector3.UP
		# The ash wipe travels A to B when the source dies (and back on feed).
		var ashen := t < _ash - 0.02 or _ash >= 1.0
		var color := ASHEN if ashen else base
		var glow := 0.5
		if powered and not ashen:
			# The pulse runs toward the drinker - direction is information.
			glow = 0.55 + 0.45 * maxf(0.0, sin(TAU * (t * 2.5 - _time * 1.3)))
		if _attuning:
			# The read-pulse comet, and a steady shimmer at the window.
			glow += 2.2 * exp(-pow((t - _attune_phase) * 9.0, 2.0))
			if absf(t - attune_window_center) <= attune_window_width * 0.5:
				glow += 0.5
		var alpha := _fade * alpha_scale * clampf(0.5 + 0.5 * glow, 0.0, 1.0)
		if dashed and int(t * SEGMENTS) % 4 >= 2:
			alpha = 0.0
		var width := 0.014 + 0.01 * minf(glow, 2.0)
		var final := Color(color.r * (0.8 + glow), color.g * (0.8 + glow),
			color.b * (0.8 + glow), alpha)
		mesh.surface_set_color(final)
		mesh.surface_add_vertex(point + across * width)
		mesh.surface_set_color(final)
		mesh.surface_add_vertex(point - across * width)
	mesh.surface_end()


func _bezier(a: Vector3, control: Vector3, b: Vector3, t: float) -> Vector3:
	return a.lerp(control, t).lerp(control.lerp(b, t), t)
