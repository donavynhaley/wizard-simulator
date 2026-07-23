class_name MagicalLink
extends Node3D

## A live magical link binding two LinkAnchors, rendered in Wizard Sight as a
## hanging strand. The strand is a real aimable object with an identity - Sever
## can only target a thread Sight renders (game-bible.md) - not a particle effect.
##
## A link is four ingredients: two anchors, the element flowing through it, and a
## pluggable LinkEffect that decides what the connection DOES. Authored links set
## their anchors and effect in the scene; player-built links are assembled by the
## LinkForge from whatever the wizard connects. Either way this class only renders
## the strand, runs the reading minigame, tracks power, and forwards power changes
## to the effect - it never hardcodes a behaviour.
##
## Power comes from the fount anchor (the one carrying an ElementSource): while it
## holds its element the link is powered; siphon it and the link starves. The
## effect is told set_active(powered) on every flip, and on_removed() when severed.
##
## Reading is the resonance attunement minigame: strike (cast press) as the comet
## threads the gate ring; enough clean beats and the working yields its fact and
## an inscription in the world. Player-built links are self-evidently known, so
## they skip reading and simply show their inscription when aimed.

const GROUP := &"magical_link"
const SEGMENTS := 20
const ASHEN := Color(0.5, 0.52, 0.58)
const INSCRIPTION_FONT := "res://assets/fonts/alegreya/Alegreya-Variable.ttf"
const BURST_SCENE := preload("res://game/spellcraft/elements/siphon_burst.tscn")
## Chord-building strikes: root, root+fifth, full resolve.
const HIT_SOUNDS: Array[String] = [
	"res://assets/sounds/attune_hit_1.wav",
	"res://assets/sounds/attune_hit_2.wav",
	"res://assets/sounds/attune_hit_3.wav",
]
const MISS_SOUND := "res://assets/sounds/attune_miss.wav"
const HUM_SOUND := "res://assets/sounds/attune_hum.wav"
const QUILL_SOUND := "res://assets/sounds/quill_scratch.wav"
## A metronome tick on every comet pass through the gate - the pulse you time to.
const PULSE_SOUND := "res://assets/sounds/attune_pulse.wav"

enum StrikeResult { MISS, HIT, COMPLETED }

signal powered_changed(powered: bool)
signal analyzed(link: MagicalLink)

@export var anchor_a_path: NodePath
@export var anchor_b_path: NodePath
## The behaviour this link produces. Authored links set it here; the LinkForge
## assigns it for player-built links.
@export var effect: LinkEffect
## Author the fount empty at ready (Case Minus One's dark lantern).
@export var drain_source_on_ready := false
## Optional element override; otherwise taken from the fount anchor.
@export var element: Element
## Journal fact granted when the strand is read (authored/discoverable links).
@export var fact_id: StringName = &""
## Journal fact required before Sight renders this strand at all.
@export var requires_fact: StringName = &""
## Journal text inscribed when read; falls back to the effect's own description.
@export_multiline var description := ""
## How hard the strand sags, as a fraction of its span.
@export var sag := 0.16

@export_group("Attunement")
## Seconds the read-pulse takes to travel the strand once (before easing).
@export var attune_period := 1.4
## Where along the strand (0-1) the resonance gate sits. The Sight indicator,
## the aim point, and the inscription all anchor here, so what the player
## strikes at is exactly what is judged.
@export var attune_window_center := 0.5
## Width of the gate's visual shimmer band in strand-phase units.
@export var attune_window_width := 0.16
## The strike judgment: a press lands if it falls within this many seconds of
## the comet crossing the gate centre - time-based, like any fair rhythm game.
@export var attune_grace := 0.12
## Clean beats required to read the working.
@export var attune_beats_needed := 3
## Optional tension ramp: the grace shrinks by this fraction per clean hit
## (floored at 40%). Masters' wards can start higher.
@export var attune_window_shrink := 0.0

var _anchor_a: LinkAnchor
var _anchor_b: LinkAnchor
var _source: ElementSource
var _player_built := false
var _fade := 0.0
var _fade_target := 0.0
var _ash := 0.0
var _ash_tween: Tween
var _time := 0.0
var _locally_analyzed := false
var _solid_mesh: ImmediateMesh
var _ghost_mesh: ImmediateMesh
var _knot_mesh: ImmediateMesh
var _attuning := false
var _attune_phase := 0.0
var _attune_hits := 0
var _hitstop := 0.0
var _sag_scale := 1.0
var _sag_tween: Tween
var _wobble := 0.0
var _ash_flash := 0.0
var _shake := 0.0
var _display_progress := 0.0
var _display_tween: Tween
var _detonation := -1.0
var _white_flash := 0.0
var _gate_flash := 0.0
var _was_approaching := false
var _ink_progress := 0.0
var _label: Label3D
var _label_alpha := 0.0
var _label_hold := 0.0
var _aimed_in_sight := false
var _beat_audio: AudioStreamPlayer3D
var _hum_audio: AudioStreamPlayer3D
var _pulse_audio: AudioStreamPlayer3D
var _quill_audio: AudioStreamPlayer3D
var _ink_embers: GPUParticles3D


## Assembles a link the player just forged (bypasses the scene NodePaths).
func setup_runtime(a: LinkAnchor, b: LinkAnchor, link_effect: LinkEffect) -> void:
	_anchor_a = a
	_anchor_b = b
	effect = link_effect
	_player_built = true


func _ready() -> void:
	add_to_group(GROUP)
	if _anchor_a == null:
		_anchor_a = get_node_or_null(anchor_a_path) as LinkAnchor
	if _anchor_b == null:
		_anchor_b = get_node_or_null(anchor_b_path) as LinkAnchor
	_build_strand_meshes()
	_build_label()
	# Anchors are children of their props and ready after this sibling node, so
	# resolve the fount and apply the effect a frame later when they are wired.
	_wire_source.call_deferred()


func _wire_source() -> void:
	var fount := source_anchor()
	if fount != null:
		_source = fount.source()
		if element == null:
			element = fount.provided_element()
	if _source != null:
		if drain_source_on_ready:
			_source.deplete_silently()
		_source.consumed.connect(_on_starved)
		_source.restored.connect(_on_rekindled)
	_ash = 0.0 if is_powered() else 1.0
	_apply_effect()
	if _player_built:
		# A forged link is self-evidently known: inscribe it at once as a receipt.
		_reveal_inscription()


func anchor_a() -> LinkAnchor:
	return _anchor_a


func anchor_b() -> LinkAnchor:
	return _anchor_b


## The fount anchor (the element provider), or null for a symmetric link.
func source_anchor() -> LinkAnchor:
	if _anchor_a != null and _anchor_a.provides_element():
		return _anchor_a
	if _anchor_b != null and _anchor_b.provides_element():
		return _anchor_b
	return null


## The anchor an effect acts on - the non-fount side, or B by convention.
func sink_anchor() -> LinkAnchor:
	var fount := source_anchor()
	if fount == null:
		return _anchor_b
	return _anchor_b if fount == _anchor_a else _anchor_a


func is_powered() -> bool:
	return _source == null or _source.available()


func is_analyzed() -> bool:
	if _player_built:
		return true
	if fact_id != &"":
		return JournalFacts.knows(fact_id)
	return _locally_analyzed


## True when Sight is allowed to render and aim this strand.
func sight_relevant() -> bool:
	return JournalFacts.satisfied(requires_fact)


func endpoint_a() -> Vector3:
	return _anchor_a.anchor_point() if _anchor_a != null else global_position


func endpoint_b() -> Vector3:
	return _anchor_b.anchor_point() if _anchor_b != null else global_position


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


## Cut the link: reverse the effect, spark at the gate, and free the strand.
func sever() -> void:
	if effect != null:
		effect.on_removed(self)
	if _source != null:
		if _source.consumed.is_connected(_on_starved):
			_source.consumed.disconnect(_on_starved)
		if _source.restored.is_connected(_on_rekindled):
			_source.restored.disconnect(_on_rekindled)
	_spawn_burst_at(gate_point(), 0.8)
	remove_from_group(GROUP)
	queue_free()


## The line inscribed in the world: authored text, else the effect's own words.
func inscription_text() -> String:
	if not description.is_empty():
		return description
	if effect != null:
		return effect.describe(self)
	return ""


## --- Reading: the resonance attunement minigame ---

func begin_attunement() -> void:
	if is_analyzed() or _attuning:
		return
	_attuning = true
	_attune_phase = 0.0
	_attune_hits = 0
	_was_approaching = true
	_set_display(0.0, true)
	_start_hum()


func end_attunement() -> void:
	_attuning = false
	_attune_hits = 0
	_stop_hum()


func is_attuning() -> bool:
	return _attuning


func attunement_phase() -> float:
	return _attune_phase


func attunement_progress() -> float:
	return float(_attune_hits) / maxf(float(attune_beats_needed), 1.0)


## The streak as the HUD shows it: hits land instantly, misses drain away.
func display_progress() -> float:
	return _display_progress


## The gate's world position - the aim point, the HUD diamond, the inscription
## anchor, and the strike target are all this same spot by construction.
func gate_point() -> Vector3:
	var from := endpoint_a()
	var to := endpoint_b()
	return _bezier(from, _control_point(from, to), to, attune_window_center)


func _effective_grace() -> float:
	return attune_grace * maxf(1.0 - attune_window_shrink * float(_attune_hits), 0.4)


## The comet decelerates into the gate and sprints the far side of the loop.
func _phase_speed_multiplier() -> float:
	var wrapped := absf(wrapf(_attune_phase - attune_window_center, -0.5, 0.5))
	return 0.45 + 1.35 * pow(wrapped * 2.0, 1.4)


## Signed seconds until the comet crosses the gate centre at its current
## speed: positive approaching, negative just past.
func _signed_time_to_gate() -> float:
	var signed_delta := wrapf(attune_window_center - _attune_phase, -0.5, 0.5)
	var speed := _phase_speed_multiplier() / maxf(attune_period, 0.05)
	return signed_delta / maxf(speed, 0.001)


## The strike judgment, and the HUD flare cue - identical by definition:
## a press right now lands iff this is true.
func is_phase_in_window() -> bool:
	return _attuning and absf(_signed_time_to_gate()) <= _effective_grace()


## 0-1 nearness (in time) of the read-pulse to the gate; drives the breathing
## shimmer, the HUD diamond, and the approach hum's pitch.
func window_glow() -> float:
	if not _attuning:
		return 0.0
	return clampf(1.0 - absf(_signed_time_to_gate()) / 0.45, 0.0, 1.0)


## Screen-space wobble for the HUD diamond after a miss.
func marker_shake() -> float:
	return sin(_time * 70.0) * _shake * 9.0


## A cast press during attunement. Strike as the read-pulse crosses the
## resonance window; a miss loses the rhythm and the streak drains away.
func strike() -> StrikeResult:
	if not _attuning:
		return StrikeResult.MISS
	if is_phase_in_window():
		_attune_hits += 1
		_hitstop = 0.12 if _attune_hits >= attune_beats_needed else 0.06
		_snap_taut()
		_spawn_burst_at(_comet_point(), 0.55)
		_play_beat(true)
		_set_display(attunement_progress(), true)
		if _attune_hits >= attune_beats_needed:
			end_attunement()
			_detonate()
			analyze()
			return StrikeResult.COMPLETED
		return StrikeResult.HIT
	_attune_hits = 0
	_wobble = 0.14
	_ash_flash = 0.22
	_shake = 1.0
	# The comet stumbles backward - the rhythm slipped through your fingers.
	_attune_phase = maxf(_attune_phase - 0.07, 0.0)
	_play_beat(false)
	_set_display(0.0, false)
	return StrikeResult.MISS


func _set_display(value: float, instant: bool) -> void:
	if _display_tween != null and _display_tween.is_valid():
		_display_tween.kill()
	if instant:
		_display_progress = value
		return
	_display_tween = create_tween()
	_display_tween.tween_property(self, "_display_progress", value, 0.4)


## The strand tightens under a clean strike, then relaxes.
func _snap_taut() -> void:
	if _sag_tween != null and _sag_tween.is_valid():
		_sag_tween.kill()
	_sag_tween = create_tween()
	_sag_tween.tween_property(self, "_sag_scale", 0.45, 0.07)
	_sag_tween.tween_property(self, "_sag_scale", 1.0, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _comet_point() -> Vector3:
	var from := endpoint_a()
	var to := endpoint_b()
	return _bezier(from, _control_point(from, to), to, _attune_phase)


func _spawn_burst_at(point: Vector3, burst_scale: float) -> void:
	var burst := BURST_SCENE.instantiate() as Node3D
	if burst == null:
		return
	var world: Node = get_tree().current_scene
	if world == null:
		world = get_tree().root
	world.add_child(burst)
	burst.global_position = point
	burst.scale = Vector3.ONE * burst_scale
	if burst.has_method(&"set_color") and element != null:
		burst.call(&"set_color", element.color)


## The final strike detonates: twin ember fronts race outward along the strand
## from the window while the whole thread flashes white, and the endpoints
## spark as the fronts arrive.
func _detonate() -> void:
	_detonation = 0.0
	_white_flash = 1.0
	var tween := create_tween()
	tween.tween_property(self, "_detonation", 1.0, 0.45)
	tween.parallel().tween_property(self, "_white_flash", 0.0, 0.55)
	tween.tween_callback(func() -> void:
		_spawn_burst_at(endpoint_a(), 0.7)
		_spawn_burst_at(endpoint_b(), 0.7)
		_detonation = -1.0)


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
	# Ash spreads from the dead fount toward the sink; the effect only flips when
	# the last of the element gutters out at the far end.
	_tween_ash(1.0, 0.5, _apply_effect)


func _on_rekindled() -> void:
	powered_changed.emit(true)
	# Feeding is the payoff beat: the element races down the strand, then the
	# effect answers - ignite first, flip when the light arrives.
	_tween_ash(0.0, 0.4, _apply_effect)


func _tween_ash(target: float, duration: float, finished: Callable) -> void:
	if _ash_tween != null and _ash_tween.is_valid():
		_ash_tween.kill()
	_ash_tween = create_tween()
	_ash_tween.tween_property(self, "_ash", target, duration)
	if not finished.is_null():
		_ash_tween.tween_callback(finished)


func _apply_effect() -> void:
	if effect != null:
		effect.set_active(self, is_powered())


func _play_beat(hit: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _beat_audio == null:
		_beat_audio = AudioStreamPlayer3D.new()
		_beat_audio.bus = &"SpellCast"
		add_child(_beat_audio)
	_beat_audio.global_position = gate_point()
	if hit:
		# The streak builds a chord: root, then the fifth, then the resolve.
		_beat_audio.stream = load(HIT_SOUNDS[clampi(_attune_hits - 1, 0, HIT_SOUNDS.size() - 1)])
	else:
		_beat_audio.stream = load(MISS_SOUND)
	_beat_audio.pitch_scale = 1.0
	_beat_audio.play()


## The .wav import loop flag is not honoured in this build, so force the loop in
## code - otherwise the sustained hum plays a single pass and falls silent. The
## imported loop_end is 0, so a bare LOOP_FORWARD makes a ZERO-LENGTH loop (dead
## silence); set the end to the full sample length in frames.
static func _looping_stream(path: String) -> AudioStream:
	var stream: AudioStream = load(path)
	var wav := stream as AudioStreamWAV
	if wav != null:
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


func _start_hum() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _hum_audio == null:
		_hum_audio = AudioStreamPlayer3D.new()
		_hum_audio.bus = &"SpellCast"
		_hum_audio.stream = _looping_stream(HUM_SOUND)
		# Carry the drone well past the strand so it reads across the room.
		_hum_audio.unit_size = 18.0
		_hum_audio.max_db = 6.0
		add_child(_hum_audio)
	_hum_audio.global_position = gate_point()
	_hum_audio.volume_db = -9.0
	_hum_audio.play()


## The hum rises toward the window and falls away after - timing by ear.
func _update_hum() -> void:
	if _hum_audio == null or not _hum_audio.playing:
		return
	var glow := window_glow()
	_hum_audio.pitch_scale = 0.72 + 0.55 * glow
	_hum_audio.volume_db = lerpf(-9.0, 2.0, glow)


## The pulse: a metronome tick each time the comet threads the gate, so the
## rhythm is audible and you can time the strike by ear instead of by eye.
func _play_gate_pulse() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _pulse_audio == null:
		_pulse_audio = AudioStreamPlayer3D.new()
		_pulse_audio.bus = &"SpellCast"
		_pulse_audio.stream = load(PULSE_SOUND)
		_pulse_audio.unit_size = 18.0
		_pulse_audio.max_db = 6.0
		add_child(_pulse_audio)
	_pulse_audio.global_position = gate_point()
	_pulse_audio.volume_db = 0.0
	_pulse_audio.play()


func _stop_hum() -> void:
	if _hum_audio != null:
		_hum_audio.stop()


## --- The world inscription: how Sight information is read ---

func _build_label() -> void:
	_label = Label3D.new()
	_label.text = ""
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
	_start_quill()
	_start_ink_embers()
	# Label3D has no visible_ratio; ink the text in character by character.
	var ink := create_tween()
	ink.tween_method(_set_ink_progress, 0.0, 1.0, 1.2)
	ink.tween_callback(_finish_ink)


func _set_ink_progress(progress: float) -> void:
	_ink_progress = progress
	if _label != null:
		var text := inscription_text()
		_label.text = text.substr(0, int(round(text.length() * progress)))


func _finish_ink() -> void:
	_stop_quill()
	if _ink_embers != null:
		_ink_embers.emitting = false


func _start_quill() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _quill_audio == null:
		_quill_audio = AudioStreamPlayer3D.new()
		_quill_audio.bus = &"SpellCast"
		_quill_audio.stream = _looping_stream(QUILL_SOUND)
		_quill_audio.volume_db = -10.0
		add_child(_quill_audio)
	_quill_audio.global_position = gate_point()
	_quill_audio.play()


func _stop_quill() -> void:
	if _quill_audio != null:
		_quill_audio.stop()


## A small ember emitter rides the leading edge of the reveal - the line looks
## written by a burning quill.
func _start_ink_embers() -> void:
	if _ink_embers == null:
		_ink_embers = GPUParticles3D.new()
		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3(0.0, 1.0, 0.0)
		mat.spread = 32.0
		mat.initial_velocity_min = 0.04
		mat.initial_velocity_max = 0.14
		mat.gravity = Vector3(0.0, 0.06, 0.0)
		mat.scale_min = 0.35
		mat.scale_max = 0.7
		var tint := element.color if element != null else Color(0.7, 0.75, 0.95)
		mat.color = Color(tint.r * 1.8, tint.g * 1.8, tint.b * 1.8, 1.0)
		_ink_embers.process_material = mat
		var quad := QuadMesh.new()
		quad.size = Vector2(0.014, 0.014)
		var quad_material := StandardMaterial3D.new()
		quad_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		quad_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		quad_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		quad_material.vertex_color_use_as_albedo = true
		quad_material.no_depth_test = true
		quad_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		quad.material = quad_material
		_ink_embers.draw_pass_1 = quad
		_ink_embers.amount = 14
		_ink_embers.lifetime = 0.5
		_ink_embers.local_coords = false
		_ink_embers.top_level = true
		add_child(_ink_embers)
	_ink_embers.emitting = true


func _update_label(delta: float) -> void:
	if _label == null:
		return
	var show := false
	if _label_hold > 0.0:
		_label_hold -= delta
		show = true
	elif is_analyzed() and _aimed_in_sight and _fade > 0.3:
		show = true
		_label.text = inscription_text()
	_label_alpha = move_toward(_label_alpha, 1.0 if show else 0.0, delta / 0.25)
	_label.visible = _label_alpha > 0.01
	if not _label.visible:
		return
	_label.modulate.a = _label_alpha * 0.95
	_label.outline_modulate.a = _label_alpha * 0.9
	var camera := get_viewport().get_camera_3d()
	var beside := Vector3.UP * 0.12
	var write_direction := Vector3.RIGHT
	if camera != null:
		write_direction = camera.global_transform.basis.x
		beside += write_direction * 0.55
	_label.global_position = gate_point() + beside
	if _ink_embers != null and _ink_embers.emitting:
		_ink_embers.global_position = _label.global_position \
			+ write_direction * lerpf(-0.19, 0.19, _ink_progress)


func _build_strand_meshes() -> void:
	_solid_mesh = ImmediateMesh.new()
	_ghost_mesh = ImmediateMesh.new()
	_knot_mesh = ImmediateMesh.new()
	# All passes depth-test, so the opaque shadow-puppet cutouts (and any solid
	# geometry) hide a link running behind them - no x-raying through shapes.
	for config: Array in [[_solid_mesh, false], [_ghost_mesh, false], [_knot_mesh, false]]:
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
		# Hitstop: the comet freezes for a beat after a clean strike.
		if _hitstop > 0.0:
			_hitstop -= delta
		else:
			_attune_phase = fmod(_attune_phase
				+ delta * _phase_speed_multiplier() / maxf(attune_period, 0.05), 1.0)
		# The gate pops and ticks at the exact crossing - the "now" the player
		# times to, seen AND heard, even when they do not strike.
		var approaching := _signed_time_to_gate() > 0.0
		if _was_approaching and not approaching:
			_gate_flash = 1.0
			_play_gate_pulse()
		_was_approaching = approaching
		_update_hum()
	elif _hitstop > 0.0:
		_hitstop -= delta
	_gate_flash = maxf(_gate_flash - delta * 3.5, 0.0)
	_wobble = maxf(_wobble - delta * 0.6, 0.0)
	_ash_flash = maxf(_ash_flash - delta, 0.0)
	_shake = maxf(_shake - delta * 4.0, 0.0)
	_fade = move_toward(_fade, _fade_target, delta / 0.18)
	_update_label(delta)
	if _fade <= 0.005:
		_solid_mesh.clear_surfaces()
		_ghost_mesh.clear_surfaces()
		_knot_mesh.clear_surfaces()
		return
	_rebuild_knots()
	var from := endpoint_a()
	var to := endpoint_b()
	if from.distance_to(to) < 0.05:
		return
	var control := _control_point(from, to)
	_rebuild(_solid_mesh, from, control, to, 1.0, false)
	_rebuild(_ghost_mesh, from, control, to, 0.16, true)


## --- The knotwork: a bound object looks tied ---
## The thread's language continued onto its endpoints: luminous loops lace
## around each anchored object in the link's colour, slowly creeping like rope
## under tension, ashen while the link starves. Bind is a knot made visible.
func _rebuild_knots() -> void:
	_knot_mesh.clear_surfaces()
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for anchor in [_anchor_a, _anchor_b]:
		if anchor != null and is_instance_valid(anchor):
			_draw_knot(anchor, camera.global_position)


func _draw_knot(anchor: LinkAnchor, cam: Vector3) -> void:
	const RINGS := 2
	const SEGMENTS := 28
	var center := anchor.anchor_point()
	var axis := (anchor.global_transform.basis * anchor.knot_axis).normalized()
	var u := axis.cross(Vector3.UP)
	if u.length() < 0.01:
		u = axis.cross(Vector3.RIGHT)
	u = u.normalized()
	var powered := is_powered()
	var base := marker_color() if powered else ASHEN
	for ring in RINGS:
		var dir := 1.0 if ring % 2 == 0 else -1.0
		# Alternate tilts interleave the loops like lacing.
		var normal := axis.rotated(u, 0.35 * dir)
		var ring_u := u
		var ring_v := normal.cross(ring_u).normalized()
		var radius := anchor.knot_radius * (1.0 + 0.14 * float(ring))
		var spin := _time * 0.3 * dir
		_knot_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for segment in SEGMENTS + 1:
			var angle := spin + TAU * float(segment) / float(SEGMENTS)
			var point := center + (ring_u * cos(angle) + ring_v * sin(angle)) * radius
			var tangent := -ring_u * sin(angle) + ring_v * cos(angle)
			var across := tangent.cross(cam - point)
			across = across.normalized() if across.length() > 0.001 else Vector3.UP
			# A slow pulse creeps around the loop; a starved knot barely glows.
			var glow := 0.55 + 0.45 * maxf(0.0, sin(angle * 2.0 - _time * 2.2 * dir))
			if not powered:
				glow = 0.3
			var alpha := _fade * 0.85 * (0.45 + 0.55 * glow)
			var width := 0.011 + 0.007 * glow
			var color := Color(base.r * (0.9 + glow), base.g * (0.9 + glow),
				base.b * (0.9 + glow), alpha)
			_knot_mesh.surface_set_color(color)
			_knot_mesh.surface_add_vertex(point + across * width)
			_knot_mesh.surface_set_color(color)
			_knot_mesh.surface_add_vertex(point - across * width)
		_knot_mesh.surface_end()


func _control_point(from: Vector3, to: Vector3) -> Vector3:
	var span := to - from
	var control := (from + to) * 0.5 \
		+ Vector3.DOWN * clampf(span.length() * sag * _sag_scale, 0.02, 0.9)
	if _wobble > 0.0:
		# A missed strike leaves the strand shuddering.
		var side := span.cross(Vector3.UP)
		side = side.normalized() if side.length() > 0.001 else Vector3.RIGHT
		control += side * sin(_time * 32.0) * _wobble
	return control


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
		# The ash wipe travels A to B when the fount dies (and back on feed).
		# A missed strike also washes the strand ashen for a beat.
		var ashen := t < _ash - 0.02 or _ash >= 1.0 or _ash_flash > 0.0
		var color := ASHEN if ashen else base
		var glow := 1.2
		var ripple := 0.0
		if powered and not ashen:
			# The pulse runs toward the drinker - direction is information.
			glow = 1.3 + 0.7 * maxf(0.0, sin(TAU * (t * 2.5 - _time * 1.3)))
		if _attuning:
			# The read-pulse comet with a trailing tail, rippling the strand.
			var lag := t - _attune_phase
			glow += 2.2 * exp(-pow(lag * 9.0, 2.0))
			if lag < 0.0 and lag > -0.35:
				glow += 1.1 * exp(lag * 10.0)
			ripple = 0.012 * exp(-pow(lag * 7.0, 2.0))
			# The gate's shimmer band breathes harder as the comet approaches
			# and pops at the exact crossing.
			if absf(t - attune_window_center) <= attune_window_width * 0.5:
				glow += 0.25 + 0.55 * window_glow() + 1.4 * _gate_flash
		if _detonation >= 0.0:
			# Twin ember fronts racing outward from the window.
			var front_up := attune_window_center + _detonation * (1.0 - attune_window_center)
			var front_down := attune_window_center * (1.0 - _detonation)
			glow += 2.6 * exp(-pow((t - front_up) * 10.0, 2.0))
			glow += 2.6 * exp(-pow((t - front_down) * 10.0, 2.0))
		if _white_flash > 0.0:
			color = color.lerp(Color.WHITE, _white_flash)
		var alpha := _fade * alpha_scale * clampf(0.7 + 0.5 * glow, 0.0, 1.0)
		if dashed and int(t * SEGMENTS) % 4 >= 2:
			alpha = 0.0
		var width := 0.03 + 0.02 * minf(glow, 2.5) + ripple
		var final := Color(color.r * (1.0 + glow * 1.6), color.g * (1.0 + glow * 1.6),
			color.b * (1.0 + glow * 1.6), alpha)
		mesh.surface_set_color(final)
		mesh.surface_add_vertex(point + across * width)
		mesh.surface_set_color(final)
		mesh.surface_add_vertex(point - across * width)
	mesh.surface_end()
	if not dashed and not is_analyzed():
		_add_gate_ring(mesh, from, control, to)


## The resonance gate: a small ring the comet visibly threads. This is the
## strike target - it sits exactly at the judged crossing point.
func _add_gate_ring(
	mesh: ImmediateMesh, from: Vector3, control: Vector3, to: Vector3
) -> void:
	var center := _bezier(from, control, to, attune_window_center)
	var tangent := _bezier(from, control, to, minf(attune_window_center + 0.05, 1.0)) \
		- _bezier(from, control, to, maxf(attune_window_center - 0.05, 0.0))
	tangent = tangent.normalized() if tangent.length() > 0.001 else Vector3.UP
	var side := tangent.cross(Vector3.UP)
	side = side.normalized() if side.length() > 0.001 else Vector3.RIGHT
	var up := tangent.cross(side).normalized()
	var powered := is_powered()
	var base := element.color if element != null else Color.WHITE
	var ring_color := base if powered or _attuning else ASHEN
	if _white_flash > 0.0:
		ring_color = ring_color.lerp(Color.WHITE, _white_flash)
	var brightness := 0.35
	if _attuning:
		brightness = 0.55 + 0.85 * window_glow() + 1.6 * _gate_flash
	var alpha := _fade * clampf(0.35 + 0.4 * brightness, 0.0, 1.0)
	var final := Color(ring_color.r * (0.8 + brightness),
		ring_color.g * (0.8 + brightness), ring_color.b * (0.8 + brightness), alpha)
	var inner := 0.042 + 0.014 * _gate_flash
	var outer := 0.06 + 0.02 * _gate_flash
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in 17:
		var angle := TAU * index / 16.0
		var spoke := side * cos(angle) + up * sin(angle)
		mesh.surface_set_color(final)
		mesh.surface_add_vertex(center + spoke * outer)
		mesh.surface_set_color(final)
		mesh.surface_add_vertex(center + spoke * inner)
	mesh.surface_end()


func _bezier(a: Vector3, control: Vector3, b: Vector3, t: float) -> Vector3:
	return a.lerp(control, t).lerp(control.lerp(b, t), t)
