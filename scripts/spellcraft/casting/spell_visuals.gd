class_name SpellVisuals

## Shared visual vocabulary for spell effects. The same recipe always looks the
## same, and the look reads back the runes: element sets color, "precise" runs
## thin and focused, "raging"/"wild" grow jagged spikes and flicker, size scales
## everything. Spells should feel like THEIR spell.


static func emissive(color: Color, energy: float = 1.8, alpha: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.roughness = 0.4
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


static func add_light(parent: Node3D, color: Color, energy: float = 1.2, light_range: float = 4.0) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false
	parent.add_child(light)
	return light


## Core orb visual: a sphere that wears its modifiers on its sleeve.
static func orb_node(def: SpellDefinition, radius: float) -> Node3D:
	var root := Node3D.new()
	var color := def.primary_color()

	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	var thin := def.thinness()
	sphere.radius = radius * (1.0 - thin * 0.5)
	sphere.height = sphere.radius * 2.0
	core.mesh = sphere
	core.material_override = emissive(color, 2.2)
	root.add_child(core)

	# Raging or wild spells grow jagged spikes; precise ones stay clean.
	var jagged := def.jaggedness()
	if jagged > 0.3:
		var spike_count := int(4 + jagged * 6.0)
		for i in spike_count:
			var spike := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = radius * 0.28
			cone.height = radius * (1.2 + jagged)
			spike.mesh = cone
			spike.material_override = emissive(color.lightened(0.2), 2.6)
			var dir := Vector3(
				sin(i * TAU / spike_count), cos(i * 2.4 + 0.7) * 0.8, cos(i * TAU / spike_count)).normalized()
			spike.position = dir * radius * 0.7
			# Cone mesh points +Y; arc-rotate it onto the spike direction.
			spike.quaternion = Quaternion(Vector3.UP, dir)
			root.add_child(spike)

	var halo := MeshInstance3D.new()
	var halo_mesh := SphereMesh.new()
	halo_mesh.radius = sphere.radius * 1.5
	halo_mesh.height = halo_mesh.radius * 2.0
	halo.mesh = halo_mesh
	halo.material_override = emissive(color, 0.8, 0.18)
	root.add_child(halo)

	add_light(root, color, 1.4 if not def.is_silent() else 0.7, 3.0 + radius * 4.0)
	return root


## Per-frame pulse/flicker driven by the recipe. Call from an effect's _process.
static func personality_scale(def: SpellDefinition, time: float) -> float:
	var pulse := 1.0 + sin(time * 6.0) * 0.05
	var jagged := def.jaggedness()
	if jagged > 0.2:
		# Deterministic flicker; unstable spells look like they might change their mind.
		pulse += sin(time * 31.0) * 0.06 * jagged + sin(time * 53.0 + 1.7) * 0.04 * jagged
	return pulse


## One-shot burst of shards, used for impacts, detonations, and crumbling scrolls.
static func spawn_burst(world: Node, pos: Vector3, color: Color, count: int = 24,
		spread: float = 3.2, life: float = 0.7) -> void:
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = count
	particles.lifetime = life
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = spread * 0.5
	particles.initial_velocity_max = spread
	particles.gravity = Vector3(0.0, -5.0, 0.0)
	particles.scale_amount_min = 0.04
	particles.scale_amount_max = 0.12
	var shard := BoxMesh.new()
	shard.material = emissive(color, 2.0)
	particles.mesh = shard
	world.add_child(particles)
	particles.global_position = pos
	particles.emitting = true
	var timer := world.get_tree().create_timer(life + 0.4)
	timer.timeout.connect(particles.queue_free)


## Comic floating text ("AIEEE!", "ribbit", "gnak!") that rises and fades.
static func floating_text(world: Node, pos: Vector3, text: String, color: Color = Color.WHITE,
		size: int = 48) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.004
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 8
	world.add_child(label)
	label.global_position = pos
	var tween := label.create_tween()
	tween.tween_property(label, "global_position", pos + Vector3.UP * 0.9, 1.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.1)
	tween.tween_callback(label.queue_free)


## A glowing cylinder between two points; the bone of beams and chain arcs.
static func segment(world: Node, from: Vector3, to: Vector3, color: Color,
		thickness: float, fade: float = 0.35) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		return
	var beam := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = thickness
	mesh.bottom_radius = thickness
	mesh.height = length
	beam.mesh = mesh
	beam.material_override = emissive(color, 2.4, 0.85)
	world.add_child(beam)
	beam.global_position = (from + to) * 0.5
	beam.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	var tween := beam.create_tween()
	tween.tween_property(beam, "transparency", 1.0, fade)
	tween.tween_callback(beam.queue_free)


## Short-lived expanding flash sphere for explosions.
static func spawn_flash(world: Node, pos: Vector3, color: Color, radius: float) -> void:
	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	flash.mesh = mesh
	flash.material_override = emissive(color, 3.0, 0.5)
	world.add_child(flash)
	flash.global_position = pos
	add_light(flash, color, 3.0, radius * 3.0)
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * radius * 10.0, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(flash, "transparency", 1.0, 0.22)
	tween.tween_callback(flash.queue_free)
